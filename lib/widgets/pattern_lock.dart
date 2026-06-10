import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Custom pattern lock widget (3x3 grid)
class PatternLock extends StatefulWidget {
  final Function(List<int>) onPatternComplete;
  final String? title;
  final String? subtitle;
  final bool showError;

  const PatternLock({
    super.key,
    required this.onPatternComplete,
    this.title,
    this.subtitle,
    this.showError = false,
  });

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock> {
  final List<int> _pattern = [];
  final Set<int> _selectedDots = {};
  Offset? _currentPosition;

  // 3x3 grid positions (0-8)
  final List<Offset> _dotPositions = [];
  static const int _gridSize = 3;
  static const double _dotRadius = 30.0;

  @override
  void initState() {
    super.initState();
    // Calculate dot positions will be done in build based on available size
  }

  void _calculateDotPositions(Size size) {
    _dotPositions.clear();
    final spacing = size.width / 4;
    final startX = spacing;
    final startY = (size.height - spacing * 2) / 2;

    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        _dotPositions.add(
          Offset(startX + col * spacing, startY + row * spacing),
        );
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _pattern.clear();
      _selectedDots.clear();
      _currentPosition = null;
    });
    _addDotIfNear(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPosition = details.localPosition;
    });
    _addDotIfNear(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _currentPosition = null;
    });

    if (_pattern.length >= 4) {
      widget.onPatternComplete(_pattern);
    } else {
      // Pattern too short
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pattern must connect at least 4 dots'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _pattern.clear();
        _selectedDots.clear();
      });
    }
  }

  void _addDotIfNear(Offset position) {
    for (int i = 0; i < _dotPositions.length; i++) {
      final distance = (position - _dotPositions[i]).distance;
      if (distance < _dotRadius && !_selectedDots.contains(i)) {
        setState(() {
          _pattern.add(i);
          _selectedDots.add(i);
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  widget.title!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.showError
                          ? Colors.red
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_dotPositions.isEmpty) {
                _calculateDotPositions(constraints.biggest);
              }

              return GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  size: constraints.biggest,
                  painter: _PatternPainter(
                    dotPositions: _dotPositions,
                    pattern: _pattern,
                    currentPosition: _currentPosition,
                    selectedDots: _selectedDots,
                    showError: widget.showError,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the pattern lock
class _PatternPainter extends CustomPainter {
  final List<Offset> dotPositions;
  final List<int> pattern;
  final Offset? currentPosition;
  final Set<int> selectedDots;
  final bool showError;

  _PatternPainter({
    required this.dotPositions,
    required this.pattern,
    required this.currentPosition,
    required this.selectedDots,
    required this.showError,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw lines between selected dots
    if (pattern.length > 1) {
      final linePaint = Paint()
        ..color = showError ? Colors.red : AppColors.accentBlue
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < pattern.length - 1; i++) {
        canvas.drawLine(
          dotPositions[pattern[i]],
          dotPositions[pattern[i + 1]],
          linePaint,
        );
      }

      // Draw line to current finger position
      if (currentPosition != null && pattern.isNotEmpty) {
        canvas.drawLine(
          dotPositions[pattern.last],
          currentPosition!,
          linePaint,
        );
      }
    }

    // Draw dots
    for (int i = 0; i < dotPositions.length; i++) {
      final isSelected = selectedDots.contains(i);

      // Outer circle
      final outerPaint = Paint()
        ..color = isSelected
            ? (showError
                ? Colors.red.withValues(alpha: 0.3)
                : AppColors.accentBlue.withValues(alpha: 0.3))
            : Colors.grey.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(dotPositions[i], 30, outerPaint);

      // Inner circle
      final innerPaint = Paint()
        ..color = isSelected
            ? (showError ? Colors.red : AppColors.accentBlue)
            : Colors.grey
        ..style = PaintingStyle.fill;

      canvas.drawCircle(dotPositions[i], isSelected ? 12 : 8, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
