import 'package:flutter/material.dart';

import '../config/app_config.dart';

class HoverRoadChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const HoverRoadChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<HoverRoadChip> createState() => _HoverRoadChipState();
}

class _HoverRoadChipState extends State<HoverRoadChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selected || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
        decoration: BoxDecoration(
          color: widget.selected ? AppConfig.deepNavy.withValues(alpha: 0.1) : Colors.white,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: widget.selected
                ? AppConfig.deepNavy.withValues(alpha: 0.45)
                : AppConfig.deepNavy.withValues(alpha: isActive ? 0.24 : 0.14),
            width: widget.selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppConfig.deepNavy.withValues(alpha: _hovered ? 0.14 : 0.06),
              blurRadius: _hovered ? 16 : 8,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  if (widget.selected) ...[
                    const Icon(Icons.check_rounded, size: 13, color: AppConfig.deepNavy),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.selected ? AppConfig.deepNavy : AppConfig.skySlate,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
