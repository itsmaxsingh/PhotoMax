import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/photos/photos_screen.dart';
import 'screens/albums/albums_screen.dart';
import 'widgets/bottom_pill_navigation.dart';
import 'utils/app_colors.dart';

void main() {
  // Set system UI overlay style (status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

/// Main screen with bottom navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 0 = Photos, 1 = Albums
  int _tapCount = 0; // Track total tab switches (for learning)

  // List of screens corresponding to each tab
  final List<Widget> _screens = const [
    PhotosScreen(),
    AlbumsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex], // Display current screen

      // Bottom Navigation
      bottomNavigationBar: BottomPillNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Switch tab
            _tapCount++; // Increment counter
            print('Tab switched! Total taps: $_tapCount'); // Debug output
          });
        },
      ),
    );
  }
}
