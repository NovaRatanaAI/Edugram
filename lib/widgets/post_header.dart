import 'package:flutter/material.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/utils/colors.dart';

class PostHeader extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isOwnPost;
  final bool isFollowingUser;
  final bool hasActiveStory;
  final bool isFollowLoading;
  final bool isDeleting;
  final bool isNewlyRefreshed;
  final String followLabel;
  final String timeLabel;
  final VoidCallback onAvatarTap;
  final VoidCallback onProfileTap;
  final VoidCallback onFollowTap;
  final VoidCallback onOptionsTap;

  const PostHeader({
    Key? key,
    required this.post,
    required this.isOwnPost,
    required this.isFollowingUser,
    required this.hasActiveStory,
    required this.isFollowLoading,
    required this.isDeleting,
    required this.isNewlyRefreshed,
    required this.followLabel,
    required this.timeLabel,
    required this.onAvatarTap,
    required this.onProfileTap,
    required this.onFollowTap,
    required this.onOptionsTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasActiveStory
                          ? const LinearGradient(
                              colors: [
                                Color(0xFFF58529),
                                Color(0xFFDD2A7B),
                                Color(0xFF8134AF),
                              ],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            )
                          : null,
                      color: hasActiveStory
                          ? null
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: LocalImage(
                        url: post['profImage'] ?? '',
                        radius: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onProfileTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['username'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: secondaryColor,
                            ),
                          ),
                          if (isNewlyRefreshed) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: blueColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: blueColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isOwnPost)
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 92,
                maxWidth: followLabel == 'Follow back'
                    ? 126
                    : (isFollowingUser ? 110 : 96),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: isFollowingUser ? 1 : 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        isFollowLoading
                            ? const Color(0xFF4A4F58)
                            : const Color(0xFF2D3139),
                        const Color(0xFF1F232B),
                        value,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: value > 0
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            )
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isFollowLoading ? null : onFollowTap,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: isFollowLoading
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    followLabel,
                                    key: ValueKey(followLabel),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (isOwnPost)
            IconButton(
              onPressed: isDeleting ? null : onOptionsTap,
              icon: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.more_vert),
            ),
        ],
      ),
    );
  }
}

