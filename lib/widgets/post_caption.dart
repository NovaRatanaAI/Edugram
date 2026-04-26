import 'package:flutter/material.dart';
import 'package:edugram/utils/colors.dart';

class PostCaption extends StatelessWidget {
  final String username;
  final String description;
  final bool isExpanded;
  final VoidCallback onExpand;

  const PostCaption({
    Key? key,
    required this.username,
    required this.description,
    required this.isExpanded,
    required this.onExpand,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (description.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: double.infinity,
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    color: Theme.of(context).primaryColor,
                    height: 1.35,
                  ),
              children: [
                TextSpan(
                  text: '$username ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: isExpanded || description.length <= 88
                      ? description
                      : '${description.substring(0, 88).trimRight()}...',
                ),
                if (!isExpanded && description.length > 88)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: onExpand,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'more',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: secondaryColor,
                          ),
                        ),
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

