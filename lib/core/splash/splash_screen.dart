import 'dart:math' as math;

import 'package:flutter/material.dart';


/// Splash UI palette — animations only; navigation stays in router.
abstract final class _SplashUi {
  static const deep = Color(0xFF3B0764);
  static const mid = Color(0xFF9333EA);
  static const accent = Color(0xFFDB2777);
  static const teal = Color(0xFFDB2777);
  static const glow = Color(0xFFA855F7);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late AnimationController _shimmerCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _titleSlideAnim;
  late Animation<double> _footerFadeAnim;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _fadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _titleSlideAnim = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _footerFadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
    );

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Router handles navigation after auth init — splash is visual only.
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AnimatedBackdrop(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                _PremiumLogo(
                  entry: _entryCtrl,
                  pulse: _pulseCtrl,
                  orbit: _orbitCtrl,
                  shimmer: _shimmerCtrl,
                  fadeAnim: _fadeAnim,
                  scaleAnim: _scaleAnim,
                ),
                const SizedBox(height: 32),
                _TitleBlock(
                  fadeAnim: _fadeAnim,
                  slideAnim: _titleSlideAnim,
                ),
                const Spacer(flex: 2),
                FadeTransition(
                  opacity: _footerFadeAnim,
                  child: const _LoadingBlock(),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _footerFadeAnim,
                  child: Text(
                    'v1.0.0  ·  Powered by SchoolMS',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated background ───────────────────────────────────────
class _Particle {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double angle;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.angle,
    required this.opacity,
  });
}

class _ParticleFieldPainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;

  _ParticleFieldPainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final dx = math.cos(p.angle) * p.speed * animationValue * 120;
      final dy = math.sin(p.angle) * p.speed * animationValue * 120;

      final px = (p.x + dx) % size.width;
      final py = (p.y + dy) % size.height;

      final currentOpacity = p.opacity *
          (0.4 + 0.6 * math.sin(animationValue * 2 * math.pi + p.x));
      paint.color =
          Colors.white.withValues(alpha: currentOpacity.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) => true;
}

class _AnimatedBackdrop extends StatefulWidget {
  const _AnimatedBackdrop();

