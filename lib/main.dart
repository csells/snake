import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Snake',
      theme: ThemeData.dark(),
      home: const SnakeGame(),
    );
  }
}

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  // Board configuration
  static const int initialBoardRows = 20;
  static const int initialBoardCols = 20;
  int boardRows = initialBoardRows;
  int boardCols = initialBoardCols;

  // Snake state
  List<Offset> snakeBody = [];
  Offset snakeHead = const Offset(10, 10);
  Offset snakeDirection = const Offset(1, 0); // moving right
  bool isGameOver = false;
  bool isPaused = false;

  // Apples
  List<Offset> apples = [];
  int applesEaten = 0;

  // Score and speed
  int score = 0;
  Duration tickSpeed = const Duration(milliseconds: 300);

  // 10-second countdown
  late Timer countdownTimer;
  int countdown = 10;

  // Bouncing balls
  List<_BouncingBall> balls = [];

  // Main game loop
  Timer? gameTimer;

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  void resetGame() {
    setState(() {
      isGameOver = false;
      isPaused = false;

      boardRows = initialBoardRows;
      boardCols = initialBoardCols;

      // Snake
      snakeHead = Offset(boardCols / 2, boardRows / 2);
      snakeDirection = const Offset(1, 0);
      snakeBody = [
        snakeHead.translate(-1, 0),
        snakeHead.translate(-2, 0),
      ];

      // Apples
      apples.clear();
      apples.add(_randomApplePosition());
      applesEaten = 0;

      // Balls
      balls.clear();

      // Score & speed
      score = 0;
      tickSpeed = const Duration(milliseconds: 300);

      // 10s countdown
      countdown = 10;
      countdownTimer =
          Timer.periodic(const Duration(seconds: 1), _onCountdownTick);

      // Game loop
      gameTimer?.cancel();
      gameTimer = Timer.periodic(tickSpeed, _updateGame);
    });
  }

  void _onCountdownTick(Timer timer) {
    if (!isPaused && !isGameOver) {
      setState(() {
        countdown--;
        // If time's up, spawn another apple & reset countdown
        if (countdown <= 0) {
          apples.add(_randomApplePosition());
          countdown = 10;
        }
      });
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    countdownTimer.cancel();
    super.dispose();
  }

  Offset _randomApplePosition() {
    // Simple random approach. You might improve it to avoid collisions.
    return Offset(
      (boardCols *
              (0.1 + 0.8 * (DateTime.now().millisecondsSinceEpoch % 100) / 100))
          .floorToDouble(),
      (boardRows *
              (0.1 +
                  0.8 *
                      (DateTime.now().millisecondsSinceEpoch % 10000) /
                      10000))
          .floorToDouble(),
    );
  }

  void _updateGame(Timer timer) {
    if (isPaused || isGameOver) return;

    setState(() {
      final newHead = snakeHead + snakeDirection;

      // End game BEFORE going off the board
      if (newHead.dx < 0 ||
          newHead.dy < 0 ||
          newHead.dx >= boardCols ||
          newHead.dy >= boardRows) {
        _gameOver();
        return;
      }

      // Move snake
      snakeBody.insert(0, snakeHead);
      snakeHead = newHead;

      // Check collision with self
      if (snakeBody.contains(snakeHead)) {
        _gameOver();
        return;
      }

      // Check for apple
      bool ateApple = false;
      for (int i = 0; i < apples.length; i++) {
        if (apples[i] == snakeHead) {
          ateApple = true;
          score++;
          applesEaten++;
          apples.removeAt(i);
          break;
        }
      }

      if (!ateApple) {
        // Normal move: remove tail
        snakeBody.removeLast();
      } else {
        // Increase speed slightly
        gameTimer?.cancel();
        tickSpeed =
            Duration(milliseconds: (tickSpeed.inMilliseconds * 0.95).floor());
        gameTimer = Timer.periodic(tickSpeed, _updateGame);

        // Every 5 apples => add a bouncing ball
        if (applesEaten % 5 == 0) {
          balls.add(_BouncingBall(
            position: Offset(boardCols / 2, boardRows / 2),
            velocity: const Offset(1, -1),
          ));
        }

        // Immediately spawn new apple & reset countdown
        apples.add(_randomApplePosition());
        countdown = 10;
      }

      // Update balls
      _updateBalls();
    });
  }

  void _updateBalls() {
    for (int i = 0; i < balls.length; i++) {
      final current = balls[i];
      final newPosition = current.position + current.velocity;

      double newDx = current.velocity.dx;
      double newDy = current.velocity.dy;

      // Bounce off walls
      if (newPosition.dx < 0 || newPosition.dx >= boardCols) {
        newDx = -newDx;
      }
      if (newPosition.dy < 0 || newPosition.dy >= boardRows) {
        newDy = -newDy;
      }

      Offset finalVelocity = Offset(newDx, newDy);
      Offset finalPos = current.position + finalVelocity;

      // Bounce off snake body or apples
      if (snakeBody.contains(finalPos) || apples.contains(finalPos)) {
        finalVelocity = Offset(-finalVelocity.dx, -finalVelocity.dy);
        finalPos = current.position + finalVelocity;
      }

      // Collision with snake HEAD => game over
      if (finalPos == snakeHead) {
        _gameOver();
        return;
      }

      // Update
      balls[i] = _BouncingBall(position: finalPos, velocity: finalVelocity);
    }
  }

  void _gameOver() {
    setState(() {
      isGameOver = true;
    });
    gameTimer?.cancel();
    countdownTimer.cancel();
  }

  void _pauseGame() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  // Replace RawKeyEvent with KeyEvent to avoid deprecation
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Only handle keyDown events
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      // Prevent reversing into oneself
      if (key == LogicalKeyboardKey.arrowUp && snakeDirection.dy == 0) {
        if (snakeDirection.dy != 1) {
          snakeDirection = const Offset(0, -1);
        }
      } else if (key == LogicalKeyboardKey.arrowDown &&
          snakeDirection.dy == 0) {
        if (snakeDirection.dy != -1) {
          snakeDirection = const Offset(0, 1);
        }
      } else if (key == LogicalKeyboardKey.arrowLeft &&
          snakeDirection.dx == 0) {
        if (snakeDirection.dx != 1) {
          snakeDirection = const Offset(-1, 0);
        }
      } else if (key == LogicalKeyboardKey.arrowRight &&
          snakeDirection.dx == 0) {
        if (snakeDirection.dx != -1) {
          snakeDirection = const Offset(1, 0);
        }
      } else if (key == LogicalKeyboardKey.space) {
        _pauseGame();
      }
      return KeyEventResult.handled; // We handled this event
    }
    return KeyEventResult.ignored; // We didn't handle this event
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isGameOver
            ? 'Game Over! Score: $score'
            : 'Flutter Snake - Score: $score'),
        actions: [
          if (!isGameOver)
            IconButton(
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _pauseGame,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetGame,
          ),
        ],
      ),
      body: Column(
        children: [
          // Timer above the board
          if (!isGameOver)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Timer: $countdown',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          // Board area
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: boardCols * 20,
                  height: boardRows * 20,
                  // Focus widget with onKeyEvent
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: _handleKeyEvent,
                    child: Stack(
                      children: [
                        // CustomPaint for the board
                        CustomPaint(
                          size: Size(boardCols * 20, boardRows * 20),
                          painter: _BoardPainter(
                            rows: boardRows,
                            cols: boardCols,
                            snakeHead: snakeHead,
                            snakeBody: snakeBody,
                            apples: apples,
                            balls: balls,
                          ),
                        ),
                        // "Play Again" overlay
                        if (isGameOver)
                          Center(
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Game Over!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Score: $score',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: resetGame,
                                    child: const Text('Play Again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple data for a bouncing ball
class _BouncingBall {
  final Offset position;
  final Offset velocity;
  const _BouncingBall({
    required this.position,
    required this.velocity,
  });
}

/// The CustomPainter for the board, snake, apples, etc.
class _BoardPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Offset snakeHead;
  final List<Offset> snakeBody;
  final List<Offset> apples;
  final List<_BouncingBall> balls;

  _BoardPainter({
    required this.rows,
    required this.cols,
    required this.snakeHead,
    required this.snakeBody,
    required this.apples,
    required this.balls,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // 1) Draw just a big border (no grid)
    final Paint borderPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer border for the entire board
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(boardRect, borderPaint);

    // 2) Draw snake body
    final Paint snakePaint = Paint()..color = Colors.blue;
    for (final segment in snakeBody) {
      canvas.drawRect(
        Rect.fromLTWH(segment.dx * cellWidth, segment.dy * cellHeight,
            cellWidth, cellHeight),
        snakePaint,
      );
    }

    // 3) Draw snake head
    final Paint headPaint = Paint()..color = Colors.lightBlueAccent;
    canvas.drawRect(
      Rect.fromLTWH(snakeHead.dx * cellWidth, snakeHead.dy * cellHeight,
          cellWidth, cellHeight),
      headPaint,
    );

    // 4) Draw apples
    final Paint applePaint = Paint()..color = Colors.red;
    for (final apple in apples) {
      canvas.drawRect(
        Rect.fromLTWH(
            apple.dx * cellWidth, apple.dy * cellHeight, cellWidth, cellHeight),
        applePaint,
      );
    }

    // 5) Draw bouncing balls
    final Paint ballPaint = Paint()..color = Colors.greenAccent;
    for (final ball in balls) {
      canvas.drawRect(
        Rect.fromLTWH(ball.position.dx * cellWidth,
            ball.position.dy * cellHeight, cellWidth, cellHeight),
        ballPaint,
      );
    }

    // 6) Draw a “grid-like” path from snake head to the NEAREST apple (if any).
    //    We'll do a naive horizontal-then-vertical path and outline those cells
    //    to visually mimic a small "grid" between head and apple.
    if (apples.isNotEmpty) {
      // Find the apple closest to the snake head (in Manhattan distance, for example)
      final nearest = _findNearestApple(snakeHead, apples);
      // Build the path
      final pathCells = _computeStraightLinePath(snakeHead, nearest);
      final Paint pathPaint = Paint()
        ..color = Colors.purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      for (final cell in pathCells) {
        final rect = Rect.fromLTWH(
          cell.dx * cellWidth,
          cell.dy * cellHeight,
          cellWidth,
          cellHeight,
        );
        canvas.drawRect(rect, pathPaint);
      }
    }
  }

  /// Find the apple with the smallest Manhattan distance to the snake head
  Offset _findNearestApple(Offset head, List<Offset> apples) {
    Offset nearest = apples.first;
    double nearestDist = double.infinity;
    for (final apple in apples) {
      final dist = (head.dx - apple.dx).abs() + (head.dy - apple.dy).abs();
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = apple;
      }
    }
    return nearest;
  }

  /// A simple horizontal-then-vertical path from `start` to `end` (or vice versa).
  /// No collision checks, purely for display.
  List<Offset> _computeStraightLinePath(Offset start, Offset end) {
    final List<Offset> path = [];
    final x0 = start.dx.toInt();
    final y0 = start.dy.toInt();
    final x1 = end.dx.toInt();
    final y1 = end.dy.toInt();

    // Move horizontally first
    if (x1 > x0) {
      for (int x = x0 + 1; x <= x1; x++) {
        path.add(Offset(x.toDouble(), y0.toDouble()));
      }
    } else if (x1 < x0) {
      for (int x = x0 - 1; x >= x1; x--) {
        path.add(Offset(x.toDouble(), y0.toDouble()));
      }
    }

    // Then move vertically
    if (y1 > y0) {
      for (int y = y0 + 1; y <= y1; y++) {
        path.add(Offset(x1.toDouble(), y.toDouble()));
      }
    } else if (y1 < y0) {
      for (int y = y0 - 1; y >= y1; y--) {
        path.add(Offset(x1.toDouble(), y.toDouble()));
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    // Repaint whenever the snake or apples or anything changes
    return true;
  }
}
