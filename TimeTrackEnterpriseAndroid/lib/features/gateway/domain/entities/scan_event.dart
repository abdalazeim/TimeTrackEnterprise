/// A barcode accepted by the local HTTP gateway (`/scans`).
class ScanEvent {
  const ScanEvent({
    required this.seq,
    required this.code,
    required this.at,
  });

  final int seq;
  final String code;
  final DateTime at;

  Map<String, Object?> toJson() => <String, Object?>{
        'seq': seq,
        'code': code,
        'at': at.millisecondsSinceEpoch,
      };
}
