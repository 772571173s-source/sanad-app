class CenterReportSettings {
  final String centerId;
  final String? logoBase64;
  final String? logoFileName;
  final String arabicHeaderText;
  final String englishHeaderText;
  final String defaultReportTitle;
  final String defaultTechnicalSupervisorName;
  final String footerNotes;
  final bool reportsToFund;
  final String fundName;
  final bool showFundCardNumber;
  final bool showReferralDate;
  final bool showReferralSource;
  final String updatedAt;

  const CenterReportSettings({
    required this.centerId,
    this.logoBase64,
    this.logoFileName,
    this.arabicHeaderText = '',
    this.englishHeaderText = '',
    this.defaultReportTitle = '',
    this.defaultTechnicalSupervisorName = '',
    this.footerNotes = '',
    this.reportsToFund = false,
    this.fundName = '',
    this.showFundCardNumber = false,
    this.showReferralDate = false,
    this.showReferralSource = false,
    required this.updatedAt,
  });

  factory CenterReportSettings.defaults(String centerId) => CenterReportSettings(
        centerId: centerId,
        defaultReportTitle: 'التقرير الربع سنوي للحالة',
        updatedAt: DateTime.now().toIso8601String(),
      );

  static CenterReportSettings fromMap(Map<String, Object?> row) =>
      CenterReportSettings(
        centerId: (row['center_id'] ?? '') as String,
        logoBase64: row['logo_base64'] as String?,
        logoFileName: row['logo_file_name'] as String?,
        arabicHeaderText: (row['arabic_header_text'] ?? '') as String,
        englishHeaderText: (row['english_header_text'] ?? '') as String,
        defaultReportTitle: (row['default_report_title'] ?? '') as String,
        defaultTechnicalSupervisorName:
            (row['default_technical_supervisor_name'] ?? '') as String,
        footerNotes: (row['footer_notes'] ?? '') as String,
        reportsToFund: ((row['reports_to_fund'] ?? 0) as int) == 1,
        fundName: (row['fund_name'] ?? '') as String,
        showFundCardNumber: ((row['show_fund_card_number'] ?? 0) as int) == 1,
        showReferralDate: ((row['show_referral_date'] ?? 0) as int) == 1,
        showReferralSource: ((row['show_referral_source'] ?? 0) as int) == 1,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'center_id': centerId,
        'logo_base64': logoBase64,
        'logo_file_name': logoFileName,
        'arabic_header_text': arabicHeaderText,
        'english_header_text': englishHeaderText,
        'default_report_title': defaultReportTitle,
        'default_technical_supervisor_name': defaultTechnicalSupervisorName,
        'footer_notes': footerNotes,
        'reports_to_fund': reportsToFund ? 1 : 0,
        'fund_name': fundName,
        'show_fund_card_number': showFundCardNumber ? 1 : 0,
        'show_referral_date': showReferralDate ? 1 : 0,
        'show_referral_source': showReferralSource ? 1 : 0,
        'updated_at': updatedAt,
      };

  CenterReportSettings copyWith({
    String? centerId,
    String? logoBase64,
    String? logoFileName,
    String? arabicHeaderText,
    String? englishHeaderText,
    String? defaultReportTitle,
    String? defaultTechnicalSupervisorName,
    String? footerNotes,
    bool? reportsToFund,
    String? fundName,
    bool? showFundCardNumber,
    bool? showReferralDate,
    bool? showReferralSource,
    String? updatedAt,
  }) {
    return CenterReportSettings(
      centerId: centerId ?? this.centerId,
      logoBase64: logoBase64 ?? this.logoBase64,
      logoFileName: logoFileName ?? this.logoFileName,
      arabicHeaderText: arabicHeaderText ?? this.arabicHeaderText,
      englishHeaderText: englishHeaderText ?? this.englishHeaderText,
      defaultReportTitle: defaultReportTitle ?? this.defaultReportTitle,
      defaultTechnicalSupervisorName:
          defaultTechnicalSupervisorName ?? this.defaultTechnicalSupervisorName,
      footerNotes: footerNotes ?? this.footerNotes,
      reportsToFund: reportsToFund ?? this.reportsToFund,
      fundName: fundName ?? this.fundName,
      showFundCardNumber: showFundCardNumber ?? this.showFundCardNumber,
      showReferralDate: showReferralDate ?? this.showReferralDate,
      showReferralSource: showReferralSource ?? this.showReferralSource,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
