part of '../arcade_games.dart';

class TicTacToeGame extends StatefulWidget {
  const TicTacToeGame({super.key});
  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> with _Emit {
  static const String _id = 'tictactoe';
  final math.Random _rnd = math.Random();
  final List<int> _b = List<int>.filled(9, 0); // 0 empty, 1 player, 2 ai
  List<int> _winLine = const <int>[];
  int _best = 0; // wins
  GameStatus _status = GameStatus.ready;
  String _overText = 'Draw';

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _winner(List<int> b) {
    for (final l in _lines) {
      if (b[l[0]] != 0 && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) {
        return b[l[0]];
      }
    }
    return 0;
  }

  static const List<List<int>> _lines = <List<int>>[
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  List<int> _winLineFor(List<int> b) {
    for (final l in _lines) {
      if (b[l[0]] != 0 && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) return l;
    }
    return const <int>[];
  }

  int? _findMove(int player) {
    for (var i = 0; i < 9; i++) {
      if (_b[i] == 0) {
        final copy = List<int>.from(_b);
        copy[i] = player;
        if (_winner(copy) == player) return i;
      }
    }
    return null;
  }

  void _aiMove() {
    // Always take a win; but Pico only blocks most of the time so a child can
    // actually win — a perfect opponent is no fun for this audience.
    var move = _findMove(2);
    if (move == null && _rnd.nextDouble() < 0.65) move = _findMove(1);
    if (move == null) {
      const prefs = <int>[4, 0, 2, 6, 8, 1, 3, 5, 7];
      final avail = <int>[for (final p in prefs) if (_b[p] == 0) p];
      if (avail.isNotEmpty) {
        // Favour good squares but mix in some chance so it's beatable.
        move = _rnd.nextDouble() < 0.6
            ? avail.first
            : avail[_rnd.nextInt(avail.length)];
      }
    }
    if (move != null) {
      _b[move] = 2;
      TonePlayer.instance.playClick(pitch: 0.7);
    }
  }

  void _finish(int w) {
    if (w == 1) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _best + 1).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else if (w == 2) {
      _status = GameStatus.over;
      _overText = 'Pico wins!';
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
    } else {
      _status = GameStatus.over;
      _overText = 'Draw!';
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      emit(ExperienceEvent.correctAnswer);
    }
  }

  void _tap(int i) {
    if (_status != GameStatus.playing || _b[i] != 0) return;
    setState(() {
      _b[i] = 1;
      TonePlayer.instance.playCue(SoundCue.wood);
      var w = _winner(_b);
      if (w == 0 && _b.contains(0)) {
        _aiMove();
        w = _winner(_b);
      }
      if (w != 0 || !_b.contains(0)) {
        _winLine = _winLineFor(_b);
        _finish(w);
      }
    });
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < 9; i++) {
        _b[i] = 0;
      }
      _winLine = const <int>[];
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '⭕ Tic-Tac-Toe',
      introHow: 'Get three in a row before the computer does!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _best,
      best: _best,
      status: _status,
      overEmoji: '🐾',
      overText: _overText,
      winEmoji: '⭐',
      winText: 'You win!',
      accent: const Color(0xFF43E97B),
      rankByScore: false,
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF12314A), Color(0xFF0C2233)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  for (var i = 0; i < 9; i++)
                    GestureDetector(
                      onTapDown: (_) => _tap(i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _winLine.contains(i)
                              ? const Color(0xFFFFD166).withOpacity(0.35)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: _winLine.contains(i)
                              ? Border.all(
                                  color: const Color(0xFFFFD166), width: 3)
                              : null,
                        ),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('ttt-$i-${_b[i]}'),
                          tween: Tween<double>(
                              begin: _b[i] != 0 ? 1.4 : 1.0, end: 1.0),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          builder: (c, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _b[i] == 1 ? '⭐' : _b[i] == 2 ? '🐾' : '',
                              maxLines: 1,
                              style: const TextStyle(fontSize: 52),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Brick Break — slide the paddle to bounce the ball and clear every brick.
// A physics classic: wall + paddle bounces, brick hits, lose if the ball
// drops. Clear the wall to win.
// ===========================================================================
