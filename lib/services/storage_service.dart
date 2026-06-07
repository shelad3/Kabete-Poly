import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  Future<List<String>> uploadImages(List<File> files, String folderPath) async {
    List<String> urls = [];
    for (int i = 0; i < files.length; i++) {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String path = '$folderPath/image_${timestamp}_$i.jpg';
      String? url = await uploadImage(files[i], path);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<String?> uploadFile(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading file: $e");
      return null;
    }
  }
}
