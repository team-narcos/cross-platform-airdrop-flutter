import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/simple_transfer_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SimpleTransferProvider(),
      child: MaterialApp(
        title: 'AirDrop Flutter',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: SimpleFileShareScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SimpleFileShareScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SimpleTransferProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Simple File Share'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.share, size: 64, color: Colors.blue),
                        SizedBox(height: 16),
                        Text(
                          'Cross-Platform File Sharing',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          provider.serverStatus,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                ElevatedButton.icon(
                  onPressed: provider.isServerRunning 
                      ? null 
                      : () => provider.startServer(),
                  icon: Icon(Icons.power_settings_new),
                  label: Text(provider.isServerRunning ? 'Server Running' : 'Start Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.isServerRunning ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                
                SizedBox(height: 16),
                
                ElevatedButton.icon(
                  onPressed: () => provider.pickAndShareFile(),
                  icon: Icon(Icons.file_upload),
                  label: Text('Share Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                
                SizedBox(height: 16),
                
                if (provider.sharedFiles.isNotEmpty) ...[
                  Text(
                    'Shared Files:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: provider.sharedFiles.length,
                      itemBuilder: (context, index) {
                        final file = provider.sharedFiles[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.insert_drive_file),
                            title: Text(file['name']),
                            subtitle: Text('${(file['size'] / 1024).toStringAsFixed(1)} KB'),
                            trailing: IconButton(
                              icon: Icon(Icons.copy),
                              onPressed: () => provider.copyShareUrl(file['name']),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}