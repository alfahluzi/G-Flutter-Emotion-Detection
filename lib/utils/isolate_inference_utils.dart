/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;
import 'package:kepuasan_pelanggan/utils/image_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class IsolateInference {
  static const String _debugName = "TFLITE_INFERENCE";
  final ReceivePort _receivePort = ReceivePort();
  late Isolate _isolate;
  late SendPort _sendPort;

  SendPort get sendPort => _sendPort;

  Future<void> start() async {
    // log("Start isolate inference");
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: _debugName,
    );
    // log("Waiting for port");
    _sendPort = await _receivePort.first;
  }

  Future<void> close() async {
    _isolate.kill();
    _receivePort.close();
  }

  static void entryPoint(SendPort sendPort) async {
    // log("Entry point");

    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final InferenceModel isolateModel in port) {
      // log("Inference model: $isolateModel");
      image_lib.Image? img;
      isolateModel.isCameraFrame()
          ? img = ImageUtils.convertCameraImage(isolateModel.cameraImage!)
          : img = isolateModel.image;

      // resize original image to match model shape.
      // log("Resize image");
      image_lib.Image imageInput = image_lib.copyResize(
        img!,
        width: isolateModel.inputShape[1],
        height: isolateModel.inputShape[2],
      );

      if (Platform.isAndroid && isolateModel.isCameraFrame()) {
        imageInput = image_lib.copyRotate(imageInput, angle: 90);
      }

      // Convert image to tensor
      // log("Convert image to tensor");
      final imageMatrix = List.generate(
        imageInput.height,
        (y) => List.generate(
          imageInput.width,
          (x) {
            final pixel = imageInput.getPixel(x, y);
            return [pixel.r, pixel.g, pixel.b];
          },
        ),
      );

      // Set tensor input [1, 224, 224, 3]
      // log("Set tensor input");
      final input = [imageMatrix];
      // Set tensor output [1, 1001]
      // log("Set tensor output");
      final output = [List<double>.filled(isolateModel.outputShape[1], 0)];
      // // Run inference
      // log("Run inference");
      Interpreter interpreter =
          Interpreter.fromAddress(isolateModel.interpreterAddress);
      interpreter.run(input, output);
      // Get first output tensor
      // log("Get first output tensor");
      final result = output.first;
      double maxScore = result.reduce((a, b) => a + b);
      // Set classification map {label: points}
      // log("Set classification map");
      var classification = <String, double>{};
      for (var i = 0; i < result.length; i++) {
        // Set label: points
        // log("Set label: points");
        if (result[i] != 0) {
          // Set label: points
          // log("Set label: points");
          // log(isolateModel.labels[i]);
          // log(result[i].toString());
          classification[isolateModel.labels[i]] =
              result[i].toDouble() / maxScore.toDouble();
        }
      }
      // Send classification map
      // log("Send classification map");
      isolateModel.responsePort.send(classification);
    }
  }
}

class InferenceModel {
  CameraImage? cameraImage;
  image_lib.Image? image;
  int interpreterAddress;
  List<String> labels;
  List<int> inputShape;
  List<int> outputShape;
  late SendPort responsePort;

  InferenceModel(
    this.cameraImage,
    this.image,
    this.interpreterAddress,
    this.labels,
    this.inputShape,
    this.outputShape,
  );

  // check if it is camera frame or still image
  bool isCameraFrame() {
    return cameraImage != null;
  }
}
