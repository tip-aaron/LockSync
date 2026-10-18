import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/system_check_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const LockSyncApp());
}

class LockSyncApp extends StatelessWidget {
  const LockSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF040608),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          surface: Color(0xFF080C10),
        ),
      ),
      home: const MobileLandingScreen(),
    );
  }
}

class MobileLandingScreen extends StatefulWidget {
  const MobileLandingScreen({super.key});

  @override
  State<MobileLandingScreen> createState() => _MobileLandingScreenState();
}

class _MobileLandingScreenState extends State<MobileLandingScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _isError = false;
  bool _isSuccess = false;
  String? _statusMessage;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final TextEditingController _hiddenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _hiddenController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isSuccess || _isError) return;
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
      });
      _hiddenController.text = _enteredPin;
      if (_enteredPin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_isSuccess || _isError) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _statusMessage = null;
      });
      _hiddenController.text = _enteredPin;
    }
  }

  void _onClearPressed() {
    if (_isSuccess || _isError) return;
    setState(() {
      _enteredPin = '';
      _statusMessage = null;
    });
    _hiddenController.clear();
  }

  Future<void> _verifyPin() async {
    final isValid = AuthService.instance.verifyPin(_enteredPin);
    if (isValid) {
      setState(() {
        _isSuccess = true;
        _isError = false;
        _statusMessage = 'ACCESS GRANTED';
      });

      await Future.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, _, _) => const SystemCheckScreen(),
          transitionsBuilder: (context, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      setState(() {
        _isError = true;
        _statusMessage = 'INCORRECT PASSWORD';
      });

      _shakeController.forward(from: 0.0);

      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        setState(() {
          _enteredPin = '';
          _isError = false;
          _statusMessage = null;
        });
        _hiddenController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C10),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),

                  // 1. Brand Wordmark & Tagline
                  const BrandWordmark(),
                  const SizedBox(height: 6),
                  const Text(
                    'Your lock, redefined.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: Color(0xFF7A889B),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Technical Lock Visual
                  const SmartLockGraphic(size: 130),

                  const SizedBox(height: 20),

                  // 3. ENTER PASSWORD Title & Status Text
                  const Text(
                    'ENTER PASSWORD',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: Color(0xFFF1F5F9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusMessage ?? 'Enter 6-digit master passcode',
                    style: TextStyle(
                      fontFamily: _isError || _isSuccess ? 'JetBrains Mono' : 'Inter',
                      fontSize: 12,
                      fontWeight: _isError || _isSuccess ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: _isError || _isSuccess ? 1.0 : 0.0,
                      color: _isError
                          ? const Color(0xFFFF5252)
                          : _isSuccess
                              ? const Color(0xFF00E676)
                              : const Color(0xFF7A889B),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. 6-Digit PIN Indicators
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final offset = _isError
                          ? math.sin(_shakeAnimation.value * math.pi * 4) * 8
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            final isFilled = index < _enteredPin.length;
                            Color dotColor;
                            Color borderColor;
                            List<BoxShadow> shadows = [];

                            if (_isError) {
                              dotColor = const Color(0xFFFF5252);
                              borderColor = const Color(0xFFFF5252);
                              shadows = [
                                const BoxShadow(
                                  color: Color(0x66FF5252),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ];
                            } else if (_isSuccess) {
                              dotColor = const Color(0xFF00E676);
                              borderColor = const Color(0xFF00E676);
                              shadows = [
                                const BoxShadow(
                                  color: Color(0x6600E676),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ];
                            } else if (isFilled) {
                              dotColor = const Color(0xFF00D4FF);
                              borderColor = const Color(0xFF00D4FF);
                              shadows = [
                                const BoxShadow(
                                  color: Color(0x6600D4FF),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ];
                            } else {
                              dotColor = const Color(0xFF0C131D);
                              borderColor = const Color(0xFF1E2E42);
                            }

                            return Container(
                              key: Key('pin_dot_$index'),
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                                border: Border.all(color: borderColor, width: 1.5),
                                boxShadow: shadows,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 5. Numeric Keypad 0 to 9
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      children: [
                        _buildKeypadRow(['1', '2', '3']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['4', '5', '6']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['7', '8', '9']),
                        const SizedBox(height: 10),
                        _buildKeypadBottomRow(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 6. Subtext / Hint
                  const Text(
                    'DEFAULT PASSCODE: 123456',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: Color(0xFF4A5C70),
                    ),
                  ),

                  // Hidden input field for physical keyboard typing and programmatic test inputs
                  Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: TextField(
                        key: const Key('pin_hidden_input'),
                        controller: _hiddenController,
                        autofocus: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _enteredPin = val;
                          });
                          if (val.length == 6) {
                            _verifyPin();
                          }
                        },
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

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _buildKeypadButton(
              key: Key('pin_key_$digit'),
              label: digit,
              onTap: () => _onDigitPressed(digit),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Clear Button (C)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _buildKeypadButton(
              key: const Key('pin_key_clear'),
              label: 'C',
              isAction: true,
              onTap: _onClearPressed,
            ),
          ),
        ),
        // 0 Button
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _buildKeypadButton(
              key: const Key('pin_key_0'),
              label: '0',
              onTap: () => _onDigitPressed('0'),
            ),
          ),
        ),
        // Backspace Button (⌫)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _buildKeypadButton(
              key: const Key('pin_key_backspace'),
              icon: Icons.backspace_outlined,
              isAction: true,
              onTap: _onBackspacePressed,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton({
    required Key key,
    String? label,
    IconData? icon,
    bool isAction = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFF00D4FF).withValues(alpha: 0.2),
        highlightColor: const Color(0xFF00D4FF).withValues(alpha: 0.08),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isAction ? const Color(0xFF0B111A) : const Color(0xFF0D141F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAction ? const Color(0xFF14202F) : const Color(0xFF182638),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF7A889B),
                )
              : Text(
                  label!,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: isAction ? 14 : 20,
                    fontWeight: isAction ? FontWeight.w700 : FontWeight.w600,
                    color: isAction ? const Color(0xFF7A889B) : const Color(0xFFF1F5F9),
                  ),
                ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. BRAND WORDMARK
// ==========================================
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: 3.2,
        ),
        children: [
          TextSpan(
            text: 'LOCK',
            style: TextStyle(
              color: Color(0xFFF1F5F9), // Near-white
            ),
          ),
          TextSpan(
            text: 'SYNC',
            style: TextStyle(
              color: Color(0xFF00D4FF), // Vivid Cyan
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. SMART LOCK VISUAL & ARDUINO CIRCUITRY
// ==========================================
class SmartLockGraphic extends StatelessWidget {
  final double size;
  const SmartLockGraphic({super.key, this.size = 130});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 210,
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Faint cyan ambient glow around lock
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                      blurRadius: 52,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),

              // Custom Painted Technical Lock & Circuit Details
              CustomPaint(
                size: const Size(210, 210),
                painter: ArduinoLockPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArduinoLockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Outer Circuit Track Ring (Subtle PCB boundary)
    final outerRingPaint = Paint()
      ..color = const Color(0xFF142433)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, 94, outerRingPaint);

    // 2. Arduino Circuit Traces & PCB Vias (Understated details)
    final circuitTracePaint = Paint()
      ..color = const Color(0xFF162B3D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    void drawTrace(List<Offset> points) {
      if (points.isEmpty) return;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, circuitTracePaint);
    }

    void drawVia(Offset pt) {
      final viaPaint = Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 1.8, viaPaint);
    }

    // Top-Left Trace
    drawTrace([
      Offset(center.dx - 82, center.dy - 35),
      Offset(center.dx - 60, center.dy - 35),
      Offset(center.dx - 45, center.dy - 50),
    ]);
    drawVia(Offset(center.dx - 82, center.dy - 35));

    // Bottom-Left Trace
    drawTrace([
      Offset(center.dx - 75, center.dy + 42),
      Offset(center.dx - 50, center.dy + 42),
      Offset(center.dx - 35, center.dy + 58),
    ]);
    drawVia(Offset(center.dx - 75, center.dy + 42));

    // Top-Right Trace
    drawTrace([
      Offset(center.dx + 80, center.dy - 40),
      Offset(center.dx + 55, center.dy - 40),
      Offset(center.dx + 40, center.dy - 55),
    ]);
    drawVia(Offset(center.dx + 80, center.dy - 40));

    // Bottom-Right Trace
    drawTrace([
      Offset(center.dx + 70, center.dy + 48),
      Offset(center.dx + 48, center.dy + 48),
      Offset(center.dx + 38, center.dy + 58),
    ]);
    drawVia(Offset(center.dx + 70, center.dy + 48));

    // Horizontal Data Buses (Left & Right)
    drawTrace([
      Offset(center.dx - 92, center.dy),
      Offset(center.dx - 74, center.dy),
    ]);
    drawVia(Offset(center.dx - 92, center.dy));

    drawTrace([
      Offset(center.dx + 98, center.dy + 10),
      Offset(center.dx + 76, center.dy + 10),
    ]);
    drawVia(Offset(center.dx + 98, center.dy + 10));

    // Micro Pin Indicators (4 Cardinal points around outer circumference)
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final r1 = 89.0;
      final r2 = 94.0;
      final p1 = Offset(center.dx + r1 * math.cos(angle), center.dy + r1 * math.sin(angle));
      final p2 = Offset(center.dx + r2 * math.cos(angle), center.dy + r2 * math.sin(angle));
      canvas.drawLine(p1, p2, circuitTracePaint);
    }

    // 3. Primary Cyan Illuminated Ring
    // Outer subtle glow stroke
    final ringGlowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2;
    canvas.drawCircle(center, 74, ringGlowPaint);

    // Crisp high-contrast cyan ring
    final illuminatedRingPaint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, 74, illuminatedRingPaint);

    // Inner hairline concentric ring
    final innerHairline = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, 63, innerHairline);

    // 4. Central Refined Smart-Lock Icon
    // Shackle (Top U-shape)
    final shacklePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final shacklePath = Path()
      ..moveTo(center.dx - 13, center.dy - 9)
      ..lineTo(center.dx - 13, center.dy - 23)
      ..arcToPoint(
        Offset(center.dx + 13, center.dy - 23),
        radius: const Radius.circular(13),
      )
      ..lineTo(center.dx + 13, center.dy - 9);
    canvas.drawPath(shacklePath, shacklePaint);

    // Lock Body (Geometric technical enclosure)
    final bodyPaint = Paint()
      ..color = const Color(0xFF0D1622)
      ..style = PaintingStyle.fill;

    final bodyBorderPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 8),
        width: 44,
        height: 34,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, bodyBorderPaint);

    // Center Core / Keyhole & Status Aperture
    final coreDotPaint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy + 6), 3.2, coreDotPaint);

    final keywayPaint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy + 7),
      Offset(center.dx, center.dy + 14),
      keywayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
