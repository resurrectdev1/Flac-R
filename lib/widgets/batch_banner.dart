import 'package:flutter/material.dart';
import '../theme/flacr_theme.dart';

class BatchBanner extends StatelessWidget {
  const BatchBanner({
    super.key,
    required this.count,
    required this.total,
    required this.theme,
    required this.onSelectAll,
    required this.onCancel,
    required this.onBatchEdit,
  });

  final int count;
  final int total;
  final FlacRTheme theme;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback onBatchEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCancel,
            child: Icon(Icons.close_rounded, color: theme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count selected',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            child: Text(
              'All ($total)',
              style: TextStyle(color: theme.primary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: count == 0 ? null : onBatchEdit,
            child: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
