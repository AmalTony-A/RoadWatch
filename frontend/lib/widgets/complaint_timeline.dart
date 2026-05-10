import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/complaint.dart';

class ComplaintTimeline extends StatelessWidget {
  final ComplaintItem complaint;

  const ComplaintTimeline({super.key, required this.complaint});

  Color _statusColor(String status) {
    switch (status) {
      case 'Read':
        return AppConfig.safeGreen;
      case 'Delivered':
        return AppConfig.deepNavy;
      case 'Sent':
        return AppConfig.safeGreen;
      case 'Resolved':
        return AppConfig.safeGreen;
      case 'In Progress':
        return AppConfig.cautionYellow;
      default:
        return AppConfig.dangerRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complaint.id,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(complaint.status).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  complaint.status,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _statusColor(complaint.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(complaint.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          _InfoChipRow(
            theme: theme,
            chips: [
              'Dept: ${complaint.recommendedDepartment}',
              'Ticket: ${complaint.authorityTicket}',
              complaint.sentToAuthority ? 'Sent' : 'Draft',
              complaint.readByAuthority ? 'Read' : 'Unread',
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complaint.routingReason,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          if (complaint.complaintLetter.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              child: Text(
                complaint.complaintLetter,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.5),
              ),
            ),
          const SizedBox(height: 12),
          ...complaint.timeline.map((event) {
            final date = DateTime.tryParse(event.at)?.toLocal();
            final dateText = date == null ? event.at : DateFormat('dd MMM, HH:mm').format(date);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _statusColor(event.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${event.status} - $dateText',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(event.note, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.72))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoChipRow extends StatelessWidget {
  final List<String> chips;
  final ThemeData theme;

  const _InfoChipRow({required this.chips, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (chip) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chip,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.72)),
              ),
            ),
          )
          .toList(),
    );
  }
}
