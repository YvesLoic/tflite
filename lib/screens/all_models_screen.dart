import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:goa/cards/found_object_card.dart';

import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

const String ssd = "SSD MobileNet";
const String yolo = "Tiny YOLOv2";

class AllModels extends StatefulWidget {
  static const String name = 'all_models';

  const AllModels({Key? key}) : super(key: key);

  @override
  _AllModelsState createState() => _AllModelsState();
}

class _AllModelsState extends State<AllModels> {
  File? _image;
  List? _recognitions;
  String? _model;
  double? _imageHeight;
  double? _imageWidth;
  bool _busy = false;
  List foundObjects = [];

// when the screen loads, 'initState' calls 'loadModel' to load all the models
  @override
  void initState() {
    super.initState();

    _busy = true;

    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

// getting the image and passing it to 'predictImage()'
  Future predictImagePicker(ImageSource source) async {
    var pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;
    setState(() {
      _busy = true;
      _image = File(pickedFile.path);
    });
    predictImage(_image!);
  }

// runs the desired model on the image recieved from 'predictImagePicker()'
  Future predictImage(File image) async {
    // if (image == null) return;

    switch (_model) {
      // checks for the desired model
      case yolo:
        await yolov2Tiny(image);
        break;
      default:
        await ssdMobileNet(image);
    }

    FileImage(image) // gets the image height and width
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      setState(() {
        _imageHeight = info.image.height.toDouble();
        _imageWidth = info.image.width.toDouble();
      });
    }));

    setState(() {
      _image = image; // '_image' is set
      _busy = false;
    });
  }

// loads the model with the required assets
  Future loadModel() async {
    Tflite.close();
    try {
      String? res;
      switch (_model) {
        case yolo:
          res = await Tflite.loadModel(
            model: "assets/yolov2_tiny.tflite",
            labels: "assets/yolov2_tiny.txt",
            // useGpuDelegate: true,
          );
          print('Model: YOLO');
          break;
        default:
          res = await Tflite.loadModel(
            model: "assets/ssd_mobilenet.tflite",
            labels: "assets/ssd_mobilenet.txt",
            // useGpuDelegate: true,
          );
          print('Model: SSD MobileNet');
      }
      print(res);
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

// function to call the model: YOLO
  Future yolov2Tiny(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      model: "YOLO",
      threshold: 0.3,
      imageMean: 0.0,
      imageStd: 255.0,
      numResultsPerClass: 1,
    );
    setState(() {
      _recognitions = recognitions; // sets '_recognitions'
    });
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
  }

// function to call the model: SSD
  Future ssdMobileNet(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
    );
    setState(() {
      _recognitions = recognitions; // sets '_recognitions'
    });
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
  }

// changes the model when we change it from the app bar
  onSelect(model) async {
    setState(() {
      _busy = true;
      _model = model;
      _recognitions = null;
    });
    await loadModel();

    if (_image != null) {
      predictImage(_image!);
    } else {
      setState(() {
        _busy = false;
      });
    }
  }

// renders boxes over our image along with its attributes
  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight! / _imageWidth! * screen.width;

    List<dynamic> objects = [];
    for (var x in _recognitions!) {
      if (x['confidenceInClass'] < 0.4) {
        break;
      }
      objects.add(x);
    }
    foundObjects = _recognitions!;
    print('found $foundObjects');
    return objects.map((re) {
      print(
          'renderBoxes ${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%');
      return FoundObject(
          name: "${re["detectedClass"]}",
          percent: "${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%");
      // return Positioned(
      //   left: re["rect"]["x"] * factorX,
      //   top: re["rect"]["y"] * factorY,
      //   width: re["rect"]["w"] * factorX,
      //   height: re["rect"]["h"] * factorY,
      //   child: Container(
      //     decoration: BoxDecoration(
      //       borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      //       border: Border.all(
      //         color: Colors.red,
      //         width: 2,
      //       ),
      //     ),
      //     child: Text(
      //       "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
      //       style: TextStyle(
      //         background: Paint()..color = Colors.red,
      //         color: Colors.white,
      //         fontSize: 12.0,
      //       ),
      //     ),
      //   ),
      // );
    }).toList();
  }

// stacks are used to display boxes over an image
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];

    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width,
      child: _image == null
          ? const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No \nImage \nUploaded \n:(',
                style: TextStyle(
                  color: Color(0xffaf8d6b),
                  fontSize: 40,
                  fontFamily: 'FjallaOne',
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(5.0),
              height: size.height / 2.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: FileImage(_image!),
                ),
              ),
            ),
    ));

    stackChildren.addAll(renderBoxes(size));

    // if (_busy) {
    //   stackChildren.add(const Opacity(
    //     child: ModalBarrier(dismissible: false, color: Colors.grey),
    //     opacity: 0.3,
    //   ));
    //   stackChildren.add(const Center(child: CircularProgressIndicator()));
    // }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TensorFlow Lite',
          style: TextStyle(
            fontFamily: 'FjallaOne',
          ),
        ),
        backgroundColor: const Color(0xff1B7E81),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: onSelect,
            itemBuilder: (context) {
              List<PopupMenuEntry<String>> menuEntries = [
                const PopupMenuItem<String>(
                  child: Text(ssd),
                  value: ssd,
                ),
                const PopupMenuItem<String>(
                  child: Text(yolo),
                  value: yolo,
                ),
              ];
              return menuEntries;
            },
          )
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _image == null
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No \nImage \nUploaded \n:(',
                    style: TextStyle(
                      color: Color(0xffaf8d6b),
                      fontSize: 40,
                      fontFamily: 'FjallaOne',
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  // padding: const EdgeInsets.all(5.0),
                  height: size.height / 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: FileImage(_image!),
                    ),
                  ),
                ),
          const SizedBox(
            height: 5.0,
          ),
          _image != null
              ? Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ListView.builder(
                      itemCount: foundObjects.length,
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 16),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return FoundObject(
                            name: "${foundObjects[index]["detectedClass"]}",
                            percent:
                                "${(foundObjects[index]["confidenceInClass"] * 100).toStringAsFixed(0)}%");
                      },
                    ),
                  ),
                )
              : const SizedBox(
                  height: 5.0,
                ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () {
              predictImagePicker(ImageSource.camera);
            },
            tooltip: 'Pick Image',
            child: const Icon(Icons.add_a_photo),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FloatingActionButton(
              onPressed: () {
                predictImagePicker(ImageSource.gallery);
              },
              heroTag: 'image0',
              tooltip: 'Pick Image',
              child: const Icon(Icons.image),
            ),
          ),
        ],
      ),
    );
  }
}
