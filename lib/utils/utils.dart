import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Single shared instance — ImagePicker has no state, no need to recreate it
final _imagePicker = ImagePicker();

Future<Uint8List?> pickImage(
  ImageSource imgSource, {
  int? imageQuality,
  double? maxWidth,
  double? maxHeight,
}) async {
  try {
    final XFile? file = await _imagePicker.pickImage(
      source: imgSource,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    if (file != null) {
      return file.readAsBytes();
    }
  } catch (error) {
    debugPrint('Image picker failed: $error');
  }
  return null;
}

void showSnackBar(String content, BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(content)));
}
