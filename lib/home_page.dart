import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  var urlImage = "";
  File? file;
  PlatformFile? oFile;
  bool isLoading = false;
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: (file != null || urlImage.isNotEmpty)
                  ? InteractiveViewer(
                      clipBehavior: Clip.none,
                      child: (urlImage.isEmpty
                          ? Image.file(file!)
                          : Image.network(
                              urlImage,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                } else {
                                  return const CircularProgressIndicator();
                                }
                              },
                            )),
                    )
                  : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => file != null ? upload() : getFile(),
                  child: file == null
                      ? const Text("Pick Image")
                      : (isLoading
                          ? const CircularProgressIndicator()
                          : const Text("Remove Background")),
                ),
                SizedBox(width: 5),
                Visibility(
                  visible: urlImage.isNotEmpty,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => isSaving = true);
                      _save();
                    },
                    child: isSaving
                        ? CircularProgressIndicator()
                        : const Text("Save Image"),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> getFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null) {
      setState(() {
        oFile = result.files.first;
        file = File(result.files.single.path!);
        urlImage = "";
      });
    }
  }

  Future<void> upload() async {
    setState(() => isLoading = true);
    final url = Uri.parse('https://api.replicate.com/v1/predictions');
    Uint8List? bytes = await file?.readAsBytes();
    final base64 = base64Encode(bytes as List<int>);
    final fileExtension = oFile?.extension;
    final fileURI = 'data:image/$fileExtension;base64,$base64';

    final headers = {
      'Authorization': 'Token r8_4WRzcwRkd2wJ0pJcuhZsQF5ebyMnhtI0DetU0',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'version':
          'fb8af171cfa1616ddcf1242c093f9c46bcada5ad4cf6f2fbe8b81b330ec5c003',
      'input': {
        'image': fileURI,
      },
    });

    final response = await http.post(url, headers: headers, body: body);

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 201) {
      final getURL = responseData['urls']['get'];
      getImage(getURL, headers);
    } else {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.ERROR,
        animType: AnimType.SCALE,
        title: response.statusCode.toString(),
        desc: responseData['detail'],
        btnCancelOnPress: () {},
        btnOkOnPress: () {},
      ).show();
    }
  }

  Future<void> getImage(String getURL, Map<String, String> headers) async {
    final response = await http.get(Uri.parse(getURL), headers: headers);
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['status'].toString() == 'processing') {
        getImage(getURL, headers);
      } else if (responseData['status'].toString() == 'succeeded') {
        final output = responseData['output'];
        setState(() {
          urlImage = output;
          isLoading = false;
          file = null;
        });
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.ERROR,
          animType: AnimType.SCALE,
          title: response.statusCode.toString(),
          desc: responseData['detail'],
          btnCancelOnPress: () {},
          btnOkOnPress: () {},
        ).show();
      }
    }
  }

  _save() async {
    var response = await Dio()
        .get(urlImage, options: Options(responseType: ResponseType.bytes));
    final result = await ImageGallerySaver.saveImage(
      Uint8List.fromList(response.data),
    );
    String msg = "Not Success";
    if (result["isSuccess"] == true) {
      msg = "Saved in Gallery";
      setState(() => isSaving = false);
    }
    Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.deepOrange,
        textColor: Colors.white,
        fontSize: 16.0);
  }
}
