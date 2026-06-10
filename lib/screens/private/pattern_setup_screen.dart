import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../widgets/pattern_lock.dart';
import '../../utils/app_colors.dart';

class PatternSetupScreen extends StatefulWidget {
  final bool isChangingPattern;

  const PatternSetupScreen({
    super.key,
    this.isChangingPattern = false,
  });

  @override
  State<PatternSetupScreen> createState() => _PatternSetupScreenState();
}

class _PatternSetupScreenState extends State<PatternSetupScreen> {
  int _step = 1;
  List<int>? _firstPattern;
  bool _showError = false;
  String? _selectedQuestion;
  final _answerController = TextEditingController();

  final List<String> _securityQuestions = [
    'What is your favorite color?',
    'What is your mother\'s maiden name?',
    'What was the name of your first pet?',
    'What city were you born in?',
    'What is your favorite food?',
  ];

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _onPatternComplete(List<int> pattern) async {
    if (_step == 1) {
      setState(() {
        _firstPattern = pattern;
        _step = 2;
        _showError = false;
      });
    } else if (_step == 2) {
      if (_patternsMatch(_firstPattern!, pattern)) {
        setState(() {
          _step = 3;
          _showError = false;
        });
      } else {
        setState(() {
          _showError = true;
        });

        await Future.delayed(const Duration(milliseconds: 500));

        setState(() {
          _showError = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patterns do not match. Try again.')),
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

  Future<void> _savePattern() async {
    if (_selectedQuestion == null || _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a question and provide an answer')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('pattern', json.encode(_firstPattern));
    await prefs.setString('security_question', _selectedQuestion!);
    await prefs.setString(
        'security_answer', _answerController.text.trim().toLowerCase());

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.isChangingPattern ? 'Change Pattern' : 'Set Up Pattern',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_step == 1) {
      return PatternLock(
        onPatternComplete: _onPatternComplete,
        title: 'Draw Your Pattern',
        subtitle: 'Connect at least 4 dots',
      );
    } else if (_step == 2) {
      return PatternLock(
        onPatternComplete: _onPatternComplete,
        title: 'Confirm Your Pattern',
        subtitle: _showError
            ? 'Pattern does not match!'
            : 'Draw the same pattern again',
        showError: _showError,
      );
    } else {
      return _buildSecurityQuestionForm();
    }
  }

  Widget _buildSecurityQuestionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Security Question',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This will help you recover your pattern if you forget it',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          DropdownButtonFormField<String>(
            initialValue: _selectedQuestion, // <-- To this!
            decoration: const InputDecoration(
              labelText: 'Security Question',
              border: OutlineInputBorder(),
            ),
            items: _securityQuestions.map((q) {
              return DropdownMenuItem(value: q, child: Text(q));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedQuestion = value);
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _answerController,
            decoration: const InputDecoration(
              labelText: 'Your Answer',
              border: OutlineInputBorder(),
              hintText: 'Enter your answer',
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savePattern,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Finish Setup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
