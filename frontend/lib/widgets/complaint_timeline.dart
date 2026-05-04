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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5)),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(complaint.status).withOpacity(0.16),
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
          Text(complaint.description),
          const SizedBox(height: 8),
          _InfoChipRow(
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
            style: const TextStyle(fontSize: 12, color: AppConfig.skySlate),
          ),
          const SizedBox(height: 10),
          if (complaint.complaintLetter.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                complaint.complaintLetter,
                style: const TextStyle(fontSize: 12, height: 1.5, color: AppConfig.deepNavy),
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(event.note, style: const TextStyle(fontSize: 12)),
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

  const _InfoChipRow({required this.chips});

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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chip,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConfig.skySlate),
              ),
            ),
          )
          .toList(),
    );
  }
}
