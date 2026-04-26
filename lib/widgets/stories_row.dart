import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:edugram/resources/firestore_methods.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/story_store.dart';
import 'package:edugram/screens/profile_screen.dart';
import 'package:edugram/screens/story_viewer_screen.dart';
import 'package:edugram/utils/colors.dart';

class StoriesRow extends StatefulWidget {
  const StoriesRow({Key? key}) : super(key: key);

  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  static final Set<String> _seenStoryUids = <String>{};
  final _firestoreMethods = FirestoreMethods();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firestoreMethods.deleteExpiredStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').limit(30).snapshots(),
      builder: (context, snapshot) {
        final stories = snapshot.data?.docs.map((doc) => doc.data()).toList() ??
            <Map<String, dynamic>>[];
        stories.sort((a, b) {
          final aUid = a['uid'] as String? ?? '';
          final bUid = b['uid'] as String? ?? '';
          if (aUid == currentUid) return -1;
          if (bUid == currentUid) return 1;
          return (a['username'] as String? ?? '')
              .toLowerCase()
              .compareTo((b['username'] as String? ?? '').toLowerCase());
        });
        if (stories.isEmpty) return const SizedBox.shrink();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          LocalImage.precacheUrls(
            context,
            stories.map((story) => story['photoUrl'] as String?),
            width: 56,
            height: 56,
            limit: 16,
          );
        });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('isStory', isEqualTo: true)
              .snapshots(),
          builder: (context, storySnapshot) {
            final activeStories = _activeStoriesByUid(
              storySnapshot.data?.docs ?? [],
            );
            return SizedBox(
              height: 112,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: stories.length,
                itemBuilder: (context, i) {
                  final uid = stories[i]['uid'] as String? ?? '';
                  final userStories = activeStories[uid] ?? const <StoryItem>[];
                  final hasStory = userStories.isNotEmpty;
                  return _StoryBubble(
                    username: stories[i]['username'] as String? ?? '',
                    photoUrl: stories[i]['photoUrl'] as String? ?? '',
                    isOwn: uid == currentUid,
                    hasStory: hasStory,
                    hasNew: hasStory && !_seenStoryUids.contains(uid),
                    onTap: () {
                      if (uid.isEmpty) return;
                      if (hasStory) {
                        setState(() => _seenStoryUids.add(uid));
                        Navigator.of(context).push(
                          _softRoute(
                            StoryViewerScreen(
                              story: userStories.first,
                              stories: userStories,
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        _softRoute(ProfileScreen(uid: uid)),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Map<String, List<StoryItem>> _activeStoriesByUid(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final storiesByUid = <String, List<StoryItem>>{};
    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['storyId'] ??= doc.id;
      data['postId'] ??= doc.id;
      final story = StoryItem.fromMap(data);
      if (story.id.isEmpty || story.uid.isEmpty || story.imageUrl.isEmpty) {
        continue;
      }
      if (!story.expiresAt.isAfter(now)) continue;
      storiesByUid.putIfAbsent(story.uid, () => <StoryItem>[]).add(story);
    }
    for (final stories in storiesByUid.values) {
      stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return storiesByUid;
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
}

class _StoryBubble extends StatefulWidget {
  final String username;
  final String photoUrl;
  final bool isOwn;
  final bool hasStory;
  final bool hasNew;
  final VoidCallback onTap;

  const _StoryBubble({
    required this.username,
    required this.photoUrl,
    required this.isOwn,
    required this.hasStory,
    required this.hasNew,
    required this.onTap,
  });

  @override
  State<_StoryBubble> createState() => _StoryBubbleState();
}

class _StoryBubbleState extends State<_StoryBubble>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  AnimationController? _ringController;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.hasNew) {
      _ringController?.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _StoryBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasNew && !oldWidget.hasNew) {
      _ringController?.repeat();
    } else if (!widget.hasNew && oldWidget.hasNew) {
      _ringController?.stop();
      if (_ringController != null) {
        _ringController!.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ringController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ringController ?? kAlwaysDismissedAnimation,
                      builder: (context, child) {
                        final ringValue = _ringController?.value ?? 0;
                        final scale = widget.hasNew
                            ? 1 + (0.035 * (0.5 - (ringValue - 0.5).abs()) * 2)
                            : 1.0;
                        return Transform.rotate(
                          angle: ringValue * 6.283185307179586,
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: 68,
                        height: 68,
                        decoration: widget.hasStory
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(
                                  colors: [
                                    storyGradientStart,
                                    storyGradientMid,
                                    storyGradientEnd,
                                    storyGradientStart,
                                  ],
                                ),
                              )
                            : BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3E3E3E)
                                      : const Color(0xFFDBDBDB),
                                  width: 1.5,
                                ),
                              ),
                      ),
                    ),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2.5,
                        ),
                      ),
                    ),
                    LocalImage(url: widget.photoUrl, radius: 28),
                    if (widget.isOwn)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: blueColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add,
                              size: 14, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isOwn ? 'Your Story' : widget.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

