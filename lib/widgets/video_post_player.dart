import 'dart:async';

import 'package:flutter/material.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:video_player/video_player.dart';

class VideoPostPlayer extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final double height;
  final double width;

  const VideoPostPlayer({
    Key? key,
    String? videoUrl,
    String? assetPath,
    String? thumbnailUrl,
    required this.height,
    required this.width,
  })  : videoUrl = videoUrl ?? assetPath ?? '',
        thumbnailUrl = thumbnailUrl ?? '',
        super(key: key);

  @override
  State<VideoPostPlayer> createState() => _VideoPostPlayerState();
}

class _VideoPostPlayerState extends State<VideoPostPlayer> {
  VideoPlayerController? _controller;
  Timer? _controlsHideTimer;
  DateTime? _lastUiUpdate;

  bool _initialized = false;
  bool _isLoading = false;
  bool _showControls = true;
  bool _isMuted = true;
  bool _intendedPlaying = false;
  bool _isSeeking = false;
  bool _wasPlayingBeforeDrag = false;
  double? _dragPositionMs;
  Duration _uiPosition = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initVideo({required bool autoplay}) async {
    if (_isLoading || _controller != null) return;

    final source = widget.videoUrl.trim();
    if (source.isEmpty) {
      setState(() => _error = 'Missing video source');
      return;
    }

    setState(() {
      _isLoading = true;
      _showControls = true;
    });

    try {
      final controller = await _buildController(
        startAt: Duration.zero,
        autoplay: autoplay,
      );

      if (!mounted || controller == null) return;

      final duration = controller.value.duration;
      setState(() {
        _controller = controller;
        _initialized = true;
        _isLoading = false;
        _intendedPlaying = autoplay;
        _duration = duration;
        _uiPosition = Duration.zero;
      });

      if (autoplay) {
        _autoHideControls();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<VideoPlayerController?> _buildController({
    required Duration startAt,
    required bool autoplay,
  }) async {
    final source = widget.videoUrl;
    final controller = source.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.asset(source);
    controller.addListener(_onControllerUpdate);

    await controller.initialize();

    if (!mounted) {
      controller.removeListener(_onControllerUpdate);
      await controller.dispose();
      return null;
    }

    await controller.setLooping(true);
    await controller.setVolume(_isMuted ? 0 : 1);

    if (startAt > Duration.zero) {
      await controller.seekTo(startAt);
    }

    if (autoplay) {
      await controller.play();
    } else {
      await controller.pause();
    }

    return controller;
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (!mounted || controller == null) return;

    final value = controller.value;
    final duration = value.duration;
    if (duration == Duration.zero) return;
    final position = value.position;
    final nextPosition = position < Duration.zero
        ? Duration.zero
        : (position > duration ? duration : position);

    if (_dragPositionMs != null || _isSeeking) {
      if (_duration != duration) {
        setState(() => _duration = duration);
      }
      return;
    }

    if (_duration != duration || _uiPosition != nextPosition) {
      final now = DateTime.now();
      if (_duration == duration &&
          _lastUiUpdate != null &&
          now.difference(_lastUiUpdate!) < const Duration(milliseconds: 250)) {
        return;
      }
      _lastUiUpdate = now;
      setState(() {
        _duration = duration;
        _uiPosition = nextPosition;
      });
    }
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) {
      await _initVideo(autoplay: true);
      return;
    }

    final shouldPlay = !_intendedPlaying || !controller.value.isPlaying;
    setState(() {
      _intendedPlaying = shouldPlay;
      _showControls = true;
    });

    if (shouldPlay) {
      controller.play();
      _autoHideControls();
    } else {
      controller.pause();
      _controlsHideTimer?.cancel();
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;

    setState(() => _isMuted = !_isMuted);
    controller.setVolume(_isMuted ? 0 : 1);
  }

  Future<void> _seekTo(
    Duration position, {
    required bool resumeAfterSeek,
  }) async {
    final controller = _controller;
    if (controller == null || _duration == Duration.zero || _isSeeking) {
      return;
    }

    final durationMs = _duration.inMilliseconds;
    var targetMs = position.inMilliseconds;
    if (targetMs < 0) targetMs = 0;
    if (targetMs > durationMs) targetMs = durationMs;
    if (targetMs == durationMs && durationMs > 250) {
      targetMs = durationMs - 250;
    }

    final target = Duration(milliseconds: targetMs);

    setState(() {
      _isSeeking = true;
      _uiPosition = target;
    });

    try {
      await controller.seekTo(target);
      if (resumeAfterSeek) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (!mounted) return;
      setState(() {
        _isSeeking = false;
        _intendedPlaying = resumeAfterSeek;
        _uiPosition = target;
        _duration = controller.value.duration;
      });

      if (resumeAfterSeek) {
        _autoHideControls();
      } else {
        _controlsHideTimer?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSeeking = false);
    }
  }

  void _showControlsBriefly() {
    setState(() => _showControls = true);
    _autoHideControls();
  }

  void _autoHideControls() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _intendedPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, color: Colors.grey, size: 48),
              SizedBox(height: 8),
              Text(
                'Could not load video',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: _buildVideoPoster(context)),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'VIDEO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              _ControlButton(
                icon: Icons.play_arrow,
                size: 44,
                onTap: _togglePlay,
              ),
          ],
        ),
      );
    }

    final controller = _controller!;
    final value = controller.value;
    final durationMs = _duration.inMilliseconds;
    final sliderValue =
        (_dragPositionMs ?? _uiPosition.inMilliseconds.toDouble())
            .clamp(0.0, durationMs.toDouble())
            .toDouble();
    final showPauseIcon = _intendedPlaying;

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () {
              final nextShowControls = !_showControls;
              setState(() => _showControls = nextShowControls);
              if (nextShowControls && _intendedPlaying) {
                _autoHideControls();
              } else if (!nextShowControls) {
                _controlsHideTimer?.cancel();
              }
            },
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: value.size.width,
                  height: value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !_showControls && _intendedPlaying,
            child: AnimatedOpacity(
              opacity: _showControls || !_intendedPlaying ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _ControlButton(
                icon: showPauseIcon ? Icons.pause : Icons.play_arrow,
                size: 44,
                onTap: _togglePlay,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'VIDEO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 42,
            right: 12,
            child: AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _toggleMute,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: durationMs <= 0
                ? const SizedBox.shrink()
                : SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                    ),
                    child: Slider(
                      min: 0,
                      max: durationMs.toDouble(),
                      value: sliderValue,
                      onChangeStart: (_) {
                        _wasPlayingBeforeDrag =
                            _intendedPlaying || controller.value.isPlaying;
                        controller.pause();
                        setState(() {
                          _showControls = true;
                          _dragPositionMs =
                              _uiPosition.inMilliseconds.toDouble();
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          _dragPositionMs = value;
                          _uiPosition = Duration(milliseconds: value.round());
                          _showControls = true;
                        });
                      },
                      onChangeEnd: (value) async {
                        setState(() {
                          _dragPositionMs = null;
                          _uiPosition = Duration(milliseconds: value.round());
                        });
                        await _seekTo(
                          Duration(milliseconds: value.round()),
                          resumeAfterSeek: _wasPlayingBeforeDrag,
                        );
                        _showControlsBriefly();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPoster(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.thumbnailUrl.isNotEmpty)
          LocalImage(
            url: widget.thumbnailUrl,
            fit: BoxFit.cover,
            height: widget.height,
            width: widget.width,
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF1C1C1C),
                        Color(0xFF30323A),
                        Color(0xFF101114),
                      ]
                    : const [
                        Color(0xFFEDEFF5),
                        Color(0xFFC8D8E8),
                        Color(0xFFF4F0F6),
                      ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.movie_creation_outlined,
                size: 72,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.34),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

