import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../private/pattern_setup_screen.dart';
import '../albums/hidden_albums_screen.dart';

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
    if (mounted) {
      setState(() {
        _hasPattern = prefs.containsKey('pattern');
      });
    }
  }

  Future<void> _changePattern() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PatternSetupScreen(isChangingPattern: true),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
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

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pattern removed')),
      );
      _checkPattern();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gallery',
          style: TextStyle(
              color: Colors.black, fontSize: 24, fontWeight: FontWeight.w400),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Browse'),
          _buildListTile(
            title: 'View hidden albums',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HiddenAlbumsScreen()),
              ).then((_) => _checkPattern());
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Security'),
          if (_hasPattern) ...[
            _buildListTile(
              title: 'Change private pattern',
              onTap: _changePattern,
            ),
            _buildListTile(
              title: 'Remove pattern',
              onTap: _removePattern,
            ),
          ] else
            _buildListTile(
              title: 'Set up private pattern',
              onTap: _changePattern,
            ),
          const SizedBox(height: 24),
          _buildSectionHeader('Additional settings'),
          _buildListTile(
            title: 'About PhotoMax',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'PhotoMax',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.photo_library, size: 48),
                children: [const Text('Custom Android gallery application.')],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7986CB),
        ),
      ),
    );
  }

  Widget _buildListTile({required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black)),
            const Icon(Icons.chevron_right, color: Colors.black45, size: 22),
          ],
        ),
      ),
    );
  }
}
