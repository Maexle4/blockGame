// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:blockGame/piece.dart';
import 'package:blockGame/pixel.dart';
import 'package:blockGame/values.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('blockGameBox');

  await hideBar();

  runApp(const MyApp());
}

Future hideBar() async {
  // Versteckt die Systemleisten (Immersive Mode)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const blockGamePage(), 
    );
  }
}

class blockGameScoreDatabase {
  int currentScore = 0;
  final _blockGameBox = Hive.box('blockGameBox');

  void createInitialDate() {
    currentScore = 0;
  }

  void loadData() {
    // Falls noch kein Score da ist, setze ihn auf 0
    currentScore = _blockGameBox.get("blockGameBox") ?? 0;
  }

  void updateData() {
    _blockGameBox.put("blockGameBox", currentScore);
  }
}

List<List<Tetromino?>> gameBoard = List.generate(
  colLength,
  (i) => List.generate(
    rowLength,
    (j) => null,
  ),
);

class blockGamePage extends StatefulWidget {
  const blockGamePage({super.key});

  @override
  State<blockGamePage> createState() => _blockGamePageState();
}

class _blockGamePageState extends State<blockGamePage> {
  final _blockGameBox = Hive.box('blockGameBox');
  blockGameScoreDatabase tb = blockGameScoreDatabase();

  Piece currentPiece = Piece(type: Tetromino.L);

  int currentScore = 0;
  bool gameOver = false;
  bool paused = false;

  // Timer für den "Nach unten"-Turbo
  Timer? _moveTimer;

  @override
  void initState() {
    super.initState();
    if (_blockGameBox.get("blockGameBox") != null) {
      tb.loadData();
    }
    startGame();
  }

