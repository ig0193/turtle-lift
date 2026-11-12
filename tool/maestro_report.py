"""Merges per-flow JUnit files from tool/maestro_run.sh into junit.xml and
report.html, and prints a pass/fail table. Exit 1 if any flow failed.

  python3 tool/maestro_report.py build/maestro/<device>
"""
import html
import pathlib
import sys
import xml.etree.ElementTree as ET

out = pathlib.Path(sys.argv[1])
rows = []
merged = ET.Element('testsuites', name=out.name)
for f in sorted((out / 'junit').glob('*.xml')):
    try:
        root = ET.parse(f).getroot()
    except ET.ParseError:
        rows.append((f.stem, 'ERROR', 'unreadable JUnit file'))
        continue
    for case in root.iter('testcase'):
        fail = case.find('failure')
        err = case.find('error')
        bad = fail if fail is not None else err
        msg = '' if bad is None else (bad.get('message') or bad.text or '').strip()
        rows.append((case.get('name') or f.stem, 'FAIL' if bad is not None else 'PASS', msg))
    for suite in root.iter('testsuite'):
        merged.append(suite)
ET.ElementTree(merged).write(out / 'junit.xml', encoding='utf-8', xml_declaration=True)

width = max([len(r[0]) for r in rows] + [4])
print(f"{'flow'.ljust(width)}  result")
for name, result, msg in rows:
    print(f"{name.ljust(width)}  {result}" + (f"  {msg.splitlines()[0][:120]}" if msg else ''))

body = ''.join(
    f"<tr class='{r.lower()}'><td>{html.escape(n)}</td><td>{r}</td>"
    f"<td><pre>{html.escape(m)}</pre></td></tr>" for n, r, m in rows)
(out / 'report.html').write_text(
    "<!doctype html><meta charset='utf-8'><title>Maestro: "
    f"{html.escape(out.name)}</title><style>body{{font:14px system-ui;margin:16px}}"
    "td{border-bottom:1px solid #ccc;padding:4px 8px;vertical-align:top}"
    ".pass td:nth-child(2){color:#060}.fail td:nth-child(2),.error td:nth-child(2){color:#b00}"
    f"pre{{white-space:pre-wrap;margin:0}}</style><h1>{html.escape(out.name)}</h1>"
    f"<table><tr><th>Flow</th><th>Result</th><th>Detail</th></tr>{body}</table>")
sys.exit(0 if rows and all(r[1] == 'PASS' for r in rows) else 1)
