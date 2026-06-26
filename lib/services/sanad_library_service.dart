import 'database_service.dart';

/// Seeds and provides access to the global Sanad therapy program library.
///
/// The global library uses [centerId] = `''` so that it is visible to every
/// center via the `(center_id = '' OR center_id = ?)` query pattern in
/// [SanadRepository.therapyProgramTemplates].
///
/// Call [ensureSeeded] once at startup (or lazily before the demo center is
/// created) to guarantee the library exists.
class SanadLibraryService {
  SanadLibraryService(this._db);

  final DatabaseService _db;

  // ─── Global library IDs ───────────────────────────────────
  static const progSpeech = 'prog_speech';
  static const progOt = 'prog_ot';
  static const progSensory = 'prog_sensory';

  static const secSpeechPhonetics = 'sec_speech_phonetics';
  static const secSpeechFluency = 'sec_speech_fluency';
  static const secOtFineMotor = 'sec_ot_fine_motor';
  static const secOtDailyLiving = 'sec_ot_daily_living';
  static const secSensoryAuditory = 'sec_sensory_auditory';
  static const secSensoryVisual = 'sec_sensory_visual';

  static const centerId = '';

  static bool isGlobalProgram(String id) =>
      id == progSpeech || id == progOt || id == progSensory;

  /// The three Sanad program names, keyed by id.
  static String programName(String id) {
    if (id == progSpeech) return 'برنامج النطق والتخاطب';
    if (id == progOt) return 'برنامج العلاج الوظيفي';
    if (id == progSensory) return 'برنامج التكامل الحسي';
    return 'برنامج علاجي';
  }

  /// Returns `true` if the global library has already been seeded.
  Future<bool> isSeeded() async {
    final row = await _db.first('therapy_program_templates',
        where: 'center_id = ? AND id = ?', whereArgs: [centerId, progSpeech]);
    return row != null;
  }

  /// Seeds the global Sanad library if it does not already exist.
  Future<void> ensureSeeded() async {
    if (await isSeeded()) return;
    await _createPrograms();
    await _createSections();
    await _createItems();
    await _createOptions();
    await _createSkillSteps();
  }

