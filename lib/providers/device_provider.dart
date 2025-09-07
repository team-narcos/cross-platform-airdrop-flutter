import 'dart:async';

import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';

class DeviceProvider extends ChangeNotifier {
  final List<DeviceModel> _discoveredDevices = [];
  DeviceModel? _currentDevice;
  Timer? _discoveryTimer;
  Timer? _broadcastTimer;
  bool _isDiscovering = false;
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();

  List<DeviceModel> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  DeviceModel? get currentDevice => _currentDevice;
  bool get isDiscovering => _isDiscovering;

  Future<void> initialize() async {
    await _initializeCurrentDevice();
    await startDiscovery();
  }

  Future<void> _initializeCurrentDevice() async {
    try {
      final deviceId = _uuid.v4();
      final deviceName = await _getDeviceName();
      final ipAddress = await _networkInfo.getWifiIP() ?? '127.0.0.1';
      final deviceType = await _getDeviceType();

      _currentDevice = DeviceModel(
        id: deviceId,
        name: deviceName,
        ipAddress: ipAddress,
        type: deviceType,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing current device: $e');
    }
  }

  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return '${iosInfo.name}';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        return macInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        return linuxInfo.name;
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }
    return 'Unknown Device';
  }

  Future<DeviceType> _getDeviceType() async {
    if (Platform.isAndroid) return DeviceType.android;
    if (Platform.isIOS) return DeviceType.ios;
    if (Platform.isWindows) return DeviceType.windows;
    if (Platform.isMacOS) return DeviceType.macos;
    if (Platform.isLinux) return DeviceType.linux;
    return DeviceType.unknown;
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    notifyListeners();

    // Start broadcasting our presence
    _startBroadcast();

    // Start discovering other devices
    _startDeviceDiscovery();

    // Clean up offline devices periodically
    _startCleanupTimer();
  }

  void _startBroadcast() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _broadcastPresence();
    });
  }

  void _startDeviceDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _scanForDevices();
    });
  }

  void _startCleanupTimer() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _cleanupOfflineDevices();
    });
  }

  Future<void> _broadcastPresence() async {
    if (_currentDevice == null) return;

    try {
      // In a real implementation, this would use UDP multicast or similar
      // For now, we'll simulate the broadcast
      await _simulateBroadcast();
    } catch (e) {
      debugPrint('Error broadcasting presence: $e');
    }
  }

  Future<void> _simulateBroadcast() async {
    // This simulates other devices discovering us
    // In a real app, this would involve actual network communication
  }

  Future<void> _scanForDevices() async {
    try {
      // In a real implementation, this would scan the network for other devices
      // For demo purposes, we'll simulate finding devices
      await _simulateDeviceDiscovery();
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
    }
  }

  Future<void> _simulateDeviceDiscovery() async {
    // Simulate discovering random devices for demo purposes
    if (_discoveredDevices.length < 3 && Random().nextBool()) {
      final newDevice = _generateRandomDevice();
      addDiscoveredDevice(newDevice);
    }
  }

  DeviceModel _generateRandomDevice() {
    final deviceNames = [
      'John\'s iPhone',
      'Sarah\'s MacBook',
      'Mike\'s Android',
      'Lisa\'s iPad',
      'Tom\'s Windows PC',
      'Anna\'s Galaxy',
    ];

    final deviceTypes = DeviceType.values.where((type) => type != DeviceType.unknown).toList();
    final random = Random();

    return DeviceModel(
      id: _uuid.v4(),
      name: deviceNames[random.nextInt(deviceNames.length)],
      ipAddress: '192.168.1.${random.nextInt(254) + 1}',
      type: deviceTypes[random.nextInt(deviceTypes.length)],
      isOnline: true,
      lastSeen: DateTime.now(),
    );
  }

  void addDiscoveredDevice(DeviceModel device) {
    // Don't add our own device
    if (device.id == _currentDevice?.id) return;

    final existingIndex = _discoveredDevices.indexWhere((d) => d.id == device.id);
    if (existingIndex != -1) {
      _discoveredDevices[existingIndex] = device.copyWith(
        isOnline: true,
        lastSeen: DateTime.now(),
      );
    } else {
      _discoveredDevices.add(device);
    }
    notifyListeners();
  }

  void removeDiscoveredDevice(String deviceId) {
    _discoveredDevices.removeWhere((device) => device.id == deviceId);
    notifyListeners();
  }

  void updateDeviceStatus(String deviceId, bool isOnline) {
    final index = _discoveredDevices.indexWhere((device) => device.id == deviceId);
    if (index != -1) {
      _discoveredDevices[index] = _discoveredDevices[index].copyWith(
        isOnline: isOnline,
        lastSeen: isOnline ? DateTime.now() : _discoveredDevices[index].lastSeen,
      );
      notifyListeners();
    }
  }

  void _cleanupOfflineDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((device) {
      final timeSinceLastSeen = now.difference(device.lastSeen);
      return timeSinceLastSeen.inMinutes > 2; // Remove devices not seen for 2 minutes
    });
    
    // Mark devices as offline if not seen recently
    for (int i = 0; i < _discoveredDevices.length; i++) {
      final timeSinceLastSeen = now.difference(_discoveredDevices[i].lastSeen);
      if (timeSinceLastSeen.inSeconds > 30 && _discoveredDevices[i].isOnline) {
        _discoveredDevices[i] = _discoveredDevices[i].copyWith(isOnline: false);
      }
    }
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _discoveryTimer?.cancel();
    _broadcastTimer?.cancel();
    notifyListeners();
  }

  void clearDiscoveredDevices() {
    _discoveredDevices.clear();
    notifyListeners();
  }

  Future<bool> pingDevice(DeviceModel device) async {
    try {
      // In a real implementation, this would ping the actual device
      // For demo purposes, we'll simulate a ping result
      await Future.delayed(const Duration(milliseconds: 500));
      final isReachable = Random().nextBool();
      
      updateDeviceStatus(device.id, isReachable);
      return isReachable;
    } catch (e) {
      debugPrint('Error pinging device: $e');
      updateDeviceStatus(device.id, false);
      return false;
    }
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _broadcastTimer?.cancel();
    super.dispose();
  }
}