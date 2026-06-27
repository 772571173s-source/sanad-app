import 'database_service.dart';

class DemoTimeService {
  DemoTimeService._();
  static final DemoTimeService instance = DemoTimeService._();

  static const demoCenterId = 'demo_center_sanad';
  static const defaultDateStr = '2026-01-01T00:00:00.000';

  DatabaseService get _db => DatabaseService.instance;

  Future<Map<String, dynamic>> getState() async {
    final state = await _db.first('demo_time_state',
        where: 'center_id = ?', whereArgs: [demoCenterId]);
    if (state == null) {
      return {
        'exists': false,
        'currentDate': null,
        'initialDate': null,
        'lastAction': null,
      };
    }
    return {
      'exists': true,
      'currentDate': state['current_date'] as String,
      'initialDate': state['initial_date'] as String,
      'lastAction': state['last_action'] as String? ?? '',
    };
  }

  Future<DateTime> getCurrentDate() async {
    final state = await _getState();
    return DateTime.parse(state['current_date'] as String);
  }

  Future<void> setCurrentDate(DateTime date, {String action = 'تعيين تاريخ'}) async {
    await _db.upsert('demo_time_state', {
      'center_id': demoCenterId,
      'current_date': date.toIso8601String(),
      'initial_date': defaultDateStr,
      'last_action': '$action: ${date.toIso8601String().substring(0, 10)}',
    });
  }

  Future<void> advanceDays(int days) async {
    final current = await getCurrentDate();
    final newDate = current.add(Duration(days: days));
    await setCurrentDate(newDate, action: 'تقديم $days يوم');
  }

  Future<void> advanceWeeks(int weeks) async {
    await advanceDays(weeks * 7);
  }

  Future<void> advanceMonths(int months) async {
    final current = await getCurrentDate();
    final newDate = DateTime(current.year, current.month + months, current.day);
    await setCurrentDate(newDate, action: 'تقديم $months شهر');
  }

  Future<void> reset() async {
    await _db.upsert('demo_time_state', {
      'center_id': demoCenterId,
      'current_date': defaultDateStr,
      'initial_date': defaultDateStr,
      'last_action': 'إعادة ضبط الزمن التجريبي',
    });
  }

  Future<Map<String, DateTime>> currentWeekRange() async {
    final date = await getCurrentDate();
    final weekStart = date.subtract(Duration(days: date.weekday - DateTime.saturday));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return {'start': weekStart, 'end': weekEnd};
  }

  Future<Map<String, DateTime>> currentMonthRange() async {
    final date = await getCurrentDate();
    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 0);
    return {'start': monthStart, 'end': monthEnd};
  }

  Future<Map<String, Object?>> _getState() async {
    final state = await _db.first('demo_time_state',
        where: 'center_id = ?', whereArgs: [demoCenterId]);
    if (state == null) {
      throw StateError('الزمن التجريبي غير مهيأ. أنشئ المركز التجريبي أولاً.');
    }
    return state;
  }
}