  // ─── Programs ─────────────────────────────────────────────
  Future<void> _createPrograms() async {
    final now = DateTime.now().toIso8601String();
    for (final p in [
      (progSpeech, 'برنامج النطق والتخاطب',
          'برنامج علاجي لاضطرابات النطق واللغة والتخاطب', 1),
      (progOt, 'برنامج العلاج الوظيفي',
          'برنامج علاجي لاضطرابات المهارات الحركية والوظيفية', 0),
      (progSensory, 'برنامج التكامل الحسي',
          'برنامج علاجي لاضطرابات التكامل والمعالجة الحسية', 0),
    ]) {
      await _db.upsert('therapy_program_templates', {
        'id': p.$1,
        'center_id': centerId,
        'name': p.$2,
        'description': p.$3,
        'uses_speech_sounds': p.$4,
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ─── Assessment sections ──────────────────────────────────
  Future<void> _createSections() async {
    final now = DateTime.now().toIso8601String();
    for (final s in [
      {
        'id': secSpeechPhonetics,
        'program_id': progSpeech,
        'title': 'مخارج الحروف',
        'description': 'تقييم مخارج الحروف الأساسية',
        'sort_order': 0,
      },
      {
        'id': secSpeechFluency,
        'program_id': progSpeech,
        'title': 'الطلاقة اللفظية',
        'description': 'تقييم الطلاقة اللفظية وسرعة الكلام',
        'sort_order': 1,
      },
      {
        'id': secOtFineMotor,
        'program_id': progOt,
        'title': 'المهارات الحركية الدقيقة',
        'description': 'تقييم المهارات الحركية الدقيقة لليد',
        'sort_order': 0,
      },
      {
        'id': secOtDailyLiving,
        'program_id': progOt,
        'title': 'المهارات اليومية',
        'description': 'تقييم مهارات الحياة اليومية',
        'sort_order': 1,
      },
      {
        'id': secSensoryAuditory,
        'program_id': progSensory,
        'title': 'المعالجة السمعية',
        'description': 'تقييم المعالجة السمعية والتكامل السمعي',
        'sort_order': 0,
      },
      {
        'id': secSensoryVisual,
        'program_id': progSensory,
        'title': 'المعالجة البصرية',
        'description': 'تقييم المعالجة البصرية والتواصل البصري',
        'sort_order': 1,
      },
    ]) {
      await _db.upsert('assessment_section_templates', {
        'id': s['id'],
        'center_id': centerId,
        'program_id': s['program_id'],
        'title': s['title'],
        'description': s['description'],
        'sort_order': s['sort_order'],
        'created_at': now,
      });
    }
  }

  // ─── Assessment items ─────────────────────────────────────
  Future<void> _createItems() async {
    final now = DateTime.now().toIso8601String();
    Future<void> addItem(
        {required String id,
        required String sectionId,
        required String title,
        required int sortOrder}) async {
      await _db.upsert('assessment_item_templates', {
        'id': id,
        'center_id': centerId,
        'section_id': sectionId,
        'title': title,
        'response_type': 'custom',
        'response_mode': 'singleChoice',
        'sort_order': sortOrder,
        'created_at': now,
      });
    }

    await addItem(
        id: 'item_speech_ra',
        sectionId: secSpeechPhonetics,
        title: 'مخرج صوت /ر/',
        sortOrder: 0);
    await addItem(
        id: 'item_speech_si',
        sectionId: secSpeechPhonetics,
        title: 'مخرج صوت /س/',
        sortOrder: 1);
    await addItem(
        id: 'item_speech_shi',
        sectionId: secSpeechPhonetics,
        title: 'مخرج صوت /ش/',
        sortOrder: 2);
    await addItem(
        id: 'item_speech_la',
        sectionId: secSpeechPhonetics,
        title: 'مخرج صوت /ل/',
        sortOrder: 3);
    await addItem(
        id: 'item_speech_fa',
        sectionId: secSpeechPhonetics,
        title: 'مخرج صوت /ف/',
        sortOrder: 4);
    await addItem(
        id: 'item_speech_fluency',
        sectionId: secSpeechFluency,
        title: 'الطلاقة اللفظية',
        sortOrder: 0);
    await addItem(
        id: 'item_speech_discrimination',
        sectionId: secSpeechFluency,
        title: 'التمييز السمعي',
        sortOrder: 1);
    await addItem(
        id: 'item_ot_writing',
        sectionId: secOtFineMotor,
        title: 'مسك القلم والكتابة',
        sortOrder: 0);
    await addItem(
        id: 'item_ot_coordination',
        sectionId: secOtFineMotor,
        title: 'التنسيق بين اليد والعين',
        sortOrder: 1);
    await addItem(
        id: 'item_ot_dressing',
        sectionId: secOtDailyLiving,
        title: 'ارتداء الملابس',
        sortOrder: 0);
    await addItem(
        id: 'item_ot_eating',
        sectionId: secOtDailyLiving,
        title: 'المهارات الغذائية',
        sortOrder: 1);
    await addItem(
        id: 'item_sen_auditory',
        sectionId: secSensoryAuditory,
        title: 'المعالجة السمعية',
        sortOrder: 0);
    await addItem(
        id: 'item_sen_auditory_discrimination',
        sectionId: secSensoryAuditory,
        title: 'التمييز السمعي للأصوات',
        sortOrder: 1);
    await addItem(
        id: 'item_sen_visual_contact',
        sectionId: secSensoryVisual,
        title: 'التواصل البصري',
        sortOrder: 0);
    await addItem(
        id: 'item_sen_visual_tracking',
        sectionId: secSensoryVisual,
        title: 'المتابعة البصرية',
        sortOrder: 1);
  }

  // ─── Assessment options ───────────────────────────────────
  Future<void> _createOptions() async {
    final now = DateTime.now().toIso8601String();
    Future<void> addOption(
        {required String id,
        required String itemId,
        required String label,
        required bool generatesTherapy,
        String weaknessTemplate = '',
        String goalTemplate = '',
        String therapyTemplate = ''}) async {
      await _db.upsert('assessment_option_templates', {
        'id': id,
        'center_id': centerId,
        'item_id': itemId,
        'label': label,
        'generates_therapy': generatesTherapy ? 1 : 0,
        'weakness_template': weaknessTemplate,
        'goal_template': goalTemplate,
        'therapy_template': therapyTemplate,
        'sort_order': 0,
        'created_at': now,
      });
    }

    for (final itemId in [
      'item_speech_ra',
      'item_speech_si',
      'item_speech_shi',
      'item_speech_la',
      'item_speech_fa'
    ]) {
      await addOption(
          id: '${itemId}_opt_weak',
          itemId: itemId,
          label: 'ضعيف',
          generatesTherapy: true,
          weaknessTemplate: 'ضعف في نطق الصوت',
          goalTemplate: 'إتقان نطق الصوت',
          therapyTemplate: 'تمارين نطق');
      await addOption(
          id: '${itemId}_opt_help',
          itemId: itemId,
          label: 'بمساعدة',
          generatesTherapy: true,
          weaknessTemplate: 'نطق الصوت بمساعدة',
          goalTemplate: 'إتقان نطق الصوت',
          therapyTemplate: 'تمارين لفظية');
      await addOption(
          id: '${itemId}_opt_good',
          itemId: itemId,
          label: 'جيد',
          generatesTherapy: false);
      await addOption(
          id: '${itemId}_opt_excellent',
          itemId: itemId,
          label: 'متقن',
          generatesTherapy: false);
    }
    for (final itemId in [
      'item_speech_fluency',
      'item_speech_discrimination'
    ]) {
      await addOption(
          id: '${itemId}_opt_weak',
          itemId: itemId,
          label: 'ضعيف',
          generatesTherapy: true,
          weaknessTemplate: 'ضعف في المهارة',
          goalTemplate: 'تحسين المهارة',
          therapyTemplate: 'تمارين');
      await addOption(
          id: '${itemId}_opt_good',
          itemId: itemId,
          label: 'جيد',
          generatesTherapy: false);
    }
    for (final itemId in [
      'item_ot_writing',
      'item_ot_coordination',
      'item_ot_dressing',
      'item_ot_eating'
    ]) {
      await addOption(
          id: '${itemId}_opt_weak',
          itemId: itemId,
          label: 'ضعيف',
          generatesTherapy: true,
          weaknessTemplate: 'ضعف في المهارة',
          goalTemplate: 'تحسين المهارة',
          therapyTemplate: 'تمارين علاجية');
      await addOption(
          id: '${itemId}_opt_help',
          itemId: itemId,
          label: 'بمساعدة',
          generatesTherapy: true,
          weaknessTemplate: 'يحتاج مساعدة',
          goalTemplate: 'زيادة الاستقلالية',
          therapyTemplate: 'تدريب');
      await addOption(
          id: '${itemId}_opt_independent',
          itemId: itemId,
          label: 'مستقل',
          generatesTherapy: false);
    }
    for (final itemId in [
      'item_sen_auditory',
      'item_sen_auditory_discrimination',
      'item_sen_visual_contact',
      'item_sen_visual_tracking'
    ]) {
      await addOption(
          id: '${itemId}_opt_weak',
          itemId: itemId,
          label: 'ضعيف',
          generatesTherapy: true,
          weaknessTemplate: 'ضعف في المعالجة',
          goalTemplate: 'تحسين المعالجة',
          therapyTemplate: 'تمارين تكامل');
      await addOption(
          id: '${itemId}_opt_help',
          itemId: itemId,
          label: 'بمساعدة',
          generatesTherapy: true,
          weaknessTemplate: 'يحتاج مساعدة',
          goalTemplate: 'تحسين المهارة',
          therapyTemplate: 'أنشطة');
      await addOption(
          id: '${itemId}_opt_good',
          itemId: itemId,
          label: 'جيد',
          generatesTherapy: false);
    }
  }

  // ─── Skill-step templates ─────────────────────────────────
  Future<void> _createSkillSteps() async {
    final now = DateTime.now().toIso8601String();
    for (final entry in [
      {'ownerType': 'program', 'ownerId': progSpeech, 'title': 'محاولة نطق الصوت'},
      {'ownerType': 'program', 'ownerId': progSpeech, 'title': 'نطق الصوت منفردًا'},
      {'ownerType': 'program', 'ownerId': progSpeech, 'title': 'نطق الصوت في مقاطع'},
      {'ownerType': 'program', 'ownerId': progSpeech, 'title': 'نطق الصوت في كلمات'},
      {'ownerType': 'program', 'ownerId': progSpeech, 'title': 'نطق الصوت في جمل'},
      {'ownerType': 'program', 'ownerId': progOt, 'title': 'تقليد الحركة'},
      {'ownerType': 'program', 'ownerId': progOt, 'title': 'أداء المهارة بمساعدة'},
      {'ownerType': 'program', 'ownerId': progOt, 'title': 'أداء المهارة بشكل مستقل'},
      {'ownerType': 'program', 'ownerId': progSensory, 'title': 'التعرض للمؤثر'},
      {'ownerType': 'program', 'ownerId': progSensory, 'title': 'تحمل المؤثر'},
      {'ownerType': 'program', 'ownerId': progSensory, 'title': 'التكيف مع المؤثر'},
    ]) {
      await _db.upsert('skill_step_templates', {
        'id':
            'sst_${entry['ownerId']}_${entry['title']}'.replaceAll(' ', '_'),
        'center_id': centerId,
        'owner_type': entry['ownerType'],
        'owner_id': entry['ownerId'],
        'title': entry['title'],
        'sort_order': 0,
        'created_at': now,
      });
    }
  }
}
