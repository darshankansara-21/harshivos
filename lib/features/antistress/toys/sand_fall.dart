import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A falling-sand fidget toy.
///
/// A coarse pixel grid where tapping or dragging pours colored sand grains
/// from the touch point. Grains fall under gravity and slide diagonally to
/// pile up naturally (a simple sand cellular automaton stepped each tick).
/// The pour color drifts through pastel hues over time. A floating button
/// clears the canvas. No fail states — just a calm, endless sandbox.
class SandFallToy extends StatefulWidget {
  const SandFallToy({super.key});

  @override
  State<SandFallToy> createState() => _SandFallToyState();
}

class _SandFallToyState extends State<SandFallToy>
    with SingleTickerProviderStateMixin {
  static const double _cellSize = 9.0;
  static const int _brushRadius = 2;

  late final AnimationController _controller;

  int _cols = 0;
  int _rows = 0;

  /// Grid of grain hues. -1 means empty cell.
  List<double> _grid = <double>[];

  Size _canvasSize = Size.zero;
  double _hue = 8.0;
  Offset? _pourPoint;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_onTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _ensureGrid(Size size) {
    final int cols = math.max(1, (size.width / _cellSize).floor());
    final int rows = math.max(1, (size.height / _cellSize).floor());
    if (cols == _cols && rows == _rows && _grid.isNotEmpty) {
      _canvasSize = size;
      return;
    }
    _cols = cols;
    _rows = rows;
    _grid = List<double>.filled(cols * rows, -1.0);
    _canvasSize = size;
  }

  int _index(int x, int y) => y * _cols + x;

  void _onTick() {
    if (_grid.isEmpty) return;
    _hue = (_hue + 0.6) % 360.0;

    // Inject sand at the active pour point.
    if (_pourPoint != null) {
      _pourAt(_pourPoint!);
    }

    _stepSand();
    if (mounted) setState(() {});
  }

  void _pourAt(Offset point) {
    final int cx = (point.dx / _cellSize).floor();
    final int cy = (point.dy / _cellSize).floor();
    for (int dy = -_brushRadius; dy <= _brushRadius; dy++) {
      for (int dx = -_brushRadius; dx <= _brushRadius; dx++) {
        final int x = cx + dx;
        final int y = cy + dy;
        if (x < 0 || x >= _cols || y < 0 || y >= _rows) continue;
        if (dx * dx + dy * dy > _brushRadius * _brushRadius) continue;
        if (_grid[_index(x, y)] < 0 && _random.nextDouble() < 0.55) {
          final double jitter = _random.nextDouble() * 14.0 - 7.0;
          _grid[_index(x, y)] = (_hue + jitter) % 360.0;
        }
      }
    }
  }

  void _stepSand() {
    // Step from the bottom up so grains move at most one cell per tick.
    for (int y = _rows - 2; y >= 0; y--) {
      // Alternate horizontal scan direction to avoid drift bias.
      final bool leftFirst = (y + _controller.value * 1000).toInt().isEven;
      for (int i = 0; i < _cols; i++) {
        final int x = leftFirst ? i : (_cols - 1 - i);
        final int here = _index(x, y);
        final double grain = _grid[here];
        if (grain < 0) continue;

        final int below = _index(x, y + 1);
        if (_grid[below] < 0) {
          _grid[below] = grain;
          _grid[here] = -1.0;
          continue;
        }

        // Try to slide diagonally to settle into a pile.
        final bool tryLeftFirst = _random.nextBool();
        final List<int> order =
            tryLeftFirst ? <int>[-1, 1] : <int>[1, -1];
        bool moved = false;
        for (final int dir in order) {
          final int nx = x + dir;
          if (nx < 0 || nx >= _cols) continue;
          final int diag = _index(nx, y + 1);
          if (_grid[diag] < 0) {
            _grid[diag] = grain;
            _grid[here] = -1.0;
            moved = true;
            break;
          }
        }
        if (moved) continue;
      }
    }
  }

  void _handlePour(Offset localPosition) {
    _pourPoint = localPosition;
    HapticFeedback.selectionClick();
  }

  void _clear() {
    setState(() {
      _grid = List<double>.filled(_cols * _rows, -1.0);
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureGrid(size);
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (DragStartDetails d) =>
                    _handlePour(d.localPosition),
                onPanUpdate: (DragUpdateDetails d) =>
                    _pourPoint = d.localPosition,
                onPanEnd: (DragEndDetails d) => _pourPoint = null,
                onPanCancel: () => _pourPoint = null,
                onTapDown: (TapDownDetails d) => _handlePour(d.localPosition),
                onTapUp: (TapUpDetails d) => _pourPoint = null,
                child: CustomPaint(
                  painter: _SandPainter(
                    grid: _grid,
                    cols: _cols,
                    rows: _rows,
                    cellSize: _cellSize,
                  ),
                  size: _canvasSize,
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: _ClearButton(onTap: _clear),
            ),
          ],
        );
      },
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              Icon(Icons.cleaning_services_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Clear',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SandPainter extends CustomPainter {
  _SandPainter({
    required this.grid,
    required this.cols,
    required this.rows,
    required this.cellSize,
  });

  final List<double> grid;
  final int cols;
  final int rows;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Calm deep background gradient.
    final Rect bounds = Offset.zero & size;
    final Paint bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF101428), Color(0xFF1B2140)],
      ).createShader(bounds);
    canvas.drawRect(bounds, bg);

    if (grid.isEmpty) return;

    final Paint cellPaint = Paint()..style = PaintingStyle.fill;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final double hue = grid[y * cols + x];
        if (hue < 0) continue;
        cellPaint.color =
            HSLColor.fromAHSL(1.0, hue, 0.55, 0.72).toColor();
        canvas.drawRect(
          Rect.fromLTWH(
            x * cellSize,
            y * cellSize,
            cellSize + 0.5,
            cellSize + 0.5,
          ),
          cellPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SandPainter oldDelegate) => true;
}
