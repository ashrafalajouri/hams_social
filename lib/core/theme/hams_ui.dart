import 'package:flutter/material.dart';

import 'app_theme.dart';

class HamsScreenBackground extends StatelessWidget {
  const HamsScreenBackground({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;

    return DecoratedBox(
      decoration: HamsDecor.screenDecoration(brightness),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -40,
            child: _GlowOrb(
              size: 180,
              color: (dark ? HamsColors.primaryLight : HamsColors.primary)
                  .withOpacity(0.14),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -35,
            child: _GlowOrb(
              size: 200,
              color: (dark ? HamsColors.secondary : HamsColors.accent)
                  .withOpacity(0.1),
            ),
          ),
          SafeArea(
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ],
      ),
    );
  }
}

class HamsGlassCard extends StatelessWidget {
  const HamsGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius = 18,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark
        ? Colors.white.withOpacity(0.07)
        : Colors.white.withOpacity(0.92);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              borderColor ??
              (dark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.06)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(dark ? 0.24 : 0.06),
          ),
        ],
      ),
      child: child,
    );
  }
}

class HamsSectionTitle extends StatelessWidget {
  const HamsSectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    return Row(
      children: [
        Text(title, style: style),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class HamsGradientButton extends StatelessWidget {
  const HamsGradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.height = 44,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: HamsGradients.brand,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: HamsColors.primary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HamsStatPill extends StatelessWidget {
  const HamsStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HamsGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 16,
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
