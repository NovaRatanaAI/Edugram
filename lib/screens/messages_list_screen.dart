import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/resources/story_store.dart';
import 'package:edugram/screens/message_chat_screen.dart';
import 'package:edugram/utils/colors.dart';
import 'package:edugram/utils/message_store.dart';

// ignore_for_file: library_private_types_in_public_api
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({Key? key}) : super(key: key);

  @override
  _MessagesListScreenState createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final _db = LocalStore.instance;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  IconData _previewIcon(String subtitle) {
    if (subtitle == 'Sent a photo') return Icons.image_outlined;
    if (subtitle == 'Voice message') return Icons.graphic_eq_rounded;
    return Icons.chat_bubble_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MessageStore.instance.watchConversations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Messages')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load messages:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          );
        }

        final conversations = snapshot.data ?? const <Map<String, dynamic>>[];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('isStory', isEqualTo: true)
              .snapshots(),
          builder: (context, storySnapshot) {
            final activeStoryUids = _activeStoryUids(
              storySnapshot.data?.docs ?? const [],
            );

            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                centerTitle: false,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      conversations.isEmpty
                          ? 'No active conversations'
                          : '${conversations.length} conversation${conversations.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                iconTheme:
                    IconThemeData(color: isDark ? Colors.white : Colors.black),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              body: snapshot.connectionState == ConnectionState.waiting &&
                      conversations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : conversations.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
                          children: [
                            _buildActiveRail(
                              conversations,
                              activeStoryUids,
                              isDark,
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildInboxPrompt(
                                conversations.length,
                                isDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _sectionHeader('Recent', isDark),
                            ),
                            const SizedBox(height: 4),
                            ...conversations.map((convo) {
                              final uid = convo['uid'] as String;
                              final user = _db.users[uid] ?? {};
                              final username =
                                  user['username'] ?? convo['username'] ?? '';
                              final photoUrl =
                                  user['photoUrl'] ?? convo['photoUrl'] ?? '';
                              final lastMsg =
                                  convo['lastMessage'] as String? ?? '';
                              final lastTime = convo['lastTime'] as DateTime?;
                              final unread = convo['unread'] as bool? ?? false;

                              return StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .snapshots(),
                                builder: (context, userSnapshot) {
                                  return _buildConversationCard(
                                    context,
                                    uid: uid,
                                    username: username,
                                    photoUrl: photoUrl,
                                    subtitle: lastMsg.isEmpty
                                        ? 'Tap to message'
                                        : lastMsg,
                                    previewIcon: _previewIcon(
                                      lastMsg.isEmpty ? '' : lastMsg,
                                    ),
                                    trailing: _formatTime(lastTime),
                                    unread: unread,
                                    hasActiveStory:
                                        activeStoryUids.contains(uid),
                                    isOnline:
                                        _isOnline(userSnapshot.data?.data()),
                                    isDark: isDark,
                                  );
                                },
                              );
                            }),
                          ],
                        ),
            );
          },
        );
      },
    );
  }

  Set<String> _activeStoryUids(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final activeUids = <String>{};
    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['storyId'] ??= doc.id;
      data['postId'] ??= doc.id;
      final story = StoryItem.fromMap(data);
      if (story.uid.isEmpty || story.imageUrl.isEmpty) continue;
      if (story.expiresAt.isAfter(now)) {
        activeUids.add(story.uid);
      }
    }
    return activeUids;
  }

  BoxDecoration _storyRingDecoration({
    required bool hasActiveStory,
    required bool isDark,
  }) {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: hasActiveStory
          ? const SweepGradient(
              colors: [
                storyGradientStart,
                storyGradientMid,
                storyGradientEnd,
                storyGradientStart,
              ],
            )
          : null,
      color: hasActiveStory
          ? null
          : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF58529),
                    Color(0xFFDD2A7B),
                    Color(0xFF8134AF),
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDD2A7B).withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open Search, choose a user profile, then tap Message to start a chat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                'Open a profile and tap Message',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRail(
    List<Map<String, dynamic>> conversations,
    Set<String> activeStoryUids,
    bool isDark,
  ) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final convo = conversations[index];
          final uid = convo['uid'] as String;
          final user = _db.users[uid] ?? {};
          final username = user['username'] ?? convo['username'] ?? '';
          final photoUrl = user['photoUrl'] ?? convo['photoUrl'] ?? '';
          final hasActiveStory = activeStoryUids.contains(uid);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              final isOnline = _isOnline(userSnapshot.data?.data());
              return GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MessageChatScreen(
                      username: username,
                      photoUrl: photoUrl,
                      uid: uid,
                    ),
                  ));
                  setState(() {});
                },
                child: SizedBox(
                  width: 66,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: _storyRingDecoration(
                              hasActiveStory: hasActiveStory,
                              isDark: isDark,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                              ),
                              child: LocalImage(url: photoUrl, radius: 25),
                            ),
                          ),
                          if (isOnline) _buildOnlineDot(context, 10),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isOnline(Map<String, dynamic>? userData) {
    if (userData?['isOnline'] != true) return false;
    final lastSeen = userData?['lastSeen'];
    if (lastSeen is! Timestamp) return true;
    return DateTime.now().difference(lastSeen.toDate()).inSeconds < 100;
  }

  Widget _buildOnlineDot(BuildContext context, double size) {
    return Positioned(
      right: 2,
      bottom: 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF31D158),
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildInboxPrompt(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color(0xFF0095F6),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count chat${count == 1 ? '' : 's'} ready to continue',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildConversationCard(
    BuildContext context, {
    required String uid,
    required String username,
    required String photoUrl,
    required String subtitle,
    required IconData previewIcon,
    required String trailing,
    required bool unread,
    required bool hasActiveStory,
    required bool isOnline,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MessageChatScreen(
              username: username,
              photoUrl: photoUrl,
              uid: uid,
            ),
          ));
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: _storyRingDecoration(
                      hasActiveStory: hasActiveStory,
                      isDark: isDark,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: LocalImage(url: photoUrl, radius: 26),
                    ),
                  ),
                  if (unread)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0095F6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (isOnline) _buildOnlineDot(context, 12),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (trailing.isNotEmpty)
                          Text(
                            trailing,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w500,
                              color: unread
                                  ? const Color(0xFF0095F6)
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          previewIcon,
                          size: 14,
                          color: unread
                              ? const Color(0xFF0095F6)
                              : (isDark ? Colors.white30 : Colors.black38),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: unread
                                  ? (isDark ? Colors.white70 : Colors.black87)
                                  : (isDark ? Colors.white38 : Colors.black45),
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

