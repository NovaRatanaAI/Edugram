import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:edugram/screens/feed_screen.dart';
import 'package:edugram/screens/notifications_screen.dart';
import 'package:edugram/screens/profile_screen.dart';
import 'package:edugram/screens/search_screen.dart';
import 'package:edugram/utils/colors.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({Key? key}) : super(key: key);

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
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

  void onPageChanged(int page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_page != 0) {
          navigationTapped(0);
        }
      },
      child: Scaffold(
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: pageController,
          onPageChanged: onPageChanged,
          children: _screens,
        ),
        bottomNavigationBar: uid.isEmpty
            ? _buildTabBar(0)
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .doc(uid)
                    .collection('items')
                    .where('read', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) =>
                    _buildTabBar(snapshot.data?.docs.length ?? 0),
              ),
      ),
    );
  }

  CupertinoTabBar _buildTabBar(int unread) {
    return CupertinoTabBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      currentIndex: _page,
      onTap: navigationTapped,
      items: [
        _barItem(Icons.home, 0),
        _barItem(Icons.search, 1),
        _notifBarItem(unread),
        _barItem(Icons.person, 3),
      ],
    );
  }

  BottomNavigationBarItem _barItem(IconData icon, int page) =>
      BottomNavigationBarItem(
        icon: Icon(icon,
            color: _page == page
                ? Theme.of(context).primaryColor
                : secondaryColor),
        backgroundColor: Theme.of(context).primaryColor,
      );

  BottomNavigationBarItem _notifBarItem(int unread) => BottomNavigationBarItem(
        backgroundColor: Theme.of(context).primaryColor,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.favorite,
              color:
                  _page == 2 ? Theme.of(context).primaryColor : secondaryColor,
            ),
            if (unread > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
}

