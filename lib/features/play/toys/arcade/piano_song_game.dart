part of '../arcade_games.dart';

/// Piano Song — follow the lit key to play a whole nursery tune. The next note
/// glows; tap it to hear it and move on. Finish three little songs to win. A
/// gentle, no-pressure music game — a wrong key just waits for you to try again.
class PianoSongGame extends StatefulWidget {
  const PianoSongGame({super.key});
  @override
  State<PianoSongGame> createState() => _PianoSongGameState();
}

class _Song {
  const _Song(this.name, this.keys);
  final String name;
  final List<int> keys; // indices into the 7 white keys (C..B)
}

class _PianoSongGameState extends State<PianoSongGame> with _Emit {
  static const String _id = 'piano_song';
  // White-key letters and their pentatonic/diatonic degree for TonePlayer.
  static const List<String> _letters = <String>['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const List<int> _degrees = <int>[0, 2, 4, 5, 7, 9, 11];
  static const List<_Song> _songs = <_Song>[
    _Song('Twinkle Twinkle', <int>[0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0]),
    _Song('Mary Had a Lamb', <int>[2, 1, 0, 1, 2, 2, 2, 1, 1, 1, 2, 4, 4]),
    _Song('Row Your Boat', <int>[0, 0, 0, 1, 2, 2, 1, 2, 3, 4]),
  ];
  static const int _target = 3; // songs to win
  final math.Random _rnd = math.Random();

  // Shuffled song order for this playthrough — without this, every single
  // run played 'Twinkle Twinkle', 'Mary Had a Lamb', 'Row Your Boat' in the
  // exact same fixed sequence forever (the same "identical every session"
  // gap class already fixed in xylophone_tap/dot_to_dot/mirror_draw).
  late List<int> _order;
  int _orderPos = 0;
  int _notePos = 0;
  int _score = 0; // songs completed
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  int _wrongKey = -1; // brief red flash on a mis-tapped key

  @override
  void initState() {
    super.initState();
    _order = List<int>.generate(_songs.length, (i) => i)..shuffle(_rnd);
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  _Song get _song => _songs[_order[_orderPos]];
  int get _nextKey => _song.keys[_notePos];

  void _start() {
    setState(() {
      _order = List<int>.generate(_songs.length, (i) => i)..shuffle(_rnd);
      _orderPos = 0;
      _notePos = 0;
      _score = 0;
      _banner = null;
      _status = GameStatus.playing;
    });
  }

  void _tapKey(int k) {
    if (_status != GameStatus.playing) return;
    TonePlayer.instance.playNote(_degrees[k], seconds: 0.28);
    if (k == _nextKey) {
      _notePos++;
      if (_notePos >= _song.keys.length) {
        // Song finished.
        _score++;
        emit(ExperienceEvent.bubblePopped);
        TonePlayer.instance.playCue(SoundCue.success);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _orderPos++;
          _notePos = 0;
          _banner = 'Lovely! Next: ${_song.name}';
        }
      } else {
        _banner = null;
      }
    } else {
      // A wrong key previously only changed the banner text at the top of
      // the screen — the mis-tapped key itself gave no sign it was the
      // wrong one. Added the same brief red-flash-then-clear feedback used
      // catalog-wide (dot_to_dot/odd_one_out/shadow_match) so the tap the
      // child actually felt is the one that visibly answers them.
      _banner = 'Follow the glowing key';
      _wrongKey = k;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _wrongKey == k) setState(() => _wrongKey = -1);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final progress = _status == GameStatus.playing
        ? '${_song.name} · ${_notePos + 1}/${_song.keys.length}'
        : 'Tap the lit keys to play a song';
    return _Shell(
      title: '🎹 Piano Song',
      introHow:
          'The next key lights up — tap it to play the note and move through '
          'the tune. Finish three nursery songs to win!',
      onStart: _start,
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? progress,
      winEmoji: '🎹',
      winText: 'Keep playing!',
      accent: const Color(0xFFFFB5E8),
      onPlayAgain: _start,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A1A3E), Color(0xFF140C22)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 150, 10, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var k = 0; k < 7; k++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _PianoKey(
                        letter: _letters[k],
                        lit: _status == GameStatus.playing && _nextKey == k,
                        wrong: _wrongKey == k,
                        onTap: () => _tapKey(k),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PianoKey extends StatelessWidget {
  const _PianoKey({
    required this.letter,
    required this.lit,
    required this.onTap,
    this.wrong = false,
  });
  final String letter;
  final bool lit;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: wrong
                ? const <Color>[Color(0xFFFFD9D9), Color(0xFFFF8A8A)]
                : (lit
                    ? const <Color>[Color(0xFFFFE3F6), Color(0xFFFF8ED8)]
                    : const <Color>[Color(0xFFFDFDFD), Color(0xFFDADADA)]),
          ),
          border: wrong
              ? Border.all(color: const Color(0xFFE23B3B), width: 3)
              : (lit
                  ? Border.all(color: const Color(0xFFFF4FC3), width: 3)
                  : Border.all(color: Colors.black26, width: 1)),
          boxShadow: lit
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFFF8ED8).withOpacity(0.7),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          letter,
          style: TextStyle(
            color: wrong
                ? const Color(0xFF8A1414)
                : (lit ? const Color(0xFF7A1457) : Colors.black54),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
