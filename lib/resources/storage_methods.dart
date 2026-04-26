import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StoredImage {
  final String url;
  final String path;

  const StoredImage({
    required this.url,
    required this.path,
  });
}

class StorageMethods {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadImageToStorage(
    String childName,
    Uint8List file,
    bool isPost,
  ) async {
    final storedImage = await uploadImageToStorageWithPath(
      childName,
      file,
      isPost,
    );
    return storedImage.url;
  }

  Future<StoredImage> uploadImageToStorageWithPath(
    String childName,
    Uint8List file,
    bool isPost,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseException(
        plugin: 'firebase_auth',
        message: 'You need to log in before uploading.',
      );
    }

    Reference ref = _storage.ref().child(childName).child(currentUser.uid);
    if (isPost) {
      ref = ref.child(const Uuid().v1());
    }

    final uploadTask = ref.putData(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final snapshot = await uploadTask.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        uploadTask.cancel();
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'timeout',
          message:
              'Upload timed out. Check your internet and try a smaller photo.',
        );
      },
    );
    final url = await snapshot.ref.getDownloadURL().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'timeout',
          message: 'Upload finished but download URL took too long.',
        );
      },
    );
    return StoredImage(url: url, path: snapshot.ref.fullPath);
  }
}
