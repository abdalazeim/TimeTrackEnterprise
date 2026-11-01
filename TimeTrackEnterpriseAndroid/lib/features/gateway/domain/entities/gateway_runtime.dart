/// Live state of the local HTTP gateway.
class GatewayRuntime {
  const GatewayRuntime({
    this.running = false,
    this.starting = false,
    this.port = 8080,
    this.error,
    this.startedAt,
    this.scansPending = 0,
    this.scansReceived = 0,
  });

  final bool running;
  final bool starting;
  final int port;
  final String? error;
  final DateTime? startedAt;
  final int scansPending;
  final int scansReceived;

  GatewayRuntime copyWith({
    bool? running,
    bool? starting,
    int? port,
    String? error,
    bool clearError = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    int? scansPending,
    int? scansReceived,
  }) {
    return GatewayRuntime(
      running: running ?? this.running,
      starting: starting ?? this.starting,
      port: port ?? this.port,
      error: clearError ? null : (error ?? this.error),
      startedAt:
          clearStartedAt ? null : (startedAt ?? this.startedAt),
      scansPending: scansPending ?? this.scansPending,
      scansReceived: scansReceived ?? this.scansReceived,
    );
  }
}
