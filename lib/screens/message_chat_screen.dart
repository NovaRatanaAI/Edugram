import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/story_store.dart';
import 'package:edugram/utils/colors.dart';
import 'package:edugram/utils/message_store.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// ignore_for_file: library_private_types_in_public_api
class MessageChatScreen extends StatefulWidget {
  final String username;
  final String photoUrl;
  final String uid;

  const MessageChatScreen({
    Key? key,
    required this.username,
    required this.photoUrl,
    required this.uid,
  }) : super(key: key);

  @override
  _MessageChatScreenState createState() => _MessageChatScreenState();
}

class _MessageChatScreenState extends State<MessageChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  AudioRecorder? _recorder;
  AudioPlayer? _audioPlayer;
  bool _hasText = false;
  bool _isRecording = false;
  bool _isSending = false;
  bool _audioPlayerListenerAttached = false;
  DateTime? _recordingStartedAt;
  int? _playingVoiceIndex;
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  List<Map<String, dynamic>> _latestMessages = const [];
  final List<Map<String, dynamic>> _pendingMessages = [];

  @override
  void initState() {
    super.initState();
    _messagesStream = MessageStore.instance.watchMessages(
      widget.uid,
      otherUsername: widget.username,
      otherPhotoUrl: widget.photoUrl,
    );
    _messageController.addListener(_handleComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _recorder?.dispose().catchError((_) {});
    _audioPlayer?.dispose().catchError((_) {});
    super.dispose();
  }

  AudioRecorder _getRecorder() {
    _recorder ??= AudioRecorder();
    return _recorder!;
  }

  AudioPlayer _getAudioPlayer() {
    final player = _audioPlayer ??= AudioPlayer();
    if (!_audioPlayerListenerAttached) {
      _audioPlayerListenerAttached = true;
      player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() => _playingVoiceIndex = null);
      });
    }
    return player;
  }

  void _handleComposerChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (_hasText == hasText) return;
    setState(() => _hasText = hasText);
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _animateToBottom() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _formatBubbleTime(DateTime time) => DateFormat.jm().format(time);

  String _formatDayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(time.year, time.month, time.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat.MMMd().format(time);
  }

  String _formatVoiceDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<Directory> _chatMediaDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Local chat media folders are not available on web.');
    }
    final documentsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${documentsDir.path}/chat_media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final pendingId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _isSending = true;
      _pendingMessages.add({
        'messageId': pendingId,
        'type': 'text',
        'text': text,
        'time': DateTime.now(),
        'isMe': true,
        'isPending': true,
      });
      _hasText = false;
    });
    _messageController.clear();
    _animateToBottom();
    try {
      await MessageStore.instance.addTextMessage(
        widget.uid,
        text,
        otherUsername: widget.username,
        otherPhotoUrl: widget.photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere(
          (message) => message['messageId'] == pendingId,
        );
      });
    } catch (error) {
      if (!mounted) return;
      _messageController.text = text;
      setState(() {
        _hasText = true;
        _pendingMessages.removeWhere(
          (message) => message['messageId'] == pendingId,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendCameraPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 45,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked == null) return;
    if (kIsWeb) {
      final imageBytes = await picked.readAsBytes();
      final pendingId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
      setState(() {
        _pendingMessages.add({
          'messageId': pendingId,
          'type': 'image',
          'imageBytes': imageBytes,
          'text': 'Sending photo...',
          'time': DateTime.now(),
          'isMe': true,
          'isPending': true,
        });
      });
      _animateToBottom();
      await MessageStore.instance.addImageBytesMessage(
        widget.uid,
        imageBytes,
        otherUsername: widget.username,
        otherPhotoUrl: widget.photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere(
          (message) => message['messageId'] == pendingId,
        );
      });
      _animateToBottom();
      return;
    }
    final mediaDir = await _chatMediaDirectory();
    final imagePath =
        '${mediaDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(imagePath);
    final pendingId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _pendingMessages.add({
        'messageId': pendingId,
        'type': 'image',
        'imagePath': imagePath,
        'text': 'Sending photo...',
        'time': DateTime.now(),
        'isMe': true,
        'isPending': true,
      });
    });
    _animateToBottom();
    await MessageStore.instance.addImageMessage(
      widget.uid,
      imagePath,
      otherUsername: widget.username,
      otherPhotoUrl: widget.photoUrl,
    );
    if (!mounted) return;
    setState(() {
      _pendingMessages.removeWhere(
        (message) => message['messageId'] == pendingId,
      );
    });
    _animateToBottom();
  }

  Future<void> _toggleRecording() async {
    try {
      final recorder = _getRecorder();
      if (_isRecording) {
        final audioPath = await recorder.stop();
        final startedAt = _recordingStartedAt;
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordingStartedAt = null;
        });

        if (audioPath == null || startedAt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No voice message was recorded.')),
          );
          return;
        }

        final duration = DateTime.now()
            .difference(startedAt)
            .inSeconds
            .clamp(1, 600)
            .toInt();
        final pendingId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
        setState(() {
          _pendingMessages.add({
            'messageId': pendingId,
            'type': 'voice',
            'audioPath': audioPath,
            'durationSeconds': duration,
            'text': 'Sending voice message...',
            'time': DateTime.now(),
            'isMe': true,
            'isPending': true,
          });
        });
        _animateToBottom();
        await MessageStore.instance.addVoiceMessage(
          widget.uid,
          audioPath: audioPath,
          durationSeconds: duration,
          otherUsername: widget.username,
          otherPhotoUrl: widget.photoUrl,
        );
        if (!mounted) return;
        setState(() {
          _pendingMessages.removeWhere(
            (message) => message['messageId'] == pendingId,
          );
        });
        _animateToBottom();
        return;
      }

      final hasPermission = await recorder.hasPermission();
      if (!mounted) return;
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is needed for voice notes.'),
          ),
        );
        return;
      }

      final String path;
      if (kIsWeb) {
        path = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } else {
        final dir = await _chatMediaDirectory();
        path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingStartedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingStartedAt = null;
      });
      final message = error.toString().contains('MissingPluginException')
          ? 'Voice recording needs a full app rebuild after adding the record package.'
          : 'Could not start voice recording: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _cancelRecording() async {
    try {
      if (_isRecording) {
        final recorder = _getRecorder();
        await recorder.stop();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingStartedAt = null;
    });
  }

  Future<void> _toggleVoicePlayback(int index) async {
    try {
      final player = _getAudioPlayer();
      final current = _latestMessages[index];
      final audioPath = (current['audioUrl'] as String?) ??
          (current['audioPath'] as String? ?? '');
      if (_playingVoiceIndex == index) {
        await player.stop();
        setState(() => _playingVoiceIndex = null);
        return;
      }

      if (audioPath.isEmpty) return;
      if (kIsWeb && !_isWebPlayableAudioSource(audioPath)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('This voice note is stored locally on another device.'),
          ),
        );
        return;
      }
      await player.stop();
      setState(() => _playingVoiceIndex = index);
      await player.play(_audioSourceFor(audioPath));
    } catch (error) {
      if (!mounted) return;
      setState(() => _playingVoiceIndex = null);
      final message = error.toString().contains('MissingPluginException')
          ? 'Voice playback needs a full app rebuild after adding audioplayers.'
          : 'Could not play voice message: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Source _audioSourceFor(String audioPath) {
    final isUrl = _isWebPlayableAudioSource(audioPath);
    if (kIsWeb || isUrl) return UrlSource(audioPath);
    return DeviceFileSource(audioPath);
  }

  bool _isWebPlayableAudioSource(String audioPath) {
    return audioPath.startsWith('http') ||
        audioPath.startsWith('blob:') ||
        audioPath.startsWith('data:');
  }

  bool _hasActiveStory(
    List<firestore.QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['storyId'] ??= doc.id;
      data['postId'] ??= doc.id;
      final story = StoryItem.fromMap(data);
      if (story.uid != widget.uid || story.imageUrl.isEmpty) continue;
      if (story.expiresAt.isAfter(now)) return true;
    }
    return false;
  }

  bool _isOnline(Map<String, dynamic>? userData) {
    if (userData?['isOnline'] != true) return false;
    final lastSeen = userData?['lastSeen'];
    if (lastSeen is! firestore.Timestamp) return true;
    return DateTime.now().difference(lastSeen.toDate()).inSeconds < 100;
  }

  Widget _buildHeaderAvatar(bool isDark, bool isOnline) {
    return StreamBuilder<firestore.QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.uid)
          .where('isStory', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final hasActiveStory = _hasActiveStory(snapshot.data?.docs ?? const []);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
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
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: LocalImage(url: widget.photoUrl, radius: 18),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF31D158),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not available in this demo yet.')),
    );
  }

  Widget _buildVoiceBubble(
    Map<String, dynamic> msg,
    bool isMe,
    bool isDark,
    int index,
  ) {
    final duration = msg['durationSeconds'] as int? ?? 0;
    final playing = _playingVoiceIndex == index;
    final barHeights = List<double>.generate(
      18,
      (barIndex) => 8 + ((barIndex % 5) * 3).toDouble(),
    );

    return GestureDetector(
      onTap: () => _toggleVoicePlayback(index),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.18)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 18,
              color: isMe
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(barHeights.length, (barIndex) {
                  final activeBars = playing
                      ? ((barIndex + 1) / barHeights.length) <
                              ((DateTime.now().millisecond / 1000) + 0.25)
                          ? true
                          : barIndex < barHeights.length ~/ 2
                      : false;
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 3,
                      height: activeBars
                          ? barHeights[barIndex] + 4
                          : barHeights[barIndex],
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white
                                .withValues(alpha: activeBars ? 0.95 : 0.55)
                            : (isDark
                                ? Colors.white
                                    .withValues(alpha: activeBars ? 0.78 : 0.35)
                                : Colors.black
                                    .withValues(alpha: activeBars ? 0.5 : 0.2)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatVoiceDuration(duration),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.9)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        leadingWidth: 40,
        titleSpacing: 0,
        title: StreamBuilder<firestore.DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            final isOnline = _isOnline(userSnapshot.data?.data());
            return Row(
              children: [
                _buildHeaderAvatar(isDark, isOnline),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        isOnline ? 'Active now' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline
                              ? const Color(0xFF31D158)
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.call_outlined,
                color: isDark ? Colors.white : Colors.black),
            onPressed: () => _showComingSoon('Voice call'),
          ),
          IconButton(
            icon: Icon(Icons.videocam_outlined,
                color: isDark ? Colors.white : Colors.black),
            onPressed: () => _showComingSoon('Video call'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load chat:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }

                final remoteMessages =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                final messages = [...remoteMessages, ..._pendingMessages];
                _latestMessages = messages;

                if (snapshot.connectionState == ConnectionState.waiting &&
                    messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return messages.isEmpty
                    ? SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 56),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFF58529),
                                      Color(0xFFDD2A7B),
                                      Color(0xFF8134AF),
                                    ],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: LocalImage(
                                      url: widget.photoUrl, radius: 42),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                widget.username,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Send a message, photo, or voice note',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 18),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 28,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Take a photo with the camera button or tap the mic to send a local voice note style message.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['isMe'] as bool? ?? false;
                          final type = msg['type'] as String? ?? 'text';
                          final time =
                              msg['time'] as DateTime? ?? DateTime.now();
                          final isPending = msg['isPending'] == true;
                          final previous =
                              index > 0 ? messages[index - 1] : null;
                          final previousTime = previous?['time'] as DateTime?;
                          final showDayLabel = previousTime == null ||
                              previousTime.year != time.year ||
                              previousTime.month != time.month ||
                              previousTime.day != time.day;

                          Widget bubbleChild;
                          if (type == 'image') {
                            final imageBytes = msg['imageBytes'] as Uint8List?;
                            final imagePath = msg['imagePath'] as String? ?? '';
                            final imageUrl = msg['imageUrl'] as String? ?? '';
                            bubbleChild = ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (imageBytes != null)
                                    Image.memory(
                                      imageBytes,
                                      width: 200,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    )
                                  else if (!kIsWeb &&
                                      imagePath.isNotEmpty &&
                                      File(imagePath).existsSync())
                                    Image.file(
                                      File(imagePath),
                                      width: 200,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    )
                                  else if (imageUrl.isNotEmpty)
                                    LocalImage(
                                      url: imageUrl,
                                      width: 200,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(
                                      width: 200,
                                      height: 220,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black
                                              .withValues(alpha: 0.06),
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 8, 10, 2),
                                    child: Text(
                                      isPending
                                          ? 'Sending...'
                                          : _formatBubbleTime(time),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white
                                                .withValues(alpha: 0.78)
                                            : (isDark
                                                ? Colors.white38
                                                : Colors.black38),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (type == 'story_reply') {
                            final storyImageUrl =
                                msg['storyImageUrl'] as String? ?? '';
                            bubbleChild = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: storyImageUrl.isNotEmpty
                                          ? LocalImage(
                                              url: storyImageUrl,
                                              width: 54,
                                              height: 72,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 54,
                                              height: 72,
                                              color: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.08)
                                                  : Colors.black
                                                      .withValues(alpha: 0.06),
                                              child: Icon(
                                                Icons.auto_stories_outlined,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isMe
                                                ? 'You replied to their story'
                                                : 'Replied to your story',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isMe
                                                  ? Colors.white
                                                      .withValues(alpha: 0.78)
                                                  : (isDark
                                                      ? Colors.white54
                                                      : Colors.black54),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            msg['text'] as String? ?? '',
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.35,
                                              color: isMe
                                                  ? Colors.white
                                                  : (isDark
                                                      ? Colors.white
                                                      : Colors.black),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    isPending
                                        ? 'Sending...'
                                        : _formatBubbleTime(time),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.78)
                                          : (isDark
                                              ? Colors.white38
                                              : Colors.black38),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else if (type == 'voice') {
                            bubbleChild = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildVoiceBubble(msg, isMe, isDark, index),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    isPending
                                        ? 'Sending...'
                                        : _formatBubbleTime(time),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.78)
                                          : (isDark
                                              ? Colors.white38
                                              : Colors.black38),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            bubbleChild = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  msg['text'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.35,
                                    color: isMe
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isPending
                                          ? 'Sending...'
                                          : _formatBubbleTime(time),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white
                                                .withValues(alpha: 0.78)
                                            : (isDark
                                                ? Colors.white38
                                                : Colors.black38),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              if (showDayLabel)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black
                                              .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _formatDayLabel(time),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                      ),
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: type == 'image'
                                      ? const EdgeInsets.all(4)
                                      : const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.72,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF0095F6)
                                        : (isDark
                                            ? const Color(0xFF1F232B)
                                            : Colors.black
                                                .withValues(alpha: 0.06)),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft:
                                          Radius.circular(isMe ? 20 : 6),
                                      bottomRight:
                                          Radius.circular(isMe ? 6 : 20),
                                    ),
                                    boxShadow: isMe
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF0095F6)
                                                  .withValues(alpha: 0.18),
                                              blurRadius: 14,
                                              offset: const Offset(0, 8),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: bubbleChild,
                                ),
                              ),
                            ],
                          );
                        },
                      );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                if (_isRecording) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Recording voice note...',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _cancelRecording,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  GestureDetector(
                    onTap: _sendCameraPhoto,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 23,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _hasText
                        ? const Color(0xFF0095F6)
                        : _isRecording
                            ? Colors.red.withValues(alpha: 0.12)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05)),
                    shape: BoxShape.circle,
                    boxShadow: _hasText
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0095F6)
                                  .withValues(alpha: 0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _isSending
                          ? null
                          : (_hasText ? _sendMessage : _toggleRecording),
                      child: Icon(
                        _isSending
                            ? Icons.hourglass_top_rounded
                            : (_hasText
                                ? Icons.send_rounded
                                : (_isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_none_rounded)),
                        color: _hasText
                            ? Colors.white
                            : (_isRecording
                                ? Colors.red
                                : (isDark ? Colors.white70 : Colors.black54)),
                        size: 23,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

