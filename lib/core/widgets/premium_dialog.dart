import 'package:flutter/material.dart';

/// Shared premium dialog styling — use for all app dialogs (logic stays in callers).
abstract final class PremiumDialogUi {
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const teal = Color(0xFF0D9488);
  static const mid = Color(0xFF1E3A8A);
}

/// Standard two-button premium dialog (cancel + confirm).
Future<void> showPremiumTwoButtonDialog({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
  required Color confirmColor,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) => PremiumDialogFrame(
      child: PremiumDialogBody(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        actions: Row(
          children: [
            Expanded(
              child: PremiumDialogOutlinedButton(
                label: cancelLabel,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumDialogFilledButton(
                label: confirmLabel,
                color: confirmColor,
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Premium dialog shell — wrap custom content (e.g. GPS dialog).
class PremiumDialogFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsets? insetPadding;

  const PremiumDialogFrame({
    super.key,
    required this.child,
    this.insetPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding ??
          const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: PremiumDialogUi.border),
          boxShadow: [
            BoxShadow(
              color: PremiumDialogUi.mid.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PremiumDialogUi.mid,
                      PremiumDialogUi.teal,
                    ],
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumDialogBody extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget actions;

  const PremiumDialogBody({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withValues(alpha: 0.18),
                  iconColor.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: iconColor.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: iconColor, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: PremiumDialogUi.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: PremiumDialogUi.inkMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 26),
          actions,
        ],
      ),
    );
  }
}

class PremiumDialogOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PremiumDialogOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PremiumDialogUi.border, width: 1.5),
            color: const Color(0xFFF8FAFC),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: PremiumDialogUi.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumDialogFilledButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const PremiumDialogFilledButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [color, color.withValues(alpha: 0.88)],
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
