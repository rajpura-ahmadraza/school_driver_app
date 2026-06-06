import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'dart:math' as math;
import '../../core/api/api_client.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/utils/student_image_url.dart';

// ── UI Palette ──
abstract final class _StudentsUi {
  static const canvas = Color(0xFFF1F5F9);
  static const deep = Color(0xFF9333EA);
  static const mid = Color(0xFF9333EA);
  static const teal = Color(0xFFDB2777);
  static const ink = Color(0xFF1E293B);
  static const inkMuted = Color(0xFF64748B);
}

// ── Students loader (GetX-compatible) ──
Future<List<dynamic>> fetchRouteStudents(int routeId) async {
  final api = Get.find<ApiClient>();
  final resp = await api.get('/bus/route/$routeId/students');
  final data = resp.data;
  if (data is Map && data['students'] != null) {
    return List<dynamic>.from(data['students'] as List);
  }
  return [];
}

class _StudentsController extends GetxController {
  final int routeId;
  _StudentsController(this.routeId);

  final RxList<dynamic> students = <dynamic>[].obs;
  final RxBool isLoading = true.obs;
  final Rx<Object?> error = Rx<Object?>(null);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      students.value = await fetchRouteStudents(routeId);
    } catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }
}

class StudentsScreen extends StatefulWidget {
  final int routeId;
  const StudentsScreen({required this.routeId, super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen>
    with SingleTickerProviderStateMixin {
  final Set<int> _markedAbsent = {};
  bool _saved = false;
  String _searchQuery = '';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late final _StudentsController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      _StudentsController(widget.routeId),
      tag: widget.routeId.toString(),
    );
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
    Get.delete<_StudentsController>(tag: widget.routeId.toString());
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshStudents() async {
    await _ctrl.load();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _StudentsUi.canvas,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                _StudentsHeader(
                  routeId: widget.routeId,
                  markedAbsentCount: _markedAbsent.length,
                  onRefresh: _refreshStudents,
                  onSearchChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                  },
                ),
                Expanded(
                  child: Obx(() {
                    final ctrl = Get.find<_StudentsController>(
                        tag: widget.routeId.toString());
                    if (ctrl.isLoading.value) return _buildLoading();
                    if (ctrl.error.value != null)
                      return _buildError(ctrl.error.value!);
                    final filtered = ctrl.students.where((student) {
                      final name =
                          (student['name'] as String? ?? '').toLowerCase();
                      return name.contains(_searchQuery.toLowerCase());
                    }).toList();
                    return _buildContent(filtered);
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }

  Widget _buildError(Object err) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'error'.tr(),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _StudentsUi.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _StudentsUi.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => Get.find<_StudentsController>(
                        tag: widget.routeId.toString())
                    .load(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'retry'.tr(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _StudentsUi.teal,
                  side: const BorderSide(color: _StudentsUi.teal, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<dynamic> students) {
    final absentCount =
        students.where((s) => _markedAbsent.contains(s['id'] as int)).length;
    final presentCount = students.length - absentCount;

    return Column(
      children: [
        // Stats & Bulk action bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'total'.tr(),
                      value: students.length,
                      color: _StudentsUi.mid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: 'present'.tr(),
                      value: presentCount,
                      color: _StudentsUi.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: 'absent'.tr(),
                      value: absentCount,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              if (students.isNotEmpty) ...[
                const SizedBox(height: 12),
                // Bulk Actions Row
                Row(
                  children: [
                    Expanded(
                      child: _BulkBtn(
                        label: 'all_present'.tr(),
                        onTap: () => setState(() {
                          for (final s in students) {
                            _markedAbsent.remove(s['id'] as int);
                          }
                        }),
                        color: const Color(0xFF22C55E),
                        icon: Icons.done_all_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BulkBtn(
                        label: 'all_absent'.tr(),
                        onTap: () => setState(() {
                          for (final s in students) {
                            _markedAbsent.add(s['id'] as int);
                          }
                        }),
                        color: const Color(0xFFEF4444),
                        icon: Icons.person_off_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Students list (pull to refresh)
        Expanded(
          child: RefreshIndicator(
            color: _StudentsUi.teal,
            onRefresh: _refreshStudents,
            child: students.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.22,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                size: 48,
                                color: _StudentsUi.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'no_students'.tr(),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: _StudentsUi.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final s = students[i];
                      final id = s['id'] as int;
                      final isAbsent = _markedAbsent.contains(id);
                      return _StudentCard(
                        student: s,
                        isAbsent: isAbsent,
                        onToggle: () => setState(() {
                          if (isAbsent) {
                            _markedAbsent.remove(id);
                          } else {
                            _markedAbsent.add(id);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ),

        // Premium Save button
        if (students.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              25,
              20,
              MediaQuery.paddingOf(context).bottom + 14,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _saved ? null : _saveAttendance,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: _saved
                          ? [
                              _StudentsUi.mid.withValues(alpha: 0.6),
                              _StudentsUi.teal.withValues(alpha: 0.6),
                            ]
                          : [_StudentsUi.mid, _StudentsUi.teal],
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _saved
                              ? Icons.check_circle_rounded
                              : Icons.save_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _saved
                              ? 'attendance_saved'.tr()
                              : 'save_attendance'.tr(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .moveY(
                begin: 0,
                end: -2,
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
      ],
    );
  }

  void _saveAttendance() {
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Attendance saved. ${_markedAbsent.length} student(s) marked absent.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _StudentsUi.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _saved = false);
    });
  }
}

// ── Custom premium header ──
class _StudentsHeader extends StatefulWidget {
  final int routeId;
  final int markedAbsentCount;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onSearchChanged;

  const _StudentsHeader({
    required this.routeId,
    required this.markedAbsentCount,
    required this.onRefresh,
    this.onSearchChanged,
  });

  @override
  State<_StudentsHeader> createState() => _StudentsHeaderState();
}

class _StudentsHeaderState extends State<_StudentsHeader>
    with TickerProviderStateMixin {
  late AnimationController _driftCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _searchCtrl.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchTextChanged);
    _driftCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: top + 128,
      child: AnimatedBuilder(
        animation: _driftCtrl,
        builder: (context, _) {
          final t = _driftCtrl.value * 2 * math.pi;
          return ClipRRect(
            // borderRadius: const BorderRadius.only(
            //   bottomLeft: Radius.circular(28),
            //   bottomRight: Radius.circular(28),
            // ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _StudentsUi.deep,
                        _StudentsUi.teal,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: top + 20 + math.sin(t) * 10,
                  right: -30,
                  child: const _StudentsOrb(
                    size: 110,
                    color: Color.fromARGB(20, 255, 255, 255),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: -40 + math.cos(t) * 12,
                  child: const _StudentsOrb(
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
                      children: [
                        // Top Row with Back button, Centered Title, and Refresh button
                        Row(
                          children: [
                            // Back Button
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
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
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
                                    'my_students'.tr(),
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
                            // Refresh Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onRefresh,
                                borderRadius: BorderRadius.circular(40),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(40),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        // Search Field (replaces profile box & route label)
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              const Icon(
                                Icons.search_rounded,
                                color: _StudentsUi.deep,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  focusNode: _searchFocusNode,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14.5,
                                    color: Color(0xFF1E293B),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    hintText: 'search_students'.tr(),
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontFamily: 'Poppins',
                                      fontSize: 13.5,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  onChanged: widget.onSearchChanged,
                                ),
                              ),
                              if (_searchCtrl.text.isNotEmpty)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _StudentsUi.deep,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    widget.onSearchChanged?.call('');
                                    setState(() {});
                                  },
                                ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
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

class _StudentsOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _StudentsOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Student Avatar ──
class _StudentAvatar extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool isAbsent;
  final String initial;

  const _StudentAvatar({
    required this.student,
    required this.isAbsent,
    required this.initial,
  });

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final imageUrl = StudentImageUrl.fromStudent(student);
    final token = Get.find<AuthController>().token.value;

    final borderColor = isAbsent
        ? const Color(0xFFEF4444).withValues(alpha: 0.25)
        : const Color(0xFF22C55E).withValues(alpha: 0.2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
        gradient: imageUrl == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAbsent
                    ? [
                        const Color(0xFFFEE2E2),
                        const Color(0xFFFCA5A5),
                      ]
                    : [
                        const Color(0xFFDCFCE7),
                        const Color(0xFFF0FDF4),
                      ],
              )
            : null,
      ),
      child: ClipOval(
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                headers:
                    token != null ? {'Authorization': 'Bearer $token'} : null,
                errorBuilder: (_, __, ___) => _fallbackInitial(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isAbsent
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF22C55E),
                      ),
                    ),
                  );
                },
              )
            : _fallbackInitial(),
      ),
    );
  }

  Widget _fallbackInitial() {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: isAbsent ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
        ),
      ),
    );
  }
}

// ── Student Card ──
class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool isAbsent;
  final VoidCallback onToggle;

  const _StudentCard({
    required this.student,
    required this.isAbsent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String? ?? '';
    final className = student['class']?['name'] as String? ?? '';
    final section = student['class']?['section'] as String? ?? '';

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final subtitleParts = <String>[];
    if (className.isNotEmpty) {
      subtitleParts.add('$className${section.isNotEmpty ? ' - $section' : ''}');
    }
    final subtitleText = subtitleParts.join(' · ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isAbsent ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAbsent
              ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
              : const Color(0xFF86EFAC).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isAbsent
                ? const Color(0xFFEF4444).withValues(alpha: 0.03)
                : const Color(0xFF22C55E).withValues(alpha: 0.03),
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
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _StudentAvatar(
                  student: student,
                  isAbsent: isAbsent,
                  initial: initial,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: isAbsent
                              ? const Color(0xFF94A3B8)
                              : _StudentsUi.ink,
                          decoration: isAbsent
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: const Color(0xFF94A3B8),
                        ),
                      ),
                      if (subtitleText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _StudentsUi.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isAbsent
                        ? const Color(0xFF22C55E).withValues(alpha: 0.08)
                        : const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAbsent
                          ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                          : const Color(0xFFEF4444).withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAbsent
                            ? Icons.check_circle_outline_rounded
                            : Icons.person_off_rounded,
                        size: 13,
                        color: isAbsent
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB91C1C),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAbsent ? 'mark_present'.tr() : 'mark_absent'.tr(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAbsent
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
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
    );
  }
}

// ── Stat Chip ──
class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$value',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _StudentsUi.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulk Button ──
class _BulkBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  const _BulkBtn({
    required this.label,
    required this.onTap,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton Card ──
class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 85,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}
