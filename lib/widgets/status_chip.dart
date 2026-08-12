// One compact status indicator for the dashboard status strip.
//
// The registrar dashboard used to answer "is my device working and is my work
// safe?" with three full-size cards (GPS, sync, statistics). A chip carries the
// same answer in one line; the detail lives one tap away.
import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
    this.busy = false,
    this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  /// Optional count shown as a badge. Use it when the label describes a state
  /// and would otherwise hide the number - e.g. "Paused" while items wait.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final chip = _buildChip(context);
    if (badgeCount == null || badgeCount! <= 0) return chip;
    return Badge.count(
      count: badgeCount!,
      alignment: Alignment.topRight,
      // Pull the badge inwards so it stays inside the row and is not clipped.
      offset: const Offset(-4, 2),
      backgroundColor: color,
      textColor: Colors.white,
      child: chip,
    );
  }

  Widget _buildChip(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
