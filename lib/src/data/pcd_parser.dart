import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pcd_viewer_kcesarp/src/domain/models/point3d.dart';

class PcdParser {
  /// Parsea un archivo PCD. `content` debe contener al menos la cabecera en ASCII.
  /// Si es binary, pase también `bytes` (raw file bytes) para leer la sección binaria.
  static List<Point3D> parse(String content, {Uint8List? bytes}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final header = <String, String>{};
    final fields = <String>[];

    // Detectar DATA y construir header lines
    int headerLineCount = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      headerLineCount++;
      if (line.toLowerCase().startsWith('fields')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length > 1) fields.addAll(parts.sublist(1));
      }

      if (line.toLowerCase().startsWith('data')) {
        header['DATA'] = line.split(RegExp(r'\s+')).elementAt(1);
        break;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) header[parts[0].toUpperCase()] = parts.sublist(1).join(' ');
    }

    final dataMode = (header['DATA'] ?? 'ascii').toLowerCase();
    final pointCount = int.tryParse(header['POINTS'] ?? '') ?? int.tryParse(header['WIDTH'] ?? '') ?? 0;

    final sizes = (header['SIZE']?.split(RegExp(r'\s+')).map((s) => int.tryParse(s) ?? 0).toList()) ?? [];
    final types = (header['TYPE']?.split(RegExp(r'\s+')) ?? []).map((s) => s.toUpperCase()).toList();

    // map field -> index for ASCII parsing
    final fieldIndex = <String,int>{};
    for (var i = 0; i < fields.length; i++) fieldIndex[fields[i]] = i;

    if (dataMode == 'ascii') {
      // parse ascii lines after headerLineCount
      final parsed = <Point3D>[];
      for (var i = headerLineCount; i < lines.length; i++) {
        final raw = lines[i].trim();
        if (raw.isEmpty || raw.startsWith('#')) continue;
        final parts = raw.split(RegExp(r'\s+'));
        if (parts.length < 3) continue;
        // map parts according to fields
        double getD(String name, [double fallback = 0.0]) {
          final idx = fieldIndex[name];
          if (idx == null || idx >= parts.length) return fallback;
          return double.tryParse(parts[idx]) ?? fallback;
        }

        final x = getD('x');
        final y = getD('y');
        final z = getD('z');

        Color? color;
        if (fieldIndex.containsKey('rgb')) {
          final token = parts[fieldIndex['rgb']!];
          final d = double.tryParse(token);
          if (d != null) {
            final packed = _floatToUint32(d);
            color = _colorFromPacked(packed);
          } else {
            final iRgb = int.tryParse(token);
            if (iRgb != null) color = _colorFromPacked(iRgb);
          }
        } else if (fieldIndex.containsKey('r') && fieldIndex.containsKey('g') && fieldIndex.containsKey('b')) {
          final r = (double.tryParse(parts[fieldIndex['r']!]) ?? 0.0).round().clamp(0,255);
          final g = (double.tryParse(parts[fieldIndex['g']!]) ?? 0.0).round().clamp(0,255);
          final b = (double.tryParse(parts[fieldIndex['b']!]) ?? 0.0).round().clamp(0,255);
          color = Color.fromARGB(255, r, g, b);
        }

        parsed.add(Point3D(x,y,z,color));
      }
      return parsed;
    }

    if (dataMode.startsWith('binary')) {
      if (bytes == null) throw Exception('Binary PCD requires passing raw bytes');

      // encontrar offset exacto (bytes) del final de la cabecera
      int headerByteOffset = _findHeaderEnd(bytes);

      final view = ByteData.sublistView(bytes, headerByteOffset);

      // compute point stride
      int stride = 0;
      if (sizes.isNotEmpty) {
        stride = sizes.reduce((a, b) => a + b);
      } else {
        // fallback assume float x,y,z
        stride = 12;
      }

      final parsed = <Point3D>[];
      int offset = 0;
      for (var p = 0; p < pointCount; p++) {
        if (offset + stride > view.lengthInBytes) break;

        double x = 0, y = 0, z = 0;
        Color? color;

        int localOffset = offset;
        for (var f = 0; f < fields.length; f++) {
          final fname = fields[f];
          final fsize = (f < sizes.length) ? sizes[f] : 4;
          final ftype = (f < types.length) ? types[f] : 'F';

          if (fname == 'x' && fsize == 4 && ftype == 'F') {
            x = view.getFloat32(localOffset, Endian.little);
          } else if (fname == 'y' && fsize == 4 && ftype == 'F') {
            y = view.getFloat32(localOffset, Endian.little);
          } else if (fname == 'z' && fsize == 4 && ftype == 'F') {
            z = view.getFloat32(localOffset, Endian.little);
          } else if (fname.toLowerCase() == 'rgb' && fsize == 4) {
            // could be float packed or uint32
            if (ftype == 'F') {
              final f = view.getFloat32(localOffset, Endian.little);
              final packed = _floatToUint32(f);
              color = _colorFromPacked(packed);
            } else if (ftype == 'U' || ftype == 'I') {
              final packed = view.getUint32(localOffset, Endian.little);
              color = _colorFromPacked(packed);
            }
          } else if ((fname == 'r' || fname == 'g' || fname == 'b') && fsize == 1) {
            final val = view.getUint8(localOffset);
            int r = 0, g = 0, b = 0;
            if (fname == 'r') r = val;
            if (f + 1 < fields.length && fields[f + 1] == 'g') {
              g = view.getUint8(localOffset + fsize);
            }
            if (f + 2 < fields.length && fields[f + 2] == 'b') {
              b = view.getUint8(localOffset + fsize * 2);
            }
            color = Color.fromARGB(255, r, g, b);
          }

          localOffset += fsize;
        }

        parsed.add(Point3D(x, y, z, color));
        offset += stride;
      }

      return parsed;
    }

    throw Exception('Unsupported PCD data mode: $dataMode');
  }

  /// Encuentra dónde termina la cabecera textual y empieza el payload binario.
  static int _findHeaderEnd(Uint8List bytes) {
    final marker = utf8.encode('\nDATA');
    for (int i = 0; i < bytes.length - marker.length; i++) {
      bool match = true;
      for (int j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        // avanzar hasta el próximo '\n' después de DATA ...
        for (int k = i + marker.length; k < bytes.length; k++) {
          if (bytes[k] == 0x0A) {
            return k + 1;
          }
        }
      }
    }
    throw FormatException('No se encontró la línea DATA en el header PCD');
  }

  static int _floatToUint32(double f) {
    final bd = ByteData(4);
    bd.setFloat32(0, f, Endian.little);
    return bd.getUint32(0, Endian.little);
  }

  static Color _colorFromPacked(int packed) {
    final r = (packed >> 16) & 0xFF;
    final g = (packed >> 8) & 0xFF;
    final b = packed & 0xFF;
    return Color.fromARGB(255, r, g, b);
  }
}