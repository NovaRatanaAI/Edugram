import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:edugram/resources/firestore_methods.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/story_store.dart';
import 'package:edugram/utils/message_store.dart';
import 'package:edugram/widgets/like_animation.dart';

class StoryViewerScreen extends StatefulWidget {
  final StoryItem story;
  final List<StoryItem> stories;
  final int initialIndex;

  StoryViewerScreen({
    Key? key,
    required this.story,
    List<StoryItem>? stories,
    this.initialIndex = 0,
  })  : stories = stories ?? <StoryItem>[story],
        super(key: key);

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _storyDuration = Duration(seconds: 5);

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  late final AnimationController _progressController;
  late int _storyIndex;
  late List<StoryItem> _activeStories;
  bool _isSending = false;
  bool _isLiking = false;
  bool _isDeleting = false;
  bool _likedOverride = false;
  final _firestoreMethods = FirestoreMethods();

  List<StoryItem> get _stories => _activeStories;
  StoryItem get story => _stories[_storyIndex.clamp(0, _stories.length - 1)];
  bool get _isOwnStory => FirebaseAuth.instance.currentUser?.uid == story.uid;

  @override
  void initState() {
    super.initState();
    _activeStories = widget.stories.isEmpty
        ? <StoryItem>[widget.story]
        : List<StoryItem>.from(widget.stories);
    _storyIndex = widget.initialIndex.clamp(0, _stories.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _goToNextStory();
        }
      })
      ..forward();
    _messageFocus.addListener(_handleMessageFocusChange);
  }

  @override
  void dispose() {
    _messageFocus.removeListener(_handleMessageFocusChange);
    _progressController.dispose();
    _messageController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  String _storyAge() {
    final diff = DateTime.now().difference(story.createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }

  void _restartStoryProgress() {
    _progressController
      ..stop()
      ..reset()
      ..forward();
  }

  void _pauseStoryProgress() {
    if (_progressController.isAnimating) {
      _progressController.stop();
    }
  }

  void _resumeStoryProgress() {
    if (!mounted || _isDeleting || _messageFocus.hasFocus) return;
    if (_progressController.status != AnimationStatus.completed) {
      _progressController.forward();
    }
  }

  void _handleMessageFocusChange() {
    if (_messageFocus.hasFocus) {
      _pauseStoryProgress();
    } else {
      _resumeStoryProgress();
    }
  }

  void _goToNextStory() {
    if (_storyIndex < _stories.length - 1) {
      setState(() {
        _storyIndex++;
        _likedOverride = false;
      });
      _restartStoryProgress();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _goToPreviousStory() {
    if (_storyIndex > 0) {
      setState(() {
        _storyIndex--;
        _likedOverride = false;
      });
      _restartStoryProgress();
    } else {
      _restartStoryProgress();
    }
  }

  Future<void> _sendStoryMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (_isOwnStory) {
      _showSnack('You cannot message your own story.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await MessageStore.instance.addStoryReply(
        story.uid,
        text,
        storyImageUrl: story.imageUrl,
        otherUsername: story.username,
        otherPhotoUrl: story.userPhotoUrl,
      );
      _messageController.clear();
      _messageFocus.unfocus();
      if (!mounted) return;
      _showSnack('Message sent.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Could not send message: $error');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleLike(bool isLiked) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || _isLiking) return;
    if (_isOwnStory) {
      _showSnack('You cannot like your own story.');
      return;
    }

    setState(() {
      _isLiking = true;
      _likedOverride = !isLiked;
    });
    try {
      await FirebaseFirestore.instance.collection('posts').doc(story.id).set({
        'storyLikes': !isLiked
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;
      setState(() => _likedOverride = isLiked);
      _showSnack('Could not update like: $error');
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showStoryOptions() {
    final isOwnStory = _isOwnStory;
    _pauseStoryProgress();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              if (isOwnStory)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete story',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: _isDeleting
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _deleteStory();
                        },
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.info_outline,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'Story options',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    'No options available.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ).whenComplete(_resumeStoryProgress);
  }

  Future<void> _deleteStory() async {
    if (_isDeleting) return;
    _pauseStoryProgress();
    setState(() => _isDeleting = true);
    final res = await _firestoreMethods.deleteStory(story.id);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (res == 'success') {
      _showSnack('Story deleted.');
      if (_stories.length <= 1) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _activeStories.removeAt(_storyIndex);
        _storyIndex = _storyIndex.clamp(0, _activeStories.length - 1);
      });
      _restartStoryProgress();
    } else {
      _showSnack(res);
      _resumeStoryProgress();
    }
  }

  void _showStoryLikes(List<String> likeUids) {
    _pauseStoryProgress();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Story likes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${likeUids.length}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (likeUids.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No likes yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Flexible(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadLikedUsers(likeUids),
                    builder: (context, snapshot) {
                      final users = snapshot.data ?? const [];
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: users.length,
                        separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withValues(alpha: 0.08)),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: LocalImage(
                              url: user['photoUrl'] as String? ?? '',
                              radius: 22,
                            ),
                            title: Text(
                              user['username'] as String? ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ).whenComplete(_resumeStoryProgress);
  }

  Future<List<Map<String, dynamic>>> _loadLikedUsers(List<String> uids) async {
    final users = <Map<String, dynamic>>[];
    for (final uid in uids) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) continue;
      users.add(data);
    }
    return users;
  }

  Widget _buildStoryProgressBars() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        return Row(
          children: List.generate(_stories.length, (index) {
            final value = index < _storyIndex
                ? 1.0
                : (index == _storyIndex ? _progressController.value : 0.0);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == _stories.length - 1 ? 0 : 4,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildStoryTapZones() {
    return Positioned(
      left: 0,
      right: 0,
      top: 92,
      bottom: 96,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _goToPreviousStory,
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _goToNextStory,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            LocalImage(
              key: ValueKey<String>(story.imageUrl),
              url: story.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            _buildStoryTextOverlay(),
            _buildStoryTapZones(),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Column(
                children: [
                  _buildStoryProgressBars(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      LocalImage(url: story.userPhotoUrl, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: story.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: '  ${_storyAge()}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isDeleting ? null : _showStoryOptions,
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(story.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  final likes = List<String>.from(
                    snapshot.data?.data()?['storyLikes'] ?? const <String>[],
                  );
                  final streamLiked =
                      currentUid.isNotEmpty && likes.contains(currentUid);
                  final isLiked = _isLiking ? _likedOverride : streamLiked;

                  if (_isOwnStory) {
                    return GestureDetector(
                      onTap: () => _showStoryLikes(likes),
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                likes.isEmpty
                                    ? 'No likes yet'
                                    : '${likes.length} ${likes.length == 1 ? 'person likes' : 'people like'} your story',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white.withValues(alpha: 0.75),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.62),
                              width: 1.2,
                            ),
                            color: Colors.black.withValues(alpha: 0.16),
                          ),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _messageFocus,
                            enabled: !_isOwnStory && !_isSending,
                            onSubmitted: (_) => _sendStoryMessage(),
                            textInputAction: TextInputAction.send,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: _isOwnStory
                                  ? 'Your story'
                                  : 'Send message...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _toggleLike(isLiked),
                        child: LikeAnimation(
                          isAnimating: isLiked,
                          smallLike: true,
                          duration: const Duration(milliseconds: 260),
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isLiked ? Colors.redAccent : Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: _sendStoryMessage,
                        child: _isSending
                            ? const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Icon(
                                Icons.send_outlined,
                                color: Colors.white,
                                size: 34,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryTextOverlay() {
    final text = story.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final textWidth = width * 0.78;

          return Stack(
            children: [
              Align(
                alignment: Alignment(
                  (story.textX * 2) - 1,
                  (story.textY * 2) - 1,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: textWidth),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

