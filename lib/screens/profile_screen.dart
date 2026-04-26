import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:edugram/resources/auth_methods.dart';
import 'package:edugram/resources/firebase_utils.dart';
import 'package:edugram/resources/firestore_methods.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/resources/story_store.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/screens/login_screen.dart';
import 'package:edugram/screens/add_post_screen.dart';
import 'package:edugram/screens/message_chat_screen.dart';
import 'package:edugram/screens/story_viewer_screen.dart';
import 'package:edugram/utils/app_sounds.dart';
import 'package:edugram/utils/colors.dart';
import 'package:edugram/widgets/post_card.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// ignore_for_file: library_private_types_in_public_api
class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  var userData = <String, dynamic>{};
  bool isLoading = true;
  String? _loadError;
  bool _isFollowLoading = false;
  bool _isDeletingPost = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      _loadError = null;
    });
    try {
      final snap = await _firestore.collection('users').doc(widget.uid).get();
      userData = Map<String, dynamic>.from(snap.data() ?? {});
      if (userData.isEmpty) {
        final localUser = LocalStore.instance.users[widget.uid];
        if (localUser != null) {
          userData = Map<String, dynamic>.from(localUser);
        }
      }
    } catch (error) {
      final localUser = LocalStore.instance.users[widget.uid];
      if (localUser != null) {
        userData = Map<String, dynamic>.from(localUser);
      } else {
        _loadError = error.toString();
      }
    }
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  bool get isMe => _auth.currentUser?.uid == widget.uid;
  bool get isFollowing =>
      (userData['followers'] as List? ?? []).contains(_auth.currentUser?.uid);
  int get followers => (userData['followers'] as List? ?? []).length;
  int get following => (userData['following'] as List? ?? []).length;
  List<String> get _profileUidCandidates {
    final uids = <String>{widget.uid};
    final dataUid = userData['uid'];
    if (dataUid is String && dataUid.trim().isNotEmpty) {
      uids.add(dataUid.trim());
    }
    return uids.where((uid) => uid.isNotEmpty).take(10).toList();
  }

  Future<void> _handleFollow() async {
    if (_isFollowLoading) return;
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again.')),
      );
      return;
    }
    setState(() => _isFollowLoading = true);
    try {
      await FirestoreMethods().followUser(currentUid, widget.uid);
      await _loadData();
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _openProfileStory() async {
    try {
      final stories = await StoryLookup.activeForAnyUid(_profileUidCandidates);
      if (!mounted) return;
      if (stories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active story.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            story: stories.first,
            stories: stories,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open story: $error')),
      );
    }
  }

  List<StoryItem> _activeStoriesFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final stories = <StoryItem>[];
    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['storyId'] ??= doc.id;
      data['postId'] ??= doc.id;
      if (data['isStory'] != true) continue;
      final story = StoryItem.fromMap(data);
      if (story.id.isEmpty || story.uid.isEmpty || story.imageUrl.isEmpty) {
        continue;
      }
      if (!story.expiresAt.isAfter(now)) continue;
      stories.add(story);
    }
    stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return stories;
  }

  void _handleComposerResult(Object? result) {
    _loadData();
    if (result is! Map) return;
    final kind = result['kind'] as String? ?? 'post';
    final status = result['status'];
    if (status is! Future<bool>) return;

    final label = kind == 'story' ? 'Story' : 'Post';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      _uploadSnackBar(
        '$label is uploading...',
        icon: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0095F6),
          ),
        ),
        duration: const Duration(days: 1),
      ),
    );
    status.then((success) {
      if (!mounted) return;
      _loadData();
      if (success) AppSounds.playUploadSuccess();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        _uploadSnackBar(
          success
              ? '$label uploaded.'
              : '$label could not upload. Please try again.',
          icon: Icon(
            success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: success ? const Color(0xFF42D77D) : Colors.redAccent,
            size: 22,
          ),
        ),
      );
    });
  }

  SnackBar _uploadSnackBar(
    String message, {
    required Widget icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF2C3038) : const Color(0xFFFFFFFF);
    final foregroundColor = isDark ? Colors.white : const Color(0xFF101318);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.10);
    return SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      content: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).clearUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    try {
      await AuthMethods().signOut();
    } catch (error) {
      debugPrint('Sign out failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loadError != null || userData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 58,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 14),
                Text(
                  _loadError == null
                      ? 'Profile not found.'
                      : 'Could not load profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: isDark ? Colors.white : Colors.black,
            floating: true,
            snap: true,
            elevation: 0,
            centerTitle: true,
            leading: canPop
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : isMe
                    ? IconButton(
                        icon: Icon(Icons.add_box_outlined,
                            color: isDark ? Colors.white : Colors.black,
                            size: 26),
                        onPressed: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                  builder: (_) => const AddPostScreen()),
                            )
                            .then(_handleComposerResult),
                      )
                    : null,
            title: Text(
              userData['username'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              if (isMe)
                IconButton(
                  icon: Icon(Icons.menu_rounded,
                      color: isDark ? Colors.white : Colors.black),
                  onPressed: () => _showMenu(context, isDark),
                ),
            ],
          ),
          SliverToBoxAdapter(child: _buildProfileHeader(context, isDark)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: isDark ? Colors.white : Colors.black,
                indicatorWeight: 1.5,
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                ],
              ),
              isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context) {
    final uidCandidates = _profileUidCandidates;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uidCandidates.length <= 1
          ? _firestore
              .collection('posts')
              .where(
                'uid',
                isEqualTo:
                    uidCandidates.isEmpty ? widget.uid : uidCandidates.first,
              )
              .snapshots()
          : _firestore
              .collection('posts')
              .where('uid', whereIn: uidCandidates)
              .snapshots(),
      builder: (context, snapshot) {
        final activeStories = _activeStoriesFromDocs(snapshot.data?.docs ?? []);
        final hasActiveStory = activeStories.isNotEmpty;
        final avatar = LocalImage(
          url: userData['photoUrl'] ?? '',
          radius: 42,
        );

        return SizedBox(
          width: 94,
          height: 94,
          child: Center(
            child: GestureDetector(
              onTap: hasActiveStory ? _openProfileStory : null,
              child: hasActiveStory
                  ? Container(
                      width: 94,
                      height: 94,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            storyGradientStart,
                            storyGradientMid,
                            storyGradientEnd,
                            storyGradientStart,
                          ],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: avatar,
                      ),
                    )
                  : avatar,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + stats row
          Row(
            children: [
              _buildProfileAvatar(context),
              const SizedBox(width: 8),
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore
                          .collection('posts')
                          .where('uid', isEqualTo: widget.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final localCount = LocalStore.instance
                            .getPostsByUser(widget.uid)
                            .length;
                        final firebaseCount = snapshot.data?.docs
                                .where((doc) => doc.data()['isStory'] != true)
                                .length ??
                            0;
                        return _statCol(
                            localCount + firebaseCount, 'Posts', isDark);
                      },
                    ),
                    _statCol(followers, 'Followers', isDark),
                    _statCol(following, 'Following', isDark),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Username + bio
          Text(
            userData['username'] ?? '',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          if ((userData['bio'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              userData['bio'] ?? '',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          if (isMe)
            _outlineButton(
              label: 'Edit Profile',
              isDark: isDark,
              onTap: () => _showEditProfile(context, isDark),
            )
          else
            Row(
              children: [
                Expanded(
                  child: isFollowing
                      ? _outlineButton(
                          label: _isFollowLoading ? '...' : 'Following',
                          isDark: isDark,
                          onTap: _handleFollow,
                        )
                      : _solidButton(
                          label: _isFollowLoading ? '...' : 'Follow',
                          onTap: _handleFollow,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _outlineButton(
                    label: 'Message',
                    isDark: isDark,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MessageChatScreen(
                          username: userData['username'] ?? '',
                          photoUrl: userData['photoUrl'] ?? '',
                          uid: widget.uid,
                        ),
                      ));
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildPostsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('posts')
          .where('uid', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final localPosts = LocalStore.instance.getPostsByUser(widget.uid);
        if (snapshot.connectionState == ConnectionState.waiting &&
            localPosts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = [
          ...localPosts,
          ...snapshot.data?.docs
                  .map((doc) => dataWithDate(doc.data()))
                  .where((post) => post['isStory'] != true)
                  .toList() ??
              <Map<String, dynamic>>[],
        ];
        posts.sort((a, b) => (b['datePublished'] as DateTime)
            .compareTo(a['datePublished'] as DateTime));
        final photoPosts = posts.where((p) => p['isVideo'] != true).toList();
        final videoPosts = posts.where((p) => p['isVideo'] == true).toList();
        return _buildPhotoGrid(photoPosts, videoPosts, isDark);
      },
    );
  }

  Widget _buildPhotoGrid(List photoPosts, List videoPosts, bool isDark) {
    final allItems = [...photoPosts, ...videoPosts];
    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined,
                size: 56, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 15),
            Text(
              'No Posts Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Share your first photo',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final post = allItems[index];
        final isVideo = post['isVideo'] == true;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ProfilePostScreen(
                post: Map<String, dynamic>.from(post),
                onChanged: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              isVideo
                  ? Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 36),
                      ),
                    )
                  : LocalImage(
                      url: post['postUrl'] ?? '',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
              if (isVideo)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.videocam_rounded,
                      color: Colors.white, size: 18),
                ),
              if (isMe)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _isDeletingPost
                        ? null
                        : () => _showPostOptions(context, post, isDark),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        shape: BoxShape.circle,
                      ),
                      child: _isDeletingPost
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showPostOptions(
    BuildContext context,
    Map<String, dynamic> post,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete this post?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'This action cannot be undone.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _deletePostFromProfile(post['postId'] as String? ?? '');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Delete Post',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePostFromProfile(String postId) async {
    if (postId.isEmpty || _isDeletingPost) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeletingPost = true);
    final res = await FirestoreMethods().deletePost(postId);
    final isSuccess = res == 'success';

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isSuccess
              ? 'Post deleted successfully.'
              : 'Could not delete post: $res',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (!mounted) return;
    setState(() => _isDeletingPost = false);
    if (isSuccess) AppSounds.playUploadSuccess();
  }

  void _showEditProfile(BuildContext context, bool isDark) {
    final usernameCtrl =
        TextEditingController(text: userData['username'] ?? '');
    final bioCtrl = TextEditingController(text: userData['bio'] ?? '');
    final emailCtrl = TextEditingController(text: userData['email'] ?? '');
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    InputDecoration fieldDecor(String hint) => InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        );

    TextStyle labelStyle() => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : Colors.black54);

    Widget sectionDivider(String title) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(children: [
            Expanded(
                child:
                    Divider(color: isDark ? Colors.white12 : Colors.black12)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ),
            Expanded(
                child:
                    Divider(color: isDark ? Colors.white12 : Colors.black12)),
          ]),
        );

    bool showCurrentPass = false;
    bool showNewPass = false;
    bool showConfirmPass = false;
    Uint8List? pickedPhoto;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),

                    // ── PROFILE INFO ──────────────────────────────────
                    sectionDivider('PROFILE INFO'),

                    // Avatar
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (picked == null) return;
                          final pickedPhotoBytes = await picked.readAsBytes();
                          setSheetState(() => pickedPhoto = pickedPhotoBytes);
                        },
                        child: Stack(children: [
                          pickedPhoto != null
                              ? CircleAvatar(
                                  radius: 42,
                                  backgroundImage: MemoryImage(pickedPhoto!),
                                )
                              : LocalImage(
                                  url: userData['photoUrl'] ?? '', radius: 42),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0095F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Username', style: labelStyle()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: usernameCtrl,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: fieldDecor(''),
                    ),
                    const SizedBox(height: 12),
                    Text('Bio', style: labelStyle()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bioCtrl,
                      maxLines: 3,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: fieldDecor('Write a bio...'),
                    ),

                    // ── CHANGE EMAIL ──────────────────────────────────
                    sectionDivider('CHANGE EMAIL'),

                    Text('New Email', style: labelStyle()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: fieldDecor('Enter new email'),
                    ),

                    // ── CHANGE PASSWORD ───────────────────────────────
                    sectionDivider('CHANGE PASSWORD'),

                    Text('Current Password', style: labelStyle()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: currentPassCtrl,
                      obscureText: !showCurrentPass,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: fieldDecor('Enter current password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              showCurrentPass
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38),
                          onPressed: () => setSheetState(
                              () => showCurrentPass = !showCurrentPass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('New Password', style: labelStyle()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: !showNewPass,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: fieldDecor('Min 6 characters').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              showNewPass
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38),
                          onPressed: () =>
                              setSheetState(() => showNewPass = !showNewPass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Confirm New Password', style: labelStyle()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: !showConfirmPass,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: fieldDecor('Re-enter new password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              showConfirmPass
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38),
                          onPressed: () => setSheetState(
                              () => showConfirmPass = !showConfirmPass),
                        ),
                      ),
                    ),

                    // ── Save button ───────────────────────────────────
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        final uid = widget.uid;

                        // Save username + bio
                        await AuthMethods().updateProfile(
                          uid,
                          usernameCtrl.text.trim(),
                          bioCtrl.text.trim(),
                        );

                        // Save new profile photo if picked
                        if (pickedPhoto != null) {
                          await AuthMethods()
                              .updateProfilePhoto(uid, pickedPhoto!);
                        }

                        // Change email if modified
                        final newEmail = emailCtrl.text.trim();
                        if (newEmail.isNotEmpty &&
                            newEmail != (userData['email'] ?? '')) {
                          final res =
                              await AuthMethods().updateEmail(uid, newEmail);
                          if (res != 'success') {
                            if (!sheetCtx.mounted) return;
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(
                                    content: Text(res),
                                    backgroundColor: Colors.red));
                            return;
                          }
                        }

                        // Change password only if any password field filled
                        if (currentPassCtrl.text.isNotEmpty ||
                            newPassCtrl.text.isNotEmpty) {
                          if (newPassCtrl.text != confirmPassCtrl.text) {
                            if (!sheetCtx.mounted) return;
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('New passwords do not match.'),
                                    backgroundColor: Colors.red));
                            return;
                          }
                          final res = await AuthMethods().updatePassword(
                            uid,
                            currentPassCtrl.text,
                            newPassCtrl.text,
                          );
                          if (res != 'success') {
                            if (!sheetCtx.mounted) return;
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(
                                    content: Text(res),
                                    backgroundColor: Colors.red));
                            return;
                          }
                        }

                        if (!sheetCtx.mounted) return;
                        Navigator.pop(sheetCtx);
                        _loadData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Profile updated!'),
                                backgroundColor: Colors.green));
                      },
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0095F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1F2937),
                          const Color(0xFF111827),
                        ]
                      : [
                          const Color(0xFFEAF5FF),
                          const Color(0xFFFFFFFF),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0095F6).withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF0095F6),
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'End this session?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _handleSignOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0095F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(int num, String label, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num >= 1000 ? '${(num / 1000).toStringAsFixed(1)}k' : '$num',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _solidButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2D3139),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _outlineButton(
      {required String label,
      required bool isDark,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F232B) : const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      ),
    );
  }
}

class _ProfilePostScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onChanged;

  const _ProfilePostScreen({
    required this.post,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        children: [
          PostCard(
            snap: post,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bgColor;
  _TabBarDelegate(this.tabBar, this.bgColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: bgColor, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

