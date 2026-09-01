import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/camera_device_info.dart';

class NetworkDiscoveryService {
  RawDatagramSocket? _broadcasterSocket;
  RawDatagramSocket? _listenerSocket;
  Timer? _broadcastTimer;

  final StreamController<List<CameraDeviceInfo>> _discoveredCamerasController =
      StreamController<List<CameraDeviceInfo>>.broadcast();

  final Map<String, CameraDeviceInfo> _discoveredCameras = {};
  Timer? _cleanupTimer;

  Stream<List<CameraDeviceInfo>> get discoveredCamerasStream =>
      _discoveredCamerasController.stream;

  List<CameraDeviceInfo> get discoveredCameras =>
      _discoveredCameras.values.toList();

  /// Start broadcasting camera existence over local Wi-Fi UDP
  Future<void> startBroadcasting({
    required String deviceName,
    required int streamPort,
    required int controlPort,
  }) async {
    stopBroadcasting();
    try {
      _broadcasterSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _broadcasterSocket?.broadcastEnabled = true;

      _broadcastTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
        final localIps = await getLocalIpAddresses();
        final ip = localIps.isNotEmpty ? localIps.first : '127.0.0.1';
        final payload = jsonEncode({
          'sig': AppConstants.discoverySignature,
          'deviceName': deviceName,
          'ip': ip,
          'streamPort': streamPort,
          'controlPort': controlPort,
          'timestamp': DateTime.now().toIso8601String(),
        });

        final data = utf8.encode(payload);

        // Broadcast to the subnet-directed address of every local interface
        // (e.g. 192.168.1.255) in addition to the limited broadcast, because
        // many routers/APs silently drop 255.255.255.255.
        final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
        for (final localIp in localIps) {
          final parts = localIp.split('.');
          if (parts.length == 4) {
            parts[3] = '255';
            try {
              targets.add(InternetAddress(parts.join('.')));
            } catch (_) {}
          }
        }

        for (final target in targets) {
          try {
            _broadcasterSocket?.send(data, target, AppConstants.discoveryPort);
          } catch (e) {
            debugPrint('Discovery broadcast to $target error: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to start UDP broadcaster: $e');
    }
  }

  void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcasterSocket?.close();
    _broadcasterSocket = null;
  }

  /// Start listening for camera beacons on the local network
  Future<void> startListening() async {
    stopListening();
    try {
      _listenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
        reusePort: false,
      );
      _listenerSocket?.broadcastEnabled = true;

      _listenerSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenerSocket?.receive();
          if (datagram != null) {
            _handleIncomingBeacon(datagram);
          }
        }
      });

      // Cleanup cameras that haven't sent a heartbeat in 10 seconds
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final now = DateTime.now();
        final expiredKeys = <String>[];
        _discoveredCameras.forEach((key, cam) {
          if (now.difference(cam.lastSeen).inSeconds > 8) {
            expiredKeys.add(key);
          }
        });
        if (expiredKeys.isNotEmpty) {
          for (final key in expiredKeys) {
            _discoveredCameras.remove(key);
          }
          _discoveredCamerasController.add(_discoveredCameras.values.toList());
        }
      });
    } catch (e) {
      debugPrint('Failed to start UDP listener: $e');
    }
  }

  void _handleIncomingBeacon(Datagram datagram) {
    try {
      final msg = utf8.decode(datagram.data);
      final json = jsonDecode(msg) as Map<String, dynamic>;
      if (json['sig'] == AppConstants.discoverySignature) {
        final ip = datagram.address.address;
        final deviceName = json['deviceName'] as String? ?? 'Jokarz Camera';
        final streamPort = json['streamPort'] as int? ?? AppConstants.defaultHttpPort;
        final controlPort = json['controlPort'] as int? ?? AppConstants.defaultControlPort;

        final device = CameraDeviceInfo(
          id: 'cam_$ip',
          ip: ip,
          streamPort: streamPort,
          controlPort: controlPort,
          deviceName: deviceName,
          lastSeen: DateTime.now(),
        );

        _discoveredCameras[device.id] = device;
        _discoveredCamerasController.add(_discoveredCameras.values.toList());
      }
    } catch (e) {
      // Ignore invalid packet
    }
  }

  void stopListening() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _listenerSocket?.close();
    _listenerSocket = null;
  }

  /// Get local active IPv4 addresses
  static Future<List<String>> getLocalIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting IP interfaces: $e');
    }
    return ips;
  }

  void dispose() {
    stopBroadcasting();
    stopListening();
    _discoveredCamerasController.close();
  }
}
