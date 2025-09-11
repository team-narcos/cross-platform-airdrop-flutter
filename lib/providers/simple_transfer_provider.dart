import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class SimpleTransferProvider extends ChangeNotifier {
  HttpServer? _server;
  bool _isServerRunning = false;
  String _serverUrl = '';
  List<Map<String, dynamic>> _sharedFiles = [];
  
  bool get isServerRunning => _isServerRunning;
  String get serverStatus => _isServerRunning ? 'Server: $_serverUrl' : 'Server not started';
  List<Map<String, dynamic>> get sharedFiles => _sharedFiles;
  
  Future<void> startServer() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final sharedDir = Directory('${appDir.path}/shared');
      if (!await sharedDir.exists()) {
        await sharedDir.create(recursive: true);
      }
      
      final handler = _createHandler(sharedDir.path);
      
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      final ip = await _getLocalIpAddress();
      _serverUrl = 'http://$ip:8080';
      _isServerRunning = true;
      
      print('Server started: $_serverUrl');
      notifyListeners();
    } catch (e) {
      print('Failed to start server: $e');
    }
  }
  
  Handler _createHandler(String sharedDirPath) {
    return (Request request) async {
      // Add CORS headers manually
      final headers = <String, String>{
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      };
      
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      
      final path = request.url.path;
      
      if (path == 'files' || path == '') {
        final response = _handleFilesList(sharedDirPath);
        return response.change(headers: headers);
      }
      
      if (path.startsWith('download/')) {
        final filename = path.substring(9);
        final response = _handleFileDownload(sharedDirPath, filename);
        return response.change(headers: headers);
      }
      
      return Response.notFound('Not found', headers: headers);
    };
  }
  
  Response _handleFilesList(String sharedDirPath) {
    try {
      final dir = Directory(sharedDirPath);
      if (!dir.existsSync()) {
        return Response.ok('<h2>No files shared yet</h2>', 
          headers: {'Content-Type': 'text/html'});
      }
      
      final files = dir.listSync()
          .where((entity) => entity is File)
          .map((file) => {
                'name': (file as File).uri.pathSegments.last,
                'size': file.lengthSync(),
              })
          .toList();
      
      final html = '''
<!DOCTYPE html>
<html>
<head>
    <title>Shared Files</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; margin: 20px; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .file { padding: 15px; border: 1px solid #ddd; margin: 10px 0; border-radius: 5px; background: #fafafa; }
        a { text-decoration: none; color: #2196F3; font-weight: bold; }
        .size { color: #666; font-size: 14px; }
        h2 { color: #333; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h2>📁 Shared Files (${files.length})</h2>
        ${files.isEmpty ? '<p>No files shared yet</p>' : files.map((f) {
          final sizeKB = ((f['size'] as int) / 1024).toStringAsFixed(1);
          return '<div class="file"><a href="/download/${f['name']}">${f['name']}</a><br><span class="size">$sizeKB KB</span></div>';
        }).join('')}
    </div>
</body>
</html>
      ''';
      
      return Response.ok(html, headers: {'Content-Type': 'text/html'});
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  }
  
  Response _handleFileDownload(String sharedDirPath, String filename) {
    try {
      final file = File('$sharedDirPath/$filename');
      if (!file.existsSync()) {
        return Response.notFound('File not found');
      }
      
      final bytes = file.readAsBytesSync();
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="$filename"',
          'Content-Length': bytes.length.toString(),
        },
      );
    } catch (e) {
      return Response.internalServerError(body: 'Download failed: $e');
    }
  }
  
  Future<void> pickAndShareFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final sharedDir = Directory('${appDir.path}/shared');
        
        if (!await sharedDir.exists()) {
          await sharedDir.create(recursive: true);
        }
        
        for (final file in result.files) {
          if (file.path != null) {
            final sourceFile = File(file.path!);
            final targetFile = File('${sharedDir.path}/${file.name}');
            await sourceFile.copy(targetFile.path);
            
            // Check if file already exists in list
            final existingIndex = _sharedFiles.indexWhere((f) => f['name'] == file.name);
            
            if (existingIndex >= 0) {
              // Update existing file
              _sharedFiles[existingIndex] = {
                'name': file.name,
                'size': file.size,
                'path': targetFile.path,
              };
            } else {
              // Add new file
              _sharedFiles.add({
                'name': file.name,
                'size': file.size,
                'path': targetFile.path,
              });
            }
          }
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error sharing file: $e');
    }
  }
  
  Future<void> copyShareUrl(String filename) async {
    final url = '$_serverUrl/download/$filename';
    await Clipboard.setData(ClipboardData(text: url));
  }
  
  Future<String> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && 
              !addr.isLoopback && 
              !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting IP: $e');
    }
    return '192.168.1.100';
  }
  
  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }
}