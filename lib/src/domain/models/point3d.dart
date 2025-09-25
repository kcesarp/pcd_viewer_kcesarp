import 'package:flutter/material.dart';

class Point3D {
  final double x, y, z;
  final Color? color;
  const Point3D(this.x, this.y, this.z, [this.color]);

  @override
  String toString() => 'Point3D($x,$y,$z, color=$color)';
}