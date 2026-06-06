import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:school_driver_app/features/tracking/gps_disabled_dialog.dart';
import '../../core/controllers/gps_controller.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/controllers/locale_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/premium_dialog.dart';

// ── UI Palette matching the premium visual aesthetic ────────
abstract final class _HomeUi {
  static const canvas = Color(0xFFF1F5F9);
  static const deep = Color(0xFF9333EA);
  static const mid = Color(0xFF9333EA);
  static const teal = Color(0xFFDB2777);
  static const ink = Color(0xFF1E293B);
  static const inkMuted = Color(0xFF64748B);
  static const coral = Color(0xFFF97316);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'good_morning';
    if (h < 17) return 'good_afternoon';
    return 'good_evening';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = Get.find<AuthController>().user.value;
      final name = (user?['name'] as String? ?? 'driver'.tr()).split(' ').first;

      return Scaffold(
        backgroundColor: _HomeUi.canvas,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                _HomeHeader(
                  greeting: _greeting().tr(),
                  name: name,
                  user: user,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _StatusCard(),
                        const SizedBox(height: 20),
                        _LabelRow(title: 'quick_actions'.tr()),
                        const SizedBox(height: 12),
                        _ActionCard(
                          icon: Icons.groups_rounded,
                          label: 'my_students'.tr(),
                          subtitle: 'students_on_route'.tr(),
                          onTap: () => context.push(
                            '${AppRoutes.students}?route_id=2',
                          ),
                        ),
                        const SizedBox(height: 24),
                        _TipsCard(
                          key: ValueKey(context.locale.languageCode),
                        ),
                        const SizedBox(height: 24),
                        // Bottom Action Buttons
                        _BottomActionButtons(
                          onLangPicker: () => _showLangPicker(context),
                          onLogout: () => _confirmLogout(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }); // end Obx
  }

  void _showLangPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'select_language'.tr(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _HomeUi.ink,
                  ),
                ),
                const SizedBox(height: 16),
                for (final lang in [
                  ('en', '🇬🇧', 'English'),
                  ('hi', '🇮🇳', 'हिन्दी'),
                  ('gu', '🇮🇳', 'ગુજરાતી'),
                ]) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: ctx.locale.languageCode == lang.$1
                          ? _HomeUi.teal.withValues(alpha: 0.08)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () async {
                          await changeAppLocale(
                            ctx,
                            Locale(lang.$1),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Text(lang.$2,
                                  style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  lang.$3,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight:
                                        ctx.locale.languageCode == lang.$1
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    fontSize: 15,
                                    color: ctx.locale.languageCode == lang.$1
                                        ? _HomeUi.teal
                                        : _HomeUi.ink,
                                  ),
                                ),
                              ),
                              if (ctx.locale.languageCode == lang.$1)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: _HomeUi.teal,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showPremiumTwoButtonDialog(
      context: context,
      icon: Icons.logout_rounded,
      iconColor: AppTheme.danger,
      title: 'confirm_logout'.tr(),
      message: 'confirm_logout_msg'.tr(),
      cancelLabel: 'cancel'.tr(),
      confirmLabel: 'logout'.tr(),
      confirmColor: AppTheme.danger,
      onCancel: () => Navigator.pop(context),
      onConfirm: () {
        Navigator.pop(context);
        Get.find<AuthController>().logout();
      },
    );
  }
}

// ── Header Component (without language and logout buttons) ──
class _HomeHeader extends StatefulWidget {
  final String greeting;
  final String name;
  final Map<String, dynamic>? user;

  const _HomeHeader({
    required this.greeting,
    required this.name,
    required this.user,
  });

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader>
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
    final hasContactInfo =
        (widget.user?['email'] as String? ?? '').isNotEmpty ||
            widget.user?['phone'] != null;
    final initial = widget.name.isNotEmpty
        ? widget.name.characters.first.toUpperCase()
        : 'D';

