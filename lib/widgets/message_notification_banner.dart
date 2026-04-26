import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/screens/message_chat_screen.dart';
import 'package:edugram/utils/app_navigator.dart';
import 'package:edugram/utils/message_store.dart';

class MessageNotificationBanner extends StatefulWidget {
  final Widget child;

  const MessageNotificationBanner({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<MessageNotificationBanner> createState() =>
      _MessageNotificationBannerState();
}

class _MessageNotificationBannerState extends State<MessageNotificationBanner> {
  static const _notificationSound =
      'sounds/mixkit-correct-answer-tone-2870.wav';

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, DateTime> _lastSeenByUid = {};
  Map<String, dynamic>? _activeConversation;
  Timer? _hideTimer;
  bool _primed = false;

  @override
  void initState() {
    super.initState();
    _subscription =
        MessageStore.instance.watchConversations().listen(_handleConversations);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _audioPlayer.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _handleConversations(List<Map<String, dynamic>> conversations) {
    final myUid = MessageStore.instance.currentUid;
    if (myUid == null || myUid.isEmpty) return;

    if (!_primed) {
      for (final conversation in conversations) {
        final uid = conversation['uid'] as String? ?? '';
        final lastTime = conversation['lastTime'] as DateTime?;
        if (uid.isNotEmpty && lastTime != null) {
          _lastSeenByUid[uid] = lastTime;
        }
      }
      _primed = true;
      return;
    }

    for (final conversation in conversations) {
      final uid = conversation['uid'] as String? ?? '';
      final lastTime = conversation['lastTime'] as DateTime?;
      final lastSenderUid = conversation['lastSenderUid'] as String? ?? '';
      if (uid.isEmpty || lastTime == null) continue;

      final previous = _lastSeenByUid[uid];
      _lastSeenByUid[uid] = lastTime;

      final isNewer = previous == null || lastTime.isAfter(previous);
      final isIncoming = lastSenderUid.isNotEmpty && lastSenderUid != myUid;
      if (isNewer && isIncoming) {
        _showBanner(conversation);
        break;
      }
    }
  }

  void _showBanner(Map<String, dynamic> conversation) {
    _hideTimer?.cancel();
    _playIncomingAlert();
    setState(() => _activeConversation = conversation);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _activeConversation = null);
    });
  }

  Future<void> _playIncomingAlert() async {
    try {
      await HapticFeedback.mediumImpact();
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(_notificationSound));
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  void _openChat() {
    final conversation = _activeConversation;
    if (conversation == null) return;
    final uid = conversation['uid'] as String? ?? '';
    if (uid.isEmpty) return;

    _hideTimer?.cancel();
    setState(() => _activeConversation = null);

    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          uid: uid,
          username: conversation['username'] as String? ?? 'User',
          photoUrl: conversation['photoUrl'] as String? ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _activeConversation;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          top: topPadding + 8,
          child: IgnorePointer(
            ignoring: conversation == null,
            child: SafeArea(
              bottom: false,
              child: AnimatedSlide(
                offset:
                    conversation == null ? const Offset(0, -1.35) : Offset.zero,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: conversation == null ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: conversation == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openChat,
                          child: _BannerCard(
                            conversation: conversation,
                            isDark: isDark,
                            onTap: _openChat,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final bool isDark;
  final VoidCallback onTap;

  const _BannerCard({
    required this.conversation,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final username = conversation['username'] as String? ?? 'User';
    final photoUrl = conversation['photoUrl'] as String? ?? '';
    final message = conversation['lastMessage'] as String? ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C3038) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              LocalImage(url: photoUrl, radius: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.isEmpty ? 'New message' : message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF0095F6),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

