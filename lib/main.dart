// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_json_viewer/flutter_json_viewer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(camera: cameras.first));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({required this.camera, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Ecode Verify',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(camera: camera));
  }
}

class MyHomePage extends StatefulWidget {
  final CameraDescription camera;
  const MyHomePage({required this.camera, Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController _controller;
  List<Map> codes = List.empty(growable: true);
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future _incrementCounter() async {
    setState(() {
      codes.clear();
    });
    await _initializeControllerFuture;
    final image = await _controller.takePicture();
    await getCodes(image.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ecode Veriy"),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                SizedBox(
                  height: (MediaQuery.of(context).size.height / 2),
                  width: MediaQuery.of(context).size.width,
                  child: CameraPreview(_controller),
                ),
                SizedBox(
                  height: (MediaQuery.of(context).size.height / 2) - 100,
                  width: MediaQuery.of(context).size.width,
                  child: ListView.separated(
                    itemCount: codes.length,
                    separatorBuilder: (context, index) {
                      return const Divider();
                    },
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Text(
                            codes[index]["code"] +
                                " : " +
                                codes[index]["status"],
                            style: const TextStyle(fontSize: 25),
                          ),
                          JsonViewer(codes[index]),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Scan',
        child: const Icon(Icons.scanner),
      ),
    );
  }

  Future importData() async {
    final response =
        await http.get(Uri.parse("https://ecode.figlab.io/data/ecodes.json"));
    final ecodes = json.decode(response.body);
    final ecodeBox = await getEcodeBox();

    ecodes.forEach((key, value) async {
      await ecodeBox.put(key, value);
    });
  }

  Future getCodes(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    var words = RegExp('E[0-9]+', multiLine: true)
        .allMatches(recognizedText.text)
        .map((m) => m.group(0));

    var box = await getEcodeBox();

    for (var element in words) {
      var codeInfo = box.get(element);
      setState(() {
        codes.add(codeInfo);
      });
    }
  }

  Future<Box<dynamic>> getEcodeBox() async {
    WidgetsFlutterBinding.ensureInitialized();
    final directory = await getApplicationDocumentsDirectory();
    Hive.init(directory.path);
    return await Hive.openBox("ecodebox");
  }

  Future<void> init() async {
    await importData();
    await _controller.initialize();
  }
}
