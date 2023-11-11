import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ml_kits/main.dart';
import 'package:tflite/tflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:typed_data';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isWorking = false;
  String result = "";
  CameraImage? imgCamer;
  CameraController? camController;

  String initialCamera = "assets/camera.jpg";

  String imagePath = '';

  loadModel() async{
    await Tflite.loadModel(
      model: "assets/mobilenet_v1_1.0_224.tflite",
      labels: "assets/mobilenet_v1_1.0_224.txt"
    );
  }

  initCamera(){
    camController = new CameraController(cameras![0], ResolutionPreset.medium);
    camController!.initialize().then((value) {
      
      if(!mounted){
        return;
      }

      setState(() {
        camController!.startImageStream((image) => {
          
          if(!isWorking){
            isWorking = true,
            imgCamer = image,
            runModelOnStreamFrames(),
          }

        });
      });

      // setState(() {
      //   camController!.takePicture().then((XFile file) {

      //     setState(() {
      //       imagePath = file.path;
      //       initialCamera = imagePath;
      //     });

      //     print("Image saved to: $imagePath");

      //     isWorking = true;
      //     imgCamer = null; // Tidak perlu menggunakan frame saat mengambil gambar
      //     runModelOnStreamFrames();
      //   });
      // });

    });
  }

  List<int> concatenatePlanes(List<Plane> planes) {
    List<int> bytes = [];

    for (Plane plane in planes) {
      bytes.addAll(plane.bytes);
    }

    return bytes;
  }

   Future<void>saveImageToFile(CameraImage imgCamer) async {
    try {
      final path = join(
        (await getTemporaryDirectory()).path,
        '${DateTime.now()}.png',
      );

      await File(path).writeAsBytes(
        concatenatePlanes(imgCamer.planes),
      );

      setState(() {
        imagePath = path;
        initialCamera = imagePath;
      });
    } catch (e) {
      print('Error saving image: $e');
    }
  }

  runModelOnStreamFrames() async{
    if(imgCamer != null){
      var recognition = await Tflite.runModelOnFrame(
        bytesList: imgCamer!.planes.map((e) {
          return e.bytes;
        }).toList(),
        imageHeight: imgCamer!.height,
        imageWidth: imgCamer!.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: 90,
        numResults: 2, // number of pbject for detection
        threshold: 0.1,
        asynch: true
      );
      result = "";
      recognition!.forEach((response) { 
        result += response["label"] + " " + (response["confidence"] as double).toStringAsFixed(2) + "\n\n";
      });

      // Menyimpan gambar saat berhasil mendeteksi objek
      // await saveImageToFile(imgCamer!);

      setState(() {
        result;
      });

      isWorking = false;

    }
  }

  @override
  void initState() {
    super.initState();

    loadModel();
  }

  @override
  void dispose() async{
    super.dispose();
    await Tflite.close();
    camController!.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:  BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/jarvis.jpg") // saat di click kameranya simpan dan cetak gambar disini
          )
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Center(
                  child: Container(
                    height: 320,
                    width: 330,
                    // child: Image.asset("assets/camera.jpg"),
                    decoration:  BoxDecoration(
                      image: DecorationImage(
                        image: imagePath.isNotEmpty ? FileImage(File(imagePath)) as ImageProvider<Object> : AssetImage(initialCamera),
                      )
                    ),
                  ),
                ),
                Center(
                    child: TextButton(
                    onPressed: () {
                      initCamera();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 35),
                      height: 270,
                      width: 360,
                      child: imgCamer == null 
                        ? Container(
                          height: 270,
                          width: 360,
                          child: const Icon(
                            Icons.photo_camera_front,
                            color: Colors.blueAccent,
                            size: 40,
                          ),
                        ) 
                        : AspectRatio(
                            aspectRatio: camController!.value.aspectRatio,
                            child: CameraPreview(camController!),
                          ),
                    )
                  ),
                ),
              ],
            ),
            Center(
              child: Container(
                child: SingleChildScrollView(
                  child: Text(
                    result,
                    style: TextStyle(
                      backgroundColor: Colors.black87,
                      fontSize: 30.0,
                      color: Colors.white
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}