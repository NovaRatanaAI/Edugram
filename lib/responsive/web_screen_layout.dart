import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:edugram/screens/add_post_screen.dart';
import 'package:edugram/screens/feed_screen.dart';
import 'package:edugram/screens/notifications_screen.dart';
import 'package:edugram/screens/profile_screen.dart';
import 'package:edugram/screens/search_screen.dart';
import 'package:edugram/utils/colors.dart';
import 'package:edugram/widgets/edugram_wordmark.dart';

class WebScreenLayout extends StatefulWidget {
  const WebScreenLayout({Key? key}) : super(key: key);

  @override
  State<WebScreenLayout> createState() => _WebScreenLayoutState();
}

class _WebScreenLayoutState extends State<WebScreenLayout> {
  static const _switchDuration = Duration(milliseconds: 260);
  static const _switchCurve = Curves.easeOutCubic;

  int _page = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  List<Widget> get _screens => [
        const FeedScreen(),
        const SearchScreen(),
        const AddPostScreen(),
        const NotificationsScreen(),
        ProfileScreen(uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
      ];

  void navigationTapped(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    pageController.animateToPage(
      page,
      duration: _switchDuration,
      curve: _switchCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        centerTitle: false,
        title: const EdugramWordmark(
          color: primaryColor,
          height: 32,
        ),
        actions: [
          _navIcon(Icons.home, 0),
          _navIcon(Icons.search, 1),
          _navIcon(Icons.add_a_photo, 2),
          uid.isEmpty
              ? _navIcon(Icons.favorite, 3)
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(uid)
                      .collection('items')
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) => _navIcon(
                    Icons.favorite,
                    3,
                    badgeCount: snapshot.data?.docs.length ?? 0,
                  ),
                ),
          _navIcon(Icons.person, 4),
        ],
      ),
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: pageController,
        onPageChanged: (p) => setState(() => _page = p),
        children: _screens,
      ),
    );
  }

  IconButton _navIcon(IconData icon, int page, {int badgeCount = 0}) =>
      IconButton(
        onPressed: () => navigationTapped(page),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: _page == page ? primaryColor : secondaryColor),
            if (badgeCount > 0)
              Positioned(
                right: -7,
                top: -7,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