  // --- TURBO LOGIK (Nur für Down-Button) ---
  void _startMovingDown() {
    moveDown(); // Einmal sofort bewegen
    _moveTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      moveDown();
    });
  }

  void _stopMovingDown() {
    _moveTimer?.cancel();
  }
  // -----------------------------------------

  void startGame() {
    setState(() {
      tb.currentScore = 0;
    });
    tb.updateData();

    currentPiece.initPiece();

    Duration frameRate = Duration(milliseconds: 400);
    gameLoop(frameRate);
  }

  void gameLoop(Duration frameRate) {
    Timer.periodic(frameRate, (timer) {
      setState(() {
        if (paused == true) {
          return;
        } else {
          clearLines();
          checkLanding();

          if (gameOver == true) {
            timer.cancel();
            showGameOverDialog();
          }

          currentPiece.movePiece(Direction.down);
        }
      });
    });
  }

  void pauseGame() {
    setState(() {
      paused = true;
    });
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => AlertDialog(
      title: Text("Game Paused"),
      content: Text("Your Score is: " + tb.currentScore.toString()),
      actions: [
        TextButton(onPressed: () {
          Navigator.pop(context);
          setState(() {
            paused = false;
          });
        }, child: Text("Resume"))
      ],
    ));
  }

  void showGameOverDialog() {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => AlertDialog(
      title: Text("Game Over"),
      content: Text("Your Score is: " + tb.currentScore.toString()),
      actions: [
        TextButton(onPressed: () {
          resetGame();
          Navigator.pop(context);
        }, child: Text("Play Again"))
      ],
    ));
  }

  void resetGame() {
    gameBoard = List.generate(
      colLength,
      (i) => List.generate(
        rowLength,
        (j) => null,
      ),
    );

    gameOver = false;
    setState(() {
      tb.currentScore = 0;
    });
    tb.updateData();

    createNewPiece();
    startGame();
  }

  bool checkCollision(Direction direction) {
    for (int i = 0; i < currentPiece.position.length; i++) {
      int row = (currentPiece.position[i] / rowLength).floor();
      int col = currentPiece.position[i] % rowLength;

      if (direction == Direction.left) {
        col -= 1;
      } else if (direction == Direction.right) {
        col += 1;
      } else if (direction == Direction.down) {
        row += 1;
      }

      if (col < 0 || col >= rowLength || row >= colLength) {
        return true;
      }

      if (row >= 0 && gameBoard[row][col] != null) {
        return true;
      }
    }
    return false;
  }

  void checkLanding() {
    if (checkCollision(Direction.down) || checkLanded()) {
      for (int i = 0; i < currentPiece.position.length; i++) {
        int row = (currentPiece.position[i] / rowLength).floor();
        int col = currentPiece.position[i] % rowLength;

        if (row >= 0 && col >= 0) {
          gameBoard[row][col] = currentPiece.type;
        }
      }
      createNewPiece();
    }
  }

  bool checkLanded() {
    for (int i = 0; i < currentPiece.position.length; i++) {
      int row = (currentPiece.position[i] / rowLength).floor();
      int col = currentPiece.position[i] % rowLength;

      if (row + 1 < colLength && row >= 0 && gameBoard[row + 1][col] != null) {
        return true;
      }
    }
    return false;
  }

  void createNewPiece() {
    Random rand = Random();

    Tetromino randomType =
        Tetromino.values[rand.nextInt(Tetromino.values.length)];

    currentPiece = Piece(type: randomType);
    currentPiece.initPiece();
    
    // SCORE UPDATE IM SETSTATE
    setState(() {
      tb.currentScore = tb.currentScore + 10;
    });
    tb.updateData();

    if(isGameOver() == true) {
      gameOver = true;
    }
  }

  void moveLeft() {
    if (!checkCollision(Direction.left)) {
      setState(() {
        currentPiece.movePiece(Direction.left);
      });
    }
  }

  void rotatePiece() {
    setState(() {
      currentPiece.rotatePiece();
    });
  }

  void moveRight() {
    if (!checkCollision(Direction.right)) {
      setState(() {
        currentPiece.movePiece(Direction.right);
      });
    }
  }
  
  void moveDown() {
    if (!checkCollision(Direction.down)) {
      setState(() {
        currentPiece.movePiece(Direction.down);
      });
    }
  }

  void clearLines() {
    for (int row = colLength - 1; row >= 0; row--) {
      bool rowIsFull = true;

      for (int col = 0; col < rowLength; col++) {
        if (gameBoard[row][col] == null) {
          rowIsFull = false;
          break;
        }
      }
      if (rowIsFull) {
        for (int r = row; r > 0; r--) {
          gameBoard[r] = List.from(gameBoard[r - 1]);
        }
        gameBoard[0] = List.generate(rowLength, (index) => null);

        // SCORE UPDATE IM SETSTATE
        setState(() {
          tb.currentScore = tb.currentScore + 100;
        });
        tb.updateData();
      }
    }
  }

  bool isGameOver() {
    for (int col = 0; col < rowLength; col++) {
      if (gameBoard[0][col] != null) {
        return true;
      }
    }
    return false;
  }

  // --- HELFER FÜR DAS BUTTON-DESIGN ---
  Widget _buildButtonDesign(IconData icon) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            pauseGame();
          },
          icon: Icon(Icons.pause),
          color: Colors.white,
        ),
        centerTitle: true,
        title: Text(
          "Score: " + tb.currentScore.toString(),
          style: TextStyle(color: Colors.grey[300]),
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              itemCount: rowLength * colLength,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: rowLength),
              itemBuilder: (context, index) {
                int row = (index / rowLength).floor();
                int col = index % rowLength;

                if (currentPiece.position.contains(index)) {
                  return Pixel(
                    color: currentPiece.color,
                  );
                } else if (gameBoard[row][col] != null) {
                  final Tetromino? tetrominoType = gameBoard[row][col];
                  return Pixel(
                    color: tetrominoColors[tetrominoType],
                  );
                } else {
                  return Pixel(
                    color: Colors.grey[900],
                  );
                }
              },
            ),
          ),

          // STEUERUNGS BEREICH
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0, top: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Left (Normaler Klick)
                GestureDetector(
                  onTap: moveLeft,
                  child: _buildButtonDesign(Icons.arrow_back),
                ),

                // Rotate (Normaler Klick)
                GestureDetector(
                  onTap: rotatePiece,
                  child: _buildButtonDesign(Icons.rotate_right),
                ),

                // Right (Normaler Klick)
                GestureDetector(
                  onTap: moveRight,
                  child: _buildButtonDesign(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Down (Gedrückt halten für Turbo)
                GestureDetector(
                  onTapDown: (_) => _startMovingDown(),
                  onTapUp: (_) => _stopMovingDown(),
                  onTapCancel: () => _stopMovingDown(),
                  child: _buildButtonDesign(Icons.arrow_downward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}