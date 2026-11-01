/// Models for the offline scanning database (`offline_scan.db`).
library;

class Student {
  const Student({
    required this.nin,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.classGroup,
    required this.active,
  });

  final String nin;
  final String firstName;
  final String lastName;
  final String fullName;
  final String classGroup;
  final bool active;

  String get displayName => fullName.isEmpty ? nin : fullName;
}

class AttendancePeriod {
  const AttendancePeriod({
    required this.id,
    required this.name,
    required this.startTime,
    required this.onTimeCutoff,
    required this.absentCutoff,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String startTime;
  final String onTimeCutoff;
  final String absentCutoff;
  final int sortOrder;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'start_time': startTime,
        'on_time_cutoff': onTimeCutoff,
        'absent_cutoff_time': absentCutoff,
        'sort_order': sortOrder,
      };

  factory AttendancePeriod.fromJson(Map<String, Object?> json) {
    return AttendancePeriod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      startTime: (json['start_time'] as String?) ?? '00:00:00',
      onTimeCutoff: (json['on_time_cutoff'] as String?) ?? '00:00:00',
      absentCutoff: (json['absent_cutoff_time'] as String?) ?? '23:59:59',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class OfflineStatus {
  const OfflineStatus._();

  static const String present = 'present';
  static const String late = 'late';
  static const String inactive = 'inactive';
  static const String duplicate = 'duplicate';
  static const String notFound = 'not_found';
  static const String noPeriod = 'no_period';

  static bool isArrival(String status) =>
      status == present || status == late || status == duplicate;

  static String labelAr(String status) {
    switch (status) {
      case present:
        return 'حاضر';
      case late:
        return 'متأخر';
      case inactive:
        return 'غير نشط';
      case duplicate:
        return 'مسجل مسبقاً';
      case noPeriod:
        return 'خارج الحصة';
      case notFound:
        return 'غير موجود';
      default:
        return status;
    }
  }

  static String labelEn(String status) {
    switch (status) {
      case present:
        return 'Present';
      case late:
        return 'Late';
      case inactive:
        return 'Inactive';
      case duplicate:
        return 'Already recorded';
      case noPeriod:
        return 'No active period';
      case notFound:
        return 'Not found';
      default:
        return status;
    }
  }
}

class ScanVerdict {
  const ScanVerdict({
    required this.status,
    this.student,
    this.period,
    this.clientId,
    this.scannedAt,
  });

  final String status;
  final Student? student;
  final AttendancePeriod? period;
  final String? clientId;
  final String? scannedAt;

  bool get queued => clientId != null;
  String get displayName =>
      student?.fullName.isNotEmpty == true ? student!.fullName : '';
}

class QueuedScan {
  const QueuedScan({
    required this.id,
    required this.clientId,
    required this.code,
    required this.scannedAt,
    required this.scanDate,
    required this.status,
    required this.studentName,
    required this.classGroup,
    required this.synced,
    this.studentNin,
    this.syncStatus,
    this.syncMessage,
  });

  final int id;
  final String clientId;
  final String code;
  final String scannedAt;
  final String scanDate;
  final String status;
  final String studentName;
  final String classGroup;
  final bool synced;
  final String? studentNin;
  final String? syncStatus;
  final String? syncMessage;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'client_id': clientId,
        'code': code,
        'scanned_at': scannedAt,
        'scan_date': scanDate,
        'local_status': status,
        'student_name': studentName,
        'class_group': classGroup,
        'sync_status': syncStatus,
        'sync_message': syncMessage,
        'synced': synced,
      };
}

class OfflineStats {
  const OfflineStats({
    this.today = 0,
    this.todayLate = 0,
    this.pending = 0,
    this.synced = 0,
  });

  final int today;
  final int todayLate;
  final int pending;
  final int synced;
}
