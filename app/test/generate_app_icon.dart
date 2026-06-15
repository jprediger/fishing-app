// Gerador do ícone do app (não é teste de regressão — nome sem `_test` para
// ficar fora da suíte). Rasteriza o SVG `assets/icon/icone_pescaja.svg`
// (reproduzido fielmente no Canvas) num PNG 1024×1024 em `assets/icon/app_icon.png`.
//
// Regenerar: flutter test test/generate_app_icon.dart
// Depois aplicar nas plataformas: dart run flutter_launcher_icons

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bg = Color(0xFF0D2B45);
const _teal = Color(0xFF2A9D8F);
const _gold = Color(0xFFE9C46A);
const _wave = Color(0x995DD4C8); // #5DD4C8 com ~60% de opacidade

void _paintIcon(Canvas canvas) {
  // SVG em espaço 512×512; escalamos 2x para 1024 (mantém larguras de traço).
  canvas.scale(2.0);

  // Fundo arredondado.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 512, 512),
      const Radius.circular(112),
    ),
    Paint()..color = _bg,
  );

  // Corpo do peixe (elipse) + cauda (triângulo).
  final fishPaint = Paint()..color = _teal;
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(236, 296), width: 240, height: 144),
    fishPaint,
  );
  canvas.drawPath(
    Path()
      ..moveTo(356, 296)
      ..lineTo(460, 210)
      ..lineTo(460, 382)
      ..close(),
    fishPaint,
  );

  // Olho.
  canvas.drawCircle(const Offset(152, 280), 28, Paint()..color = Colors.white);
  canvas.drawCircle(const Offset(152, 280), 14, Paint()..color = _bg);

  // Linha + anzol (dourado).
  final goldStroke = Paint()
    ..color = _gold
    ..strokeWidth = 14
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(const Offset(256, 80), const Offset(256, 232), goldStroke);
  canvas.drawCircle(const Offset(256, 80), 18, Paint()..color = _gold);
  canvas.drawPath(
    Path()
      ..moveTo(256, 228)
      ..quadraticBezierTo(256, 268, 210, 278),
    Paint()
      ..color = _gold
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );

  // Onda da água.
  canvas.drawPath(
    Path()
      ..moveTo(180, 320)
      ..quadraticBezierTo(220, 305, 256, 320)
      ..quadraticBezierTo(292, 335, 330, 320),
    Paint()
      ..color = _wave
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );
}

void main() {
  testWidgets('gera assets/icon/app_icon.png a partir do SVG', (tester) async {
    late final Uint8List pngBytes;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1024, 1024));
      _paintIcon(canvas);
      final image = await recorder.endRecording().toImage(1024, 1024);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      pngBytes = data!.buffer.asUint8List();
    });

    final file = File('assets/icon/app_icon.png');
    file.writeAsBytesSync(pngBytes);

    expect(file.existsSync(), isTrue);
    expect(pngBytes.lengthInBytes, greaterThan(0));
  });
}