  @override
  State<_AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<_AnimatedBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _driftCtrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    final random = math.Random();
    _particles = List.generate(28, (index) {
      return _Particle(
        x: random.nextDouble() * 500,
        y: random.nextDouble() * 1000,
        speed: 0.12 + random.nextDouble() * 0.38,
        size: 1.2 + random.nextDouble() * 2.2,
        angle: random.nextDouble() * 2 * math.pi,
        opacity: 0.12 + random.nextDouble() * 0.48,
      );
    });
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _driftCtrl,
      builder: (context, _) {
        final t = _driftCtrl.value * 2 * math.pi;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _SplashUi.deep,
                _SplashUi.mid,
                Color(0xFFBE185D),
                _SplashUi.accent,
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80 + math.sin(t) * 22,
                right: -60 + math.cos(t) * 16,
                child: _GlowOrb(
                  size: 240,
                  color: _SplashUi.glow.withValues(alpha: 0.24),
                ),
              ),
              Positioned(
                bottom: 120 + math.cos(t * 0.8) * 24,
                left: -90 + math.sin(t * 0.7) * 20,
                child: _GlowOrb(
                  size: 300,
                  color: _SplashUi.teal.withValues(alpha: 0.2),
                ),
              ),
              Positioned(
                top: MediaQuery.sizeOf(context).height * 0.32,
                left: MediaQuery.sizeOf(context).width * 0.5 - 100,
                child: _GlowOrb(
                  size: 180,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticleFieldPainter(_particles, _driftCtrl.value),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Logo with orbit ring + pulse ──────────────────────────────
class _PremiumLogo extends StatelessWidget {
  final AnimationController entry;
  final AnimationController pulse;
  final AnimationController orbit;
  final AnimationController shimmer;
  final Animation<double> fadeAnim;
  final Animation<double> scaleAnim;

  const _PremiumLogo({
    required this.entry,
    required this.pulse,
    required this.orbit,
    required this.shimmer,
    required this.fadeAnim,
    required this.scaleAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([entry, pulse, orbit, shimmer]),
      builder: (context, child) {
        final pulseScale = 1.0 + (pulse.value * 0.04);
        final glowOpacity = 0.35 + (pulse.value * 0.25);
        final floatOffset =
            pulse.value * 4.5; // Gently floats up/down by 4.5 pixels
        final entryTilt =
            (1.0 - fadeAnim.value) * -0.25; // Gentle tilt rotation on entrance

        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: Transform.rotate(
              angle: entryTilt,
              child: Transform.scale(
                scale: pulseScale,
                child: SizedBox(
                  width: 170,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (int i = 0; i < 2; i++)
                        Builder(
                          builder: (context) {
                            final progress = (pulse.value + (i * 0.5)) % 1.0;
                            final size = 118 + (progress * 70);
                            final opacity = (1.0 - progress) * 0.28;
                            return Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      _SplashUi.teal.withValues(alpha: opacity),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                      Transform.rotate(
                        angle: orbit.value * 2 * math.pi,
                        child: Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.02),
                                Colors.white.withValues(alpha: 0.55),
                                _SplashUi.teal.withValues(alpha: 0.8),
                                Colors.white.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _SplashUi.glow.withValues(alpha: glowOpacity),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.2,
                          ),
                        ),
                      ),
                      Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.06),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: ClipOval(
                                child: Transform.translate(
                                  offset: Offset(
                                    -120 + shimmer.value * 280,
                                    0,
                                  ),
                                  child: Container(
                                    width: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Drop shadow for bus icon
                            Transform.translate(
                              offset: Offset(1, 3 - floatOffset),
                              child: Icon(
                                Icons.directions_bus_rounded,
                                size: 60,
                                color: Colors.black.withValues(alpha: 0.16),
                              ),
                            ),
                            // High-end glowing bus icon
                            Transform.translate(
                              offset: Offset(0, -floatOffset),
                              child: const Icon(
                                Icons.directions_bus_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final Animation<double> fadeAnim;
  final Animation<double> slideAnim;

  const _TitleBlock({
    required this.fadeAnim,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([fadeAnim, slideAnim]),
      builder: (context, child) => FadeTransition(
        opacity: fadeAnim,
        child: Transform.translate(
          offset: Offset(0, slideAnim.value),
          child: child,
        ),
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFFCE7F3)],
            ).createShader(bounds),
            child: const Text(
              'School Driver',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.0,
                height: 1.1,
                shadows: [
                  Shadow(
                    color: Color(0x2E000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              'GPS Tracking & Route Management',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Premium loading tracker path ──────────────────────────────
class _LoadingBlock extends StatefulWidget {
  const _LoadingBlock();

  @override
  State<_LoadingBlock> createState() => _LoadingBlockState();
}

class _LoadingBlockState extends State<_LoadingBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _busCtrl;

  @override
  void initState() {
    super.initState();
    _busCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _busCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 30,
          child: AnimatedBuilder(
            animation: _busCtrl,
            builder: (context, _) {
              final value = _busCtrl.value;
              double opacity = 1.0;
              if (value < 0.15) {
                opacity = value / 0.15;
              } else if (value > 0.85) {
                opacity = (1.0 - value) / 0.15;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 1.5,
                    width: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.02),
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    child: SizedBox(
                      width: 180,
                      height: 4,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 180 * (1.0 - value),
                            child: Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    _SplashUi.teal.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      return Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      );
                    }),
                  ),
                  Positioned(
                    left: 10 + (value * 180),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: _SplashUi.teal.withValues(alpha: 0.8),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFFCE7F3)],
          ).createShader(bounds),
          child: Text(
            'Initializing Secure Session...',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
