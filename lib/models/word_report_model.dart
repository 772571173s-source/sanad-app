class WordReportModel {
  final String centerName;
  final String studentName;
  final String dateRange;
  final List<WordReportSection> sections;

  const WordReportModel({
    required this.centerName,
    required this.studentName,
    required this.dateRange,
    required this.sections,
  });
}

class WordReportSection {
  final String sectionTitle;
  final String? titleIcon;
  final List<WordReportRow> rows;

  const WordReportSection({
    required this.sectionTitle,
    this.titleIcon,
    required this.rows,
  });
}

class WordReportRow {
  final List<String> cells;

  const WordReportRow({
    required this.cells,
  });
}
