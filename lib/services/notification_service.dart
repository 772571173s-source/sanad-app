class SanadNotification {
  const SanadNotification({
    required this.id,
    required this.centerId,
    required this.studentId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String centerId;
  final String studentId;
  final String title;
  final String body;
  final String type;
  final String createdAt;
  final bool read;
}

class NotificationService {
  const NotificationService();

  SanadNotification homeworkCreated(
      {required String centerId,
      required String studentId,
      required String title}) {
    return SanadNotification(
      id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
      centerId: centerId,
      studentId: studentId,
      title: 'واجب جديد',
      body: title,
      type: 'homework',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  SanadNotification reportReady(
      {required String centerId,
      required String studentId,
      required String type}) {
    return SanadNotification(
      id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
      centerId: centerId,
      studentId: studentId,
      title: 'تقرير جاهز',
      body: type,
      type: 'report',
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}
