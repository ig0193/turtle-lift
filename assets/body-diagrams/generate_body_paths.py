#!/usr/bin/env python3
"""
generate_body_paths.py — converts the four traced SVGs into Dart point data.

Every path in these assets is a pure M/L/Z polyline, so each one reduces to an
ordered list of points. That removes the need for an SVG library at runtime and,
more importantly, makes per-segment fill and per-segment hit-testing trivial:
build a ui.Path from the points, fill it with whatever colour the segment's
state calls for, and use Path.contains for taps.

Emits body_paths.dart. Re-run after any SVG change. Fails loudly if a future
asset introduces curves, since the point list would then be wrong rather than
merely imprecise.
"""
import pathlib
import re
import sys

ASSETS = {
    "frontMale": "body-diagram-front.svg",
    "backMale": "body-diagram-back.svg",
    "frontFemale": "body-diagram-front-female.svg",
    "backFemale": "body-diagram-back-female.svg",
}

GROUP = re.compile(r'<g\b([^>]*class="muscle-segment"[^>]*)>(.*?)</g>', re.S)
ATTR = re.compile(r'([\w-]+)="([^"]*)"')
DPATH = re.compile(r'(?:^|\s)d="([^"]*)"')
DECO = re.compile(r'<path aria-hidden="true"[^>]*?(?:^|\s)d="([^"]*)"', re.S)
NUM = re.compile(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")


def points(d):
    cmds = set(re.findall(r"[A-Za-z]", d))
    extra = cmds - {"M", "L", "Z"}
    if extra:
        raise SystemExit(
            f"Path uses {sorted(extra)}. These assets are expected to be pure "
            "M/L/Z polylines; a curve cannot be represented as a point list. "
            "Either flatten the curve when exporting, or switch the renderer "
            "to a real path parser."
        )
    n = [float(x) for x in NUM.findall(d)]
    return list(zip(n[0::2], n[1::2]))


def fmt(pts):
    return "[" + ",".join(f"{x:g},{y:g}" for x, y in pts) + "]"


def main(src=".", out="."):
    src, out = pathlib.Path(src), pathlib.Path(out)
    lines = [
        "// GENERATED FILE -- do not edit by hand.",
        "// Produced by generate_body_paths.py from the traced body-diagram SVGs.",
        "//",
        "// Every segment is a flat list of x,y pairs. Build a ui.Path from it for",
        "// filling, and use Path.contains(offset) for hit-testing a tap. No SVG",
        "// library needed at runtime.",
        "//",
        "// Sketch of the intended use:",
        "//",
        "//   final asset = kBodyAssets[isFemale ? 'frontFemale' : 'frontMale']!;",
        "//",
        "//   // in CustomPainter.paint, after scaling canvas to asset.viewBox:",
        "//   for (final seg in asset.segments) {",
        "//     canvas.drawPath(seg.toPath(), Paint()..color = colourFor(seg.id));",
        "//   }",
        "//",
        "//   // hit-testing a tap, in the same scaled coordinate space:",
        "//   final hit = asset.segments.lastWhere(",
        "//     (s) => s.toPath().contains(localPosition),",
        "//     orElse: () => null,",
        "//   );",
        "//",
        "// Cache the built Paths rather than calling toPath() every frame.",
        "// Segment ids match muscle_taxonomy.dart exactly, so colourFor() can key",
        "// straight off the session's primary/secondary muscle sets.",
        "",
        "import 'dart:ui';",
        "",
        "class BodySegment {",
        "  /// '<muscleGroup>/<subMuscleGroup>' -- matches muscle_taxonomy.dart.",
        "  final String id;",
        "  final String group;",
        "  final String label;",
        "  /// Flat x,y pairs. One entry per sub-path; a segment usually has two",
        "  /// (left and right side), and they fill and hit-test as one unit.",
        "  final List<List<double>> outlines;",
        "  const BodySegment(this.id, this.group, this.label, this.outlines);",
        "",
        "  Path toPath() {",
        "    final p = Path();",
        "    for (final o in outlines) {",
        "      if (o.length < 4) continue;",
        "      p.moveTo(o[0], o[1]);",
        "      for (var i = 2; i < o.length; i += 2) {",
        "        p.lineTo(o[i], o[i + 1]);",
        "      }",
        "      p.close();",
        "    }",
        "    return p;",
        "  }",
        "}",
        "",
        "class BodyAsset {",
        "  final Size viewBox;",
        "  /// Non-interactive silhouette (head, neck, knee tie-in). Draw first, muted.",
        "  final List<List<double>> decorative;",
        "  final List<BodySegment> segments;",
        "  const BodyAsset(this.viewBox, this.decorative, this.segments);",
        "}",
        "",
    ]

    total_seg = 0
    total_pts = 0
    body = ["const Map<String, BodyAsset> kBodyAssets = {"]

    for key, fname in ASSETS.items():
        text = (src / fname).read_text()
        vb = [float(x) for x in re.search(r'viewBox="([^"]+)"', text).group(1).split()]
        deco = [points(d) for d in DECO.findall(text)]

        merged = {}
        for m in GROUP.finditer(text):
            a = dict(ATTR.findall(m.group(1)))
            sid = f'{a["data-muscle-group"]}/{a["data-sub-muscle-group"]}'
            entry = merged.setdefault(
                sid, {"group": a["data-muscle-group"], "label": a.get("data-label", ""), "out": []}
            )
            entry["out"].extend(points(d) for d in DPATH.findall(m.group(2)))

        body.append(f"  '{key}': BodyAsset(")
        body.append(f"    const Size({vb[2]:g}, {vb[3]:g}),")
        body.append("    const [" + ",".join(fmt(p) for p in deco) + "],")
        body.append("    const [")
        for sid, e in sorted(merged.items()):
            outs = ",".join(fmt(p) for p in e["out"])
            body.append(
                f"      BodySegment('{sid}', '{e['group']}', "
                f"'{e['label'].replace(chr(39), chr(92) + chr(39))}', [{outs}]),"
            )
            total_seg += 1
            total_pts += sum(len(p) for p in e["out"])
        body.append("    ],")
        body.append("  ),")

    body.append("};")
    (out / "body_paths.dart").write_text("\n".join(lines + body) + "\n")
    kb = (out / "body_paths.dart").stat().st_size // 1024
    print(f"OK  4 assets, {total_seg} segments, {total_pts} points -> body_paths.dart ({kb}KB)")


if __name__ == "__main__":
    main(*sys.argv[1:])
