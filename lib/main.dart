import 'package:flutter/material.dart';
import 'screens/photos/photos_screen.dart';
import 'screens/albums/albums_screen.dart';
import 'widgets/bottom_pill_navigation.dart';

void main() {
  runApp(const PhotoMaxApp());
}

class PhotoMaxApp extends StatelessWidget {
  const PhotoMaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoMax',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const MainLayoutScreen(),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  bool _isSelectionMode = false;

  // Force the controller to explicitly start at 0
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    // ✅ FIX 3: Absolutely forces the app to jump to the Photos page immediately on boot
    _currentIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              PhotosScreen(
                onSelectionModeChanged: (isSelecting) {
                  setState(() {
                    _isSelectionMode = isSelecting;
                  });
                },
              ),
              const AlbumsScreen(),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutBack,
            bottom: _isSelectionMode ? -100 : 0,
            left: 0,
            right: 0,
            child: BottomPillNavigation(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}
