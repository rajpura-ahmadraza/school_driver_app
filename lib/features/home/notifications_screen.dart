import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

abstract final class _NotificationsUi {
  static const canvas = Color(0xFFF1F5F9);
  static const deep = Color(0xFF9333EA);
  static const teal = Color(0xFFDB2777);
  static const ink = Color(0xFF1E293B);
  static const inkMuted = Color(0xFF64748B);
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _driftCtrl;

  final List<Map<String, dynamic>> _mockNotifications = [
    {
      'title': 'Tracking Started',
      'body': 'Your route is now being tracked. Have a safe drive!',
      'time': 'Just now',
      'icon': Icons.gps_fixed_rounded,
      'color': const Color(0xFF10B981),
    },
    {
      'title': 'Attendance Saved',
      'body': 'Student attendance for Route 2 has been synchronized successfully.',
      'time': '1 hour ago',
      'icon': Icons.check_circle_rounded,
      'color': const Color(0xFF9333EA),
    },
    {
      'title': 'System Update',
      'body': 'Weekly driver checklist is updated. Please review before starting.',
      'time': 'Yesterday',
      'icon': Icons.announcement_rounded,
      'color': const Color(0xFFF97316),
    },
  ];

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

    return Scaffold(
      backgroundColor: _NotificationsUi.canvas,
      body: Column(
        children: [
          // Premium Custom Header
          SizedBox(
            height: top + 80,
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
                            colors: [
                              _NotificationsUi.deep,
                              _NotificationsUi.teal,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: top - 10 + math.sin(t) * 8,
                        right: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromARGB(20, 255, 255, 255),
                          ),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // Circular Back Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.maybePop(context),
                                  borderRadius: BorderRadius.circular(40),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(40),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [Colors.white, Color(0xFFFCE7F3)],
                                    ).createShader(bounds),
                                    child: Text(
                                      'notifications'.tr(),
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Spacing match for back button alignment
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              itemCount: _mockNotifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final notif = _mockNotifications[i];
                final color = notif['color'] as Color;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Localized/Themed icon container
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            notif['icon'] as IconData,
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    (notif['title'] as String).tr(),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: _NotificationsUi.ink,
                                    ),
                                  ),
                                  Text(
                                    notif['time'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _NotificationsUi.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (notif['body'] as String).tr(),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: _NotificationsUi.inkMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
