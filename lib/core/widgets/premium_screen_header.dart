import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared mint/aqua premium header (same as home screen).
abstract final class PremiumHeaderColors {
  static const gradStart = Color(0xFF9333EA);
  // static const gradMid = Color(0xFFBE185D);
  static const gradEnd = Color(0xFFDB2777);
}

class PremiumScreenHeader extends StatefulWidget {
  /// Content height below the status bar (not including safe-area top).
  final double bodyHeight;
  final Widget child;

  const PremiumScreenHeader({
    super.key,
    required this.bodyHeight,
    required this.child,
  });

  @override
  State<PremiumScreenHeader> createState() => _PremiumScreenHeaderState();
}

class _PremiumScreenHeaderState extends State<PremiumScreenHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _driftCtrl;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: top + widget.bodyHeight,
      child: AnimatedBuilder(
        animation: _driftCtrl,
        builder: (context, _) {
          final t = _driftCtrl.value * 2 * math.pi;
          return ClipPath(
            clipper: _PremiumHeaderClipper(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PremiumHeaderColors.gradStart,
                        // PremiumHeaderColors.gradMid,
                        PremiumHeaderColors.gradEnd,
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: top + 8 + math.sin(t) * 10,
                  right: -24,
                  child: _PremiumHeaderOrb(
                    size: 128,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                Positioned(
                  top: top + 48 + math.cos(t) * 6,
                  right: 48,
                  child: _PremiumHeaderOrb(
                    size: 36,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                Positioned(
                  bottom: 32,
                  left: -32 + math.cos(t) * 10,
                  child: _PremiumHeaderOrb(
                    size: 92,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PremiumHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PremiumHeaderOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _PremiumHeaderOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class PremiumHeaderIconBox extends StatelessWidget {
  final Widget child;

  const PremiumHeaderIconBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE0F2FE)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 2,
        ),
      ),
      child: Center(child: child),
    );
  }
}

class PremiumHeaderBadge extends StatelessWidget {
  final String text;

  const PremiumHeaderBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

class PremiumHeaderTitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const PremiumHeaderTitle({
    super.key,
    required this.text,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Color(0xFFECFDF5)],
      ).createShader(bounds),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class PremiumHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const PremiumHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDestructive
                  ? [
                      const Color(0xFFFECACA).withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.12),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0.1),
                    ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isDestructive ? 21 : 20,
          ),
        ),
      ),
    );
  }
}

class PremiumHeaderInfoPanel extends StatelessWidget {
  final Widget child;

  const PremiumHeaderInfoPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: child,
    );
  }
}

class PremiumHeaderInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const PremiumHeaderInfoChip({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
