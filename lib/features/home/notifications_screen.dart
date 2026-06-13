import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import './notification_service.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'homework', 'leave', 'announcement', 'timetable'
  final DateTime timestamp;
  final RxBool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    required bool isRead,
    this.data,
  }) : isRead = isRead.obs;

  factory NotificationModel.fromJson(
      Map<String, dynamic> json, String defaultId) {
    final dataMap = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final type = dataMap['type'] ?? json['type'] ?? 'announcement';
    return NotificationModel(
      id: json['id']?.toString() ?? defaultId,
      title: json['title'] ?? 'No Title',
      body: json['body'] ?? 'No Body',
      type: type.toString().toLowerCase(),
      timestamp: DateTime.tryParse(json['received_at'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
      data: dataMap,
    );
  }
}

class NotificationsController extends GetxController {
  final RxList<NotificationModel> allNotifications = <NotificationModel>[].obs;
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  int _page = 1;
  final NotificationService _service = NotificationService.instance;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();

    // Listen to real-time incoming foreground notifications
    _service.newNotificationStream.listen((n) {
      final newModel = NotificationModel.fromJson(
          n, DateTime.now().millisecondsSinceEpoch.toString());
      allNotifications.insert(0, newModel);
      notifications.insert(0, newModel);
    });
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      final saved = await _service.getSavedNotifications();
      allNotifications.value = saved.asMap().entries.map((entry) {
        return NotificationModel.fromJson(entry.value, entry.key.toString());
      }).toList();
      _page = 1;
      notifications.value = allNotifications.take(15).toList();
      hasMore.value = notifications.length < allNotifications.length;
    } catch (_) {
      allNotifications.value = [];
      _page = 1;
      notifications.value = [];
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  void loadMore() {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    final start = _page * 15;
    final nextItems = allNotifications.skip(start).take(15).toList();
    if (nextItems.isNotEmpty) {
      notifications.addAll(nextItems);
      _page++;
    }
    hasMore.value = notifications.length < allNotifications.length;
    isLoadingMore.value = false;
  }

  Future<void> markAsRead(String id) async {
    final allIdx = allNotifications.indexWhere((n) => n.id == id);
    if (allIdx != -1 && !allNotifications[allIdx].isRead.value) {
      await _service.markNotificationAsRead(allIdx);
      allNotifications[allIdx].isRead.value = true;
      final dispIdx = notifications.indexWhere((n) => n.id == id);
      if (dispIdx != -1) {
        notifications[dispIdx].isRead.value = true;
      }
      notifications.refresh();
    }
  }

  Future<void> markAllAsRead() async {
    await _service.markAllNotificationsAsRead();
    for (var n in allNotifications) {
      n.isRead.value = true;
    }
    for (var n in notifications) {
      n.isRead.value = true;
    }
    notifications.refresh();
  }

  Future<void> deleteNotification(String id) async {
    final allIdx = allNotifications.indexWhere((n) => n.id == id);
    if (allIdx != -1) {
      await _service.deleteNotification(allIdx);
      allNotifications.removeAt(allIdx);
      final dispIdx = notifications.indexWhere((n) => n.id == id);
      if (dispIdx != -1) {
        notifications.removeAt(dispIdx);
      }
      notifications.refresh();
    }
  }

  Future<void> clearAll() async {
    await _service.clearNotifications();
    allNotifications.clear();
    notifications.clear();
  }
}

class _NotificationCardShimmer extends StatelessWidget {
  const _NotificationCardShimmer();

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(screenHeight / 47.25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenHeight / 47.25),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerCard(
            width: screenHeight / 17.18,
            height: screenHeight / 17.18,
            radius: screenHeight / 17.18,
          ),
          SizedBox(width: screenHeight / 54),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerCard(
                      width: screenWidth * 0.4,
                      height: 14,
                      radius: 4,
                    ),
                    const ShimmerCard(
                      width: 45,
                      height: 11,
                      radius: 4,
                    ),
                  ],
                ),
                SizedBox(height: screenHeight / 126),
                const ShimmerCard(
                  height: 13,
                  radius: 4,
                ),
                const SizedBox(height: 6),
                ShimmerCard(
                  width: screenWidth * 0.6,
                  height: 13,
                  radius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsLoadingShimmer extends StatelessWidget {
  const _NotificationsLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 5.0,
        bottom: screenHeight / 47.25,
        left: screenHeight / 47.25,
        right: screenHeight / 47.25,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: screenHeight / 75.6),
      itemBuilder: (_, __) => const _NotificationCardShimmer(),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final NotificationsController ctrl;
  final _scrollCtrl = ScrollController();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(NotificationsController());
    _scrollCtrl.addListener(_onScroll);

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
    _scrollCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!ctrl.isLoading.value &&
          !ctrl.isLoadingMore.value &&
          ctrl.hasMore.value) {
        ctrl.loadMore();
      }
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'homework':
        return Icons.assignment_rounded;
      case 'leave':
        return Icons.event_busy_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'timetable':
        return Icons.schedule_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'homework':
        return AppColors.warning;
      case 'leave':
        return AppColors.danger;
      case 'announcement':
        return AppColors.info;
      case 'timetable':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        toolbarHeight: isTablet ? 65.0 : 55.0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.gradientPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            top: isTablet ? 15.0 : 5.0,
            bottom: 10.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(
            top: isTablet ? 15.0 : 5.0,
            bottom: 10.0,
          ),
          child: const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          Obx(() {
            if (ctrl.notifications.isEmpty) return const SizedBox.shrink();
            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.white),
                  tooltip: 'Clear all',
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(MediaQuery.of(context).size.height / 37.8),
                        ),
                        title: const Text('Clear All Notifications'),
                        content: const Text(
                            'Are you sure you want to delete all notifications? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              ctrl.clearAll();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Clear',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: AppColors.danger)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                  tooltip: 'Mark all as read',
                  onPressed: () {
                    ctrl.markAllAsRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'All notifications marked as read',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(MediaQuery.of(context).size.height / 47.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MediaQuery.of(context).size.height / 63),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          }),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Obx(() {
        if (ctrl.isLoading.value) {
          return const _NotificationsLoadingShimmer();
        }

        if (ctrl.notifications.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No Notifications',
            subtitle: 'You are all caught up! No new notifications.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: ctrl.loadNotifications,
          child: ListView.separated(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: 5.0,
              bottom: screenHeight / 47.25,
              left: screenHeight / 47.25,
              right: screenHeight / 47.25,
            ),
            itemCount: ctrl.notifications.length + (ctrl.hasMore.value ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(height: screenHeight / 75.6),
            itemBuilder: (ctx, i) {
              if (i == ctrl.notifications.length) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: _NotificationCardShimmer(),
                );
              }
              final item = ctrl.notifications[i];
              final iconColor = _getColor(item.type);

              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: EdgeInsets.symmetric(horizontal: screenHeight / 37.8),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(screenHeight / 47.25),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white),
                ),
                onDismissed: (_) {
                  ctrl.deleteNotification(item.id);
                },
                child: GestureDetector(
                  onTap: () {
                    ctrl.markAsRead(item.id);
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(MediaQuery.of(context).size.height / 37.8),
                        ),
                        title: Row(
                          children: [
                            Icon(_getIcon(item.type), color: iconColor),
                            SizedBox(width: MediaQuery.of(context).size.height / 37.8),
                            Expanded(child: Text(item.title)),
                          ],
                        ),
                        content: Text(item.body),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Obx(() => Container(
                        padding: EdgeInsets.all(screenHeight / 47.25),
                        decoration: BoxDecoration(
                          color: item.isRead.value
                              ? Colors.white
                              : const Color(0xFFFAF5FF),
                          borderRadius:
                              BorderRadius.circular(screenHeight / 47.25),
                          border: Border.all(
                            color: item.isRead.value
                                ? const Color(0xFFF1F5F9)
                                : AppColors.primary.withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: screenHeight / 17.18,
                              height: screenHeight / 17.18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: iconColor.withValues(alpha: 0.1),
                              ),
                              child: Center(
                                child: Icon(
                                  _getIcon(item.type),
                                  color: iconColor,
                                  size: screenHeight / 34.36,
                                ),
                              ),
                            ),
                            SizedBox(width: screenHeight / 54),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: item.isRead.value
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _timeAgo(item.timestamp),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.normal,
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: screenHeight / 126),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.normal,
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!item.isRead.value) ...[
                              SizedBox(width: screenHeight / 94.5),
                              Container(
                                width: screenHeight / 94.5,
                                height: screenHeight / 94.5,
                                margin: EdgeInsets.only(top: screenHeight / 126),
                                decoration: const BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),
                ),
              );
            },
          ),
        );
      }),
    ),
  ),
);
  }
}

// ── Helper UI Models & Widgets ─────────────────────────────

abstract final class AppColors {
  static const primary = AppTheme.primary;
  static const secondary = AppTheme.secondary;
  static const danger = AppTheme.danger;
  static const warning = AppTheme.warning;
  static const info = Color(0xFF3B82F6); // blue
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9333EA), // Purple
      Color(0xFFDB2777), // Pink
    ],
  );
}

class ShimmerCard extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const ShimmerCard({
    super.key,
    this.width,
    this.height,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF1F5F9),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
