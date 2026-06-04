import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Custom bottom navigation bar with pill/capsule shape
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
      padding: const EdgeInsets.only(bottom: 24, left: 80, right: 80),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.navBackground,
          borderRadius: BorderRadius.circular(30), // Makes it pill-shaped
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Photos Tab
            _buildNavItem(
              icon: Icons.photo_library_outlined,
              activeIcon: Icons.photo_library,
              label: 'Photos',
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),

            // Vertical divider
            Container(
              width: 1,
              height: 30,
              color: Colors.grey.withOpacity(0.3),
            ),

            // Albums Tab
            _buildNavItem(
              icon: Icons.auto_awesome_outlined,
              activeIcon: Icons.auto_awesome,
              label: 'Albums',
              isActive: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds individual navigation item
  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.navActive : AppColors.navInactive,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.navActive : AppColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
