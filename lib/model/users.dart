class User {
  final String email;
  final String uid;
  final String photoUrl; // was: phototUrl (typo fixed)
  final String username;
  final String bio;
  final List<String> followers;
  final List<String> following;
  final List<String> savedPosts;

  const User({
    required this.email,
    required this.uid,
    required this.photoUrl,
    required this.username,
    required this.bio,
    required this.followers,
    required this.following,
    this.savedPosts = const [],
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'uid': uid,
        'photoUrl': photoUrl,
        'bio': bio,
        'followers': followers,
        'following': following,
        'savedPosts': savedPosts,
      };

  static User fromMap(Map<String, dynamic> snapshot) => User(
        email: snapshot['email'] as String? ?? '',
        uid: snapshot['uid'] as String? ?? '',
        photoUrl: snapshot['photoUrl'] as String? ?? '',
        username: snapshot['username'] as String? ?? '',
        bio: snapshot['bio'] as String? ?? '',
        followers: List<String>.from(snapshot['followers'] ?? []),
        following: List<String>.from(snapshot['following'] ?? []),
        savedPosts: List<String>.from(snapshot['savedPosts'] ?? []),
      );
}