    return SizedBox(
      height: top + (hasContactInfo ? 160 : 130),
      child: AnimatedBuilder(
        animation: _driftCtrl,
        builder: (context, _) {
          final t = _driftCtrl.value * 2 * math.pi;
          return ClipRRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_HomeUi.deep, _HomeUi.teal],
                    ),
                  ),
                ),
                Positioned(
                  top: top + 20 + math.sin(t) * 10,
                  right: -30,
                  child: const _HomeOrb(
                    size: 110,
                    color: Color.fromARGB(20, 255, 255, 255),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: -40 + math.cos(t) * 12,
                  child: const _HomeOrb(
                    size: 80,
                    color: Color.fromARGB(30, 255, 255, 255),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      widget.greeting,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [Colors.white, Color(0xFFFCE7F3)],
                                    ).createShader(bounds),
                                    child: Text(
                                      widget.name,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    context.push(AppRoutes.notifications),
                                borderRadius: BorderRadius.circular(40),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.3),
                                        Colors.white.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.45),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.notifications_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (hasContactInfo) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  if ((widget.user?['email'] as String? ?? '')
                                      .isNotEmpty)
                                    _HomeInfoChip(
                                      icon: Icons.mail_outline_rounded,
                                      text: widget.user!['email'] as String,
                                    ),
                                  if (widget.user?['phone'] != null) ...[
                                    const SizedBox(width: 8),
                                    _HomeInfoChip(
                                      icon: Icons.call_outlined,
                                      text: widget.user!['phone'] as String,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

// ── Bottom Action Buttons Component ──
class _BottomActionButtons extends StatelessWidget {
  final VoidCallback onLangPicker;
  final VoidCallback onLogout;

  const _BottomActionButtons({
    required this.onLangPicker,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BottomActionButton(
            icon: Icons.translate_rounded,
            label: 'select_language'.tr(),
            onTap: onLangPicker,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9333EA), Color(0xFFDB2777)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BottomActionButton(
            icon: Icons.power_settings_new_rounded,
            label: 'logout'.tr(),
            onTap: onLogout,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9333EA), Color(0xFFDB2777)],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Gradient gradient;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _HomeOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _HomeInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HomeInfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── GPS Tracking status card with location icon and button in same line ──
class _StatusCard extends StatefulWidget {
  const _StatusCard();

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  bool _busy = false;

  Future<void> _startTracking() async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await Get.find<GpsController>().start(routeId: 2);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) _handleError(err);
  }

  Future<void> _stopTracking() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Get.find<GpsController>().stop();
    if (mounted) setState(() => _busy = false);
  }

  void _handleError(String errKey) {
    if (errKey == 'gps_disabled') {
      showGpsDisabledDialog(context);
      return;
    }
    if (errKey == 'location_permission_title') {
      showPremiumTwoButtonDialog(
        context: context,
        icon: Icons.location_disabled_rounded,
        iconColor: AppTheme.primary,
        title: 'location_permission_title'.tr(),
        message: 'location_permission_desc'.tr(),
        cancelLabel: 'cancel'.tr(),
        confirmLabel: 'open_settings'.tr(),
        confirmColor: AppTheme.primary,
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          openAppSettings();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final gpsController = Get.find<GpsController>();
      final isTracking = gpsController.isTracking.value;
      final speed = gpsController.speed.value;

      final accent = isTracking ? const Color(0xFF10B981) : _HomeUi.teal;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isTracking
                ? [
                    const Color(0xFFF0FDF9),
                    const Color(0xFFECFDF5),
                    Colors.white,
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF8FAFC),
                    const Color(0xFFF1F5F9),
                  ],
          ),
          border: Border.all(
            color: isTracking
                ? const Color(0xFF6EE7B7).withValues(alpha: 0.55)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isTracking ? 0.14 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned(
                top: -36,
                right: -28,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: isTracking ? 0.18 : 0.1),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Icon and Button in same row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Location Icon
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(52),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isTracking
                                  ? [
                                      const Color(0xFF34D399),
                                      const Color(0xFF10B981),
                                    ]
                                  : [
                                      _HomeUi.mid,
                                      _HomeUi.teal,
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            isTracking
                                ? Icons.gps_fixed_rounded
                                : Icons.location_searching_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),

                        // Tracking Status Text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isTracking
                                        ? const Color(0xFFD1FAE5)
                                            .withValues(alpha: 0.9)
                                        : const Color(0xFFE2E8F0)
                                            .withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isTracking
                                          ? const Color(0xFF6EE7B7)
                                              .withValues(alpha: 0.5)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isTracking) ...[
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF10B981),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        'tracking_status'.tr().toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                          color: isTracking
                                              ? const Color(0xFF047857)
                                              : _HomeUi.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isTracking
                                      ? 'tracking_active'.tr()
                                      : 'tracking_stopped'.tr(),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: isTracking
                                        ? const Color(0xFF064E3B)
                                        : _HomeUi.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Play/Stop Button
                        if (_busy)
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: accent,
                            ),
                          )
                        else
                          _TrackCircleButton(
                            isTracking: isTracking,
                            onTap: isTracking ? _stopTracking : _startTracking,
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0),
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Speed Section (only when tracking)
                    if (isTracking)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                const Color(0xFFA7F3D0).withValues(alpha: 0.8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _HomeUi.teal.withValues(alpha: 0.15),
                                    _HomeUi.teal.withValues(alpha: 0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: _HomeUi.teal.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.speed_rounded,
                                size: 24,
                                color: _HomeUi.teal,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'speed'.tr(),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _HomeUi.inkMuted,
                                    ),
                                  ),
                                  Text(
                                    'kmh'.tr(),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _HomeUi.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: speed),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Text(
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: _HomeUi.ink,
                                    height: 1,
                                    letterSpacing: -0.5,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: _HomeUi.teal.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'start_desc'.tr(),
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: _HomeUi.inkMuted,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }); // end Obx
  }
}

