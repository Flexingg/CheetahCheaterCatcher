class CameraDeviceInfo {
  final String id;
  final String ip;
  final int streamPort;
  final int controlPort;
  final String deviceName;
  final DateTime lastSeen;
  final bool isTorchOn;
  final double zoom;
  final int fps;

  CameraDeviceInfo({
    required this.id,
    required this.ip,
    required this.streamPort,
    required this.controlPort,
    required this.deviceName,
    DateTime? lastSeen,
    this.isTorchOn = false,
    this.zoom = 1.0,
    this.fps = 30,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get streamUrl => 'http://$ip:$streamPort/live';
  String get controlWsUrl => 'ws://$ip:$controlPort/ws/control';

  CameraDeviceInfo copyWith({
    String? id,
    String? ip,
    int? streamPort,
    int? controlPort,
    String? deviceName,
    DateTime? lastSeen,
    bool? isTorchOn,
    double? zoom,
    int? fps,
  }) {
    return CameraDeviceInfo(
      id: id ?? this.id,
      ip: ip ?? this.ip,
      streamPort: streamPort ?? this.streamPort,
      controlPort: controlPort ?? this.controlPort,
      deviceName: deviceName ?? this.deviceName,
      lastSeen: lastSeen ?? this.lastSeen,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      zoom: zoom ?? this.zoom,
      fps: fps ?? this.fps,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ip': ip,
        'streamPort': streamPort,
        'controlPort': controlPort,
        'deviceName': deviceName,
        'lastSeen': lastSeen.toIso8601String(),
        'isTorchOn': isTorchOn,
        'zoom': zoom,
        'fps': fps,
      };

  factory CameraDeviceInfo.fromJson(Map<String, dynamic> json) => CameraDeviceInfo(
        id: json['id'] as String? ?? 'cam_${json['ip']}',
        ip: json['ip'] as String,
        streamPort: json['streamPort'] as int? ?? 8080,
        controlPort: json['controlPort'] as int? ?? 8081,
        deviceName: json['deviceName'] as String? ?? 'Jokarz Camera',
        lastSeen: DateTime.tryParse(json['lastSeen'] ?? '') ?? DateTime.now(),
        isTorchOn: json['isTorchOn'] as bool? ?? false,
        zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
        fps: json['fps'] as int? ?? 30,
      );
}
