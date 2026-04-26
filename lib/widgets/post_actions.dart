import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/widgets/like_animation.dart';

class PostActions extends StatelessWidget {
  final String postId;
  final String uid;
  final List<String> likes;
  final bool isBookmarked;
  final Animation<double> likeButtonYOffset;
  final AnimationController likeButtonJumpController;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const PostActions({
    Key? key,
    required this.postId,
    required this.uid,
    required this.likes,
    required this.isBookmarked,
    required this.likeButtonYOffset,
    required this.likeButtonJumpController,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
  }) : super(key: key);

  bool get _isLocalPost => postId.startsWith('local_');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: likeButtonJumpController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, likeButtonYOffset.value),
                  child: child,
                );
              },
              child: LikeAnimation(
                isAnimating: likes.contains(uid),
                smallLike: true,
                child: IconButton(
                  onPressed: () {
                    onLike();
                    likeButtonJumpController.forward(from: 0);
                  },
                  icon: likes.contains(uid)
                      ? const Icon(Icons.favorite, color: Colors.red)
                      : const Icon(Icons.favorite_border),
                ),
              ),
            ),
            Text(
              '${likes.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onComment,
              icon: const Icon(Icons.comment_outlined),
            ),
            _isLocalPost
                ? Text(
                    '${LocalStore.instance.commentCount(postId)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snapshot) => Text(
                      '${snapshot.data?.docs.length ?? 0}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
          ],
        ),
        IconButton(
          onPressed: onShare,
          icon: const Icon(Icons.send),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              onPressed: onBookmark,
              icon: TweenAnimationBuilder<double>(
                key: ValueKey<bool>(isBookmarked),
                tween: Tween<double>(begin: 0.72, end: 1),
                duration: const Duration(milliseconds: 210),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

