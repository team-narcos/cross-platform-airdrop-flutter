import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/device_model.dart';

class DeviceProvider extends ChangeNotifier {
  final List<DeviceModel> _discoveredDevices = [];
  DeviceModel? _currentDevice;
  Timer? _discoveryTimer;
  Timer? _broadcastTimer;
  Timer? _heartbeatTimer;
  bool _isDiscovering = false;
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();

  // WebSocket connection
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  bool _isConnected = false;

  // Signaling server URL
  static const String _signalingServerUrl =
      'wss://05538fa4-e385-477a-87a8-931b4c9d6a50-00-3pwqi7zydzj4c.sisko.replit.dev:3000';

  List<DeviceModel> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  DeviceModel? get currentDevice => _currentDevice;
  bool get isDiscovering => _isDiscovering;
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    await _initializeCurrentDevice();
    await _connectToSignalingServer();
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

  Future<void> _connectToSignalingServer() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(_signalingServerUrl),
      );

      _channelSubscription = _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          notifyListeners();
          _attemptReconnection();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;
          notifyListeners();
          _attemptReconnection();
        },
      );

      _isConnected = true;
      notifyListeners();
      debugPrint('Connected to signaling server');
    } catch (e) {
      debugPrint('Failed to connect to signaling server: $e');
      _isConnected = false;
      notifyListeners();
      _attemptReconnection();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final messageType = data['type'] as String?;

      switch (messageType) {
        case 'device_announcement':
          _handleDeviceAnnouncement(data);
          break;
        case 'device_list':
          _handleDeviceList(data);
          break;
        case 'device_offline':
          _handleDeviceOffline(data);
          break;
        case 'ping':
          _handlePing(data);
          break;
        case 'pong':
          _handlePong(data);
          break;
        default:
          debugPrint('Unknown message type: $messageType');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  void _handleDeviceAnnouncement(Map<String, dynamic> data) {
    print('DEBUG: Device announcement data: $data'); // Add debug
    try {
      final deviceData = data['device'] as Map<String, dynamic>;
      print('DEBUG: Extracted device data: $deviceData'); // Add debug

      final device = DeviceModel(
        id: deviceData['id'] as String,
        name: deviceData['name'] as String,
        ipAddress: deviceData['ipAddress'] as String,
        type: _parseDeviceType(deviceData['type'] as String),
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      print(
          'DEBUG: Created device object: ${device.name}, ID: ${device.id}'); // Add debug
      addDiscoveredDevice(device);
      print(
          'DEBUG: Device added to list. Total devices: ${_discoveredDevices.length}'); // Add debug
    } catch (e) {
      debugPrint('Error handling device announcement: $e');
    }
  }

  void _handleDeviceList(Map<String, dynamic> data) {
    try {
      final devices = data['devices'] as List<dynamic>;
      for (final deviceData in devices) {
        final device = DeviceModel(
          id: deviceData['id'] as String,
          name: deviceData['name'] as String,
          ipAddress: deviceData['ipAddress'] as String,
          type: _parseDeviceType(deviceData['type'] as String),
          isOnline: deviceData['isOnline'] as bool? ?? true,
          lastSeen: DateTime.now(),
        );
        addDiscoveredDevice(device);
      }
    } catch (e) {
      debugPrint('Error handling device list: $e');
    }
  }

  void _handleDeviceOffline(Map<String, dynamic> data) {
    try {
      final deviceId = data['deviceId'] as String;
      updateDeviceStatus(deviceId, false);
    } catch (e) {
      debugPrint('Error handling device offline: $e');
    }
  }

  void _handlePing(Map<String, dynamic> data) {
    try {
      final fromDeviceId = data['fromDeviceId'] as String;
      _sendPong(fromDeviceId);
    } catch (e) {
      debugPrint('Error handling ping: $e');
    }
  }

  void _handlePong(Map<String, dynamic> data) {
    try {
      final fromDeviceId = data['fromDeviceId'] as String;
      updateDeviceStatus(fromDeviceId, true);
    } catch (e) {
      debugPrint('Error handling pong: $e');
    }
  }

  DeviceType _parseDeviceType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'android':
        return DeviceType.android;
      case 'ios':
        return DeviceType.ios;
      case 'windows':
        return DeviceType.windows;
      case 'macos':
        return DeviceType.macos;
      case 'linux':
        return DeviceType.linux;
      default:
        return DeviceType.unknown;
    }
  }

  String _deviceTypeToString(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return 'android';
      case DeviceType.ios:
        return 'ios';
      case DeviceType.windows:
        return 'windows';
      case DeviceType.macos:
        return 'macos';
      case DeviceType.linux:
        return 'linux';
      case DeviceType.unknown:
        return 'unknown';
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    notifyListeners();

    // Ensure we're connected to the signaling server
    if (!_isConnected) {
      await _connectToSignalingServer();
    }

    // Start broadcasting our presence
    _startBroadcast();

    // Start heartbeat to keep connection alive
    _startHeartbeat();

    // Request current device list
    _requestDeviceList();

    // Clean up offline devices periodically
    _startCleanupTimer();
  }

  void _startBroadcast() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _broadcastPresence();
    });

    // Broadcast immediately
    _broadcastPresence();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHeartbeat();
    });
  }

  void _startCleanupTimer() {
    Timer.periodic(const Duration(seconds: 60), (timer) {
      _cleanupOfflineDevices();
    });
  }

  Future<void> _broadcastPresence() async {
    if (_currentDevice == null || !_isConnected) return;

    try {
      final message = {
        'type': 'announce_device',
        'device': {
          'id': _currentDevice!.id,
          'name': _currentDevice!.name,
          'ipAddress': _currentDevice!.ipAddress,
          'type': _deviceTypeToString(_currentDevice!.type),
          'isOnline': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      };

      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error broadcasting presence: $e');
    }
  }

  void _requestDeviceList() {
    if (!_isConnected) return;

    try {
      final message = {
        'type': 'request_device_list',
        'fromDeviceId': _currentDevice?.id,
      };

      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error requesting device list: $e');
    }
  }

  void _sendHeartbeat() {
    if (!_isConnected) return;

    try {
      final message = {
        'type': 'heartbeat',
        'deviceId': _currentDevice?.id,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending heartbeat: $e');
    }
  }

  void _sendPong(String toDeviceId) {
    if (!_isConnected) return;

    try {
      final message = {
        'type': 'pong',
        'fromDeviceId': _currentDevice?.id,
        'toDeviceId': toDeviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending pong: $e');
    }
  }

  void addDiscoveredDevice(DeviceModel device) {
    print(
        'DEBUG: Adding device: ${device.name} with ID: ${device.id}'); // Add debug

    // Don't add our own device
    if (device.id == _currentDevice?.id) {
      print('DEBUG: Skipping own device'); // Add debug
      return;
    }

    final existingIndex =
        _discoveredDevices.indexWhere((d) => d.id == device.id);
    if (existingIndex != -1) {
      print(
          'DEBUG: Updating existing device at index $existingIndex'); // Add debug
      _discoveredDevices[existingIndex] = device.copyWith(
        isOnline: true,
        lastSeen: DateTime.now(),
      );
    } else {
      print('DEBUG: Adding new device to list'); // Add debug
      _discoveredDevices.add(device);
    }

    print(
        'DEBUG: Total discovered devices now: ${_discoveredDevices.length}'); // Add debug
    print(
        'DEBUG: Device list: ${_discoveredDevices.map((d) => d.name).toList()}'); // Add debug

    notifyListeners(); // This is crucial!
    print('DEBUG: notifyListeners() called'); // Add debug
  }

  void removeDiscoveredDevice(String deviceId) {
    _discoveredDevices.removeWhere((device) => device.id == deviceId);
    notifyListeners();
  }

  void updateDeviceStatus(String deviceId, bool isOnline) {
    final index =
        _discoveredDevices.indexWhere((device) => device.id == deviceId);
    if (index != -1) {
      _discoveredDevices[index] = _discoveredDevices[index].copyWith(
        isOnline: isOnline,
        lastSeen:
            isOnline ? DateTime.now() : _discoveredDevices[index].lastSeen,
      );
      notifyListeners();
    }
  }

  void _cleanupOfflineDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((device) {
      final timeSinceLastSeen = now.difference(device.lastSeen);
      return timeSinceLastSeen.inMinutes >
          5; // Remove devices not seen for 5 minutes
    });

    // Mark devices as offline if not seen recently
    for (int i = 0; i < _discoveredDevices.length; i++) {
      final timeSinceLastSeen = now.difference(_discoveredDevices[i].lastSeen);
      if (timeSinceLastSeen.inMinutes > 2 && _discoveredDevices[i].isOnline) {
        _discoveredDevices[i] = _discoveredDevices[i].copyWith(isOnline: false);
      }
    }
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _discoveryTimer?.cancel();
    _broadcastTimer?.cancel();
    _heartbeatTimer?.cancel();

    // Send offline notification
    if (_isConnected && _currentDevice != null) {
      try {
        final message = {
          'type': 'device_offline',
          'deviceId': _currentDevice!.id,
        };
        _channel?.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('Error sending offline notification: $e');
      }
    }

    notifyListeners();
  }

  void clearDiscoveredDevices() {
    _discoveredDevices.clear();
    notifyListeners();
  }

  Future<bool> pingDevice(DeviceModel device) async {
    if (!_isConnected) return false;

    try {
      final message = {
        'type': 'ping',
        'fromDeviceId': _currentDevice?.id,
        'toDeviceId': device.id,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _channel?.sink.add(jsonEncode(message));

      // Wait for pong response (timeout after 5 seconds)
      final completer = Completer<bool>();
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          updateDeviceStatus(device.id, false);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('Error pinging device: $e');
      updateDeviceStatus(device.id, false);
      return false;
    }
  }

  void _attemptReconnection() {
    if (_isDiscovering && !_isConnected) {
      Timer(const Duration(seconds: 5), () {
        if (!_isConnected) {
          debugPrint('Attempting to reconnect to signaling server...');
          _connectToSignalingServer();
        }
      });
    }
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _broadcastTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
