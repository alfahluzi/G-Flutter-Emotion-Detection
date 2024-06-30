import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:face_camera/face_camera.dart';
import 'package:flutter/material.dart';
import 'package:kepuasan_pelanggan/views/home_page.dart';

List<CameraDescription> cameras = [];
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
    await FaceCamera.initialize();
  } on CameraException catch (e) {
    // log("${e.code} ${e.description}");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Upload MySQL',
      home: HomePage(),
    );
  }
}
