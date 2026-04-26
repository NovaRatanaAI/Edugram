import 'package:flutter/material.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/screens/profile_screen.dart';

class CommentCard extends StatelessWidget {
  final Map<String, dynamic> snap;
  final VoidCallback? onReply;
  final double leftInset;
  const CommentCard(
      {Key? key, required this.snap, this.onReply, this.leftInset = 0})
      : super(key: key);

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w';
    if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo';
    }
    return '${(difference.inDays / 365).floor()}y';
  }

  @override
  Widget build(BuildContext context) {
    final datePublished = snap['datePublished'] as DateTime;
    final commentUserId = snap['uid'] as String? ?? '';
    final replyToUsername = (snap['replyToUsername'] ?? '').toString().trim();
    final isReply = replyToUsername.isNotEmpty;

    void openProfile() {
      if (commentUserId.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(uid: commentUserId),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16 + leftInset, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: openProfile,
            child: LocalImage(
              url: snap['profilePic'] ?? '',
              radius: isReply ? 14 : 18,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: openProfile,
                    child: Row(
                      children: [
                        Text(
                          snap['username'] ?? '',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            _timeAgo(datePublished),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 14,
                        ),
                        children: [
                          if (replyToUsername.isNotEmpty)
                            TextSpan(
                              text: '@$replyToUsername ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8EA7FF),
                              ),
                            ),
                          TextSpan(text: snap['commentText'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                  if (onReply != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: onReply,
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Icon(Icons.favorite, size: 16),
        ],
      ),
    );
  }
}

