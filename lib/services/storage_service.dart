import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import '../config/cloudinary_config.dart';

class StorageService {
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    CloudinaryConfig.cloudName,
    CloudinaryConfig.uploadPreset,
  );

  Future<String?> uploadImage(File file, String path) async {
    try {
      final folderParts = path.split('/');
      final fileName = folderParts.removeLast();
      final folder = folderParts.join('/');

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder.isNotEmpty ? folder : null,
          publicId: fileName.replaceAll('.jpg', '').replaceAll('.png', ''),
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<List<String>> uploadImages(List<File> files, String folderPath) async {
    List<String> urls = [];
    for (int i = 0; i < files.length; i++) {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String path = '$folderPath/image_${timestamp}_$i';
      String? url = await uploadImage(files[i], path);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<String?> uploadFile(File file, String path) async {
    try {
      final folderParts = path.split('/');
      final fileName = folderParts.removeLast();
      final folder = folderParts.join('/');

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Auto,
          folder: folder.isNotEmpty ? folder : null,
          publicId: fileName,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }
}
