import 'package:flutter/material.dart';

class ShimmerListPlaceholder extends StatefulWidget {
  const ShimmerListPlaceholder({
    super.key,
    this.itemCount = 6,
    this.horizontalPadding = 12,
  });

  final int itemCount;
  final double horizontalPadding;

  @override
  State<ShimmerListPlaceholder> createState() => _ShimmerListPlaceholderState();
}

class _ShimmerListPlaceholderState extends State<ShimmerListPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.white10 : Colors.black12;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final opacity = 0.35 + (_controller.value * 0.35);
        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: 12,
          ),
          itemCount: widget.itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) {
            return Container(
              height: 92,
              decoration: BoxDecoration(
                color: base.withOpacity(opacity),
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
  }
}
