import 'center_report_settings.dart';

class WordReportModel {
  final String centerName;
  final String studentName;
  final String dateRange;
  final List<WordReportSection> sections;
  final String programType;
  final String diagnosis;
  final CenterReportSettings? centerSettings;
  final int year;
  final String studentAge;
  final List<int> months;
  final List<String> activeServiceNames;

  const WordReportModel({
    required this.centerName,
    required this.studentName,
    required this.dateRange,
    required this.sections,
    this.programType = '',
    this.diagnosis = '',
    this.centerSettings,
    this.year = 0,
    this.studentAge = '',
    this.months = const [],
    this.activeServiceNames = const [],
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
