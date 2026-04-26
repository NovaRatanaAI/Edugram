import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edugram/model/users.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/resources/firebase_utils.dart';
import 'package:edugram/resources/firestore_methods.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/utils/utils.dart';
import 'package:provider/provider.dart';

import '../widgets/comment_card.dart';

/// Show comments as a draggable bottom sheet (like real Instagram).
/// Call this instead of Navigator.push.
Future<void> showCommentsSheet(
    BuildContext context, Map<String, dynamic> snap) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (ctx) => CommentsSheet(snap: snap),
  );
}

// ignore_for_file: library_private_types_in_public_api
class CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> snap;
  const CommentsSheet({Key? key, required this.snap}) : super(key: key);

  @override
  _CommentsSheetState createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _replyTarget;

  List<_CommentThread> _buildThreads(List<Map<String, dynamic>> comments) {
    final topLevelComments = comments
        .where((comment) => comment['parentCommentId'] == null)
        .toList(growable: false);
    final repliesByParent = <String, List<Map<String, dynamic>>>{};

    for (final comment in comments) {
      final parentCommentId = comment['parentCommentId'] as String?;
      if (parentCommentId == null) continue;
      repliesByParent.putIfAbsent(parentCommentId, () => []).add(comment);
    }

    return topLevelComments
        .map(
          (comment) => _CommentThread(
            comment: comment,
            replies: List<Map<String, dynamic>>.unmodifiable(
              repliesByParent[comment['commentId'] as String? ?? ''] ??
                  const <Map<String, dynamic>>[],
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _submitComment(User user) async {
    var text = _commentController.text.trim();
    if (text.isEmpty) return;

    final parentCommentId = _replyTarget == null
        ? null
        : ((_replyTarget!['parentCommentId'] ?? _replyTarget!['commentId'])
            as String?);
    final replyToUsername = (_replyTarget?['username'] ?? '').toString().trim();
    final replyPrefix = replyToUsername.isEmpty ? '' : '@$replyToUsername ';
    if (replyPrefix.isNotEmpty && text.startsWith(replyPrefix)) {
      text = text.substring(replyPrefix.length).trim();
    }
    if (text.isEmpty) return;

    final res = await FirestoreMethods().postComment(
      widget.snap['postId'],
      text,
      user.uid,
      user.username,
      user.photoUrl,
      parentCommentId: parentCommentId,
      replyToUsername: replyToUsername.isEmpty ? null : replyToUsername,
    );
    if (!mounted) return;
    if (res == 'success') {
      _commentController.clear();
      setState(() {
        _replyTarget = null;
      });
    } else {
      showSnackBar(res, context);
    }
  }

  void _replyToComment(Map<String, dynamic> comment) {
    final username = (comment['username'] ?? '').toString().trim();
    if (username.isEmpty) return;
    setState(() => _replyTarget = comment);

    final replyPrefix = '@$username ';
    _commentController.value = TextEditingValue(
      text: replyPrefix,
      selection: TextSelection.collapsed(offset: replyPrefix.length),
    );
    _commentFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User user = Provider.of<UserProvider>(context, listen: false).getUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isLocalPost =
        (widget.snap['postId'] ?? '').toString().startsWith('local_');

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // ── Handle + header ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Spacer(),
                      Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),

                // ── Comments list ─────────────────────────────────────────
                Expanded(
                  child: isLocalPost
                      ? _buildCommentsList(
                          LocalStore.instance
                              .getComments(widget.snap['postId']),
                          scrollController,
                          isDark,
                        )
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _firestore
                              .collection('posts')
                              .doc(widget.snap['postId'])
                              .collection('comments')
                              .orderBy('datePublished', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final comments = snapshot.data?.docs
                                    .map((doc) => dataWithDate(doc.data()))
                                    .toList() ??
                                <Map<String, dynamic>>[];
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            return _buildCommentsList(
                              comments,
                              scrollController,
                              isDark,
                            );
                          },
                        ),
                ),

                // ── Input bar ─────────────────────────────────────────────
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                if (_replyTarget != null)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to @${_replyTarget!['username']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _replyTarget = null;
                              _commentController.clear();
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 8,
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                      LocalImage(url: user.photoUrl, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Center(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitComment(user),
                                style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: _replyTarget == null
                                      ? 'Add a comment...'
                                      : 'Write a reply...',
                                  hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _submitComment(user),
                        child: const Text(
                          'Post',
                          style: TextStyle(
                            color: Color(0xFF0095F6),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentsList(
    List<Map<String, dynamic>> comments,
    ScrollController scrollController,
    bool isDark,
  ) {
    final threads = _buildThreads(comments);
    if (comments.isEmpty) {
      return Center(
        child: Text(
          'No comments yet.\nBe the first to comment!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 14,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final thread = threads[index];

        return Column(
          key: ValueKey(thread.comment['commentId']),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommentCard(
              snap: thread.comment,
              onReply: () => _replyToComment(thread.comment),
            ),
            for (final reply in thread.replies)
              CommentCard(
                key: ValueKey(reply['commentId']),
                snap: reply,
                leftInset: 44,
                onReply: () => _replyToComment(reply),
              ),
          ],
        );
      },
    );
  }
}

// Keep CommentsScreen as a thin alias so any old reference still compiles
class CommentsScreen extends StatelessWidget {
  final Map<String, dynamic> snap;
  const CommentsScreen({Key? key, required this.snap}) : super(key: key);

  @override
  Widget build(BuildContext context) => CommentsSheet(snap: snap);
}

class _CommentThread {
  final Map<String, dynamic> comment;
  final List<Map<String, dynamic>> replies;

  const _CommentThread({
    required this.comment,
    required this.replies,
  });
}

