import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, danger, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = isEnabled ? AppColors.primaryButton : AppColors.line;
        foregroundColor = isEnabled ? AppColors.buttonTextLight : AppColors.inkMuted;
        break;
      case AppButtonVariant.secondary:
        backgroundColor = Colors.transparent;
        foregroundColor = isEnabled ? AppColors.ink : AppColors.inkMuted;
        borderSide = const BorderSide(color: AppColors.line, width: 1.5);
        break;
      case AppButtonVariant.danger:
        backgroundColor = isEnabled ? AppColors.rust : AppColors.line;
        foregroundColor = isEnabled ? Colors.white : AppColors.inkMuted;
        break;
      case AppButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = isEnabled ? AppColors.forest : AppColors.inkMuted;
        break;
    }

    Widget content;
    if (isLoading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelLarge.copyWith(color: foregroundColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelLarge.copyWith(color: foregroundColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      content = Text(
        text,
        style: AppTypography.labelLarge.copyWith(color: foregroundColor),
        overflow: TextOverflow.ellipsis,
      );
    }

    final buttonWidget = Container(
      constraints: BoxConstraints(
        minHeight: 50,
        minWidth: isFullWidth ? double.infinity : 120,
      ),
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: borderSide ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: variant == AppButtonVariant.primary
              ? AppColors.primaryButtonPressed
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Center(child: content),
          ),
        ),
      ),
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: buttonWidget) : buttonWidget;
  }
}
