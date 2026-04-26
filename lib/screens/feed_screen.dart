import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edugram/resources/firebase_utils.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/utils/app_sounds.dart';
import 'package:edugram/utils/colors.dart';
import 'package:edugram/utils/global_variables.dart';

import '../screens/add_post_screen.dart';
import '../screens/messages_list_screen.dart';
import '../widgets/change_theme_button_widget.dart';
import '../widgets/edugram_wordmark.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream;
  final ScrollController _feedScrollController = ScrollController();
  int _shuffleSeed = 0;
  String _lastPrecacheSignature = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _postsStream = _firestore
        .collection('posts')
        .orderBy('datePublished', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _feedScrollController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _shuffleSeed++);

  void _handlePostChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      setState(() => _shuffleSeed++);
      AppSounds.playFeedRefresh();
    }
  }

  void _openAddPost() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddPostScreen()))
        .then(_handleComposerResult);
  }

  void _handleComposerResult(Object? result) {
    _refresh();
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
      _refresh();
      if (success) {
        AppSounds.playUploadSuccess();
        _scrollToNewPost();
      }
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

  void _scrollToNewPost() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_feedScrollController.hasClients) return;
      _feedScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
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

  List<Map<String, dynamic>> _buildFeedOrder(List<Map<String, dynamic>> posts) {
    final now = DateTime.now();
    final recentPosts = <Map<String, dynamic>>[];
    final olderPosts = <Map<String, dynamic>>[];

    for (final post in posts) {
      final publishedAt = post['datePublished'];
      final isRecent = publishedAt is DateTime &&
          now.difference(publishedAt) <= const Duration(minutes: 30);
      if (isRecent) {
        recentPosts.add(post);
      } else {
        olderPosts.add(post);
      }
    }

    recentPosts.sort((a, b) => (b['datePublished'] as DateTime)
        .compareTo(a['datePublished'] as DateTime));
    olderPosts.shuffle(Random(_shuffleSeed));
    return [...recentPosts, ...olderPosts];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > webScreenSize;

    return Scaffold(
      backgroundColor: isWeb
          ? webBackgroundColor
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: isWeb
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 1,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.add_box_outlined,
                    color: Theme.of(context).primaryColor, size: 28),
                onPressed: _openAddPost,
              ),
              title: EdugramWordmark(
                color: Theme.of(context).primaryColor,
                height: 32,
              ),
              actions: [
                const ChangeThemeButtonWidget(),
                IconButton(
                  icon: Icon(Icons.messenger_outline,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MessagesListScreen(),
                    ));
                  },
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: blueColor,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _postsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load feed:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final firebasePosts = snapshot.data?.docs
                    .map((doc) => dataWithDate(doc.data()))
                    .where((post) => post['isStory'] != true)
                    .toList() ??
                <Map<String, dynamic>>[];
            final posts = _buildFeedOrder([
              ...LocalStore.instance.getLocalFallbackPosts(),
              ...firebasePosts,
            ]);
            final precacheSignature = posts
                .take(6)
                .map((post) => post['postId'] as String? ?? '')
                .join('|');
            if (precacheSignature != _lastPrecacheSignature) {
              _lastPrecacheSignature = precacheSignature;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                LocalImage.precacheUrls(
                  context,
                  posts.take(6).expand(
                        (post) => [
                          post['postUrl'] as String?,
                          post['profImage'] as String?,
                        ],
                      ),
                  width: width,
                  height: MediaQuery.of(context).size.height * 0.35,
                  limit: 12,
                );
              });
            }

            if (posts.isEmpty) {
              return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(
                      child: Text(
                        'No posts yet.\nCreate one with the + button!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ]);
            }

            return ListView.builder(
              key: const PageStorageKey<String>('feed_posts_list'),
              controller: _feedScrollController,
              cacheExtent: 1200,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      const SizedBox(height: 6),
                      const StoriesRow(),
                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.2),
                      ),
                    ],
                  );
                }

                final post = posts[index - 1];
                final postId = post['postId'] as String? ?? '$index';
                final content = isWeb
                    ? Padding(
                        key: ValueKey(postId),
                        padding: EdgeInsets.symmetric(
                            horizontal: width * 0.3, vertical: 10),
                        child: PostCard(
                          snap: post,
                          onChanged: _handlePostChanged,
                          isNewlyRefreshed: _shuffleSeed > 0 && index <= 3,
                        ),
                      )
                    : PostCard(
                        key: ValueKey(postId),
                        snap: post,
                        onChanged: _handlePostChanged,
                        isNewlyRefreshed: _shuffleSeed > 0 && index <= 3,
                      );

                return RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>('feed-$postId-$_shuffleSeed'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: content,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

