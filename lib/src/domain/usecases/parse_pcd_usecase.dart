import 'dart:typed_data';
import 'package:pcd_viewer_kcesarp/src/domain/models/point3d.dart';
import 'package:pcd_viewer_kcesarp/src/data/pcd_parser.dart';

/// Caso de uso para parsear archivos PCD.
/// Mantiene la lógica de separación de responsabilidades.
class ParsePcdUseCase {
  List<Point3D> call(String content, {Uint8List? binaryData}) {
    return PcdParser.parse(content, bytes: binaryData);
  }
}
