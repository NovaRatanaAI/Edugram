import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

class FirebaseDemoMigrator {
  FirebaseDemoMigrator._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _batchId = 'local-demo-v1';

  static final List<_SeedUser> _users = [
    _SeedUser(
      localUid: 'seed-user-demo',
      email: 'demo@instagram.com',
      password: 'demo1234',
      username: 'demo_user',
      bio: 'Default demo account. Just exploring!',
      avatarAsset: 'assets/demo.png',
      followers: [
        'seed-user-alex',
        'seed-user-maria',
        'seed-user-kai',
        'seed-user-khmer',
      ],
      following: [
        'seed-user-alex',
        'seed-user-maria',
        'seed-user-kai',
        'seed-user-khmer',
      ],
    ),
    _SeedUser(
      localUid: 'seed-user-alex',
      email: 'alex@instagram.com',
      password: 'alex1234',
      username: 'Dara',
      bio: 'Photography | Light chaser | Always exploring',
      avatarAsset: 'assets/dara.png',
      followers: ['seed-user-demo'],
      following: ['seed-user-demo', 'seed-user-maria'],
    ),
    _SeedUser(
      localUid: 'seed-user-maria',
      email: 'maria@instagram.com',
      password: 'maria1234',
      username: 'SreyPich',
      bio: 'Good vibes only | Coffee addict | she/her',
      avatarAsset: 'assets/sreypich.png',
      followers: ['seed-user-demo', 'seed-user-alex'],
      following: ['seed-user-demo', 'seed-user-kai'],
    ),
    _SeedUser(
      localUid: 'seed-user-kai',
      email: 'kai@instagram.com',
      password: 'kai1234',
      username: 'Sok',
      bio: 'Adventure seeker | Share the journey',
      avatarAsset: 'assets/sok.png',
      followers: ['seed-user-demo', 'seed-user-maria'],
      following: ['seed-user-demo', 'seed-user-alex'],
    ),
    _SeedUser(
      localUid: 'seed-user-khmer',
      email: 'khmer@instagram.com',
      password: 'khmer1234',
      username: 'Khmer',
      bio: 'Cambodia proud | Happy Khmer New Year',
      avatarAsset: 'assets/khmer_flag.png',
      followers: ['seed-user-demo'],
      following: ['seed-user-demo'],
    ),
  ];

