import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _primary = Color(0xFF0B6E99);
const _secondary = Color(0xFF14A38B);
const _sand = Color(0xFFF2C14E);
const _white = Colors.white;

Future<Uint8List> _renderIcon({required bool transparentBackground}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1024, 1024));

  if (!transparentBackground) {
    const rect = Rect.fromLTWH(0, 0, 1024, 1024);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(232));
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_primary, _secondary],
      ).createShader(rect);
    canvas.drawRRect(rrect, background);

    final wavePaint = Paint()
      ..color = _white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(164, 760)
        ..cubicTo(300, 700, 452, 826, 608, 760)
        ..cubicTo(724, 712, 820, 728, 908, 784),
      wavePaint,
    );
  }

  final fishPaint = Paint()..color = _white;
  final fishBody = Path()
    ..moveTo(290, 472)
    ..quadraticBezierTo(390, 360, 558, 378)
    ..quadraticBezierTo(674, 390, 730, 474)
    ..quadraticBezierTo(676, 560, 560, 574)
    ..quadraticBezierTo(390, 594, 290, 472)
    ..close();
  canvas.drawPath(fishBody, fishPaint);

  final tail = Path()
    ..moveTo(688, 474)
    ..lineTo(834, 358)
    ..lineTo(834, 592)
    ..close();
  canvas.drawPath(tail, fishPaint);

  final hookStroke = Paint()
    ..color = _sand
    ..style = PaintingStyle.stroke
    ..strokeWidth = transparentBackground ? 30 : 28
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final hookTopY = transparentBackground ? 200.0 : 214.0;
  final hookBottomY = transparentBackground ? 414.0 : 430.0;
  final hookPath = Path()
    ..moveTo(510, hookTopY)
    ..lineTo(510, hookBottomY)
    ..quadraticBezierTo(500, 500, 420, 540);
  canvas.drawPath(hookPath, hookStroke);
  canvas.drawCircle(
    Offset(510, hookTopY - 24),
    transparentBackground ? 34 : 30,
    Paint()..color = _sand,
  );

  final cutWave = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeWidth = transparentBackground ? 26 : 22
    ..strokeCap = StrokeCap.round;
  canvas.saveLayer(const Rect.fromLTWH(0, 0, 1024, 1024), Paint());
  canvas.drawPath(fishBody, fishPaint);
  canvas.drawPath(tail, fishPaint);
  canvas.drawPath(
    Path()
      ..moveTo(398, 500)
      ..quadraticBezierTo(482, 468, 560, 504)
      ..quadraticBezierTo(628, 536, 696, 500),
    cutWave,
  );
  canvas.restore();

  if (transparentBackground) {
    final subtleWave = Paint()
      ..color = _white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(276, 760)
        ..quadraticBezierTo(398, 716, 512, 760)
        ..quadraticBezierTo(638, 804, 756, 760),
      subtleWave,
    );
  }

  final image = await recorder.endRecording().toImage(1024, 1024);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('gera os assets oficiais de launcher icon', (tester) async {
    late final Uint8List fullIcon;
    late final Uint8List foregroundIcon;

    await tester.runAsync(() async {
      fullIcon = await _renderIcon(transparentBackground: false);
      foregroundIcon = await _renderIcon(transparentBackground: true);
    });

    final fullIconFile = File('assets/icon/app_icon.png');
    final foregroundIconFile = File('assets/icon/app_icon_foreground.png');

    fullIconFile.writeAsBytesSync(fullIcon);
    foregroundIconFile.writeAsBytesSync(foregroundIcon);

    expect(fullIconFile.existsSync(), isTrue);
    expect(foregroundIconFile.existsSync(), isTrue);
    expect(fullIcon.lengthInBytes, greaterThan(0));
    expect(foregroundIcon.lengthInBytes, greaterThan(0));
  });
}
