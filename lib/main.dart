import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AtelierChronoApp());
}

class AtelierChronoApp extends StatelessWidget {
  const AtelierChronoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atelier Chrono',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'serif'),
      home: const AtelierMasterDialScreen(),
    );
  }
}

class AtelierMasterDialScreen extends StatefulWidget {
  const AtelierMasterDialScreen({super.key});

  @override
  State<AtelierMasterDialScreen> createState() => _AtelierMasterDialScreenState();
}

class _AtelierMasterDialScreenState extends State<AtelierMasterDialScreen>
    with SingleTickerProviderStateMixin {
  int _activeComplication = 0;

  double _smoothTiltX = 0.0;
  double _smoothTiltY = 0.0;
  StreamSubscription? _accelerometerSub;

  double? _heading = 0.0;
  StreamSubscription? _compassSub;

  late DateTime _now;
  Timer? _clockTicker;

  bool _isChronoRunning = false;
  int _chronoElapsedMs = 0;
  Timer? _chronoTimer;

  int _woundSeconds = 300;
  int _remainingSeconds = 300;
  bool _isTimerActive = false;
  Timer? _timerCountdown;
  double _lastDragAngle = 0.0;

  static const Color colorLinen = Color(0xFFF7F4EE);
  static const Color colorCreamOat = Color(0xFFEDE8DE);
  static const Color colorRoyalBurgundy = Color(0xFF4A0E17);
  static const Color colorNocturneBurgundy = Color(0xFF24050B);
  static const Color colorBrushedBrass = Color(0xFFC5A059);
  static const Color colorDarkEspresso = Color(0xFF161110);
  static const Color colorMutedSand = Color(0xFFD6CEBF);

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    _clockTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _accelerometerSub = accelerometerEventStream().listen((event) {
      if (mounted) {
        setState(() {
          _smoothTiltX = (_smoothTiltX * 0.85) + ((event.x / 9.8) * 0.15);
          _smoothTiltY = (_smoothTiltY * 0.85) + ((event.y / 9.8) * 0.15);
        });
      }
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _heading = event.heading);
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _accelerometerSub?.cancel();
    _compassSub?.cancel();
    _chronoTimer?.cancel();
    _timerCountdown?.cancel();
    super.dispose();
  }

  void _hapticClick() async {
    if (await Vibrate.canVibrate) {
      Vibrate.feedback(FeedbackType.light);
    }
  }

  void _hapticHeavy() async {
    if (await Vibrate.canVibrate) {
      Vibrate.feedback(FeedbackType.heavy);
    }
  }

  void _toggleChrono() {
    _hapticClick();
    if (_isChronoRunning) {
      _chronoTimer?.cancel();
      setState(() => _isChronoRunning = false);
    } else {
      setState(() => _isChronoRunning = true);
      _chronoTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (mounted) setState(() => _chronoElapsedMs += 30);
      });
    }
  }

  void _resetChrono() {
    _hapticClick();
    _chronoTimer?.cancel();
    setState(() {
      _isChronoRunning = false;
      _chronoElapsedMs = 0;
    });
  }

  void _handleCrownDrag(Offset localPos, Size dialSize) {
    if (_isTimerActive) return;

    final center = Offset(dialSize.width / 2, dialSize.height / 2);
    final currentAngle = math.atan2(localPos.dy - center.dy, localPos.dx - center.dx);

    if (_lastDragAngle != 0.0) {
      double angleDiff = currentAngle - _lastDragAngle;
      if (angleDiff > math.pi) angleDiff -= 2 * math.pi;
      if (angleDiff < -math.pi) angleDiff += 2 * math.pi;

      if (angleDiff.abs() > 0.05) {
        _hapticClick();
        setState(() {
          int addedSeconds = (angleDiff * 120).round();
          _woundSeconds = math.max(60, math.min(3600, _woundSeconds + addedSeconds));
          _remainingSeconds = _woundSeconds;
        });
      }
    }
    _lastDragAngle = currentAngle;
  }

  void _toggleCountdownTimer() {
    _hapticHeavy();
    if (_isTimerActive) {
      _timerCountdown?.cancel();
      setState(() => _isTimerActive = false);
    } else {
      if (_remainingSeconds <= 0) {
        setState(() => _remainingSeconds = _woundSeconds);
      }
      setState(() => _isTimerActive = true);
      _timerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          timer.cancel();
          setState(() => _isTimerActive = false);
          _hapticHeavy();
        }
      });
    }
  }

  Color get _canvasColor => (_activeComplication >= 2) ? colorNocturneBurgundy : colorLinen;
  Color get _dialColor => (_activeComplication >= 2) ? colorRoyalBurgundy : colorCreamOat;
  Color get _primaryText => (_activeComplication >= 2) ? colorLinen : colorDarkEspresso;

  @override
  Widget build(BuildContext context) {
    final dialDiameter = MediaQuery.of(context).size.width * 0.82;

    return Scaffold(
      backgroundColor: _canvasColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        color: _canvasColor,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "ATELIER HOROLOGIE",
                style: TextStyle(
                  letterSpacing: 6.5,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primaryText.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "GRAND COMPLICATION • CALIBRE 101",
                style: TextStyle(
                  letterSpacing: 2.2,
                  fontSize: 8.5,
                  color: colorBrushedBrass.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Center(
                child: Transform(
                  alignment: FractionalOffset.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(_smoothTiltX * 0.50)
                    ..rotateX(-_smoothTiltY * 0.50),
                  child: GestureDetector(
                    onPanStart: (details) {
                      _lastDragAngle = 0.0;
                    },
                    onPanUpdate: (details) {
                      if (_activeComplication == 3) {
                        _handleCrownDrag(
                          details.localPosition,
                          Size(dialDiameter, dialDiameter),
                        );
                      }
                    },
                    child: Container(
                      width: dialDiameter,
                      height: dialDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _dialColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 36,
                            offset: Offset(_smoothTiltX * 22, -_smoothTiltY * 22 + 14),
                          ),
                          BoxShadow(
                            color: colorBrushedBrass.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: -3,
                          ),
                        ],
                        border: Border.all(
                          color: colorBrushedBrass.withOpacity(0.7),
                          width: 2.2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(dialDiameter, dialDiameter),
                            painter: HorologyChapterPainter(
                              isNightMode: _activeComplication >= 2,
                              accentBrass: colorBrushedBrass,
                            ),
                          ),
                          if (_activeComplication == 0) _buildClockComplication(),
                          if (_activeComplication == 1) _buildCompassComplication(),
                          if (_activeComplication == 2) _buildChronoComplication(),
                          if (_activeComplication == 3) _buildTimerComplication(dialDiameter),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_activeComplication == 2) _buildChronoControls(),
              if (_activeComplication == 3) _buildTimerControls(),
              if (_activeComplication < 2) const SizedBox(height: 54),
              const SizedBox(height: 24),
              _buildComplicationSelector(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockComplication() {
    final double sec = _now.second.toDouble();
    final double min = _now.minute.toDouble() + (sec / 60.0);
    final double hr = (_now.hour % 12).toDouble() + (min / 60.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: (hr * 30.0) * (math.pi / 180.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 75),
              width: 5,
              height: 70,
              decoration: BoxDecoration(
                color: colorDarkEspresso,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        Transform.rotate(
          angle: (min * 6.0) * (math.pi / 180.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 45),
              width: 3.5,
              height: 100,
              decoration: BoxDecoration(
                color: colorRoyalBurgundy,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        Transform.rotate(
          angle: (sec * 6.0) * (math.pi / 180.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 30),
              width: 1.5,
              height: 120,
              color: colorBrushedBrass,
            ),
          ),
        ),
        Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: colorBrushedBrass,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _buildCompassComplication() {
    final heading = _heading ?? 0.0;
    return Transform.rotate(
      angle: (-heading) * (math.pi / 180.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 24,
            child: Text(
              "N",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: colorRoyalBurgundy,
                letterSpacing: 2,
              ),
            ),
          ),
          const Positioned(
            bottom: 24,
            child: Text(
              "S",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: colorDarkEspresso,
              ),
            ),
          ),
          const Positioned(
            right: 28,
            child: Text("E", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const Positioned(
            left: 28,
            child: Text("W", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          CustomPaint(
            size: const Size(20, 160),
            painter: NeedlePainter(
              northColor: colorRoyalBurgundy,
              southColor: colorMutedSand,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorCreamOat,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorBrushedBrass.withOpacity(0.5)),
            ),
            child: Text(
              "${heading.toStringAsFixed(0)}°",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorDarkEspresso,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChronoComplication() {
    final mins = (_chronoElapsedMs ~/ 60000).toString().padLeft(2, '0');
    final secs = ((_chronoElapsedMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final cs = ((_chronoElapsedMs % 1000) ~/ 10).toString().padLeft(2, '0');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "SPLIT SECONDS CHRONO",
          style: TextStyle(
            letterSpacing: 3,
            fontSize: 9,
            color: colorBrushedBrass.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "$mins:$secs",
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w300,
            color: colorLinen,
            letterSpacing: 3,
          ),
        ),
        Text(
          ".$cs",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: colorBrushedBrass.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerComplication(double dialSize) {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final progress = _woundSeconds > 0 ? _remainingSeconds / _woundSeconds : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: dialSize * 0.76,
          height: dialSize * 0.76,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 4.0,
            valueColor: const AlwaysStoppedAnimation<Color>(colorBrushedBrass),
            backgroundColor: colorBrushedBrass.withOpacity(0.12),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isTimerActive ? "MAINSPRING DRAINING" : "ROTATE DIAL TO WIND",
              style: TextStyle(
                letterSpacing: 2.5,
                fontSize: 8.5,
                color: colorBrushedBrass.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "$mins:$secs",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: colorLinen,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChronoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: _resetChrono,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorBrushedBrass.withOpacity(0.5)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            "RESET",
            style: TextStyle(color: colorLinen, letterSpacing: 2, fontSize: 11),
          ),
        ),
        const SizedBox(width: 18),
        ElevatedButton(
          onPressed: _toggleChrono,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorBrushedBrass,
            foregroundColor: colorDarkEspresso,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: Text(
            _isChronoRunning ? "STOP" : "START",
            style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerControls() {
    return ElevatedButton(
      onPressed: _toggleCountdownTimer,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorBrushedBrass,
        foregroundColor: colorDarkEspresso,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
      ),
      child: Text(
        _isTimerActive ? "HALT ESCAPEMENT" : "ENGAGE TIMER",
        style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildComplicationSelector() {
    const modes = ["CLOCK", "COMPASS", "CHRONO", "TIMER"];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (_activeComplication >= 2 ? colorRoyalBurgundy : colorMutedSand)
            .withOpacity(0.4),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: colorBrushedBrass.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(modes.length, (idx) {
          final isSelected = _activeComplication == idx;
          return GestureDetector(
            onTap: () {
              _hapticClick();
              setState(() => _activeComplication = idx);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? colorBrushedBrass : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                modes[idx],
                style: TextStyle(
                  letterSpacing: 1.5,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? colorDarkEspresso : _primaryText.withOpacity(0.6),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class HorologyChapterPainter extends CustomPainter {
  final bool isNightMode;
  final Color accentBrass;

  HorologyChapterPainter({required this.isNightMode, required this.accentBrass});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final tickPaint = Paint()
      ..color = isNightMode ? accentBrass.withOpacity(0.35) : Colors.black26
      ..strokeWidth = 1.0;

    final majorTickPaint = Paint()
      ..color = accentBrass
      ..strokeWidth = 2.0;

    for (int i = 0; i < 60; i++) {
      final angle = (i * 6) * (math.pi / 180.0);
      final isMajor = i % 5 == 0;
      final len = isMajor ? 13.0 : 6.0;

      final p1 = Offset(
        center.dx + (radius - 14) * math.cos(angle),
        center.dy + (radius - 14) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 14 - len) * math.cos(angle),
        center.dy + (radius - 14 - len) * math.sin(angle),
      );

      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NeedlePainter extends CustomPainter {
  final Color northColor;
  final Color southColor;

  NeedlePainter({required this.northColor, required this.southColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final pNorth = Path()
      ..moveTo(center.dx, center.dy - 68)
      ..lineTo(center.dx + 5, center.dy)
      ..lineTo(center.dx - 5, center.dy)
      ..close();

    final pSouth = Path()
      ..moveTo(center.dx, center.dy + 68)
      ..lineTo(center.dx + 5, center.dy)
      ..lineTo(center.dx - 6, center.dy)
      ..close();

    canvas.drawPath(pNorth, Paint()..color = northColor..style = PaintingStyle.fill);
    canvas.drawPath(pSouth, Paint()..color = southColor..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
