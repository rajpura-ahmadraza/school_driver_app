import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/premium_dialog.dart';
import 'gps_disabled_dialog.dart';
import '../../core/controllers/gps_controller.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  // Pulse animation for active tracking button
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Ripple animation for active tracking
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _rippleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleTracking() async {
    final gps = Get.find<GpsController>();
    final isTracking = gps.isTracking.value;

    if (isTracking) {
      // Stop
      await gps.stop();
      _pulseCtrl.stop();
      _rippleCtrl.stop();
    } else {
      // Start
      final err = await gps.start(routeId: 2);
      if (err == null) {
        _pulseCtrl.repeat(reverse: true);
        _rippleCtrl.repeat();
      } else if (mounted) {
        _handleError(err);
      }
    }
  }

  void _handleError(String errKey) {
    if (errKey == 'no_internet') {
      showPremiumOneButtonDialog(
        context: context,
        icon: Icons.wifi_off_rounded,
        iconColor: AppTheme.danger,
        title: 'disconnected'.tr(),
        message: 'no_internet'.tr(),
        buttonLabel: 'confirm'.tr(),
        buttonColor: AppTheme.primary,
        onPressed: () => Navigator.pop(context),
      );
      return;
    }
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final gpsController = Get.find<GpsController>();
      final isTracking = gpsController.isTracking.value;
      final speed = gpsController.speed.value;
      final lastSent = gpsController.lastSentAt.value;

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('my_route'.tr()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            // ── Status banner ────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isTracking
                    ? const Color(0xFF16A34A) // green-600
                    : const Color(0xFFF1F5F9), // slate-100
                boxShadow: isTracking
                    ? [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Pulsing dot
                  if (isTracking)
                    AnimatedBuilder(
                      animation: _rippleAnim,
                      builder: (_, child) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 16 + (_rippleAnim.value * 12),
                            height: 16 + (_rippleAnim.value * 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withValues(alpha: (1 - _rippleAnim.value) * 0.4),
                            ),
                          ),
                          child!,
                        ],
                      ),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTracking
                          ? 'tracking_active'.tr()
                          : 'tracking_stopped'.tr(),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isTracking ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (isTracking && speed > 0)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: speed),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Row(
                          children: [
                            Icon(Icons.speed_rounded,
                                color: Colors.white.withValues(alpha: 0.85),
                                size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${value.toStringAsFixed(1)} ${'kmh'.tr()}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),

            // ── Main content ─────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Big tracking button ─────────────────────
                    GestureDetector(
                      onTap: _toggleTracking,
                      child: isTracking
                          ? ScaleTransition(
                              scale: _pulseAnim,
                              child:
                                  _TrackingButton(isTracking: true, speed: speed),
                            )
                          : _TrackingButton(isTracking: false, speed: speed),
                    ),

                    const SizedBox(height: 32),

                    // ── Status description ──────────────────────
                    Text(
                      isTracking ? 'tracking_desc'.tr() : 'start_desc'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Interval info ───────────────────────────
                    if (isTracking) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.update_rounded,
                                color: AppTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'update_interval'.tr(),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Last sent timestamp
                      if (lastSent != null)
                        Text(
                          '${'last_updated'.tr()}: ${_formatTime(lastSent)}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // ── GPS coordinates display ───────────────────────
            if (isTracking && gpsController.latitude.value != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_rounded,
                        color: Colors.grey.shade400, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${gpsController.latitude.value!.toStringAsFixed(6)}, '
                      '${gpsController.longitude.value!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }); // end Obx
  }
}

// ── Tracking button widget ────────────────────────────────────
class _TrackingButton extends StatelessWidget {
  final bool isTracking;
  final double speed;
  const _TrackingButton({required this.isTracking, required this.speed});

  @override
  Widget build(BuildContext context) {
    final color = isTracking ? AppTheme.danger : AppTheme.secondary;

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.9),
            color,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 8),
          Text(
            isTracking ? 'stop_tracking'.tr() : 'start_tracking'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (isTracking && speed > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${speed.toStringAsFixed(1)} km/h',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
