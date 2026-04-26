import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edugram/resources/firebase_utils.dart';
import 'package:edugram/resources/local_image.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/screens/profile_screen.dart';
import 'package:edugram/utils/global_variables.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// ignore_for_file: library_private_types_in_public_api
class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSearching = false;
  String _lastUserPrecacheSignature = '';
  String _lastGridPrecacheSignature = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.unfocus();
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchController.text.trim();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: (v) =>
                            setState(() => _isSearching = v.isNotEmpty),
                        onTap: () => setState(() {}),
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 20,
                          ),
                          suffixIcon: _isSearching
                              ? GestureDetector(
                                  onTap: _clearSearch,
                                  child: Icon(
                                    Icons.cancel,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    size: 18,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  // Cancel button when focused
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _focusNode.hasFocus
                        ? GestureDetector(
                            onTap: _clearSearch,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(query, isDark)
                  : _buildExploreGrid(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search results list ──────────────────────────────────────────────────
  Widget _buildSearchResults(String query, bool isDark) {
    if (query.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').orderBy('username').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(
            isDark,
            'Could not search users.',
            onRetry: () => setState(() {}),
          );
        }
        final results = _matchingUsers(
          query,
          snapshot.data?.docs.map((doc) => doc.data()).toList() ??
              <Map<String, dynamic>>[],
        );
        final userPrecacheSignature = results
            .take(12)
            .map((user) => user['uid'] as String? ?? '')
            .join('|');
        if (userPrecacheSignature != _lastUserPrecacheSignature) {
          _lastUserPrecacheSignature = userPrecacheSignature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            LocalImage.precacheUrls(
              context,
              results.map((user) => user['photoUrl'] as String?),
              width: 48,
              height: 48,
              limit: 12,
            );
          });
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 52, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try a different name',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: results.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 72,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          itemBuilder: (context, i) {
            final u = results[i];
            final uid = (u['uid'] ?? '').toString();
            final followers = (u['followers'] as List?)?.length ?? 0;
            return InkWell(
              onTap: () {
                if (uid.isEmpty) return;
                _focusNode.unfocus();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(uid: uid),
                ));
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    LocalImage(url: u['photoUrl'] ?? '', radius: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['username'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u['bio'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$followers followers',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: isDark ? Colors.white24 : Colors.black26),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Explore grid ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _matchingUsers(
    String query,
    List<Map<String, dynamic>> firestoreUsers,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final mergedByUid = <String, Map<String, dynamic>>{};
    for (final user in [
      ...firestoreUsers,
      ...LocalStore.instance.searchUsers(q),
    ]) {
      final username = (user['username'] as String? ?? '').toLowerCase();
      if (!username.contains(q)) continue;

      final uid = user['uid'] as String? ?? username;
      if (uid.isEmpty) continue;
      mergedByUid[uid] = user;
    }

    final results = mergedByUid.values.toList();
    results.sort((a, b) {
      final aName = (a['username'] as String? ?? '').toLowerCase();
      final bName = (b['username'] as String? ?? '').toLowerCase();
      final aStarts = aName.startsWith(q);
      final bStarts = bName.startsWith(q);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return aName.compareTo(bName);
    });
    return results;
  }

  Widget _buildExploreGrid(bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('posts')
          .orderBy('datePublished', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(
            isDark,
            'Could not load explore.',
            onRetry: () => setState(() {}),
          );
        }
        final posts = snapshot.data?.docs
                .map((doc) => dataWithDate(doc.data()))
                .where(_isExplorePost)
                .toList() ??
            <Map<String, dynamic>>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (posts.isEmpty) {
          return Center(
            child: Text('No posts yet.',
                style:
                    TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
          );
        }

        final crossCount =
            MediaQuery.of(context).size.width > webScreenSize ? 4 : 3;
        final tileWidth = MediaQuery.of(context).size.width / crossCount;
        final gridPrecacheSignature = posts
            .take(36)
            .map((post) => post['postId'] as String? ?? '')
            .join('|');
        if (gridPrecacheSignature != _lastGridPrecacheSignature) {
          _lastGridPrecacheSignature = gridPrecacheSignature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            LocalImage.precacheUrls(
              context,
              posts.take(36).map((post) => post['postUrl'] as String?),
              width: tileWidth,
              height: tileWidth,
              limit: 36,
            );
          });
        }

        return MasonryGridView.count(
          crossAxisCount: crossCount,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          cacheExtent: 1800,
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final uid = (post['uid'] ?? '').toString();
            final isTall = index % 5 == 0;
            return RepaintBoundary(
              child: GestureDetector(
                onTap: uid.isEmpty
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: uid),
                        )),
                child: AspectRatio(
                  aspectRatio: isTall ? 0.65 : 1.0,
                  child: LocalImage(
                    url: post['postUrl'] ?? '',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isExplorePost(Map<String, dynamic> post) {
    final postUrl = (post['postUrl'] as String? ?? '').trim();
    return postUrl.isNotEmpty &&
        post['uid'] != null &&
        post['isVideo'] != true &&
        post['isStory'] != true;
  }

  Widget _buildErrorState(
    bool isDark,
    String message, {
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