// ── Stateful pulsing play/stop tracker circle button ──
class _TrackCircleButton extends StatefulWidget {
  final bool isTracking;
  final VoidCallback onTap;

  const _TrackCircleButton({
    required this.isTracking,
    required this.onTap,
  });

  @override
  State<_TrackCircleButton> createState() => _TrackCircleButtonState();
}

class _TrackCircleButtonState extends State<_TrackCircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isTracking) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _TrackCircleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTracking && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isTracking && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.isTracking ? const Color(0xFFEF4444) : _HomeUi.teal;
    final icon =
        widget.isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glowScale = 1.0 + _pulseCtrl.value * 0.15;
        final glowOpacity = 0.25 - _pulseCtrl.value * 0.15;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isTracking)
              Container(
                width: 52 * glowScale,
                height: 52 * glowScale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor.withValues(alpha: glowOpacity),
                ),
              ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: baseColor.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.isTracking
                            ? [
                                const Color(0xFFFCA5A5),
                                const Color(0xFFEF4444),
                                const Color(0xFFDC2626),
                              ]
                            : [
                                _HomeUi.mid,
                                _HomeUi.teal,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: baseColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          blurRadius: 0,
                          offset: const Offset(-2, -2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Full width action card ──
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _HomeUi.mid.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _HomeUi.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _HomeUi.coral.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: _HomeUi.coral, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _HomeUi.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _HomeUi.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _HomeUi.inkMuted,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tips card ──
class _TipsCard extends StatelessWidget {
  const _TipsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFED7AA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _HomeUi.coral.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: _HomeUi.coral,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'gps_tracking_tip_title'.tr(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'gps_tracking_tip_desc'.tr(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFFC2410C),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String title;
  const _LabelRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _HomeUi.teal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            color: _HomeUi.ink,
          ),
        ),
      ],
    );
  }
}
