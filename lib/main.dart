import 'package:flutter/material.dart';
import 'package:pcd_viewer_kcesarp/src/presentation/pcd_viewer_page.dart';

void main() {
  runApp(const PointCloudApp());
}

class PointCloudApp extends StatelessWidget {
  const PointCloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PCD Viewer',
      theme: ThemeData.dark(),
      home: const PcdViewerPage(),
    );
  }
}