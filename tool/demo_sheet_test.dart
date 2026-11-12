// Renders every exercise demonstration to contact sheets, for reviewing the
// drawn figures by eye. Not part of the suite (it lives in tool/, which
// `flutter test` does not run by default).
//
//   DEMO_SHEET_DIR=/tmp/sheets flutter test tool/demo_sheet_test.dart
//
// Each row is one exercise: start, a quarter of the way, the peak, and the
// two-position still that Reduce Motion shows.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/demo/demo_catalogue.dart';
import 'package:turtle_lift/src/demo/demo_painter.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';

void main() {
  testWidgets('demo contact sheets', (tester) async {
    final out = Platform.environment['DEMO_SHEET_DIR'] ?? 'build/demo_sheets';
    final only = Platform.environment['DEMO_ONLY'];
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
      final fontFile = File('$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
      if (fontFile.existsSync()) {
        final loader = FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(fontFile.readAsBytesSync())));
        await loader.load();
      }
      final raw = File('assets/exercises/exercises.json').readAsStringSync();
      var list = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
      if (only != null) {
        final ids = only.split(',');
        list = list.where((e) => ids.any((id) => (e['animation'] as String) == id || e['id'] == id)).toList();
      }
      const tileW = 240.0, tileH = 160.0, labelW = 200.0, perSheet = 12;
      for (var sheet = 0; sheet * perSheet < list.length; sheet++) {
        final chunk = list.skip(sheet * perSheet).take(perSheet).toList();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final size = Size(labelW + tileW * 4, tileH * chunk.length);
        canvas.drawRect(Offset.zero & size, Paint()..color = AppPalette.pageBackground);
        for (var r = 0; r < chunk.length; r++) {
          final e = chunk[r];
          final motion = demoMotionFor(e['animation'] as String?)!;
          final tp = TextPainter(
            text: TextSpan(
              text: '${e['name']}\n${e['animation']} / ${e['animationGear']}',
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: AppPalette.textPrimary),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: labelW - 10);
          tp.paint(canvas, Offset(6, r * tileH + 8));
          final peakT = motion.keys[motion.peak].t;
          final phases = <double>[0, peakT / 2, peakT, -1];
          for (var c = 0; c < 4; c++) {
            final rect = Rect.fromLTWH(labelW + c * tileW + 4, r * tileH + 4, tileW - 8, tileH - 8);
            canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = AppPalette.surface);
            canvas.save();
            canvas.translate(rect.left, rect.top);
            ExerciseDemoPainter(
              motion: motion,
              gear: e['animationGear']! as String,
              primary: (e['primary']! as List).cast<String>().toSet(),
              phase: phases[c] < 0 ? 0 : phases[c],
              still: phases[c] < 0,
              holdProgress: 0.6,
            ).paint(canvas, rect.size);
            canvas.restore();
          }
        }
        final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/sheet_${sheet.toString().padLeft(2, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}
