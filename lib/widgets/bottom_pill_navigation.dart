import 'package:flutter/material.dart';

/// Custom bottom navigation bar with floating pill shape matching Redmi Gallery
class BottomPillNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomPillNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Exactly spaced floating pill
      padding: const EdgeInsets.only(bottom: 24, left: 100, right: 100),
      child: Container(
        height: 56, // Match exact height ratio
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFD), // Clean off-white
          borderRadius: BorderRadius.circular(28), // Pill shape
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Photos Tab - No labels, just icons!
            _buildNavItem(
              icon: Icons.image_outlined,
              activeIcon: Icons.image,
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),

            // Albums Tab - No labels, just icons!
            _buildNavItem(
              icon: Icons.auto_awesome_mosaic_outlined,
              activeIcon: Icons.auto_awesome_mosaic,
              isActive: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds individual navigation item (Icon Only)
  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? Colors.black
                  : Colors.black45, // Crisp black/grey contrast
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
