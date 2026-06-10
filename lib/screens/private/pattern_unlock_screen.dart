import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../widgets/pattern_lock.dart';
import '../../utils/app_colors.dart';

class PatternUnlockScreen extends StatefulWidget {
  const PatternUnlockScreen({super.key});

  @override
  State<PatternUnlockScreen> createState() => _PatternUnlockScreenState();
}

class _PatternUnlockScreenState extends State<PatternUnlockScreen> {
  bool _showError = false;
  int _attempts = 0;

  void _onPatternComplete(List<int> pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPatternJson = prefs.getString('pattern');

    if (!mounted) return;

    if (savedPatternJson == null) {
      Navigator.pop(context, false);
      return;
    }

    final savedPattern = List<int>.from(json.decode(savedPatternJson));

    if (_patternsMatch(savedPattern, pattern)) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _showError = true;
        _attempts++;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _showError = false;
      });

      if (_attempts >= 3) {
        _showForgotPatternDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Incorrect pattern. ${3 - _attempts} attempts left.'),
            ),
          );
        }
      }
    }
  }

  bool _patternsMatch(List<int> p1, List<int> p2) {
    if (p1.length != p2.length) return false;
    for (int i = 0; i < p1.length; i++) {
      if (p1[i] != p2[i]) return false;
    }
    return true;
  }

  void _showForgotPatternDialog() {
    showDialog(
      context: context,
      builder: (context) => _ForgotPatternDialog(
        onSuccess: () {
          setState(() => _attempts = 0);
          Navigator.pop(context, true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Private Album',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _showForgotPatternDialog,
            child: const Text('Forgot?'),
          ),
        ],
      ),
      body: PatternLock(
        onPatternComplete: _onPatternComplete,
        title: 'Draw Your Pattern',
        subtitle:
            _showError ? 'Incorrect pattern!' : 'Unlock to view private photos',
        showError: _showError,
      ),
    );
  }
}

class _ForgotPatternDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const _ForgotPatternDialog({required this.onSuccess});

  @override
  State<_ForgotPatternDialog> createState() => _ForgotPatternDialogState();
}

class _ForgotPatternDialogState extends State<_ForgotPatternDialog> {
  final _answerController = TextEditingController();
  String? _securityQuestion;

  @override
  void initState() {
    super.initState();
    _loadSecurityQuestion();
  }

  Future<void> _loadSecurityQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _securityQuestion = prefs.getString('security_question');
    });
  }

  Future<void> _verifyAnswer() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAnswer = prefs.getString('security_answer');

    if (!mounted) return;

    if (savedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No security answer found')),
      );
      return;
    }

    if (_answerController.text.trim().toLowerCase() == savedAnswer) {
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect answer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forgot Pattern?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Answer your security question to unlock:'),
          const SizedBox(height: 16),
          if (_securityQuestion != null)
            Text(
              _securityQuestion!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _answerController,
            decoration: const InputDecoration(
              labelText: 'Your Answer',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _verifyAnswer,
          child: const Text('Verify'),
        ),
      ],
    );
  }
}
