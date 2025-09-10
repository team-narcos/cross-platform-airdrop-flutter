import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'
    show FilePicker, FilePickerResult, FileType;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

class FilePickerWidget extends StatefulWidget {
  final Function(List<String>) onFilesSelected;
  final bool allowMultiple;
  final List<String>? allowedExtensions;

  const FilePickerWidget({
    super.key,
    required this.onFilesSelected,
    this.allowMultiple = true,
    this.allowedExtensions,
  });

  @override
  State<FilePickerWidget> createState() => _FilePickerWidgetState();
}

class _FilePickerWidgetState extends State<FilePickerWidget> {
  final List<String> _selectedFiles = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFileTypeButtons(),
          const SizedBox(height: 16),
          if (_selectedFiles.isNotEmpty) ...[
            _buildSelectedFilesList(),
            const SizedBox(height: 16),
          ],
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.folder_open,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Files to Share',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              Text(
                widget.allowMultiple
                    ? 'Choose one or more files'
                    : 'Choose a single file',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (_selectedFiles.isNotEmpty)
          IconButton(
            onPressed: _clearSelection,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all',
          ),
      ],
    );
  }

  Widget _buildFileTypeButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFileTypeButton(
          icon: Icons.photo,
          label: 'Photos',
          color: Colors.blue,
          onPressed: () => _pickFiles(FileType.image),
        ),
        _buildFileTypeButton(
          icon: Icons.videocam,
          label: 'Videos',
          color: Colors.red,
          onPressed: () => _pickFiles(FileType.video),
        ),
        _buildFileTypeButton(
          icon: Icons.music_note,
          label: 'Audio',
          color: Colors.orange,
          onPressed: () => _pickFiles(FileType.audio),
        ),
        _buildFileTypeButton(
          icon: Icons.description,
          label: 'Documents',
          color: Colors.green,
          onPressed: () =>
              _pickFiles(FileType.custom, ['pdf', 'doc', 'docx', 'txt']),
        ),
        _buildFileTypeButton(
          icon: Icons.folder,
          label: 'Any File',
          color: Colors.purple,
          onPressed: () => _pickFiles(FileType.any),
        ),
      ],
    );
  }

  Widget _buildFileTypeButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildSelectedFilesList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Files (${_selectedFiles.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_selectedFiles.length, (index) {
            final filePath = _selectedFiles[index];
            return _buildFileItem(filePath, index);
          }),
        ],
      ),
    );
  }

  Widget _buildFileItem(String filePath, int index) {
    final fileName = path.basename(filePath);
    final file = File(filePath);

    return FutureBuilder<int>(
      future: file.length(),
      builder: (context, snapshot) {
        final fileSize = snapshot.data ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _getFileIcon(fileName),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeFile(index),
                icon: const Icon(Icons.close),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _getFileIcon(String fileName) {
    final extension = path.extension(fileName).toLowerCase();

    IconData iconData;
    Color color;

    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        iconData = Icons.image;
        color = Colors.blue;
        break;
      case '.mp4':
      case '.avi':
      case '.mov':
        iconData = Icons.movie;
        color = Colors.red;
        break;
      case '.mp3':
      case '.wav':
      case '.m4a':
        iconData = Icons.music_note;
        color = Colors.orange;
        break;
      case '.pdf':
        iconData = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case '.doc':
      case '.docx':
        iconData = Icons.description;
        color = Colors.blue;
        break;
      case '.txt':
        iconData = Icons.text_snippet;
        color = Colors.grey;
        break;
      case '.zip':
      case '.rar':
        iconData = Icons.archive;
        color = Colors.amber;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(
      iconData,
      color: color,
      size: 24,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_selectedFiles.isNotEmpty)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendFiles,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? 'Processing...' : 'Send Files'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        if (_selectedFiles.isNotEmpty) const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _isLoading ? null : () => _pickFiles(FileType.any),
          icon: const Icon(Icons.add),
          label: const Text('Add More'),
        ),
      ],
    );
  }

  Future<void> _pickFiles(FileType type,
      [List<String>? allowedExtensions]) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request permissions
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showPermissionDialog();
          return;
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: widget.allowMultiple && _selectedFiles.isEmpty,
        allowedExtensions: allowedExtensions ?? widget.allowedExtensions,
      );

      if (result != null) {
        final newFiles =
            result.paths.where((path) => path != null).cast<String>();

        setState(() {
          if (widget.allowMultiple) {
            _selectedFiles.addAll(
                newFiles.where((file) => !_selectedFiles.contains(file)));
          } else {
            _selectedFiles.clear();
            _selectedFiles.addAll(newFiles);
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Error selecting files: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  void _sendFiles() {
    if (_selectedFiles.isNotEmpty) {
      widget.onFilesSelected(_selectedFiles);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
            'Storage permission is required to access files. Please grant permission in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
