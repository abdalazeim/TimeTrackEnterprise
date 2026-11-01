import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// لوحة توقيع خفيفة تُصدّر التوقيع كصورة PNG بترميز data URL.
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  Size _size = const Size(600, 200);

  bool get isEmpty => _strokes.isEmpty;

  void resize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _size = size;
  }

  void start(Offset point) {
    _strokes.add(<Offset>[point]);
    notifyListeners();
  }

  void extend(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  Future<String> toPngDataUrl() async {
    const scale = 2.0;
    final width = (_size.width * scale).round().clamp(1, 4096);
    final height = (_size.height * scale).round().clamp(1, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _size.width, _size.height),
      Paint()..color = Colors.white,
    );

    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          1.6,
          Paint()..color = const Color(0xFF111827),
        );
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return '';
    return 'data:image/png;base64,'
        '${base64Encode(bytes.buffer.asUint8List())}';
  }
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({required this.controller, super.key, this.height = 180});

  final SignaturePadController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          controller.resize(constraints.biggest);
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => controller.start(details.localPosition),
              onPanUpdate: (details) =>
                  controller.extend(details.localPosition),
              child: CustomPaint(
                painter: _SignaturePainter(controller._strokes),
                size: constraints.biggest,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          1.6,
          Paint()..color = const Color(0xFF111827),
        );
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
