import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import '../private/pattern_setup_screen.dart';

/// Settings screen - Change pattern, app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasPattern = false;

  @override
  void initState() {
    super.initState();
    _checkPattern();
  }

  Future<void> _checkPattern() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasPattern = prefs.containsKey('pattern');
    });
  }

  Future<void> _changePattern() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PatternSetupScreen(isChangingPattern: true),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pattern changed successfully!')),
      );
      _checkPattern();
    }
  }

  Future<void> _removePattern() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Pattern?'),
        content: const Text(
          'This will remove pattern lock from Private Album. Anyone with access to your phone will be able to view private photos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pattern');
      await prefs.remove('security_question');
      await prefs.remove('security_answer');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pattern removed')),
        );
        _checkPattern();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Security Section
          _buildSectionHeader('Security'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (_hasPattern) ...[
                  ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: const Text('Change Pattern'),
                    subtitle: const Text('Update your private album pattern'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePattern,
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: const Icon(Icons.lock_open, color: Colors.red),
                    title: const Text(
                      'Remove Pattern',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text('Disable pattern lock'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _removePattern,
                  ),
                ] else
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Set Up Pattern'),
                    subtitle: const Text('Protect your private photos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePattern,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Version'),
                  trailing: Text('1.0.0'),
                ),
                const Divider(height: 1, indent: 60),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Built with Flutter'),
                  subtitle: const Text('Custom gallery app'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'PhotoMax',
                      applicationVersion: '1.0.0',
                      applicationIcon:
                          const Icon(Icons.photo_library, size: 48),
                      children: [
                        const Text(
                            'A custom gallery application built with Flutter.'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
