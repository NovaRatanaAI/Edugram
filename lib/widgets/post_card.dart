import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edugram/model/users.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/resources/firestore_methods.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/story_store.dart';
import 'package:edugram/screens/comments_screen.dart';
import 'package:edugram/screens/profile_screen.dart';
import 'package:edugram/screens/story_viewer_screen.dart';
import 'package:edugram/utils/app_sounds.dart';
import 'package:edugram/utils/colors.dart';
import 'package:edugram/utils/global_variables.dart';
import 'package:edugram/utils/utils.dart';
import 'package:edugram/widgets/post_actions.dart';
import 'package:edugram/widgets/post_caption.dart';
import 'package:edugram/widgets/post_header.dart';
import 'package:edugram/widgets/post_media.dart';
import 'package:edugram/widgets/post_options_sheet.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> snap;
  final VoidCallback? onChanged;
  final bool isNewlyRefreshed;

  const PostCard({
    Key? key,
    required this.snap,
    this.onChanged,
    this.isNewlyRefreshed = false,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  static const double _minInstagramPostAspectRatio = 0.8;
  static const double _maxInstagramPostAspectRatio = 1.91;

  final _firestoreMethods = FirestoreMethods();

  bool _isLikeAnimating = false;
  bool _isCaptionExpanded = false;
  bool? _followingOverride;
  bool? _savedOverride;
  List<String>? _likesOverride;
  bool _isFollowLoading = false;
  bool _isLikeLoading = false;
  bool _isDeleting = false;
  int _mediaPage = 0;
  double? _resolvedImageAspectRatio;
  String? _resolvedImageUrl;
  ImageStream? _postImageStream;
  ImageStreamListener? _postImageStreamListener;
  late final AnimationController _likeButtonJumpController;
  late final Animation<double> _likeButtonYOffset;

  String get _postId => (widget.snap['postId'] ?? '').toString();
  String get _description =>
      (widget.snap['description'] ?? '').toString().trim();
  bool get _isLocalPost => _postId.startsWith('local_');

  @override
  void initState() {
    super.initState();
    _likeButtonJumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _likeButtonYOffset = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -26)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -26, end: 0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_likeButtonJumpController);
  }

  @override
  void dispose() {
    _clearImageAspectRatioListener();
    _likeButtonJumpController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageAspectRatio();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snap['postId'] != widget.snap['postId']) {
      _likesOverride = null;
    } else if (_likesOverride != null &&
        _sameLikes(
            _likesOverride!, List<String>.from(widget.snap['likes'] ?? []))) {
      _likesOverride = null;
    }
    if (oldWidget.snap['postUrl'] != widget.snap['postUrl'] ||
        oldWidget.snap['imageUrls'] != widget.snap['imageUrls'] ||
        oldWidget.snap['imageWidth'] != widget.snap['imageWidth'] ||
        oldWidget.snap['imageHeight'] != widget.snap['imageHeight'] ||
        oldWidget.snap['isVideo'] != widget.snap['isVideo']) {
      _mediaPage = 0;
      _resolveImageAspectRatio();
    }
  }

  bool _sameLikes(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final aSet = a.toSet();
    return b.every(aSet.contains);
  }

  List<String> _mediaUrls(Map<String, dynamic> post) {
    final urls = List<String>.from(post['imageUrls'] ?? [])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    if (urls.isNotEmpty) return urls;
    final postUrl = (post['postUrl'] ?? '').toString();
    return postUrl.isEmpty ? <String>[] : <String>[postUrl];
  }

  double _postAspectRatio(Map<String, dynamic> post) {
    final storedWidth = (post['imageWidth'] as num?)?.toDouble();
    final storedHeight = (post['imageHeight'] as num?)?.toDouble();
    if (storedWidth != null &&
        storedHeight != null &&
        storedWidth > 0 &&
        storedHeight > 0) {
      return _instagramPostAspectRatio(storedWidth / storedHeight);
    }
    return _instagramPostAspectRatio(_resolvedImageAspectRatio ?? 1);
  }

  double _instagramPostAspectRatio(double aspectRatio) {
    return aspectRatio
        .clamp(_minInstagramPostAspectRatio, _maxInstagramPostAspectRatio)
        .toDouble();
  }

  void _resolveImageAspectRatio() {
    final postUrl = (widget.snap['postUrl'] ?? '').toString();
    final isVideo = widget.snap['isVideo'] == true;
    final storedWidth = (widget.snap['imageWidth'] as num?)?.toDouble();
    final storedHeight = (widget.snap['imageHeight'] as num?)?.toDouble();
    if (isVideo ||
        postUrl.isEmpty ||
        (storedWidth != null &&
            storedHeight != null &&
            storedWidth > 0 &&
            storedHeight > 0)) {
      _clearImageAspectRatioListener();
      return;
    }

    if (_resolvedImageUrl == postUrl && _resolvedImageAspectRatio != null) {
      return;
    }

    _clearImageAspectRatioListener();
    _resolvedImageUrl = postUrl;
    _resolvedImageAspectRatio = null;

    final provider = LocalImage.providerForUrl(postUrl);
    if (provider == null) return;

    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (imageInfo, _) {
        final image = imageInfo.image;
        if (!mounted || image.width <= 0 || image.height <= 0) return;
        setState(() => _resolvedImageAspectRatio = image.width / image.height);
      },
      onError: (_, __) => _clearImageAspectRatioListener(),
    );
    _postImageStream = stream;
    _postImageStreamListener = listener;
    stream.addListener(listener);
  }

  void _clearImageAspectRatioListener() {
    final stream = _postImageStream;
    final listener = _postImageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _postImageStream = null;
    _postImageStreamListener = null;
  }

  String _formatPostTime(DateTime publishedAt) {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat.yMMMd().format(publishedAt);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openProfile(String uid) {
    if (uid.isEmpty) return;
    Navigator.of(context).push(_softRoute(ProfileScreen(uid: uid)));
  }

  Future<void> _openStoryOrProfile(String uid) async {
    if (uid.isEmpty) return;
    try {
      final stories = await StoryLookup.activeForUid(uid);
      if (!mounted) return;
      if (stories.isNotEmpty) {
        Navigator.of(context).push(
          _softRoute(
            StoryViewerScreen(
              story: stories.first,
              stories: stories,
            ),
          ),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }
    _openProfile(uid);
  }

  bool _hasActiveStory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['storyId'] ??= doc.id;
      data['postId'] ??= doc.id;
      if (data['isStory'] != true) continue;
      final story = StoryItem.fromMap(data);
      if (story.id.isEmpty || story.imageUrl.isEmpty) continue;
      if (story.expiresAt.isAfter(now)) return true;
    }
    return false;
  }

  PageRouteBuilder<void> _softRoute(Widget screen) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => screen,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _deletePost() async {
    if (_isDeleting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Deleting post...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(days: 1),
      ),
    );

    final res = await _firestoreMethods.deletePost(_postId);
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

    if (isSuccess) {
      AppSounds.playUploadSuccess();
      widget.onChanged?.call();
    }
    if (!mounted) return;
    setState(() => _isDeleting = false);
  }

  void _showPostOptionsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PostOptionsSheet(
        isDark: isDark,
        onDelete: _deletePost,
      ),
    );
  }

  Future<void> _toggleLike(List<String> likes, String uid) async {
    if (_isLikeLoading || uid.isEmpty) return;
    final wasLiked = likes.contains(uid);
    final nextLikes = List<String>.from(likes);
    wasLiked ? nextLikes.remove(uid) : nextLikes.add(uid);
    setState(() {
      _isLikeLoading = true;
      _likesOverride = nextLikes;
    });
    try {
      await _firestoreMethods.likePost(_postId, uid, likes);
      if (_isLocalPost) {
        widget.snap['likes'] = nextLikes;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _likesOverride = likes);
      showSnackBar(error.toString(), context);
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _toggleFollow(
    User user,
    String postOwnerUid,
    bool isFollowingUser,
  ) async {
    if (_isFollowLoading) return;
    final nextFollowing = !isFollowingUser;
    setState(() {
      _isFollowLoading = true;
      _followingOverride = nextFollowing;
    });
    try {
      await _firestoreMethods.followUser(user.uid, postOwnerUid);
      if (!mounted) return;
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
    } catch (error) {
      if (!mounted) return;
      setState(() => _followingOverride = isFollowingUser);
      showSnackBar(error.toString(), context);
    }
    if (mounted) setState(() => _isFollowLoading = false);
  }

  Future<void> _toggleBookmark(User user, bool isBookmarked) async {
    final nextSaved = !isBookmarked;
    setState(() => _savedOverride = nextSaved);
    try {
      await _firestoreMethods.toggleSavedPost(user.uid, _postId, isBookmarked);
      if (!mounted) return;
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      _showSnack(nextSaved ? 'Post saved.' : 'Post unsaved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savedOverride = isBookmarked);
      _showSnack(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final livePost = widget.snap;
    final likes = _likesOverride ?? List<String>.from(livePost['likes'] ?? []);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > webScreenSize;
    final isVideo = livePost['isVideo'] == true;
    final mediaAspectRatio = _postAspectRatio(livePost);
    final mediaUrls = _mediaUrls(livePost);
    final postOwnerUid = livePost['uid'] as String? ?? '';
    final isOwnPost = user.uid == postOwnerUid;
    final following = List<String>.from(user.following);
    final followers = List<String>.from(user.followers);
    final isFollowingUser =
        !isOwnPost && (_followingOverride ?? following.contains(postOwnerUid));
    final followsMe = !isOwnPost && followers.contains(postOwnerUid);
    final followLabel =
        isFollowingUser ? 'Following' : (followsMe ? 'Follow back' : 'Follow');
    final isBookmarked = _savedOverride ?? user.savedPosts.contains(_postId);
    final publishedAt = livePost['datePublished'] is DateTime
        ? livePost['datePublished'] as DateTime
        : DateTime.now();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isWeb ? secondaryColor : mobileBackgroundColor,
        ),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: postOwnerUid.isEmpty
                ? null
                : FirebaseFirestore.instance
                    .collection('posts')
                    .where('uid', isEqualTo: postOwnerUid)
                    .where('isStory', isEqualTo: true)
                    .snapshots(),
            builder: (context, storySnapshot) {
              final hasActiveStory =
                  _hasActiveStory(storySnapshot.data?.docs ?? []);
              return PostHeader(
                post: livePost,
                isOwnPost: isOwnPost,
                isFollowingUser: isFollowingUser,
                hasActiveStory: hasActiveStory,
                isFollowLoading: _isFollowLoading,
                isDeleting: _isDeleting,
                isNewlyRefreshed: widget.isNewlyRefreshed,
                followLabel: followLabel,
                timeLabel: _formatPostTime(publishedAt),
                onAvatarTap: () => _openStoryOrProfile(postOwnerUid),
                onProfileTap: () => _openProfile(postOwnerUid),
                onFollowTap: () =>
                    _toggleFollow(user, postOwnerUid, isFollowingUser),
                onOptionsTap: () => _showPostOptionsSheet(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              );
            },
          ),
          PostMedia(
            post: livePost,
            isVideo: isVideo,
            isLikeAnimating: _isLikeAnimating,
            width: width,
            aspectRatio: mediaAspectRatio,
            mediaPage: _mediaPage,
            mediaUrls: mediaUrls,
            onDoubleTap: () {
              _toggleLike(likes, user.uid);
              setState(() => _isLikeAnimating = true);
            },
            onLikeAnimationEnd: () => setState(() => _isLikeAnimating = false),
            onPageChanged: (page) => setState(() => _mediaPage = page),
          ),
          PostActions(
            postId: _postId,
            uid: user.uid,
            likes: likes,
            isBookmarked: isBookmarked,
            likeButtonYOffset: _likeButtonYOffset,
            likeButtonJumpController: _likeButtonJumpController,
            onLike: () => _toggleLike(likes, user.uid),
            onComment: () async {
              await showCommentsSheet(context, widget.snap);
              if (mounted) setState(() {});
            },
            onShare: () => _showSnack('Sharing is not available yet.'),
            onBookmark: () => _toggleBookmark(user, isBookmarked),
          ),
          PostCaption(
            username: widget.snap['username'] ?? '',
            description: _description,
            isExpanded: _isCaptionExpanded,
            onExpand: () => setState(() => _isCaptionExpanded = true),
          ),
        ],
      ),
    );
  }
}

