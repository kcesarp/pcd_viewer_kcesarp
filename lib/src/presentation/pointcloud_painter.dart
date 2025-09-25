import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pcd_viewer_kcesarp/src/domain/models/point3d.dart';

class PointCloudPainter extends CustomPainter {
  final List<Point3D> points;
  final double yaw, pitch;
  final double scaleView;
  final bool showColors;
  final Color defaultColor;
  final double pointSize;

  PointCloudPainter(
      this.points,
      this.yaw,
      this.pitch,
      this.scaleView, {
        this.showColors = true,
        this.defaultColor = Colors.white,
        this.pointSize = 2.0,
      });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final cx = size.width / 2;
    final cy = size.height / 2;

    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.z < minZ) minZ = p.z;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
      if (p.z > maxZ) maxZ = p.z;
    }

    final dx = maxX - minX;
    final dy = maxY - minY;
    final dz = maxZ - minZ;
    final modelSize = math.max(dx, math.max(dy, dz));
    final baseScale =
        (math.min(size.width, size.height) / (modelSize == 0 ? 1 : modelSize)) * 0.5;

    final s = baseScale * scaleView;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    final paint = Paint()..style = PaintingStyle.fill;

    final transformed = <_TransformedPoint>[];
    for (final p in points) {
      final mx = p.x - (minX + dx / 2);
      final my = p.y - (minY + dy / 2);
      final mz = p.z - (minZ + dz / 2);

      final x1 = mx * cosYaw - mz * sinYaw;
      final z1 = mx * sinYaw + mz * cosYaw;
      final y1 = my;

      final y2 = y1 * cosPitch - z1 * sinPitch;
      final z2 = y1 * sinPitch + z1 * cosPitch;
      final x2 = x1;

      final cameraDistance = modelSize * 2.0 + 1.0;
      final projZ = z2 + cameraDistance;
      final px = x2 * s / projZ * (cameraDistance) + cx;
      final py = -y2 * s / projZ * (cameraDistance) + cy;

      transformed.add(_TransformedPoint(
        px,
        py,
        projZ,
        showColors ? p.color ?? defaultColor : defaultColor,
      ));
    }

    transformed.sort((a, b) => a.depth.compareTo(b.depth));

    for (final t in transformed) {
      paint.color = t.color;
      final sizePoint = (pointSize * (1.0 / (1 + t.depth / 1000))).clamp(0.5, 6.0);
      canvas.drawCircle(Offset(t.x, t.y), sizePoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PointCloudPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.scaleView != scaleView ||
        oldDelegate.showColors != showColors;
  }
}

class _TransformedPoint {
  final double x, y, depth;
  final Color color;
  _TransformedPoint(this.x, this.y, this.depth, this.color);
}
