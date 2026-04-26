import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:edugram/resources/local_store.dart';

class MessageStore {
  MessageStore._();
  static final instance = MessageStore._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> init() async {}

  String? get _currentUid =>
      _auth.currentUser?.uid ?? LocalStore.instance.currentUid;
  String? get currentUid => _currentUid;

  String _conversationKey(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair.first}_${pair.last}';
  }

  Stream<List<Map<String, dynamic>>> watchMessages(
    String otherUid, {
    required String otherUsername,
    required String otherPhotoUrl,
  }) {
    final myUid = _currentUid;
    if (myUid == null || otherUid.isEmpty) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    final chatId = _conversationKey(myUid, otherUid);
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: myUid)
        .snapshots()
        .asyncExpand((chatSnapshot) {
      final hasChat = chatSnapshot.docs.any((doc) => doc.id == chatId);
      if (!hasChat) {
        return Stream.value(
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
      }

      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('time')
          .snapshots()
          .map((snapshot) => snapshot.docs);
    }).map((snapshot) {
      return snapshot.map((doc) {
        final message = _withDate(doc.data());
        final senderUid = message['senderUid'] as String? ?? '';
        return {
          ...message,
          'messageId': doc.id,
          'isMe': senderUid == myUid,
        };
      }).toList();
    });
  }

  Future<void> ensureConversation(
    String otherUid, {
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    final myUid = _currentUid;
    if (myUid == null || otherUid.isEmpty) return;

    final chatId = _conversationKey(myUid, otherUid);
    final currentUser = await _loadUserInfo(myUid);

    await _firestore.collection('chats').doc(chatId).set({
      'participantIds': [myUid, otherUid],
      'participantInfo': {
        myUid: currentUser,
        otherUid: {
          'username': otherUsername,
          'photoUrl': otherPhotoUrl,
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchConversations() {
    final myUid = _currentUid;
    if (myUid == null) return Stream.value(const <Map<String, dynamic>>[]);

    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
      final conversations = snapshot.docs.map((doc) {
        final data = _withDate(doc.data());
        final participantInfo =
            Map<String, dynamic>.from(data['participantInfo'] ?? {});
        final ids = List<String>.from(data['participantIds'] ?? []);
        final otherUid = ids.firstWhere(
          (id) => id != myUid,
          orElse: () => '',
        );
        final otherInfo =
            Map<String, dynamic>.from(participantInfo[otherUid] ?? {});
        return {
          'uid': otherUid,
          'username': otherInfo['username'] ?? '',
          'photoUrl': otherInfo['photoUrl'] ?? '',
          'lastMessage': data['lastMessage'] ?? '',
          'lastSenderUid': data['lastSenderUid'] ?? '',
          'lastTime': data['updatedAt'] as DateTime?,
          'unread': false,
        };
      }).where((convo) {
        final hasUser = (convo['uid'] as String?)?.isNotEmpty == true;
        final hasMessage =
            (convo['lastMessage'] as String?)?.trim().isNotEmpty == true;
        return hasUser && hasMessage;
      }).toList();

      conversations.sort((a, b) {
        final aTime = a['lastTime'] as DateTime?;
        final bTime = b['lastTime'] as DateTime?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return conversations;
    });
  }

  Future<void> addTextMessage(
    String otherUid,
    String text, {
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    if (text.trim().isEmpty) return;
    await _appendMessage(
      otherUid,
      {
        'type': 'text',
        'text': text.trim(),
      },
      lastMessage: text.trim(),
      otherUsername: otherUsername,
      otherPhotoUrl: otherPhotoUrl,
    );
  }

  Future<void> addStoryReply(
    String otherUid,
    String text, {
    required String storyImageUrl,
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    if (text.trim().isEmpty) return;
    await _appendMessage(
      otherUid,
      {
        'type': 'story_reply',
        'text': text.trim(),
        'storyImageUrl': storyImageUrl,
      },
      lastMessage: 'Replied to your story',
      otherUsername: otherUsername,
      otherPhotoUrl: otherPhotoUrl,
    );
  }

  Future<void> addImageMessage(
    String otherUid,
    String imagePath, {
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    if (imagePath.isEmpty) return;
    if (kIsWeb) return;
    final myUid = _currentUid;
    if (myUid == null) return;
    final chatId = _conversationKey(myUid, otherUid);
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('chatImages/$chatId/$fileName');
    final snapshot = await ref.putFile(
      File(imagePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await snapshot.ref.getDownloadURL();
    await _appendMessage(
      otherUid,
      {
        'type': 'image',
        'imageUrl': imageUrl,
        'text': 'Sent a photo',
      },
      lastMessage: 'Sent a photo',
      otherUsername: otherUsername,
      otherPhotoUrl: otherPhotoUrl,
    );
  }

  Future<void> addImageBytesMessage(
    String otherUid,
    Uint8List bytes, {
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    if (bytes.isEmpty) return;
    final myUid = _currentUid;
    if (myUid == null) return;
    final chatId = _conversationKey(myUid, otherUid);
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('chatImages/$chatId/$fileName');
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await snapshot.ref.getDownloadURL();
    await _appendMessage(
      otherUid,
      {
        'type': 'image',
        'imageUrl': imageUrl,
        'text': 'Sent a photo',
      },
      lastMessage: 'Sent a photo',
      otherUsername: otherUsername,
      otherPhotoUrl: otherPhotoUrl,
    );
  }

  Future<void> addVoiceMessage(
    String otherUid, {
    required String audioPath,
    required int durationSeconds,
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    if (audioPath.isEmpty) return;
    if (kIsWeb) {
      await _appendVoiceMessage(
        otherUid,
        audioUrl: audioPath,
        durationSeconds: durationSeconds,
        otherUsername: otherUsername,
        otherPhotoUrl: otherPhotoUrl,
      );
      return;
    }
    final myUid = _currentUid;
    if (myUid == null) return;
    final chatId = _conversationKey(myUid, otherUid);
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final ref = _storage.ref('chatVoice/$chatId/$fileName');
    final snapshot = await ref.putFile(
      File(audioPath),
      SettableMetadata(contentType: 'audio/mp4'),
    );
    final audioUrl = await snapshot.ref.getDownloadURL();
    await _appendVoiceMessage(
      otherUid,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      otherUsername: otherUsername,
      otherPhotoUrl: otherPhotoUrl,
    );
  }

  Future<void> _appendVoiceMessage(
    String otherUid, {
    required String audioUrl,
    required int durationSeconds,
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    await _appendMessage(
      otherUid,
      {
        'type': 'voice',
        'audioUrl': audioUrl,
        'durationSeconds': durationSeconds,
        'text': 'Voice message',
      },
      lastMessage: 'Voice message',
      otherUsername: otherUsername,
      otherPhotoUrl: otherPhotoUrl,
    );
  }

  Future<void> _appendMessage(
    String otherUid,
    Map<String, dynamic> payload, {
    required String lastMessage,
    required String otherUsername,
    required String otherPhotoUrl,
  }) async {
    final myUid = _currentUid;
    if (myUid == null || otherUid.isEmpty) return;

    final chatId = _conversationKey(myUid, otherUid);
    final now = FieldValue.serverTimestamp();

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    await ensureConversation(
      otherUid,
      otherUsername: otherUsername,
      otherPhotoUrl: otherPhotoUrl,
    );

    await chatRef.set({
      'lastMessage': lastMessage,
      'lastSenderUid': myUid,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await messageRef.set({
      'senderUid': myUid,
      'receiverUid': otherUid,
      'time': now,
      ...payload,
    });
  }

  Future<Map<String, dynamic>> _loadUserInfo(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return {
      'username': data['username'] ?? _auth.currentUser?.email ?? 'User',
      'photoUrl': data['photoUrl'] ?? '',
    };
  }

  Map<String, dynamic> _withDate(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    for (final key in ['time', 'updatedAt']) {
      final value = copy[key];
      if (value is Timestamp) {
        copy[key] = value.toDate();
      }
    }
    return copy;
  }
}

