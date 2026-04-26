import 'package:cloud_firestore/cloud_firestore.dart';

class StoryItem {
  final String id;
  final String uid;
  final String username;
  final String userPhotoUrl;
  final String imageUrl;
  final String storagePath;
  final String text;
  final double textX;
  final double textY;
  final DateTime createdAt;
  final DateTime expiresAt;

  const StoryItem({
    required this.id,
    required this.uid,
    required this.username,
    required this.userPhotoUrl,
    required this.imageUrl,
    this.storagePath = '',
    this.text = '',
    this.textX = 0.5,
    this.textY = 0.45,
    required this.createdAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'storyId': id,
        'uid': uid,
        'username': username,
        'userPhotoUrl': userPhotoUrl,
        'imageUrl': imageUrl,
        'storagePath': storagePath,
        'text': text,
        'textX': textX,
        'textY': textY,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
      };

  static StoryItem fromMap(Map<String, dynamic> data) {
    DateTime? readDate(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    double readDouble(String key, double fallback) {
      final value = data[key];
      if (value is num) return value.toDouble().clamp(0.0, 1.0);
      return fallback;
    }

    final createdAt = readDate('createdAt') ??
        readDate('datePublished') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final expiresAt =
        readDate('expiresAt') ?? DateTime.fromMillisecondsSinceEpoch(0);

    return StoryItem(
      id: data['storyId'] as String? ?? data['postId'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      username: data['username'] as String? ?? '',
      userPhotoUrl: data['userPhotoUrl'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      text: (data['text'] as String? ?? '').trim(),
      textX: readDouble('textX', 0.5),
      textY: readDouble('textY', 0.45),
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

class StoryLookup {
  const StoryLookup._();

  static Future<List<StoryItem>> activeForUid(String uid) async {
    if (uid.isEmpty) return const <StoryItem>[];
    return activeForAnyUid(<String>[uid]);
  }

  static Future<List<StoryItem>> activeForAnyUid(Iterable<String> uids) async {
    final uidList = uids
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .take(10)
        .toList();
    if (uidList.isEmpty) return const <StoryItem>[];

    final query = uidList.length == 1
        ? FirebaseFirestore.instance
            .collection('posts')
            .where('uid', isEqualTo: uidList.first)
        : FirebaseFirestore.instance
            .collection('posts')
            .where('uid', whereIn: uidList);
    final snapshot = await query.get().timeout(const Duration(seconds: 8));
    final now = DateTime.now();
    final stories = <StoryItem>[];
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['storyId'] ??= doc.id;
      data['postId'] ??= doc.id;
      if (data['isStory'] != true) continue;
      final story = StoryItem.fromMap(data);
      if (story.id.isEmpty || story.imageUrl.isEmpty) continue;
      if (!story.expiresAt.isAfter(now)) continue;
      stories.add(story);
    }
    stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return stories;
  }

  static Future<StoryItem?> latestActiveForUid(String uid) async {
    final stories = await activeForUid(uid);
    return stories.isEmpty ? null : stories.last;
  }
}
