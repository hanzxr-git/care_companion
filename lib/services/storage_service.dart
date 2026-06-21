import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a medicine proof image to Firebase Storage and returns the download URL
  static Future<String?> uploadMedicineProof(String uid, String medId, File file) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Get extension from path, or default to jpg
      final parts = file.path.split('.');
      final ext = parts.length > 1 ? parts.last : 'jpg';
      
      final ref = _storage.ref().child('med_proofs/$uid/${medId}_$timestamp.$ext');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading medicine proof: $e');
      return null;
    }
  }

  /// Deletes a medicine proof image from Firebase Storage using its download URL
  static Future<void> deleteMedicineProof(String proofUrl) async {
    try {
      final ref = _storage.refFromURL(proofUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting medicine proof: $e');
    }
  }
}