  static final List<_SeedPost> _posts = [
    _SeedPost(
      ownerLocalUid: 'seed-user-demo',
      assetPath: 'assets/screenshots/home-feed-light.jpg',
      description: 'Finally got this shot. Took 3 hours waiting for the light.',
      daysAgo: 0,
      likesFrom: ['seed-user-alex', 'seed-user-maria'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-demo',
      assetPath: 'assets/screenshots/messages-dark.jpg',
      description: 'Good morning world.',
      daysAgo: 2,
      likesFrom: ['seed-user-kai'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-alex',
      assetPath: 'assets/dara/dara_post1.jpg',
      description: 'Flutter For Mobile Applications #Flutter #MobileDev',
      daysAgo: 1,
      likesFrom: ['seed-user-demo', 'seed-user-maria', 'seed-user-kai'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-alex',
      assetPath: 'assets/dara/dara_post2.jpg',
      description: 'New Coder Should Learn Python #Python #Coding',
      daysAgo: 3,
      likesFrom: ['seed-user-demo', 'seed-user-kai'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-alex',
      assetPath: 'assets/dara/dara_post3.jpg',
      description: 'Flutter API #Flutter #API',
      daysAgo: 5,
      likesFrom: ['seed-user-maria', 'seed-user-kai', 'seed-user-demo'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-alex',
      assetPath: 'assets/dara/dara_post4.jpg',
      description: 'Flutter',
      daysAgo: 8,
      likesFrom: ['seed-user-demo', 'seed-user-maria'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-alex',
      assetPath: 'assets/dara/dara_post5.jpg',
      description: 'Edugram App With Flutter #Flutter #MobileDev',
      daysAgo: 12,
      likesFrom: ['seed-user-maria', 'seed-user-kai'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-maria',
      assetPath: 'assets/sreypich/sreypich_post1.jpg',
      description:
          'The Ordinary Niacinamide 10% + Zinc 1% Supersize Serum 60ml',
      daysAgo: 1,
      likesFrom: ['seed-user-demo', 'seed-user-alex', 'seed-user-kai'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-maria',
      assetPath: 'assets/sreypich/sreypich_post2.jpg',
      description: 'Celimax retinal booster for anti-aging and firmer skin.',
      daysAgo: 3,
      likesFrom: ['seed-user-demo', 'seed-user-kai'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-maria',
      assetPath: 'assets/sreypich/sreypich_post3.jpg',
      description: 'Beauty of Joseon Relief Sun: Rice + Probiotics SPF50+',
      daysAgo: 6,
      likesFrom: ['seed-user-alex', 'seed-user-demo'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-maria',
      assetPath: 'assets/sreypich/sreypich_post4.jpg',
      description: 'Korean Glass Skin #Skincare #GlassSkin',
      daysAgo: 10,
      likesFrom: ['seed-user-demo', 'seed-user-alex', 'seed-user-kai'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-maria',
      assetPath: 'assets/sreypich/sreypich_post5.jpg',
      description: 'Best cream for dry skin.',
      daysAgo: 14,
      likesFrom: ['seed-user-kai', 'seed-user-demo'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-kai',
      assetPath: 'assets/sok/sok_post1.jpg',
      description: 'Khmer New Year is the most cherished holiday in Cambodia.',
      daysAgo: 1,
      likesFrom: ['seed-user-demo', 'seed-user-maria', 'seed-user-alex'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-kai',
      assetPath: 'assets/sok/sok_post2.jpg',
      description:
          'Cambodian Army committed to protecting territorial integrity.',
      daysAgo: 4,
      likesFrom: ['seed-user-demo', 'seed-user-alex'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-kai',
      assetPath: 'assets/sok/sok_post3.jpg',
      description: 'Military conscription to become mandatory in 2026.',
      daysAgo: 7,
      likesFrom: ['seed-user-demo', 'seed-user-maria'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-kai',
      assetPath: 'assets/sok/sok_post4.jpg',
      description: 'Royal Cambodian Armed Forces ready to defend the nation.',
      daysAgo: 10,
      likesFrom: ['seed-user-demo', 'seed-user-alex', 'seed-user-maria'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-kai',
      assetPath: 'assets/sok/sok_post5.jpg',
      description: 'Royal Cambodian Army parade with troops and weapons.',
      daysAgo: 15,
      likesFrom: ['seed-user-demo', 'seed-user-maria'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-khmer',
      assetPath: 'assets/khmer_new_year.png',
      description: 'Happy Khmer New Year 2025!',
      daysAgo: 0,
      likesFrom: [
        'seed-user-demo',
        'seed-user-alex',
        'seed-user-maria',
        'seed-user-kai',
      ],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-khmer',
      assetPath: 'assets/khmer_flag.png',
      description: 'Cambodia forever proud.',
      daysAgo: 1,
      likesFrom: ['seed-user-demo', 'seed-user-maria'],
    ),
    _SeedPost(
      ownerLocalUid: 'seed-user-khmer',
      assetPath: 'assets/1.mp4',
      description: 'Special video from Cambodia #khmer #cambodia',
      daysAgo: 0,
      likesFrom: ['seed-user-demo', 'seed-user-alex'],
      isVideo: true,
    ),
  ];

  static Future<bool> hasDemoData() async {
    final existingSeedPosts = await _firestore
        .collection('posts')
        .where('seedBatch', isEqualTo: _batchId)
        .get();
    return existingSeedPosts.docs.length >= _posts.length;
  }

  static Future<String> seedDemoData() async {
    try {
      final existingSeedPosts = await _firestore
          .collection('posts')
          .where('seedBatch', isEqualTo: _batchId)
          .get();
      if (existingSeedPosts.docs.length >= _posts.length) {
        await _auth.signInWithEmailAndPassword(
          email: 'demo@instagram.com',
          password: 'demo1234',
        );
        return 'Demo data already exists in Firebase.';
      }

      final uidByLocalUid = <String, String>{};
      final photoByLocalUid = <String, String>{};

      for (final seedUser in _users) {
        final user = await _createOrSignIn(seedUser.email, seedUser.password);
        uidByLocalUid[seedUser.localUid] = user.uid;
        final photoUrl = await _uploadAsset(
          seedUser.avatarAsset,
          'seedProfilePics/${user.uid}',
        );
        photoByLocalUid[seedUser.localUid] = photoUrl;

        await _firestore.collection('users').doc(user.uid).set({
          'username': seedUser.username,
          'email': seedUser.email,
          'uid': user.uid,
          'photoUrl': photoUrl,
          'bio': seedUser.bio,
          'followers': const <String>[],
          'following': const <String>[],
          'seedBatch': _batchId,
        }, SetOptions(merge: true));
      }

      for (final seedUser in _users) {
        final uid = uidByLocalUid[seedUser.localUid]!;
        await _firestore.collection('users').doc(uid).update({
          'followers': seedUser.followers
              .map((localUid) => uidByLocalUid[localUid])
              .whereType<String>()
              .toList(),
          'following': seedUser.following
              .map((localUid) => uidByLocalUid[localUid])
              .whereType<String>()
              .toList(),
        });
      }

      await _auth.signInWithEmailAndPassword(
        email: 'demo@instagram.com',
        password: 'demo1234',
      );

      var createdPosts = 0;
      final failedPosts = <String>[];

      for (final seedPost in _posts) {
        try {
          final ownerUid = uidByLocalUid[seedPost.ownerLocalUid]!;
          final owner = _users.firstWhere(
            (user) => user.localUid == seedPost.ownerLocalUid,
          );
          final fileName = seedPost.assetPath.split('/').last;
          final postId = _seedPostId(seedPost);
          final postUrl = await _uploadAsset(
            seedPost.assetPath,
            'seedPosts/$ownerUid/$fileName',
          );
          await _firestore.collection('posts').doc(postId).set({
            'description': seedPost.description,
            'uid': ownerUid,
            'username': owner.username,
            'postId': postId,
            'datePublished': DateTime.now().subtract(
              Duration(days: seedPost.daysAgo),
            ),
            'postUrl': postUrl,
            'profImage': photoByLocalUid[seedPost.ownerLocalUid] ?? '',
            'likes': seedPost.likesFrom
                .map((localUid) => uidByLocalUid[localUid])
                .whereType<String>()
                .toList(),
            'isVideo': seedPost.isVideo,
            'seedBatch': _batchId,
          }, SetOptions(merge: true));
          createdPosts++;
        } catch (error) {
          failedPosts.add('${seedPost.assetPath}: $error');
        }
      }

      if (failedPosts.isNotEmpty) {
        return 'Moved $createdPosts of ${_posts.length} posts. First error: ${failedPosts.first}';
      }
      return 'success';
    } catch (error) {
      return error.toString();
    }
  }

  static Future<User> _createOrSignIn(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!;
    }
  }

  static Future<String> _uploadAsset(
      String assetPath, String storagePath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final metadata = SettableMetadata(contentType: _contentType(assetPath));
    final snapshot = await _storage.ref(storagePath).putData(bytes, metadata);
    return snapshot.ref.getDownloadURL();
  }

  static String _contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'image/jpeg';
  }

  static String _seedPostId(_SeedPost post) {
    final source = '${post.ownerLocalUid}_${post.assetPath}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return 'seed_$source';
  }
}

class _SeedUser {
  const _SeedUser({
    required this.localUid,
    required this.email,
    required this.password,
    required this.username,
    required this.bio,
    required this.avatarAsset,
    required this.followers,
    required this.following,
  });

  final String localUid;
  final String email;
  final String password;
  final String username;
  final String bio;
  final String avatarAsset;
  final List<String> followers;
  final List<String> following;
}

class _SeedPost {
  const _SeedPost({
    required this.ownerLocalUid,
    required this.assetPath,
    required this.description,
    required this.daysAgo,
    required this.likesFrom,
    this.isVideo = false,
  });

  final String ownerLocalUid;
  final String assetPath;
  final String description;
  final int daysAgo;
  final List<String> likesFrom;
  final bool isVideo;
}
