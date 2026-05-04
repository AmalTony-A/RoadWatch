class BudgetRecord {
  final String roadId;
  final String projectId;
  final int allocatedInr;
  final int spentInr;
  final String contractor;
  final String lastRepairDate;
  final int expectedScore;
  final int actualScore;
  final String transparencyNote;

  const BudgetRecord({
    required this.roadId,
    required this.projectId,
    required this.allocatedInr,
    required this.spentInr,
    required this.contractor,
    required this.lastRepairDate,
    required this.expectedScore,
    required this.actualScore,
    required this.transparencyNote,
  });

  factory BudgetRecord.fromJson(Map<String, dynamic> json) {
    return BudgetRecord(
      roadId: json['road_id'] as String,
      projectId: json['project_id'] as String,
      allocatedInr: json['allocated_inr'] as int,
      spentInr: json['spent_inr'] as int,
      contractor: json['contractor'] as String,
      lastRepairDate: json['last_repair_date'] as String,
      expectedScore: json['expected_score'] as int,
      actualScore: json['actual_score'] as int,
      transparencyNote: json['transparency_note'] as String,
    );
  }
}
