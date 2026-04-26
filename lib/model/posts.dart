import 'package:cloud_firestore/cloud_firestore.dart';

class Posts {
  final String description;
  final String uid;
  final String username;
  final String postId;
  final DateTime datePublished;
  final String postUrl;
  final List<String> imageUrls;
  final String profImage;
  final List<String> likes;
  final bool isVideo;
  final int? imageWidth;
  final int? imageHeight;

  const Posts({
    required this.description,
    required this.uid,
    required this.username,
    required this.postId,
    required this.datePublished,
    required this.postUrl,
    this.imageUrls = const [],
    required this.profImage,
    required this.likes,
    this.isVideo = false,
    this.imageWidth,
    this.imageHeight,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'uid': uid,
        'username': username,
        'postId': postId,
        'datePublished': datePublished,
        'postUrl': postUrl,
        'imageUrls': imageUrls,
        'profImage': profImage,
        'likes': likes,
        'isVideo': isVideo,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
      };

  static Posts fromMap(Map<String, dynamic> snapshot) => Posts(
        description: snapshot['description'] as String? ?? '',
        uid: snapshot['uid'] as String? ?? '',
        username: snapshot['username'] as String? ?? '',
        datePublished: snapshot['datePublished'] is Timestamp
            ? (snapshot['datePublished'] as Timestamp).toDate()
            : snapshot['datePublished'] as DateTime? ?? DateTime.now(),
        postId: snapshot['postId'] as String? ?? '',
        postUrl: snapshot['postUrl'] as String? ?? '',
        imageUrls: List<String>.from(snapshot['imageUrls'] ?? []),
        profImage: snapshot['profImage'] as String? ?? '',
        likes: List<String>.from(snapshot['likes'] ?? []),
        isVideo: snapshot['isVideo'] as bool? ?? false,
        imageWidth: (snapshot['imageWidth'] as num?)?.round(),
        imageHeight: (snapshot['imageHeight'] as num?)?.round(),
      );
}
