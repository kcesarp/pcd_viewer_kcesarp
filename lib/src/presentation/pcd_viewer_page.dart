import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:pcd_viewer_kcesarp/src/domain/models/point3d.dart';
import 'package:pcd_viewer_kcesarp/src/domain/usecases/parse_pcd_usecase.dart';
import 'pointcloud_painter.dart';

class PcdViewerPage extends StatefulWidget {
  const PcdViewerPage({super.key});

  @override
  State<PcdViewerPage> createState() => _PcdViewerPageState();
}

class _PcdViewerPageState extends State<PcdViewerPage> {
  List<Point3D> points = [];
  bool loading = false;
  String status = 'No file loaded';

  double yaw = 0.0;
  double pitch = 0.0;
  double scaleView = 1.0;
  Offset lastFocal = Offset.zero;

  void resetView() {
    setState(() {
      yaw = 0;
      pitch = 0;
      scaleView = 1.0;
    });
  }

  Future<void> pickAndLoadPcd() async {
    setState(() {
      loading = true;
      status = 'Opening file picker...';
      points = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pcd'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          loading = false;
          status = 'No file chosen';
        });
        return;
      }

      Uint8List bytes;
      if (kIsWeb) {
        bytes = result.files.single.bytes!;
      } else {
        final path = result.files.single.path!;
        bytes = await File(path).readAsBytes();
      }

      final contentStr = String.fromCharCodes(bytes);
      final usecase = ParsePcdUseCase();
      final parsed = usecase(contentStr, binaryData: bytes);

      setState(() {
        points = parsed;
        loading = false;
        status = 'Loaded ${points.length} points';
      });
    } catch (e) {
      setState(() {
        loading = false;
        status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PCD Viewer - rotate & zoom'),
        actions: [
          IconButton(
            onPressed: loading ? null : pickAndLoadPcd,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            onPressed: points.isEmpty
                ? null
                : () {
              setState(() {
                final n = (points.length / 200000).ceil();
                if (n <= 1) return;
                points = [
                  for (var i = 0; i < points.length; i += n) points[i]
                ];
                status = 'Downsampled to ${points.length} points';
              });
            },
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Downsample (fast)',
          ),
          IconButton(
            onPressed: resetView,
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Reset view',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                scaleView *= 1.2;
              });
            },
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom in',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                scaleView /= 1.2;
              });
            },
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom out',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onDoubleTap: resetView,
              onScaleStart: (details) {
                lastFocal = details.focalPoint;
              },
              onScaleUpdate: (details) {
                setState(() {
                  if (details.scale != 1.0) {
                    scaleView *= details.scale;
                    scaleView = scaleView.clamp(0.01, 50.0);
                  } else {
                    final delta = details.focalPoint - lastFocal;
                    lastFocal = details.focalPoint;

                    yaw += delta.dx * 0.01;
                    pitch += delta.dy * 0.01;

                    pitch = pitch.clamp(-3.13 / 2, 3.13 / 2);
                  }
                });
              },
              child: Container(
                color: Colors.black,
                child: CustomPaint(
                  painter: PointCloudPainter(
                    points,
                    yaw,
                    pitch,
                    scaleView,
                    showColors: true,
                  ),
                  child: Center(
                    child: loading
                        ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(status),
                      ],
                    )
                        : Text(''),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.grey.shade900,
            child: Row(
              children: [
                const Text('Points: '),
                Text('${points.length}'),
                const Spacer(),
                const Text('Rotate: drag • Zoom: pinch • Reset: double tap'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
