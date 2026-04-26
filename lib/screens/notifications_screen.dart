import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:edugram/resources/firestore_methods.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/screens/profile_screen.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ignore_for_file: library_private_types_in_public_api
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Mark all read after the first frame so the badge in the nav bar clears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markAllRead();
    });
  }

  Future<void> _markAllRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final unread = await _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
    if (!mounted) return;
    await Provider.of<UserProvider>(context, listen: false).refreshUser();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'follow':
        return Icons.person_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'like':
        return const Color(0xFFFF3B5C);
      case 'follow':
        return const Color(0xFF0095F6);
      case 'comment':
        return const Color(0xFFFF9500);
      default:
        return Colors.grey;
    }
  }

  String _messageFor(Map<String, dynamic> n) {
    switch (n['type']) {
      case 'like':
        return 'liked your photo.';
      case 'follow':
        return 'started following you.';
      case 'comment':
        final txt = n['text'] as String? ?? '';
        final preview = txt.length > 35 ? '${txt.substring(0, 35)}…' : txt;
        return 'commented: "$preview"';
      default:
        return '';
    }
  }

  // Group notifications by time
  Map<String, List<Map<String, dynamic>>> _groupNotifs(
      List<Map<String, dynamic>> notifs) {
    final Map<String, List<Map<String, dynamic>>> groups = {
      'New': [],
      'This week': [],
      'Earlier': [],
    };
    final seenFollowsByGroup = <String>{};
    final now = DateTime.now();
    for (final n in notifs) {
      final dt = n['createdAt'] as DateTime;
      final diff = now.difference(dt);
      late final String group;
      if (diff.inHours < 24) {
        group = 'New';
      } else if (diff.inDays < 7) {
        group = 'This week';
      } else {
        group = 'Earlier';
      }

      if (n['type'] == 'follow') {
        final fromUid = n['fromUid'] as String? ?? '';
        final dedupeKey = '$group:$fromUid';
        if (fromUid.isNotEmpty && !seenFollowsByGroup.add(dedupeKey)) {
          continue;
        }
      }

      groups[group]!.add(n);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentFollowing =
        Provider.of<UserProvider>(context).user?.following ?? const <String>[];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Activity',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: uid.isEmpty
          ? _buildEmpty(isDark)
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('notifications')
                  .doc(uid)
                  .collection('items')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load activity:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifs = snapshot.data?.docs.map((doc) {
                      final data = Map<String, dynamic>.from(doc.data());
                      final createdAt = data['createdAt'];
                      data['createdAt'] = createdAt is Timestamp
                          ? createdAt.toDate()
                          : DateTime.now();
                      return data;
                    }).toList() ??
                    <Map<String, dynamic>>[];
                final groups = _groupNotifs(notifs);

                return notifs.isEmpty
                    ? _buildEmpty(isDark)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          for (final entry in groups.entries)
                            if (entry.value.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 10,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Divider(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.08)
                                            : Colors.black
                                                .withValues(alpha: 0.08),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...entry.value.map(
                                (n) => _NotifTile(
                                  notif: n,
                                  isDark: isDark,
                                  timeAgo: _timeAgo(n['createdAt'] as DateTime),
                                  icon: _iconFor(n['type'] as String),
                                  iconColor: _colorFor(n['type'] as String),
                                  message: _messageFor(n),
                                  isInitiallyFollowing: currentFollowing
                                      .contains(n['fromUid'] as String? ?? ''),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProfileScreen(
                                        uid: n['fromUid'] as String,
                                      ),
                                    ),
                                  ),
                                  onFollow: n['type'] == 'follow'
                                      ? () {
                                          FirestoreMethods().followUser(
                                            uid,
                                            n['fromUid'] as String,
                                          );
                                        }
                                      : null,
                                ),
                              ),
                            ],
                        ],
                      );
              },
            ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF3B5C).withValues(alpha: 0.15),
                  const Color(0xFF0095F6).withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 40,
              color: Color(0xFFFF3B5C),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Activity Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone likes, comments,\nor follows you, it\'ll appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatefulWidget {
  final Map<String, dynamic> notif;
  final bool isDark;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;
  final String message;
  final bool isInitiallyFollowing;
  final VoidCallback onTap;
  final VoidCallback? onFollow;

  const _NotifTile({
    required this.notif,
    required this.isDark,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.isInitiallyFollowing,
    required this.onTap,
    this.onFollow,
  });

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  late bool _isFollowing;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isInitiallyFollowing;
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = widget.notif['read'] == false;
    final postUrl = widget.notif['postUrl'] as String?;
    final type = widget.notif['type'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: widget.iconColor.withValues(alpha: 0.08),
          highlightColor: widget.iconColor.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnread
                  ? widget.iconColor
                      .withValues(alpha: widget.isDark ? 0.11 : 0.07)
                  : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.025)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUnread
                    ? widget.iconColor.withValues(alpha: 0.18)
                    : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.iconColor.withValues(alpha: 0.26),
                          width: 1.5,
                        ),
                      ),
                      child: LocalImage(
                        url: widget.notif['fromPhoto'] as String? ?? '',
                        radius: 25,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          color: widget.iconColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  widget.notif['fromUsername'] as String? ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: widget.message,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isUnread) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: widget.iconColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            widget.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w500,
                              color: widget.isDark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (type == 'follow')
                  GestureDetector(
                    onTap: _isFollowLoading
                        ? null
                        : () async {
                            setState(() => _isFollowLoading = true);
                            widget.onFollow?.call();
                            await Future<void>.delayed(
                              const Duration(milliseconds: 250),
                            );
                            if (!mounted) return;
                            setState(() {
                              _isFollowing = !_isFollowing;
                              _isFollowLoading = false;
                            });
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isFollowing
                            ? Colors.transparent
                            : const Color(0xFF0095F6),
                        borderRadius: BorderRadius.circular(999),
                        border: _isFollowing
                            ? Border.all(
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : Colors.black.withValues(alpha: 0.16),
                              )
                            : null,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: _isFollowLoading
                            ? SizedBox(
                                key: const ValueKey('loading'),
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _isFollowing
                                      ? (widget.isDark
                                          ? Colors.white
                                          : Colors.black)
                                      : Colors.white,
                                ),
                              )
                            : Text(
                                _isFollowing ? 'Following' : 'Follow back',
                                key: ValueKey(_isFollowing),
                                style: TextStyle(
                                  color: _isFollowing
                                      ? (widget.isDark
                                          ? Colors.white
                                          : Colors.black)
                                      : Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                  )
                else if (postUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: LocalImage(
                        url: postUrl,
                        fit: BoxFit.cover,
                        width: 54,
                        height: 54,
                      ),
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

