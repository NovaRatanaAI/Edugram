import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:edugram/model/posts.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/resources/storage_methods.dart';
import 'package:edugram/resources/story_store.dart';
import 'package:uuid/uuid.dart';

class FirestoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> uploadPost(
    String description,
    Uint8List file,
    String uid,
    String username,
    String profImage, {
    List<Uint8List> files = const [],
    bool useLocalFallback = true,
  }) async {
    String res = 'Some error occurred';
    try {
      final uploadFiles = files.isNotEmpty ? files : <Uint8List>[file];
      final imageUrls = <String>[];
      var usedLocalFallback = false;
      String? fallbackReason;
      for (final uploadFile in uploadFiles) {
        try {
          imageUrls.add(await StorageMethods().uploadImageToStorage(
            'posts',
            uploadFile,
            true,
          ));
        } catch (err) {
          if (!useLocalFallback) return _friendlyFirebaseError(err);
          usedLocalFallback = true;
          fallbackReason ??= _friendlyFirebaseError(err);
          imageUrls.add(LocalStore.instance.storeImage(
            uploadFile,
            persist: true,
          ));
        }
      }

      if (usedLocalFallback) {
        await LocalStore.instance.uploadPost(
          description: description,
          file: uploadFiles.first,
          uid: uid,
          username: username,
          profImage: profImage,
        );
        return 'local_success:${fallbackReason ?? 'Firebase upload failed.'}';
      }

      final postId = const Uuid().v1();
      final imageSize = await _decodeImageSize(uploadFiles.first);
      final post = Posts(
        description: description.trim(),
        uid: uid,
        username: username,
        postId: postId,
        datePublished: DateTime.now(),
        postUrl: imageUrls.first,
        imageUrls: imageUrls,
        profImage: profImage,
        likes: const [],
        imageWidth: imageSize?.width.round(),
        imageHeight: imageSize?.height.round(),
      );

      try {
        await _firestore
            .collection('posts')
            .doc(postId)
            .set(post.toJson())
            .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'timeout',
              message:
                  'Post saved too slowly. Check your internet and try again.',
            );
          },
        );
      } catch (err) {
        if (!useLocalFallback) return _friendlyFirebaseError(err);
        usedLocalFallback = true;
        fallbackReason ??= _friendlyFirebaseError(err);
        await LocalStore.instance.uploadPost(
          description: description,
          file: uploadFiles.first,
          uid: uid,
          username: username,
          profImage: profImage,
        );
      }
      res = usedLocalFallback
          ? 'local_success:${fallbackReason ?? 'Firebase did not finish.'}'
          : 'firebase_success';
    } on FirebaseException catch (err) {
      res = err.message ?? err.code;
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  String _friendlyFirebaseError(Object err) {
    if (err is FirebaseException) {
      final message = err.message;
      if (message != null && message.trim().isNotEmpty) return message;
      switch (err.code) {
        case 'permission-denied':
        case 'unauthorized':
          return 'Firebase permission denied. Check Storage or Firestore rules.';
        case 'unauthenticated':
          return 'You are not signed in to Firebase.';
        case 'timeout':
          return 'Firebase timed out.';
        case 'network-request-failed':
          return 'Network request failed.';
        default:
          return 'Firebase error: ${err.code}';
      }
    }
    return err.toString();
  }

  Future<ui.Size?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = ui.Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<void> likePost(String postId, String uid, List<String> likes) async {
    if (postId.isEmpty || uid.isEmpty) return;
    if (postId.startsWith('local_')) {
      LocalStore.instance.likePost(postId, uid);
      return;
    }
    final postRef = _firestore.collection('posts').doc(postId);
    final postSnap = await postRef.get();
    final postData = postSnap.data() ?? {};
    await postRef.update({
      'likes': likes.contains(uid)
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
    if (!likes.contains(uid)) {
      try {
        await _createNotification(
          type: 'like',
          fromUid: uid,
          toUid: postData['uid'] as String? ?? '',
          postId: postId,
          postUrl: postData['postUrl'] as String?,
        );
      } catch (_) {
        // Liking the post succeeded; notification writes depend on rules.
      }
    }
  }

  Future<String> postComment(
    String postId,
    String text,
    String uid,
    String username,
    String profilePic, {
    String? parentCommentId,
    String? replyToUsername,
  }) async {
    try {
      if (text.trim().isEmpty) return 'Please write something first...';
      if (postId.startsWith('local_')) {
        return LocalStore.instance.postComment(
          postId: postId,
          text: text,
          uid: uid,
          username: username,
          profilePic: profilePic,
          parentCommentId: parentCommentId,
          replyToUsername: replyToUsername,
        );
      }
      final commentId = const Uuid().v1();
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .set({
        'commentId': commentId,
        'postId': postId,
        'commentText': text.trim(),
        'uid': uid,
        'username': username,
        'profilePic': profilePic,
        'parentCommentId': parentCommentId,
        'replyToUsername': replyToUsername,
        'datePublished': DateTime.now(),
      });
      final postSnap = await _firestore.collection('posts').doc(postId).get();
      final postData = postSnap.data() ?? {};
      await _createNotification(
        type: 'comment',
        fromUid: uid,
        toUid: postData['uid'] as String? ?? '',
        postId: postId,
        postUrl: postData['postUrl'] as String?,
        text: text.trim(),
      );
      return 'success';
    } catch (err) {
      return err.toString();
    }
  }

  Future<String> deletePost(String postId) async {
    if (postId.startsWith('local_')) {
      return LocalStore.instance.deletePost(postId);
    }
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final postSnap = await postRef.get().timeout(const Duration(seconds: 12));
      final postData = postSnap.data();
      if (!postSnap.exists || postData == null) return 'Post not found.';

      final storageUrls = _storageUrlsForPost(postData);
      await postRef.delete().timeout(const Duration(seconds: 12));
      await _deleteStorageUrls(storageUrls);
      return 'success';
    } catch (err) {
      return _friendlyFirebaseError(err);
    }
  }

  Future<String> uploadStory({
    required Uint8List file,
    required String uid,
    required String username,
    required String userPhotoUrl,
    String text = '',
    double textX = 0.5,
    double textY = 0.45,
  }) async {
    try {
      final storyId = const Uuid().v1();
      final storedImage = await StorageMethods().uploadImageToStorageWithPath(
        'stories',
        file,
        true,
      );
      final imageUrl = storedImage.url;
      final now = DateTime.now();
      final story = StoryItem(
        id: storyId,
        uid: uid,
        username: username,
        userPhotoUrl: userPhotoUrl,
        imageUrl: imageUrl,
        storagePath: storedImage.path,
        text: text.trim(),
        textX: textX.clamp(0.0, 1.0),
        textY: textY.clamp(0.0, 1.0),
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      final batch = _firestore.batch();
      batch.set(_firestore.collection('posts').doc(storyId), {
        ...story.toJson(),
        'postId': storyId,
        'postUrl': imageUrl,
        'storagePath': storedImage.path,
        'profImage': userPhotoUrl,
        'description': '',
        'likes': <String>[],
        'isVideo': false,
        'isStory': true,
        'datePublished': now,
      });
      await batch.commit().timeout(const Duration(seconds: 12));
      return 'success';
    } catch (err) {
      return _friendlyFirebaseError(err);
    }
  }

  Future<void> deleteExpiredStories() async {
    try {
      final now = DateTime.now();
      final expired = await _firestore
          .collection('posts')
          .where('isStory', isEqualTo: true)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 10));
      if (expired.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in expired.docs) {
        final story = StoryItem.fromMap(doc.data());
        if (story.expiresAt.isAfter(now)) continue;
        await _deleteStoryStorage(doc.data());
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort cleanup; active queries also hide expired stories.
    }
  }

  Future<String> deleteStory(String storyId) async {
    if (storyId.isEmpty) return 'Story not found.';
    try {
      final doc = await _firestore.collection('posts').doc(storyId).get();
      if (!doc.exists || doc.data()?['isStory'] != true) {
        return 'Story not found.';
      }
      await _deleteStoryStorage(doc.data() ?? const <String, dynamic>{});
      await doc.reference.delete().timeout(const Duration(seconds: 12));
      return 'success';
    } catch (err) {
      return _friendlyFirebaseError(err);
    }
  }

  Future<void> _deleteStoryStorage(Map<String, dynamic> storyData) async {
    final paths = <String>{};
    void addPath(Object? value) {
      if (value is String && value.trim().isNotEmpty) paths.add(value.trim());
    }

    addPath(storyData['storagePath']);
    final storagePaths = storyData['storagePaths'];
    if (storagePaths is Iterable) {
      for (final path in storagePaths) {
        addPath(path);
      }
    }

    final urls = _storageUrlsForPost(storyData);
    await Future.wait([
      ...paths.map(_deleteStoragePath),
      ...urls.map(_deleteStorageUrl),
    ]);
  }

  Future<void> _deleteStoragePath(String? path) async {
    if (path == null || path.isEmpty || path.startsWith('http')) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {
      // Firestore cleanup is more important than blocking on Storage cleanup.
    }
  }

  Future<void> _deleteStorageUrl(String? url) async {
    if (url == null || url.isEmpty || !url.startsWith('http')) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {
      // Firestore cleanup is more important than blocking on Storage cleanup.
    }
  }

  List<String> _storageUrlsForPost(Map<String, dynamic> postData) {
    final urls = <String>{};
    void addUrl(Object? value) {
      if (value is String && value.trim().startsWith('http')) {
        urls.add(value.trim());
      }
    }

    addUrl(postData['postUrl']);
    addUrl(postData['imageUrl']);
    addUrl(postData['thumbnailUrl']);
    final imageUrls = postData['imageUrls'];
    if (imageUrls is Iterable) {
      for (final url in imageUrls) {
        addUrl(url);
      }
    }
    return urls.toList();
  }

  Future<void> _deleteStorageUrls(Iterable<String> urls) async {
    await Future.wait(urls.map(_deleteStorageUrl));
  }

  Future<void> followUser(String uid, String followId) async {
    if (uid.isEmpty || followId.isEmpty || uid == followId) return;
    final userSnap = await _firestore.collection('users').doc(uid).get();
    final following = List<String>.from(userSnap.data()?['following'] ?? []);
    final batch = _firestore.batch();
    final myRef = _firestore.collection('users').doc(uid);
    final targetRef = _firestore.collection('users').doc(followId);

    if (following.contains(followId)) {
      batch.update(targetRef, {
        'followers': FieldValue.arrayRemove([uid]),
      });
      batch.update(myRef, {
        'following': FieldValue.arrayRemove([followId]),
      });
    } else {
      batch.update(targetRef, {
        'followers': FieldValue.arrayUnion([uid]),
      });
      batch.update(myRef, {
        'following': FieldValue.arrayUnion([followId]),
      });
      await batch.commit();
      await _createNotification(
        type: 'follow',
        fromUid: uid,
        toUid: followId,
      );
      return;
    }
    await batch.commit();
  }

  Future<void> toggleSavedPost(String uid, String postId, bool isSaved) async {
    if (uid.isEmpty || postId.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'savedPosts': isSaved
          ? FieldValue.arrayRemove([postId])
          : FieldValue.arrayUnion([postId]),
    });
  }

  Future<void> _createNotification({
    required String type,
    required String fromUid,
    required String toUid,
    String? postId,
    String? postUrl,
    String? text,
  }) async {
    if (fromUid.isEmpty || toUid.isEmpty || fromUid == toUid) return;

    final fromSnap = await _firestore.collection('users').doc(fromUid).get();
    final from = fromSnap.data() ?? {};
    final notificationId = type == 'like' && postId != null
        ? 'like_${postId}_$fromUid'
        : const Uuid().v1();

    await _firestore
        .collection('notifications')
        .doc(toUid)
        .collection('items')
        .doc(notificationId)
        .set({
      'id': notificationId,
      'type': type,
      'fromUid': fromUid,
      'toUid': toUid,
      'fromUsername': from['username'] ?? '',
      'fromPhoto': from['photoUrl'] ?? '',
      'postId': postId,
      'postUrl': postUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    }, SetOptions(merge: true));
  }
}

