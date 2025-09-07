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

  List<TransferModel> get transfers => List.unmodifiable(_transfers);
  List<TransferModel> get transferHistory =>
      List.unmodifiable(_transferHistory);
  List<TransferModel> get activeTransfers =>
      _transfers.where((t) => t.status.isActive).toList();

  Future<void> initialize() async {
    await _loadTransferHistory();
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
          debugPrint('Error loading transfer from history: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading transfer history: $e');
    }
  }

  Future<void> _saveTransferHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _transferHistory
          .take(50) // Keep only last 50 transfers
          .map((t) => t.toJson().toString())
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
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
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

    // Start the transfer process
    _initiateTransfer(transfer);

    return transfer;
  }

  Future<void> _initiateTransfer(TransferModel transfer) async {
    try {
      // Update status to connecting
      _updateTransferStatus(transfer.id, TransferStatus.connecting);

      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 1));

      // Start the actual transfer
      await _performTransfer(transfer);
    } catch (e) {
      _updateTransferStatus(transfer.id, TransferStatus.failed,
          errorMessage: e.toString());
    }
  }

  Future<void> _performTransfer(TransferModel transfer) async {
    _updateTransferStatus(transfer.id, TransferStatus.transferring);

    // Create a timer to simulate transfer progress
    const updateInterval = Duration(milliseconds: 100);
    const bytesPerUpdate = 1024 * 50; // 50KB per update (simulated)

    _transferTimers[transfer.id] = Timer.periodic(updateInterval, (timer) {
      final currentTransfer = _getTransferById(transfer.id);
      if (currentTransfer == null || !currentTransfer.status.isActive) {
        timer.cancel();
        return;
      }

      final newBytesTransferred = min(
        currentTransfer.bytesTransferred + bytesPerUpdate,
        currentTransfer.fileSize,
      );

      final newProgress = newBytesTransferred / currentTransfer.fileSize;

      _updateTransferProgress(transfer.id, newBytesTransferred, newProgress);

      // Complete transfer when done
      if (newBytesTransferred >= currentTransfer.fileSize) {
        timer.cancel();
        _completeTransfer(transfer.id);
      }
    });
  }

  void _updateTransferStatus(String transferId, TransferStatus status,
      {String? errorMessage}) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index != -1) {
      _transfers[index] = _transfers[index].copyWith(
        status: status,
        errorMessage: errorMessage,
      );
      notifyListeners();
    }
  }

  void _updateTransferProgress(
      String transferId, int bytesTransferred, double progress) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index != -1) {
      _transfers[index] = _transfers[index].copyWith(
        bytesTransferred: bytesTransferred,
        progress: progress,
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
      );

      _transfers[index] = completedTransfer;

      // Move to history
      _transferHistory.insert(0, completedTransfer);
      _saveTransferHistory();

      notifyListeners();

      // Clean up timers
      _transferTimers[transferId]?.cancel();
      _transferTimers.remove(transferId);
    }
  }

  TransferModel? _getTransferById(String id) {
    try {
      return _transfers.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  void pauseTransfer(String transferId) {
    final transfer = _getTransferById(transferId);
    if (transfer != null && transfer.status.canPause) {
      _transferTimers[transferId]?.cancel();
      _updateTransferStatus(transferId, TransferStatus.paused);
    }
  }

  void resumeTransfer(String transferId) {
    final transfer = _getTransferById(transferId);
    if (transfer != null && transfer.status.canResume) {
      _performTransfer(transfer);
    }
  }

  void cancelTransfer(String transferId) {
    final transfer = _getTransferById(transferId);
    if (transfer != null && transfer.status.canCancel) {
      _transferTimers[transferId]?.cancel();
      _transferSubscriptions[transferId]?.cancel();

      _updateTransferStatus(transferId, TransferStatus.cancelled);

      // Move to history
      final cancelledTransfer =
          _transfers.firstWhere((t) => t.id == transferId);
      _transferHistory.insert(0, cancelledTransfer);

      // Clean up
      _transferTimers.remove(transferId);
      _transferSubscriptions.remove(transferId);
      _saveTransferHistory();
    }
  }

  void retryTransfer(String transferId) {
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
      _transfers[index] = resetTransfer;
      notifyListeners();

      // Restart transfer
      _initiateTransfer(resetTransfer);
    }
  }

  void removeTransfer(String transferId) {
    // Cancel if active
    cancelTransfer(transferId);

    // Remove from transfers list
    _transfers.removeWhere((t) => t.id == transferId);
    notifyListeners();
  }

  void clearTransferHistory() {
    _transferHistory.clear();
    _saveTransferHistory();
    notifyListeners();
  }

  void clearCompletedTransfers() {
    _transfers.removeWhere((t) =>
        t.status == TransferStatus.completed ||
        t.status == TransferStatus.cancelled ||
        t.status == TransferStatus.failed);
    notifyListeners();
  }

  String _getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();

    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      case '.mp4':
        return 'video/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  // Statistics methods
  int get totalTransfers => _transferHistory.length + _transfers.length;

  int get completedTransfers =>
      _transferHistory
          .where((t) => t.status == TransferStatus.completed)
          .length +
      _transfers.where((t) => t.status == TransferStatus.completed).length;

  int get failedTransfers =>
      _transferHistory.where((t) => t.status == TransferStatus.failed).length +
      _transfers.where((t) => t.status == TransferStatus.failed).length;

  double get successRate {
    if (totalTransfers == 0) return 0.0;
    return completedTransfers / totalTransfers;
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

  @override
  void dispose() {
    // Cancel all active transfers
    for (final timer in _transferTimers.values) {
      timer.cancel();
    }
    for (final subscription in _transferSubscriptions.values) {
      subscription.cancel();
    }
    _transferTimers.clear();
    _transferSubscriptions.clear();
    super.dispose();
  }
}
