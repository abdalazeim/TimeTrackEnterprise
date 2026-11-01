/// Persistent configuration for the local attendance HTTP gateway.
///
/// The values mirror the original *Attendance Gateway* app: a four digit
/// pairing PIN, a 32 character hexadecimal API key and a port in the
/// user-accessible range.
class GatewaySettings {
  const GatewaySettings({
    required this.port,
    required this.apiKey,
    required this.pairPin,
    required this.deviceId,
    required this.autoStart,
    required this.keepAwake,
  });

  static const int defaultPort = 8080;
  static const int minPort = 1024;
  static const int maxPort = 65535;

  final int port;
  final String apiKey;
  final String pairPin;
  final String deviceId;
  final bool autoStart;
  final bool keepAwake;

  bool get authRequired => apiKey.isNotEmpty;
  bool get pairingEnabled => pairPin.isNotEmpty;

  String get serverUrl => 'http://0.0.0.0:$port';

  GatewaySettings copyWith({
    int? port,
    String? apiKey,
    String? pairPin,
    String? deviceId,
    bool? autoStart,
    bool? keepAwake,
  }) {
    return GatewaySettings(
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      pairPin: pairPin ?? this.pairPin,
      deviceId: deviceId ?? this.deviceId,
      autoStart: autoStart ?? this.autoStart,
      keepAwake: keepAwake ?? this.keepAwake,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'port': port,
        'api_key': apiKey,
        'pair_pin': pairPin,
        'device_id': deviceId,
        'auto_start': autoStart,
        'keep_awake': keepAwake,
      };

  factory GatewaySettings.fromJson(Map<String, Object?> json) {
    final rawPort = (json['port'] as num?)?.toInt() ?? defaultPort;
    return GatewaySettings(
      port: rawPort < minPort || rawPort > maxPort ? defaultPort : rawPort,
      apiKey: (json['api_key'] as String?) ?? '',
      pairPin: (json['pair_pin'] as String?) ?? '',
      deviceId: (json['device_id'] as String?) ?? '',
      autoStart: json['auto_start'] as bool? ?? false,
      keepAwake: json['keep_awake'] as bool? ?? true,
    );
  }
}
