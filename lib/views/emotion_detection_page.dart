import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kepuasan_pelanggan/utils/image_classification_utils.dart';

class EmotionDetectionPage extends StatefulWidget {
  const EmotionDetectionPage({
    super.key,
    required this.camera,
    required this.modelPath,
  });

  final CameraDescription camera;
  final String modelPath;
  @override
  State<StatefulWidget> createState() => EmotionDetectionPageState();
}

class EmotionDetectionPageState extends State<EmotionDetectionPage>
    with WidgetsBindingObserver {
  late CameraController cameraController;
  late ImageClassificationUtils imageClassificationUtils;
  final Stopwatch stopwatch = Stopwatch();
  Map<String, double>? classification;
  bool _isProcessing = false;
  bool _isRecording = false;
  List<FlSpot> emotionList = [];

  recordEmotion(double label, double time) {
    if (_isRecording) {
      emotionList.add(FlSpot(time, label));
    }
  }

  // init camera
  initCamera() {
    cameraController = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    cameraController.initialize().then((value) {
      cameraController.startImageStream(imageAnalysis);
      if (mounted) {
        setState(() {});
      }
    });
  }

  int getMaxValueIndex(Map<String, double> data) {
    List<String> keys = data.keys.toList();
    double maxValue = data.values.first;
    int maxIndex = 0;

    for (int i = 1; i < data.values.length; i++) {
      if (data[keys[i]]! > maxValue) {
        maxValue = data[keys[i]]!;
        maxIndex = i;
      }
    }

    return maxIndex;
  }

  Future<void> imageAnalysis(CameraImage cameraImage) async {
    // if image is still analyze, skip this frame
    if (_isProcessing) {
      return;
    }
    // log("processing...");
    _isProcessing = true;
    classification =
        await imageClassificationUtils.inferenceCameraFrame(cameraImage);

    var indexResult = null;

    classification != null
        ? indexResult = getMaxValueIndex(classification!)
        : indexResult = null;
    // log("Result: ${classification.toString()}");
    // log("Index Result: ${indexResult.toString()}");
    if (_isRecording) {
      recordEmotion(
        indexResult.toDouble(),
        stopwatch.elapsedMilliseconds / 1000.toDouble(),
      );
    }

    _isProcessing = false;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
    imageClassificationUtils = ImageClassificationUtils(widget.modelPath);
    imageClassificationUtils.initHelper();
    super.initState();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        cameraController.stopImageStream();
        break;
      case AppLifecycleState.resumed:
        if (!cameraController.value.isStreamingImages) {
          await cameraController.startImageStream(imageAnalysis);
        }
        break;
      default:
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    imageClassificationUtils.close();
    super.dispose();
  }

  Widget cameraWidget(context) {
    var camera = cameraController.value;
    // fetch screen size
    final size = MediaQuery.of(context).size;

    // calculate scale depending on screen and camera ratios
    // this is actually size.aspectRatio / (1 / camera.aspectRatio)
    // because camera preview size is received as landscape
    // but we're calculating for portrait orientation
    var scale = size.aspectRatio * camera.aspectRatio;

    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(cameraController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Size size = MediaQuery.of(context).size;
    List<Widget> list = [];

    list.add(
      SizedBox(
        child: (!cameraController.value.isInitialized)
            ? Container()
            : cameraWidget(context),
      ),
    );
    list.add(
      Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (classification != null)
                ...(classification!.entries.toList()
                      ..sort((a, b) => a.value.compareTo(b.value)))
                    .reversed
                    .take(1)
                    .map(
                  (e) {
                    // log("e key and value ${e.key} ${e.value.toString()}");
                    return Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(fontSize: 15),
                          ),
                          const Spacer(),
                          Text(
                            e.value.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 15),
                          )
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            ...list,
            Column(
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      child: const Icon(Icons.cameraswitch_outlined),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        !_isRecording ? stopwatch.start() : stopwatch.stop();
                        _isRecording = !_isRecording;
                        setState(() {});
                      },
                      child: !_isRecording
                          ? const Icon(Icons.play_arrow)
                          : const Icon(Icons.stop),
                    ),
                    _isRecording
                        ? Text(
                            "${stopwatch.elapsedMilliseconds / 1000} Seconds",
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              overflow: TextOverflow.clip,
                            ),
                          )
                        : const Text(""),
                  ],
                ),
                drawEmotionChart(emotionList),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget drawEmotionChart(List<FlSpot>? data) {
    return Container(
      decoration: const BoxDecoration(color: Colors.black),
      height: 200,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: LineChart(
          LineChartData(
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) {
                    const style = TextStyle(fontSize: 8, color: Colors.white);
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(value.toString(), style: style),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    if (value % 1 != 0) {
                      return Container();
                    }
                    const style = TextStyle(fontSize: 8, color: Colors.white);
                    String text;
                    switch (value.toInt()) {
                      case 0:
                        text = 'Angry';
                        break;
                      case 1:
                        text = 'Disgust';
                        break;
                      case 2:
                        text = 'Fear';
                        break;
                      case 3:
                        text = 'Happy';
                        break;
                      case 4:
                        text = 'Neurtral';
                        break;
                      case 5:
                        text = 'Sad';
                        break;
                      case 6:
                        text = 'Surprise';
                        break;
                      default:
                        return Container();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text(text, style: style),
                    );
                  },
                ),
              ),
            ),
            maxY: 7,
            minY: -1,
            lineBarsData: [
              LineChartBarData(
                dotData: const FlDotData(show: false),
                isStepLineChart: true,
                lineChartStepData: const LineChartStepData(stepDirection: 0),
                spots: data ?? [],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
