import 'dart:convert';
import 'dart:developer';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:kepuasan_pelanggan/main.dart';
import 'package:kepuasan_pelanggan/views/emotion_detection_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class KodeDaerah {
  final String kode;
  final String namaDaerah;

  KodeDaerah({required this.kode, required this.namaDaerah});

  factory KodeDaerah.fromJson(Map<String, dynamic> json) {
    return KodeDaerah(
      kode: json['kode'] as String,
      namaDaerah: json['nama_daerah'] as String,
    );
  }
}

class _HomePageState extends State<HomePage> {
  String message = "...";
  bool onLoading = false;
  bool canContinue = false;
  String? selectedAreaCode;
  String? selectedModel;

  List<DropdownMenuItem> listAreaCode = [];
  List<DropdownMenuItem> listModel = [
    const DropdownMenuItem(
      value: "emotion_model.tflite",
      child: Text("emotion_model Default"),
    ),
    const DropdownMenuItem(
      value: "emotion_model (0).tflite",
      child: Text("emotion_model (Acc 50% RGB)"),
    ),
    const DropdownMenuItem(
      value: "emotion_model (1).tflite",
      child: Text("emotion_model (Acc 50% Grayscale)"),
    ),
    const DropdownMenuItem(
      value: "emotion_model (2).tflite",
      child: Text("emotion_model (Acc 60% Grayscale)"),
    ),
    const DropdownMenuItem(
      value: "emotion_model (3).tflite",
      child: Text("emotion_model (Acc 62% Grayscale)"),
    ),
  ];

  Future<void> connectionCheck() async {
    Uri uri = Uri.parse("http://213.218.240.102/getkodedaerah");
    var request = http.MultipartRequest("GET", uri);

    setState(() {
      onLoading = true;
      message = "Connecting...";
    });
    try {
      var streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body)['Kode Daerah'];

        List<KodeDaerah> kodeDaerahList = [];
        for (var data in jsonResponse) {
          kodeDaerahList.add(KodeDaerah.fromJson(data));
        }

        for (var data in kodeDaerahList) {
          listAreaCode.add(
            DropdownMenuItem(
              value: data.kode,
              child: Text(data.namaDaerah),
            ),
          );
        }

        message = "Connected successfully!";
        canContinue = true;
      } else {
        message = "Connection status: ${response.statusCode}";
        canContinue = false;
      }
    } catch (error) {
      message = error.toString();
      canContinue = false;
    }

    setState(() {
      onLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    connectionCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Welcome!")),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Server Connection Status:"),
              onLoading ? const CircularProgressIndicator() : Text(message),
              canContinue
                  ? Container(
                      width: double.infinity,
                      height: 110,
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField(
                              decoration: const InputDecoration(
                                labelText: 'Area Code',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedAreaCode,
                              items: listAreaCode,
                              onChanged: (newValue) {
                                setState(() {
                                  selectedAreaCode = newValue!;
                                });
                              },
                              hint: const Text('Choose Area'),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: selectedAreaCode != null
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EmotionDetectionPage(
                                          camera: cameras.last,
                                          modelPath: selectedModel!,
                                          // areaCode: selectedAreaCode!.toString(),
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: const Text("Continue"),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: connectionCheck,
                          child: const Text("Try Again"),
                        ),
                        const Text("or"),
                        DropdownButtonFormField(
                          items: listModel,
                          value: selectedModel,
                          onChanged: (value) {
                            setState(() {
                              selectedModel = value!;
                            });
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmotionDetectionPage(
                                  camera: cameras.last,
                                  modelPath: selectedModel!,
                                  // areaCode: selectedAreaCode!.toString(),
                                ),
                              ),
                            );
                          },
                          child: const Text("Still Continue"),
                        ),
                      ],
                    )
            ],
          ),
        ),
      ),
    );
  }
}
