import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';

class FileTransferProvider extends ChangeNotifier {
  final List<TransferModel> _transfers = [];
  final List<TransferModel> _transferHistory = [];
  final Map<String, Timer> _transferTimers = {};
  final Map<String, StreamSubscription> _transferSubscriptions = {};
  final Uuid _uuid = const Uuid();
  
  // Connection management
  final Map<String, bool> _activeConnections = {};
  bool _isInitialized = false;

  List<TransferModel> get transfers => List.unmodifiable(_transfers);
  List<TransferModel> get transferHistory => List.unmodifiable(_transferHistory);
  List<TransferModel> get activeTransfers => _transfers.where((t) => t.status.isActive).toList();
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadTransferHistory();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize FileTransferProvider: $e');
      rethrow;
    }
  }

  Future<void> _loadTransferHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('transfer_history') ?? [];
      
      _transferHistory.clear();
      
      for (final jsonString in historyJson) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
          final transfer = TransferModel.fromJson(jsonMap);
          _transferHistory.add(transfer);
        } catch (e) {
          debugPrint('Error parsing transfer history item: $e');
          // Continue with other items instead of failing completely
        }
      }
      
      // Sort by most recent first
      _transferHistory.sort((a, b) => (b.startTime ?? DateTime.now()).compareTo(a.startTime ?? DateTime.now()));
      
    } catch (e) {
      debugPrint('Error loading transfer history: $e');
      // Don't rethrow - app should continue working even if history fails to load
    }
  }

  Future<void> _saveTransferHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Keep only the most recent 100 transfers and ensure they're not null
      final validHistory = _transferHistory
          .where((t) => t.id.isNotEmpty)
          .take(100)
          .toList();
      
      final historyJson = validHistory
          .map((t) => jsonEncode(t.toJson()))
          .toList();

      await prefs.setStringList('transfer_history', historyJson);
    } catch (e) {
      debugPrint('Error saving transfer history: $e');
    }
  }

  Future<TransferModel> startFileTransfer({
    required String filePath,
    required DeviceModel fromDevice,
    required DeviceModel toDevice,
    required TransferDirection direction,
  }) async {
    // Validate inputs
    if (filePath.isEmpty) {
      throw ArgumentError('File path cannot be empty');
    }
    
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File does not exist', filePath);
    }

    // Check file accessibility
    try {
      await file.length(); // This will throw if file is not accessible
    } catch (e) {
      throw FileSystemException('File is not accessible', filePath);
    }

    final fileName = path.basename(filePath);
    final fileSize = await file.length();
    final mimeType = _getMimeType(fileName);

    final transfer = TransferModel(
      id: _uuid.v4(),
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      mimeType: mimeType,
      fromDevice: fromDevice,
      toDevice: toDevice,
      status: TransferStatus.pending,
      direction: direction,
      startTime: DateTime.now(),
    );

    _transfers.add(transfer);
    notifyListeners();

    // Start the transfer process asynchronously
    unawaited(_initiateTransfer(transfer));

    return transfer;
  }

  Future<void> _initiateTransfer(TransferModel transfer) async {
    try {
      // Check if transfer was cancelled before starting
      final currentTransfer = _getTransferById(transfer.id);
      if (currentTransfer?.status == TransferStatus.cancelled) {
        return;
      }

      // Update status to connecting
      _updateTransferStatus(transfer.id, TransferStatus.connecting);

      // Simulate connection establishment with timeout
      final connectionFuture = _establishConnection(transfer);
      final timeoutFuture = Future.delayed(
        const Duration(seconds: 10),
        () => throw TimeoutException('Connection timeout', const Duration(seconds: 10)),
      );

      await Future.any([connectionFuture, timeoutFuture]);

      // Check again if transfer was cancelled during connection
      final updatedTransfer = _getTransferById(transfer.id);
      if (updatedTransfer?.status == TransferStatus.cancelled) {
        return;
      }

      // Start the actual transfer
      await _performTransfer(transfer);
      
    } catch (e) {
      String errorMessage = 'Transfer failed: ${e.toString()}';
      
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout';
      } else if (e is FileSystemException) {
        errorMessage = 'File access error: ${e.message}';
      }
      
      _updateTransferStatus(transfer.id, TransferStatus.failed, errorMessage: errorMessage);
    }
  }

  Future<void> _establishConnection(TransferModel transfer) async {
    // Simulate connection delay with some variability
    final connectionTime = 1000 + Random().nextInt(2000); // 1-3 seconds
    await Future.delayed(Duration(milliseconds: connectionTime));
    
    _activeConnections[transfer.id] = true;
  }

  Future<void> _performTransfer(TransferModel transfer) async {
    try {
      _updateTransferStatus(transfer.id, TransferStatus.transferring);

      // Dynamic transfer speed based on file size
      final baseSpeed = _calculateTransferSpeed(transfer.fileSize);
      const updateInterval = Duration(milliseconds: 100);
      final bytesPerUpdate = (baseSpeed * updateInterval.inMilliseconds / 1000).round();

      _transferTimers[transfer.id] = Timer.periodic(updateInterval, (timer) {
        final currentTransfer = _getTransferById(transfer.id);
        if (currentTransfer == null || !currentTransfer.status.isActive) {
          timer.cancel();
          _transferTimers.remove(transfer.id);
          return;
        }

        // Add some randomness to simulate real network conditions
        final randomVariation = Random().nextDouble() * 0.3 + 0.85; // 85%-115% of base speed
        final adjustedBytesPerUpdate = (bytesPerUpdate * randomVariation).round();

        final newBytesTransferred = min(
          currentTransfer.bytesTransferred + adjustedBytesPerUpdate,
          currentTransfer.fileSize,
        );

        final newProgress = newBytesTransferred / currentTransfer.fileSize;

        _updateTransferProgress(transfer.id, newBytesTransferred, newProgress);

        // Complete transfer when done
        if (newBytesTransferred >= currentTransfer.fileSize) {
          timer.cancel();
          _transferTimers.remove(transfer.id);
          _completeTransfer(transfer.id);
        }
      });

    } catch (e) {
      _updateTransferStatus(transfer.id, TransferStatus.failed, errorMessage: e.toString());
    }
  }

  int _calculateTransferSpeed(int fileSize) {
    // Simulate different speeds based on file size (bytes per second)
    if (fileSize < 1024 * 1024) { // < 1MB
      return 1024 * 500; // 500KB/s
    } else if (fileSize < 10 * 1024 * 1024) { // < 10MB
      return 1024 * 1024; // 1MB/s
    } else if (fileSize < 100 * 1024 * 1024) { // < 100MB
      return 1024 * 1024 * 2; // 2MB/s
    } else {
      return 1024 * 1024 * 5; // 5MB/s for large files
    }
  }

  void _updateTransferStatus(String transferId, TransferStatus status, {String? errorMessage}) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index != -1) {
      _transfers[index] = _transfers[index].copyWith(
        status: status,
        errorMessage: errorMessage,
      );
      notifyListeners();
    }
  }

  void _updateTransferProgress(String transferId, int bytesTransferred, double progress) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index != -1) {
      _transfers[index] = _transfers[index].copyWith(
        bytesTransferred: bytesTransferred,
        progress: progress.clamp(0.0, 1.0), // Ensure progress is always between 0 and 1
      );
      notifyListeners();
    }
  }

  void _completeTransfer(String transferId) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index != -1) {
      final completedTransfer = _transfers[index].copyWith(
        status: TransferStatus.completed,
        endTime: DateTime.now(),
        progress: 1.0, // Ensure progress is exactly 1.0 when completed
      );

      _transfers[index] = completedTransfer;

      // Move to history (insert at beginning for most recent first)
      _transferHistory.insert(0, completedTransfer);
      
      // Clean up resources
      _cleanupTransfer(transferId);
      
      // Save history asynchronously
      unawaited(_saveTransferHistory());
      
      notifyListeners();
    }
  }

  void _cleanupTransfer(String transferId) {
    _transferTimers[transferId]?.cancel();
    _transferTimers.remove(transferId);
    _transferSubscriptions[transferId]?.cancel();
    _transferSubscriptions.remove(transferId);
    _activeConnections.remove(transferId);
  }

  TransferModel? _getTransferById(String id) {
    try {
      return _transfers.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  bool pauseTransfer(String transferId) {
    final transfer = _getTransferById(transferId);
    if (transfer != null && transfer.status.canPause) {
      _transferTimers[transferId]?.cancel();
      _updateTransferStatus(transferId, TransferStatus.paused);
      return true;
    }
    return false;
  }

  bool resumeTransfer(String transferId) {
    final transfer = _getTransferById(transferId);
    if (transfer != null && transfer.status.canResume) {
      unawaited(_performTransfer(transfer));
      return true;
    }
    return false;
  }

  bool cancelTransfer(String transferId) {
    final transfer = _getTransferById(transferId);
    if (transfer != null && transfer.status.canCancel) {
      _cleanupTransfer(transferId);
      _updateTransferStatus(transferId, TransferStatus.cancelled);

      // Move to history
      final cancelledTransfer = _transfers.firstWhere((t) => t.id == transferId);
      _transferHistory.insert(0, cancelledTransfer);
      
      unawaited(_saveTransferHistory());
      return true;
    }
    return false;
  }

  bool retryTransfer(String transferId) {
    final transfer = _getTransferById(transferId);
    if (transfer != null && transfer.status == TransferStatus.failed) {
      // Reset transfer progress
      final resetTransfer = transfer.copyWith(
        status: TransferStatus.pending,
        bytesTransferred: 0,
        progress: 0.0,
        errorMessage: null,
        startTime: DateTime.now(),
        endTime: null,
      );

      final index = _transfers.indexWhere((t) => t.id == transferId);
      if (index != -1) {
        _transfers[index] = resetTransfer;
        notifyListeners();

        // Restart transfer
        unawaited(_initiateTransfer(resetTransfer));
        return true;
      }
    }
    return false;
  }

  void removeTransfer(String transferId) {
    // Cancel if active
    cancelTransfer(transferId);

    // Remove from transfers list
    _transfers.removeWhere((t) => t.id == transferId);
    notifyListeners();
  }

  Future<void> clearTransferHistory() async {
    _transferHistory.clear();
    await _saveTransferHistory();
    notifyListeners();
  }

  void clearCompletedTransfers() {
    final toRemove = _transfers.where((t) =>
        t.status == TransferStatus.completed ||
        t.status == TransferStatus.cancelled ||
        t.status == TransferStatus.failed).toList();
    
    // Clean up resources for removed transfers
    for (final transfer in toRemove) {
      _cleanupTransfer(transfer.id);
    }
    
    _transfers.removeWhere((t) =>
        t.status == TransferStatus.completed ||
        t.status == TransferStatus.cancelled ||
        t.status == TransferStatus.failed);
    
    notifyListeners();
  }

  String _getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();

    const mimeTypes = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      '.html': 'text/html',
      '.css': 'text/css',
      '.js': 'application/javascript',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.mp4': 'video/mp4',
      '.avi': 'video/x-msvideo',
      '.mkv': 'video/x-matroska',
      '.mov': 'video/quicktime',
      '.wmv': 'video/x-ms-wmv',
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.flac': 'audio/flac',
      '.aac': 'audio/aac',
      '.ogg': 'audio/ogg',
      '.zip': 'application/zip',
      '.rar': 'application/vnd.rar',
      '.7z': 'application/x-7z-compressed',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',
    };

    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  // Enhanced statistics methods
  int get totalTransfers => _transferHistory.length + _transfers.length;

  int get completedTransfers =>
      _transferHistory.where((t) => t.status == TransferStatus.completed).length +
      _transfers.where((t) => t.status == TransferStatus.completed).length;

  int get failedTransfers =>
      _transferHistory.where((t) => t.status == TransferStatus.failed).length +
      _transfers.where((t) => t.status == TransferStatus.failed).length;

  int get cancelledTransfers =>
      _transferHistory.where((t) => t.status == TransferStatus.cancelled).length +
      _transfers.where((t) => t.status == TransferStatus.cancelled).length;

  double get successRate {
    if (totalTransfers == 0) return 0.0;
    return (completedTransfers / totalTransfers).clamp(0.0, 1.0);
  }

  int get totalBytesTransferred {
    int total = 0;
    
    for (final transfer in _transferHistory) {
      if (transfer.status == TransferStatus.completed) {
        total += transfer.fileSize;
      }
    }
    
    for (final transfer in _transfers) {
      if (transfer.status == TransferStatus.completed) {
        total += transfer.fileSize;
      }
    }
    
    return total;
  }

  // Get average transfer speed
  double get averageTransferSpeed {
    final completedList = [
      ..._transferHistory.where((t) => 
          t.status == TransferStatus.completed && 
          t.startTime != null && 
          t.endTime != null),
      ..._transfers.where((t) => 
          t.status == TransferStatus.completed && 
          t.startTime != null && 
          t.endTime != null),
    ];

    if (completedList.isEmpty) return 0.0;

    double totalSpeed = 0.0;
    int validTransfers = 0;

    for (final transfer in completedList) {
      final duration = transfer.endTime!.difference(transfer.startTime!).inMilliseconds;
      if (duration > 0) {
        final speed = transfer.fileSize / (duration / 1000.0); // bytes per second
        totalSpeed += speed;
        validTransfers++;
      }
    }

    return validTransfers > 0 ? totalSpeed / validTransfers : 0.0;
  }

  // Get current transfer speed for active transfers
  Map<String, double> get currentTransferSpeeds {
    final speeds = <String, double>{};
    
    for (final transfer in _transfers.where((t) => t.status == TransferStatus.transferring)) {
      if (transfer.startTime != null && transfer.bytesTransferred > 0) {
        final elapsed = DateTime.now().difference(transfer.startTime!).inMilliseconds;
        if (elapsed > 0) {
          speeds[transfer.id] = transfer.bytesTransferred / (elapsed / 1000.0);
        }
      }
    }
    
    return speeds;
  }

  @override
  void dispose() {
    // Cancel all active transfers and clean up resources
    for (final transferId in _transferTimers.keys.toList()) {
      _cleanupTransfer(transferId);
    }
    
    _transfers.clear();
    _transferHistory.clear();
    _activeConnections.clear();
    
    super.dispose();
  }
}

// Helper extension for unawaited futures
extension Unawaited on Future {
  void get unawaited {}
}