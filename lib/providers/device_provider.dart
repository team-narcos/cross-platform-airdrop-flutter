import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
// Note: We will create a simple signaling service to help devices find each other.
// For now, it is a placeholder.
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/device_model.dart';

class DeviceProvider extends ChangeNotifier {
  // --- WebRTC Properties ---
  RTCPeerConnection? _peerConnection;
  final List<DeviceModel> _discoveredDevices = [];
  SignalingService _signalingService = SignalingService();

  // --- App State Properties ---
  DeviceModel? _currentDevice; // You can still get local device info
  bool _isConnecting = false;

  List<DeviceModel> get discoveredDevices => _discoveredDevices;
  bool get isConnecting => _isConnecting;

  // Constructor
  Future<void> initialize() async {
    // We will connect to our signaling server to discover other devices
    _signalingService.connect();

    // Listen for messages from the signaling server
    _signalingService.onMessage = (type, data) {
      switch (type) {
        case 'peers':
          // The server sent us a list of other connected devices
          final List peers = data['peers'];
          _discoveredDevices.clear();
          for (var peer in peers) {
            _discoveredDevices.add(DeviceModel.fromJson(peer));
          }
          notifyListeners();
          break;
        // Other cases for handling WebRTC offers/answers will go here later
      }
    };
  }

  Future<void> connectToDevice(DeviceModel device) async {
    _isConnecting = true;
    notifyListeners();

    // In WebRTC, you create a "peer connection"
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    }, {});

    // Then you create an "offer" to send to the other device
    RTCSessionDescription offer = await _peerConnection!.createOffer({});
    await _peerConnection!.setLocalDescription(offer);

    // We send this offer via the signaling server
    _signalingService.send('offer', {
      'offer': offer.toMap(),
      'target': device.id, // The ID of the device we want to connect to
    });

    _isConnecting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _signalingService.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }
}

// --- A simple Signaling Service using WebSockets ---
// This is a basic client. You will need a simple server for this to connect to.
class SignalingService {
  WebSocketChannel? _channel;
  Function(String type, dynamic data)? onMessage;

  void connect() {
    try {
      // --- IMPORTANT ---
      // Connect to a local signaling server for stable development.
      // You need to run a simple WebSocket server on your machine.
      // The '10.0.2.2' IP is a special alias for your computer's localhost from the Android emulator.
      final uri = kIsWeb
          ? Uri.parse('ws://localhost:8080') // For web, use localhost
          : Uri.parse(
              'ws://10.0.2.2:8080'); // For Android emulator, use the special IP

      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen((message) {
        final decoded = jsonDecode(message);
        final type = decoded['type'];
        final data = decoded['data'];
        if (onMessage != null) {
          onMessage!(type, data);
        }
      }, onError: (error) {
        debugPrint('Signaling Error: $error');
      }, onDone: () {
        debugPrint('Signaling Channel Closed');
      });
    } catch (e) {
      debugPrint('Error connecting to signaling server: $e');
    }
  }

  void send(String type, dynamic data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': type, 'data': data}));
    }
  }

  void dispose() {
    _channel?.sink.close();
  }
}
