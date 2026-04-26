import 'package:flutter/material.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/widgets/like_animation.dart';
import 'package:edugram/widgets/video_post_player.dart';

class PostMedia extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isVideo;
  final bool isLikeAnimating;
  final double width;
  final double aspectRatio;
  final int mediaPage;
  final List<String> mediaUrls;
  final VoidCallback onDoubleTap;
  final VoidCallback onLikeAnimationEnd;
  final ValueChanged<int> onPageChanged;

  const PostMedia({
    Key? key,
    required this.post,
    required this.isVideo,
    required this.isLikeAnimating,
    required this.width,
    required this.aspectRatio,
    required this.mediaPage,
    required this.mediaUrls,
    required this.onDoubleTap,
    required this.onLikeAnimationEnd,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : width;
        final mediaHeight = mediaWidth / aspectRatio;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (isVideo)
              VideoPostPlayer(
                videoUrl: post['postUrl'] ?? '',
                thumbnailUrl: post['thumbnailUrl'] ?? post['profImage'] ?? '',
                height: mediaHeight,
                width: double.infinity,
              )
            else
              GestureDetector(
                onDoubleTap: onDoubleTap,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: mediaUrls.length,
                          onPageChanged: onPageChanged,
                          itemBuilder: (context, page) {
                            return ClipRect(
                              child: LocalImage(
                                url: mediaUrls[page],
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            );
                          },
                        ),
                        if (mediaUrls.length > 1) ...[
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.48),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                '${mediaPage + 1}/${mediaUrls.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                mediaUrls.length,
                                (dotIndex) => Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dotIndex == mediaPage
                                        ? const Color(0xFF4C7DFF)
                                        : Colors.white.withValues(alpha: 0.36),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isLikeAnimating ? 1 : 0,
                child: LikeAnimation(
                  isAnimating: isLikeAnimating,
                  duration: const Duration(milliseconds: 400),
                  onEnd: onLikeAnimationEnd,
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 100,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

