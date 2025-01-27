import 'dart:async';
import 'dart:math' show min, sqrt;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

/// Basic MaterialApp
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flutter Snake',
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        home: const SnakeGame(),
      );
}

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> with WidgetsBindingObserver {
  // Defaults for board dimensions
  int boardRows = 20;
  int boardCols = 20;

  // Snake state
  List<Offset> snakeBody = [];
  Offset snakeHead = const Offset(10, 10);
  Offset snakeDirection = const Offset(1, 0); // moving right
  bool isGameOver = false;
  bool isPaused = false;

  // Only allow ONE direction change per tick
  bool _directionChangedThisTick = false;

  // Apples
  List<Offset> apples = [];
  int applesEaten = 0;

  // Score & speed
  int score = 0;
  Duration tickSpeed = const Duration(milliseconds: 300);

  // 10-second countdown
  late Timer countdownTimer;
  int countdown = 10;

  // Bouncing balls
  List<_BouncingBall> balls = [];

  // Main game loop timer
  Timer? gameTimer;

  @override
  void initState() {
    super.initState();
    resetGame();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove observer when widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    gameTimer?.cancel();
    countdownTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Pause the game when window loses focus
      if (!isPaused && !isGameOver) {
        _pauseGame();
      }
    }
  }

  /// Resets all game variables
  void resetGame() {
    setState(() {
      isGameOver = false;
      isPaused = false;

      // Center the snake
      snakeHead = Offset(
          (boardCols / 2).floorToDouble(), (boardRows / 2).floorToDouble());
      snakeDirection = const Offset(1, 0);
      snakeBody = [
        snakeHead.translate(-1, 0),
        snakeHead.translate(-2, 0),
      ];

      // Apples
      apples.clear();
      apples.add(_randomApplePosition());
      applesEaten = 0;

      // Bouncing balls
      balls.clear();

      // Score & speed - calculate based on board size
      score = 0;
      // Aim to cross board diagonally in ~11 seconds
      final diagonalLength =
          sqrt(boardRows * boardRows + boardCols * boardCols);
      tickSpeed = Duration(milliseconds: (11000 / diagonalLength).round());

      // Countdown
      countdown = 10;
      countdownTimer =
          Timer.periodic(const Duration(seconds: 1), _onCountdownTick);

      // Game loop
      gameTimer?.cancel();
      gameTimer = Timer.periodic(tickSpeed, _updateGame);
    });
  }

  /// Called every 1s for the 10-second apple timer
  void _onCountdownTick(Timer timer) {
    if (!isPaused && !isGameOver) {
      setState(() {
        countdown--;
        if (countdown <= 0) {
          apples.add(_randomApplePosition());
          countdown = 10;
        }
      });
    }
  }

  /// Main game update, called every tickSpeed
  void _updateGame(Timer timer) {
    if (isPaused || isGameOver) return;

    setState(() {
      // We allow a new direction change after this tick
      _directionChangedThisTick = false;

      final newHead = snakeHead + snakeDirection;

      // End the game BEFORE going off the board
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

      // Collision with self
      if (snakeBody.contains(snakeHead)) {
        _gameOver();
        return;
      }

      // Check for apple
      var ateApple = false;
      for (var i = 0; i < apples.length; i++) {
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
        // Speed up slightly
        gameTimer?.cancel();
        tickSpeed =
            Duration(milliseconds: (tickSpeed.inMilliseconds * 0.95).floor());
        gameTimer = Timer.periodic(tickSpeed, _updateGame);

        // Every 5 apples => add a bouncing ball
        if (applesEaten % 5 == 0) {
          balls.add(_BouncingBall(
            position: Offset((boardCols / 2).floorToDouble(),
                (boardRows / 2).floorToDouble()),
            velocity: const Offset(1, -1),
          ));
        }

        // Spawn new apple & reset countdown
        apples.add(_randomApplePosition());
        countdown = 10;
      }

      // Update the bouncing balls
      _updateBalls();
    });
  }

  /// Position + velocity for the bouncing balls
  void _updateBalls() {
    for (var i = 0; i < balls.length; i++) {
      final current = balls[i];
      final newPosition = current.position + current.velocity;

      var newDx = current.velocity.dx;
      var newDy = current.velocity.dy;

      // Bounce off walls
      if (newPosition.dx < 0 || newPosition.dx >= boardCols) {
        newDx = -newDx;
      }
      if (newPosition.dy < 0 || newPosition.dy >= boardRows) {
        newDy = -newDy;
      }

      var finalVelocity = Offset(newDx, newDy);
      var finalPos = current.position + finalVelocity;

      // Bounce off snake body or apples
      if (snakeBody.contains(finalPos) || apples.contains(finalPos)) {
        finalVelocity = Offset(-finalVelocity.dx, -finalVelocity.dy);
        finalPos = current.position + finalVelocity;
      }

      // If it hits snake head => game over
      if (finalPos == snakeHead) {
        _gameOver();
        return;
      }

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

  /// Pause or resume
  void _pauseGame() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  /// Create a random apple position
  Offset _randomApplePosition() => Offset(
        (boardCols *
                (0.1 +
                    0.8 * (DateTime.now().millisecondsSinceEpoch % 100) / 100))
            .floorToDouble(),
        (boardRows *
                (0.1 +
                    0.8 *
                        (DateTime.now().millisecondsSinceEpoch % 10000) /
                        10000))
            .floorToDouble(),
      );

  /// Dialog to let us change board rows/cols
  Future<void> _showBoardSettingsDialog() async {
    final newRowsController = TextEditingController(text: boardRows.toString());
    final newColsController = TextEditingController(text: boardCols.toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Board Dimensions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newRowsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rows'),
            ),
            TextField(
              controller: newColsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Columns'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final rows = int.tryParse(newRowsController.text) ?? boardRows;
              final cols = int.tryParse(newColsController.text) ?? boardCols;
              if (rows > 0 && cols > 0) {
                setState(() {
                  boardRows = rows;
                  boardCols = cols;
                });
                resetGame();
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  /// We only allow one direction change per tick
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) =>
      (event is KeyDownEvent && !_directionChangedThisTick)
          ? _processKeyEvent(event)
          : KeyEventResult.ignored;

  /// Helper method to process key events
  KeyEventResult _processKeyEvent(KeyDownEvent event) {
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      _pauseGame();
      return KeyEventResult.handled;
    }

    // Only process direction changes if the game is running
    if (!isPaused && !isGameOver) {
      // Prevent reversing into yourself
      if (key == LogicalKeyboardKey.arrowUp && snakeDirection.dy == 0) {
        if (snakeDirection.dy != 1) {
          snakeDirection = const Offset(0, -1);
          _directionChangedThisTick = true;
        }
      } else if (key == LogicalKeyboardKey.arrowDown &&
          snakeDirection.dy == 0) {
        if (snakeDirection.dy != -1) {
          snakeDirection = const Offset(0, 1);
          _directionChangedThisTick = true;
        }
      } else if (key == LogicalKeyboardKey.arrowLeft &&
          snakeDirection.dx == 0) {
        if (snakeDirection.dx != 1) {
          snakeDirection = const Offset(-1, 0);
          _directionChangedThisTick = true;
        }
      } else if (key == LogicalKeyboardKey.arrowRight &&
          snakeDirection.dx == 0) {
        if (snakeDirection.dx != -1) {
          snakeDirection = const Offset(1, 0);
          _directionChangedThisTick = true;
        }
      }
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            isGameOver
                ? 'Game Over! Score: $score'
                : 'Flutter Snake - Score: $score',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showBoardSettingsDialog,
              tooltip: 'Set Board Dimensions',
            ),
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
            // 1) Board area that preserves square aspect ratio
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The board is a square, so pick the smaller dimension
                  final double boardSize =
                      min(constraints.maxWidth, constraints.maxHeight);

                  return Center(
                    // We'll center a square area
                    child: SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: _handleKeyEvent,
                        child: CustomPaint(
                          size: Size(boardSize, boardSize),
                          painter: _BoardPainter(
                            rows: boardRows,
                            cols: boardCols,
                            snakeHead: snakeHead,
                            snakeBody: snakeBody,
                            apples: apples,
                            balls: balls,
                          ),
                          child: Stack(
                            children: [
                              // "Game Over" overlay
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
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
                  );
                },
              ),
            ),
            // 2) Status row below the board
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Apple Timer: ${isGameOver ? 0 : countdown}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 24), // Space between the two texts
                  Text(
                    'Snake Speed: '
                    '${(1000 / tickSpeed.inMilliseconds).toStringAsFixed(1)}x',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Simple data class for bouncing ball
class _BouncingBall {
  const _BouncingBall({required this.position, required this.velocity});
  final Offset position;
  final Offset velocity;
}

/// CustomPainter for the board elements
class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.rows,
    required this.cols,
    required this.snakeHead,
    required this.snakeBody,
    required this.apples,
    required this.balls,
  });
  final int rows;
  final int cols;
  final Offset snakeHead;
  final List<Offset> snakeBody;
  final List<Offset> apples;
  final List<_BouncingBall> balls;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // 1) Draw a border around entire board
    final borderPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    // 2) Draw the snake body
    final snakePaint = Paint()..color = Colors.blue;
    for (final segment in snakeBody) {
      final rect = Rect.fromLTWH(
        segment.dx * cellWidth,
        segment.dy * cellHeight,
        cellWidth,
        cellHeight,
      );
      canvas.drawRect(rect, snakePaint);
    }

    // 3) Draw the snake head
    final headPaint = Paint()..color = Colors.lightBlueAccent;
    final headRect = Rect.fromLTWH(
      snakeHead.dx * cellWidth,
      snakeHead.dy * cellHeight,
      cellWidth,
      cellHeight,
    );
    canvas.drawRect(headRect, headPaint);

    // 4) Draw apples
    final applePaint = Paint()..color = Colors.red;
    for (final apple in apples) {
      final rect = Rect.fromLTWH(
        apple.dx * cellWidth,
        apple.dy * cellHeight,
        cellWidth,
        cellHeight,
      );
      canvas.drawRect(rect, applePaint);
    }

    // 5) Draw bouncing balls
    final ballPaint = Paint()..color = Colors.greenAccent;
    for (final ball in balls) {
      final rect = Rect.fromLTWH(
        ball.position.dx * cellWidth,
        ball.position.dy * cellHeight,
        cellWidth,
        cellHeight,
      );
      canvas.drawRect(rect, ballPaint);
    }

    // 6) Draw naive "straight-line path" from snake head to the nearest apple
    if (apples.isNotEmpty) {
      final nearest = _findNearestApple(snakeHead, apples);
      final pathCells = _computeStraightLinePath(snakeHead, nearest);

      final pathPaint = Paint()
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

  /// Find the apple with smallest Manhattan distance to the head
  Offset _findNearestApple(Offset head, List<Offset> apples) =>
      apples.reduce((a, b) {
        final distA = (head.dx - a.dx).abs() + (head.dy - a.dy).abs();
        final distB = (head.dx - b.dx).abs() + (head.dy - b.dy).abs();
        return distA < distB ? a : b;
      });

  /// Return a horizontal-then-vertical path of grid cells from start to end
  List<Offset> _computeStraightLinePath(Offset start, Offset end) {
    final path = <Offset>[];
    final x0 = start.dx.toInt();
    final y0 = start.dy.toInt();
    final x1 = end.dx.toInt();
    final y1 = end.dy.toInt();

    // Move horizontally first
    if (x1 > x0) {
      for (var x = x0 + 1; x <= x1; x++) {
        path.add(Offset(x.toDouble(), y0.toDouble()));
      }
    } else if (x1 < x0) {
      for (var x = x0 - 1; x >= x1; x--) {
        path.add(Offset(x.toDouble(), y0.toDouble()));
      }
    }

    // Then move vertically
    if (y1 > y0) {
      for (var y = y0 + 1; y <= y1; y++) {
        path.add(Offset(x1.toDouble(), y.toDouble()));
      }
    } else if (y1 < y0) {
      for (var y = y0 - 1; y >= y1; y--) {
        path.add(Offset(x1.toDouble(), y.toDouble()));
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => true;
}
