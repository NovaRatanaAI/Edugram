import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  final _uuid = const Uuid();

  final Map<String, Map<String, dynamic>> users = {};
  final Map<String, Map<String, dynamic>> posts = {};
  final Map<String, List<Map<String, dynamic>>> comments = {};
  final Map<String, Uint8List> _images = {};
  final Map<String, MemoryImage> _memoryImages = {};
  final Map<String, AssetImage> _assetImages = {};
  final Map<String, String> _videoAssetPaths = {};
  Directory? _imageStorageDir;

  String? currentUid;
  Future<void>? _initFuture;
  bool _isInitialized = false;

  static const String defaultUid = 'seed-user-demo';
  static const String defaultEmail = 'demo@instagram.com';
  static const String defaultPassword = 'demo1234';

  static const String _alexUid = 'seed-user-alex';
  static const String _mariaUid = 'seed-user-maria';
  static const String _kaiUid = 'seed-user-kai';
  static const String _khmerUid = 'seed-user-khmer';

  Future<void> init({bool seedDemoAssets = false}) async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initInternal(seedDemoAssets: seedDemoAssets);
    await _initFuture!;
  }

  Future<void> _initInternal({required bool seedDemoAssets}) async {
    if (!kIsWeb) {
      final documentsDir = await getApplicationDocumentsDirectory();
      _imageStorageDir = Directory('${documentsDir.path}/local_images');
      if (!await _imageStorageDir!.exists()) {
        await _imageStorageDir!.create(recursive: true);
      }
    }

    if (!seedDemoAssets) {
      await _loadSavedState();
      await _loadSavedProfiles();
      _isInitialized = true;
      return;
    }

    // Individual profile pictures
    final Uint8List avatarSreyPich = await _loadAsset('assets/sreypich.png');
    final Uint8List avatarDara = await _loadAsset('assets/dara.png');
    final Uint8List avatarSok = await _loadAsset('assets/sok.png');
    final Uint8List avatarDemo = await _loadAsset('assets/demo.png');

    final demoImgs = [
      'assets/screenshots/home-feed-light.jpg',
      'assets/screenshots/messages-dark.jpg',
    ];

    const khmerFlag = 'assets/khmer_flag.png';
    const khmerNewYear = 'assets/khmer_new_year.png';

    final daraImgs = [
      'assets/dara/dara_post1.jpg',
      'assets/dara/dara_post2.jpg',
      'assets/dara/dara_post3.jpg',
      'assets/dara/dara_post4.jpg',
      'assets/dara/dara_post5.jpg',
    ];

    final sreyPichImgs = [
      'assets/sreypich/sreypich_post1.jpg',
      'assets/sreypich/sreypich_post2.jpg',
      'assets/sreypich/sreypich_post3.jpg',
      'assets/sreypich/sreypich_post4.jpg',
      'assets/sreypich/sreypich_post5.jpg',
    ];

    final sokImgs = [
      'assets/sok/sok_post1.jpg',
      'assets/sok/sok_post2.jpg',
      'assets/sok/sok_post3.jpg',
      'assets/sok/sok_post4.jpg',
      'assets/sok/sok_post5.jpg',
    ];

    final String khmerAvatarUrl = storeAssetImage('assets/khmer_flag.png');
    final String sreyPichUrl = storeImage(avatarSreyPich);
    final String daraUrl = storeImage(avatarDara);
    final String sokUrl = storeImage(avatarSok);
    final String demoUrl = storeImage(avatarDemo);

    _seedUser(
        uid: defaultUid,
        email: defaultEmail,
        password: defaultPassword,
        username: 'demo_user',
        bio: 'Default demo account 👋 Just exploring!',
        photoUrl: demoUrl,
        followers: [_alexUid, _mariaUid, _kaiUid, _khmerUid],
        following: [_alexUid, _mariaUid, _kaiUid, _khmerUid]);

    _seedUser(
        uid: _alexUid,
        email: 'alex@instagram.com',
        password: 'alex1234',
        username: 'Dara',
        bio: '📸 Photography | Light chaser | Always exploring',
        photoUrl: daraUrl,
        followers: [defaultUid],
        following: [defaultUid, _mariaUid]);

    _seedUser(
        uid: _mariaUid,
        email: 'maria@instagram.com',
        password: 'maria1234',
        username: 'SreyPich',
        bio: '🌸 Good vibes only | Coffee addict ☕ | she/her',
        photoUrl: sreyPichUrl,
        followers: [defaultUid, _alexUid],
        following: [defaultUid, _kaiUid]);

    _seedUser(
        uid: _kaiUid,
        email: 'kai@instagram.com',
        password: 'kai1234',
        username: 'Sok',
        bio: '✈️ 42 countries | Adventure seeker | Share the journey',
        photoUrl: sokUrl,
        followers: [defaultUid, _mariaUid],
        following: [defaultUid, _alexUid]);

    _seedUser(
        uid: _khmerUid,
        email: 'khmer@instagram.com',
        password: 'khmer1234',
        username: 'Khmer',
        bio: '🇰🇭 ស្រុកខ្មែរ | Cambodia proud | សួស្តីឆ្នាំថ្មី 🎉',
        photoUrl: khmerAvatarUrl,
        followers: [defaultUid],
        following: [defaultUid]);

    _seedPost(
        uid: defaultUid,
        username: 'demo_user',
        profImage: demoUrl,
        img: demoImgs[0],
        description:
            'Finally got this shot 🔥 took 3 hours waiting for the light ✨',
        daysAgo: 0,
        likesFrom: [_alexUid, _mariaUid]);
    _seedPost(
        uid: defaultUid,
        username: 'demo_user',
        profImage: demoUrl,
        img: demoImgs[1],
        description: 'Good morning world 🌅',
        daysAgo: 2,
        likesFrom: [_kaiUid]);

    // ── Dara: Python & Flutter posts (5) ──
    _seedPost(
        uid: _alexUid,
        username: 'Dara',
        profImage: daraUrl,
        img: daraImgs[0],
        description: 'Flutter For Mobile Applications #Flutter #MobileDev',
        daysAgo: 1,
        likesFrom: [defaultUid, _mariaUid, _kaiUid]);
    _seedPost(
        uid: _alexUid,
        username: 'Dara',
        profImage: daraUrl,
        img: daraImgs[1],
        description: '📱New Coder Should Learn Python #Python #Coding',
        daysAgo: 3,
        likesFrom: [defaultUid, _kaiUid]);
    _seedPost(
        uid: _alexUid,
        username: 'Dara',
        profImage: daraUrl,
        img: daraImgs[2],
        description: '🤖 Flutter API #Flutter #API',
        daysAgo: 5,
        likesFrom: [_mariaUid, _kaiUid, defaultUid]);
    _seedPost(
        uid: _alexUid,
        username: 'Dara',
        profImage: daraUrl,
        img: daraImgs[3],
        description: '💙 Flutter ',
        daysAgo: 8,
        likesFrom: [defaultUid, _mariaUid]);
    _seedPost(
        uid: _alexUid,
        username: 'Dara',
        profImage: daraUrl,
        img: daraImgs[4],
        description: 'Edugram App With Flutter #Flutter #MobileDev',
        daysAgo: 12,
        likesFrom: [_mariaUid, _kaiUid]);

    // ── SreyPich: Skincare & Cosmetics posts (5) ──
    _seedPost(
        uid: _mariaUid,
        username: 'SreyPich',
        profImage: sreyPichUrl,
        img: sreyPichImgs[0],
        description:
            'The Ordinary Niacinamide 10% + Zinc 1% Supersize Serum 60ml',
        daysAgo: 1,
        likesFrom: [defaultUid, _alexUid, _kaiUid]);
    _seedPost(
        uid: _mariaUid,
        username: 'SreyPich',
        profImage: sreyPichUrl,
        img: sreyPichImgs[1],
        description:
            '🌿 Celimax The Vita A Retinal Shot Tightening Booster | 0.1% Retinal, 3% Matryxyl, High-Strength Retinoid for Anti-Aging, Pore Minimizer, Wrinkles & Fine Lines, Firmer Skin, 15ml,',
        daysAgo: 3,
        likesFrom: [defaultUid, _kaiUid]);
    _seedPost(
        uid: _mariaUid,
        username: 'SreyPich',
        profImage: sreyPichUrl,
        img: sreyPichImgs[2],
        description:
            'Beauty of Joseon Relief Sun: Rice + Probiotics (SPF50+ PA++++) Double Pack 50mL',
        daysAgo: 6,
        likesFrom: [_alexUid, defaultUid]);
    _seedPost(
        uid: _mariaUid,
        username: 'SreyPich',
        profImage: sreyPichUrl,
        img: sreyPichImgs[3],
        description: 'Korean Glass Skin  #Skincare #GlassSkin ',
        daysAgo: 10,
        likesFrom: [defaultUid, _alexUid, _kaiUid]);
    _seedPost(
        uid: _mariaUid,
        username: 'SreyPich',
        profImage: sreyPichUrl,
        img: sreyPichImgs[4],
        description: '🌸Best Cream For Dry Skin',
        daysAgo: 14,
        likesFrom: [_kaiUid, defaultUid]);

    // ── Sok: Khmer Military & Weapons history posts (5) ──
    _seedPost(
        uid: _kaiUid,
        username: 'Sok',
        profImage: sokUrl,
        img: sokImgs[0],
        description:
            '⚔️Khmer New Year, also known as Choul Chnam Thmey, is the most important and cherished holiday in Cambodia.',
        daysAgo: 1,
        likesFrom: [defaultUid, _mariaUid, _alexUid]);
    _seedPost(
        uid: _kaiUid,
        username: 'Sok',
        profImage: sokUrl,
        img: sokImgs[1],
        description:
            '🏹 Ministry: Cambodian Army committed to protecting territorial integrity at all costs.',
        daysAgo: 4,
        likesFrom: [defaultUid, _alexUid]);
    _seedPost(
        uid: _kaiUid,
        username: 'Sok',
        profImage: sokUrl,
        img: sokImgs[2],
        description:
            '🐘 PM: Military Conscription to become mandatory in 2026.',
        daysAgo: 7,
        likesFrom: [defaultUid, _mariaUid]);
    _seedPost(
        uid: _kaiUid,
        username: 'Sok',
        profImage: sokUrl,
        img: sokImgs[3],
        description:
            '🛡️ Royal Cambodian Armed Forces ready to defend the nation.',
        daysAgo: 10,
        likesFrom: [defaultUid, _alexUid, _mariaUid]);
    _seedPost(
        uid: _kaiUid,
        username: 'Sok',
        profImage: sokUrl,
        img: sokImgs[4],
        description:
            '⚔️ Royal Cambodian Army to host parade with troops and weapons.',
        daysAgo: 15,
        likesFrom: [defaultUid, _mariaUid]);

    _seedPost(
        uid: _khmerUid,
        username: 'Khmer',
        profImage: khmerAvatarUrl,
        img: khmerNewYear,
        description: '🎉 សួស្តីឆ្នាំថ្មី! Happy Khmer New Year 2025! 🇰🇭 ✨🙏',
        daysAgo: 0,
        likesFrom: [defaultUid, _alexUid, _mariaUid, _kaiUid]);
    _seedPost(
        uid: _khmerUid,
        username: 'Khmer',
        profImage: khmerAvatarUrl,
        img: khmerFlag,
        description:
            '🇰🇭 ខ្មែររស់ជានិច្ច | Cambodia forever proud 🏯 Angkor Wat 🙏',
        daysAgo: 1,
        likesFrom: [defaultUid, _mariaUid]);

    // Khmer VIDEO post — unique timestamp so it always appears in feed
    _seedVideoPost(
      uid: _khmerUid,
      username: 'Khmer',
      profImage: khmerAvatarUrl,
      assetPath: 'assets/1.mp4',
      description:
          '🎬 វីដេអូពិសេស | Special video from Cambodia 🇰🇭 #khmer #cambodia',
      publishedAt: DateTime.now().add(const Duration(seconds: 1)),
      likesFrom: [defaultUid, _alexUid],
    );

    final firstPost = posts.keys.first;
    _seedComment(
        postId: firstPost,
        uid: _alexUid,
        username: 'Dara',
        profilePic: daraUrl,
        text: 'Incredible shot! 😍');
    _seedComment(
        postId: firstPost,
        uid: _mariaUid,
        username: 'SreyPich',
        profilePic: sreyPichUrl,
        text: 'Obsessed with this 🔥🔥');

    // Seed notifications for ALL accounts based on actual likes/follows/comments
    // Helper: find posts by owner
    Map<String, Map<String, dynamic>> postsByUid(String uid) =>
        Map.fromEntries(posts.entries.where((e) => e.value['uid'] == uid));

    // ── demo_user notifications ──
    final firstPostData = posts[firstPost];
    addNotification(
        type: 'like',
        fromUid: _alexUid,
        toUid: defaultUid,
        postId: firstPost,
        postUrl: firstPostData?['postUrl'] as String?);
    addNotification(
        type: 'like',
        fromUid: _mariaUid,
        toUid: defaultUid,
        postId: firstPost,
        postUrl: firstPostData?['postUrl'] as String?);
    addNotification(
        type: 'comment',
        fromUid: _alexUid,
        toUid: defaultUid,
        postId: firstPost,
        postUrl: firstPostData?['postUrl'] as String?,
        text: 'Incredible shot! 😍');
    addNotification(
        type: 'comment',
        fromUid: _mariaUid,
        toUid: defaultUid,
        postId: firstPost,
        postUrl: firstPostData?['postUrl'] as String?,
        text: 'Obsessed with this 🔥🔥');
    addNotification(type: 'follow', fromUid: _khmerUid, toUid: defaultUid);
    addNotification(type: 'follow', fromUid: _kaiUid, toUid: defaultUid);

    // ── Dara (alex) notifications ──
    for (final entry in postsByUid(_alexUid).entries) {
      final likes = List<String>.from(entry.value['likes'] ?? []);
      final url = entry.value['postUrl'] as String?;
      for (final liker in likes) {
        addNotification(
            type: 'like',
            fromUid: liker,
            toUid: _alexUid,
            postId: entry.key,
            postUrl: url);
      }
    }
    addNotification(type: 'follow', fromUid: defaultUid, toUid: _alexUid);

    // ── SreyPich (maria) notifications ──
    for (final entry in postsByUid(_mariaUid).entries) {
      final likes = List<String>.from(entry.value['likes'] ?? []);
      final url = entry.value['postUrl'] as String?;
      for (final liker in likes) {
        addNotification(
            type: 'like',
            fromUid: liker,
            toUid: _mariaUid,
            postId: entry.key,
            postUrl: url);
      }
    }
    addNotification(type: 'follow', fromUid: defaultUid, toUid: _mariaUid);
    addNotification(type: 'follow', fromUid: _alexUid, toUid: _mariaUid);

    // ── Sok (kai) notifications ──
    for (final entry in postsByUid(_kaiUid).entries) {
      final likes = List<String>.from(entry.value['likes'] ?? []);
      final url = entry.value['postUrl'] as String?;
      for (final liker in likes) {
        addNotification(
            type: 'like',
            fromUid: liker,
            toUid: _kaiUid,
            postId: entry.key,
            postUrl: url);
      }
    }
    addNotification(type: 'follow', fromUid: defaultUid, toUid: _kaiUid);
    addNotification(type: 'follow', fromUid: _mariaUid, toUid: _kaiUid);

    // ── Khmer notifications ──
    for (final entry in postsByUid(_khmerUid).entries) {
      final likes = List<String>.from(entry.value['likes'] ?? []);
      final url = entry.value['postUrl'] as String?;
      for (final liker in likes) {
        addNotification(
            type: 'like',
            fromUid: liker,
            toUid: _khmerUid,
            postId: entry.key,
            postUrl: url);
      }
    }
    addNotification(type: 'follow', fromUid: defaultUid, toUid: _khmerUid);

    // Re-apply saved local app data from a previous session.
    await _loadSavedState();
    await _loadSavedProfiles();
    _isInitialized = true;
  }

  // ── Profile persistence ──────────────────────────────────────────────────

  static const _kProfilePrefix = 'profile_edit_';
  static const _kCurrentUid = 'current_uid';
  static const _kAppState = 'local_store_state_v1';

  /// Persist username + bio for [uid] and update in-memory immediately.
  Future<void> saveProfile(String uid, String username, String bio) async {
    users[uid]?['username'] = username;
    users[uid]?['bio'] = bio;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kProfilePrefix$uid',
      jsonEncode({'username': username, 'bio': bio}),
    );
    await _saveState();
  }

  /// Store a new avatar photo for [uid] and update in-memory immediately.
  Future<void> saveProfilePhoto(String uid, Uint8List photo) async {
    final url = storeImage(photo, persist: true);
    users[uid]?['photoUrl'] = url;
    await _saveState();
  }

  /// Update email for [uid]. Returns 'success' or an error message.
  Future<String> updateEmail(String uid, String newEmail) async {
    if (newEmail.isEmpty) return 'Email cannot be empty.';
    if (!newEmail.contains('@')) return 'Enter a valid email address.';
    if (users.values.any((u) => u['email'] == newEmail && u['uid'] != uid)) {
      return 'That email is already in use.';
    }
    users[uid]?['email'] = newEmail;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email_$uid', newEmail);
    await _saveState();
    return 'success';
  }

  /// Update password for [uid]. Returns 'success' or an error message.
  Future<String> updatePassword(
      String uid, String currentPassword, String newPassword) async {
    if (users[uid]?['password'] != currentPassword) {
      return 'Current password is incorrect.';
    }
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters.';
    }
    users[uid]?['password'] = newPassword;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password_$uid', newPassword);
    await _saveState();
    return 'success';
  }

  /// Called once at the end of [init] to restore saved profile edits.
  Future<void> _loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    for (final uid in users.keys) {
      final raw = prefs.getString('$_kProfilePrefix$uid');
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        users[uid]?['username'] = map['username'] ?? users[uid]!['username'];
        users[uid]?['bio'] = map['bio'] ?? users[uid]!['bio'];
      } catch (_) {}
    }

    final savedUid = prefs.getString(_kCurrentUid);
    if (savedUid != null && users.containsKey(savedUid)) {
      currentUid = savedUid;
    }
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAppState);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedUsers = decoded['users'] as Map<String, dynamic>? ?? {};
      final savedPosts = decoded['posts'] as Map<String, dynamic>? ?? {};
      final savedComments = decoded['comments'] as Map<String, dynamic>? ?? {};

      users
        ..clear()
        ..addAll(
          savedUsers.map(
            (uid, value) => MapEntry(uid, Map<String, dynamic>.from(value)),
          ),
        );

      posts
        ..clear()
        ..addAll(
          savedPosts.map((postId, value) {
            final post = Map<String, dynamic>.from(value);
            final rawDate = post['datePublished'];
            post['datePublished'] = rawDate is String
                ? DateTime.tryParse(rawDate) ?? DateTime.now()
                : DateTime.now();
            return MapEntry(postId, post);
          }),
        );

      comments
        ..clear()
        ..addAll(
          savedComments.map((postId, value) {
            final list = (value as List).whereType<Map>().map((comment) {
              final parsed = Map<String, dynamic>.from(comment);
              final rawDate = parsed['datePublished'];
              parsed['datePublished'] = rawDate is String
                  ? DateTime.tryParse(rawDate) ?? DateTime.now()
                  : DateTime.now();
              return parsed;
            }).toList();
            return MapEntry(postId, list);
          }),
        );

      final savedUid = decoded['currentUid'] as String?;
      currentUid = savedUid != null && users.containsKey(savedUid)
          ? savedUid
          : currentUid;
    } catch (_) {}
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final serializablePosts = posts.map((postId, post) {
      final copy = Map<String, dynamic>.from(post);
      final date = copy['datePublished'];
      copy['datePublished'] = date is DateTime
          ? date.toIso8601String()
          : DateTime.now().toIso8601String();
      return MapEntry(postId, copy);
    });
    final serializableComments = comments.map((postId, list) {
      return MapEntry(
        postId,
        list.map((comment) {
          final copy = Map<String, dynamic>.from(comment);
          final date = copy['datePublished'];
          copy['datePublished'] = date is DateTime
              ? date.toIso8601String()
              : DateTime.now().toIso8601String();
          return copy;
        }).toList(),
      );
    });

    await prefs.setString(
      _kAppState,
      jsonEncode({
        'currentUid': currentUid,
        'users': users,
        'posts': serializablePosts,
        'comments': serializableComments,
      }),
    );
  }

  Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  String _normalizeDescription(String description) {
    return description
        .replaceAll(RegExp(r'\s+\n'), '\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  void _seedUser(
      {required String uid,
      required String email,
      required String password,
      required String username,
      required String bio,
      required String photoUrl,
      required List<String> followers,
      required List<String> following}) {
    users[uid] = {
      'uid': uid,
      'email': email,
      'password': password,
      'username': username,
      'bio': bio,
      'photoUrl': photoUrl,
      'followers': List<String>.from(followers),
      'following': List<String>.from(following),
    };
  }

  void _seedPost(
      {required String uid,
      required String username,
      required String profImage,
      required Object img,
      required String description,
      required int daysAgo,
      required List<String> likesFrom}) {
    final postId = newId();
    final postUrl =
        img is String ? storeAssetImage(img) : storeImage(img as Uint8List);
    posts[postId] = {
      'postId': postId,
      'description': _normalizeDescription(description),
      'uid': uid,
      'username': username,
      'profImage': profImage,
      'postUrl': postUrl,
      'isVideo': false,
      'likes': List<String>.from(likesFrom),
      'datePublished': DateTime.now()
          .subtract(Duration(days: daysAgo, hours: uid.hashCode.abs() % 12)),
    };
    comments[postId] = [];
  }

  void _seedVideoPost(
      {required String uid,
      required String username,
      required String profImage,
      required String assetPath,
      required String description,
      required DateTime publishedAt,
      required List<String> likesFrom}) {
    final postId = newId();
    posts[postId] = {
      'postId': postId,
      'description': _normalizeDescription(description),
      'uid': uid,
      'username': username,
      'profImage': profImage,
      'postUrl': storeVideoAsset(assetPath),
      'isVideo': true,
      'likes': List<String>.from(likesFrom),
      'datePublished': publishedAt,
    };
    comments[postId] = [];
  }

  void _seedComment(
      {required String postId,
      required String uid,
      required String username,
      required String profilePic,
      required String text,
      String? parentCommentId,
      String? replyToUsername}) {
    comments.putIfAbsent(postId, () => []);
    comments[postId]!.add({
      'commentId': newId(),
      'postId': postId,
      'commentText': text,
      'uid': uid,
      'username': username,
      'profilePic': profilePic,
      'parentCommentId': parentCommentId,
      'replyToUsername': replyToUsername,
      'datePublished': DateTime.now(),
    });
  }

  String newId() => _uuid.v1();

  String storeImage(Uint8List bytes, {bool persist = false}) {
    final id = newId();
    if (!kIsWeb && persist && _imageStorageDir != null) {
      final path = '${_imageStorageDir!.path}/$id.jpg';
      File(path).writeAsBytesSync(bytes);
      return 'file-image://$path';
    }
    _images[id] = bytes;
    return 'local://$id';
  }

  String storeAssetImage(String assetPath) {
    _assetImages.putIfAbsent(assetPath, () => AssetImage(assetPath));
    return 'asset-image://$assetPath';
  }

  String storeVideoAsset(String assetPath) {
    _videoAssetPaths[assetPath] = assetPath;
    return 'asset-video://$assetPath';
  }

  Uint8List? getBytesForUrl(String url) {
    if (!url.startsWith('local://')) return null;
    final id = url.replaceFirst('local://', '');
    return _images[id];
  }

  ImageProvider? getImageProviderForUrl(String url) {
    if (url.startsWith('file-image://')) {
      if (kIsWeb) return null;
      final path = url.replaceFirst('file-image://', '');
      final file = File(path);
      if (!file.existsSync()) return null;
      return FileImage(file);
    }
    if (url.startsWith('local://')) {
      final id = url.replaceFirst('local://', '');
      final bytes = _images[id];
      if (bytes == null) return null;
      return _memoryImages.putIfAbsent(id, () => MemoryImage(bytes));
    }
    if (url.startsWith('asset-image://')) {
      final assetPath = url.replaceFirst('asset-image://', '');
      return _assetImages.putIfAbsent(assetPath, () => AssetImage(assetPath));
    }
    return null;
  }

  String? getVideoAssetPath(String url) {
    if (!url.startsWith('asset-video://')) return null;
    return url.replaceFirst('asset-video://', '');
  }

  Future<String> signUp({
    required String email,
    required String password,
    required String username,
    required String bio,
    Uint8List? photo,
  }) async {
    // Validate text fields first so user sees field errors before photo error
    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      return 'Please fill in all fields.';
    }
    if (photo == null) return 'Please choose a profile image.';
    if (users.values.any((u) => u['email'] == email)) {
      return 'An account with that email already exists.';
    }

    final uid = newId();
    final photoUrl = storeImage(photo, persist: true);

    users[uid] = {
      'uid': uid,
      'email': email,
      'password': password,
      'username': username,
      'bio': bio,
      'photoUrl': photoUrl,
      'followers': <String>[defaultUid],
      'following': <String>[defaultUid],
    };

    final demoFollowing =
        List<String>.from(users[defaultUid]?['following'] ?? []);
    final demoFollowers =
        List<String>.from(users[defaultUid]?['followers'] ?? []);
    if (!demoFollowing.contains(uid)) demoFollowing.add(uid);
    if (!demoFollowers.contains(uid)) demoFollowers.add(uid);
    users[defaultUid]?['following'] = demoFollowing;
    users[defaultUid]?['followers'] = demoFollowers;

    currentUid = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUid, uid);
    await _saveState();
    return 'success';
  }

  Future<String> login(
      {required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      return 'Please enter all the fields.';
    }
    final entry = users.entries.firstWhere(
      (e) => e.value['email'] == email && e.value['password'] == password,
      orElse: () => const MapEntry('', {}),
    );
    if (entry.key.isEmpty) return 'Wrong email or password.';
    currentUid = entry.key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUid, entry.key);
    await _saveState();
    return 'success';
  }

  Future<void> signOut() async {
    currentUid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUid);
    await _saveState();
  }

  Map<String, dynamic>? get currentUser =>
      currentUid != null ? users[currentUid] : null;

  Future<String> uploadPost({
    required String description,
    required Uint8List file,
    required String uid,
    required String username,
    required String profImage,
  }) async {
    try {
      await createLocalFallbackPost(
        description: description,
        file: file,
        uid: uid,
        username: username,
        profImage: profImage,
      );
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> createLocalFallbackPost({
    required String description,
    required Uint8List file,
    required String uid,
    required String username,
    required String profImage,
  }) async {
    final postId = 'local_${newId()}';
    final imageSize = await _decodeImageSize(file);
    final postUrl = storeImage(file, persist: true);
    posts[postId] = {
      'postId': postId,
      'description': _normalizeDescription(description),
      'uid': uid,
      'username': username,
      'profImage': profImage,
      'postUrl': postUrl,
      'imageUrls': <String>[postUrl],
      'isVideo': false,
      'isLocalFallback': true,
      'likes': <String>[],
      'imageWidth': imageSize?.width.round(),
      'imageHeight': imageSize?.height.round(),
      'datePublished': DateTime.now(),
    };
    comments[postId] = [];
    await _saveState();
    return postId;
  }

  Future<void> removeLocalFallbackPost(String postId) async {
    if (!postId.startsWith('local_')) return;
    posts.remove(postId);
    comments.remove(postId);
    await _saveState();
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

  void likePost(String postId, String uid) {
    final likes = List<String>.from(posts[postId]?['likes'] ?? []);
    likes.contains(uid) ? likes.remove(uid) : likes.add(uid);
    posts[postId]?['likes'] = likes;
    _saveState();
  }

  List<Map<String, dynamic>> getLocalFallbackPosts() {
    final list = posts.values
        .where((post) => post['isLocalFallback'] == true)
        .map((post) => Map<String, dynamic>.from(post))
        .toList();
    list.sort((a, b) =>
        (b['datePublished'] as DateTime).compareTo(a['datePublished']));
    return list;
  }

  Future<String> postComment({
    required String postId,
    required String text,
    required String uid,
    required String username,
    required String profilePic,
    String? parentCommentId,
    String? replyToUsername,
  }) async {
    if (text.isEmpty) return 'Please write something first...';
    comments.putIfAbsent(postId, () => []);
    comments[postId]!.insert(0, {
      'commentId': newId(),
      'postId': postId,
      'commentText': text,
      'uid': uid,
      'username': username,
      'profilePic': profilePic,
      'parentCommentId': parentCommentId,
      'replyToUsername': replyToUsername,
      'datePublished': DateTime.now(),
    });
    await _saveState();
    return 'success';
  }

  Future<String> deletePost(String postId) async {
    posts.remove(postId);
    comments.remove(postId);
    await _saveState();
    return 'success';
  }

  void followUser(String myUid, String targetUid) {
    final myFollowing = List<String>.from(users[myUid]?['following'] ?? []);
    final targetFollowers =
        List<String>.from(users[targetUid]?['followers'] ?? []);
    if (myFollowing.contains(targetUid)) {
      myFollowing.remove(targetUid);
      targetFollowers.remove(myUid);
    } else {
      myFollowing.add(targetUid);
      targetFollowers.add(myUid);
    }
    users[myUid]?['following'] = myFollowing;
    users[targetUid]?['followers'] = targetFollowers;
    _saveState();
  }

  List<Map<String, dynamic>> getAllPosts() {
    final following = currentUid != null
        ? List<String>.from(users[currentUid]?['following'] ?? [])
        : <String>[];
    final visibleUids = {...following, if (currentUid != null) currentUid!};
    final list =
        posts.values.where((p) => visibleUids.contains(p['uid'])).toList();
    list.sort((a, b) =>
        (b['datePublished'] as DateTime).compareTo(a['datePublished']));
    return list;
  }

  List<Map<String, dynamic>> getPostsByUser(String uid) {
    final list = posts.values.where((p) => p['uid'] == uid).toList();
    list.sort((a, b) =>
        (b['datePublished'] as DateTime).compareTo(a['datePublished']));
    return list;
  }

  List<Map<String, dynamic>> searchUsers(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return users.values
        .where((u) => (u['username'] as String).toLowerCase().contains(q))
        .toList();
  }

  List<Map<String, dynamic>> getComments(String postId) =>
      List.from(comments[postId] ?? []);

  int commentCount(String postId) => comments[postId]?.length ?? 0;

  // ── Notifications ──────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _notifications = [];

  void addNotification({
    required String type,
    required String fromUid,
    required String toUid,
    String? postId,
    String? postUrl,
    String? text,
  }) {
    if (fromUid == toUid) return;
    final from = users[fromUid];
    if (from == null) return;
    if (type == 'like') {
      _notifications.removeWhere((n) =>
          n['type'] == 'like' &&
          n['fromUid'] == fromUid &&
          n['postId'] == postId);
    }
    _notifications.insert(0, {
      'id': newId(),
      'type': type,
      'fromUid': fromUid,
      'fromUsername': from['username'],
      'fromPhoto': from['photoUrl'] ?? '',
      'toUid': toUid,
      'postId': postId,
      'postUrl': postUrl,
      'text': text,
      'createdAt': DateTime.now(),
      'read': false,
    });
  }

  List<Map<String, dynamic>> getNotificationsFor(String uid) =>
      _notifications.where((n) => n['toUid'] == uid).toList();

  int unreadCount(String uid) => _notifications
      .where((n) => n['toUid'] == uid && n['read'] == false)
      .length;

  void markAllRead(String uid) {
    for (final n in _notifications) {
      if (n['toUid'] == uid) n['read'] = true;
    }
  }
}
