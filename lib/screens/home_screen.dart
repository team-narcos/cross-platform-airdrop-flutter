import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../providers/file_transfer_provider.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../widgets/device_list_item.dart';
import '../widgets/file_picker_widget.dart';
import '../widgets/transfer_progress_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DeviceModel? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // The new provider initializes itself in its constructor, so we don't need to call initialize() here.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSendTab(),
          _buildReceiveTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('WebRTC File Share'),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.send), text: 'Send'),
          Tab(icon: Icon(Icons.download), text: 'Receive'),
          Tab(icon: Icon(Icons.history), text: 'History'),
        ],
      ),
    );
  }

  Widget _buildSendTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // On the web, we don't need to show the current device info.
          if (!kIsWeb) ...[
            _buildCurrentDeviceCard(),
            const SizedBox(height: 20),
          ],
          _buildDeviceDiscoverySection(),
          const SizedBox(height: 20),
          if (_selectedDevice != null) ...[
            _buildFilePickerSection(),
            const SizedBox(height: 20),
          ],
          _buildActiveTransfersSection(),
        ],
      ),
    );
  }

  Widget _buildDeviceDiscoverySection() {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final devices = deviceProvider.discoveredDevices;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Available Devices', devices.length),
                if (deviceProvider.isConnecting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              _buildEmptyDeviceState()
            else
              ...devices.map((device) => DeviceListItem(
                    device: device,
                    isSelected: _selectedDevice?.id == device.id,
                    onTap: () {
                      _selectDevice(device);
                      deviceProvider.connectToDevice(device);
                    },
                  )),
          ],
        );
      },
    );
  }
  
  // --- The rest of the file has been simplified or has placeholders ---

  Widget _buildCurrentDeviceCard() {
    // This is simplified as the new provider doesn't expose local device info yet
    return const Card(
      child: ListTile(
        leading: Icon(Icons.person),
        title: Text('My Device'),
        subtitle: Text('Ready to share files'),
      ),
    );
  }

  Widget _buildEmptyDeviceState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'Searching for devices via signaling server...\nMake sure other devices are running the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
  
  void _selectDevice(DeviceModel device) {
    setState(() {
      _selectedDevice = _selectedDevice?.id == device.id ? null : device;
    });
  }

  // --- Placeholder methods for functionality we will build next ---

  Future<void> _sendFiles(List<String> filePaths) async {
    if (_selectedDevice == null) {
      _showErrorSnackBar('Please select a device first');
      return;
    }
    // TODO: Implement file sending via WebRTC Data Channel
    _showSuccessSnackBar('File transfer logic not yet implemented.');
  }

  Widget _buildReceiveTab() {
    return const Center(child: Text('Receive Tab'));
  }

  Widget _buildHistoryTab() {
    return const Center(child: Text('History Tab'));
  }

  Widget _buildFilePickerSection() {
    return FilePickerWidget(onFilesSelected: _sendFiles);
  }
  
  Widget _buildActiveTransfersSection() {
    return const SizedBox.shrink(); // Placeholder
  }
  
  Widget? _buildFloatingActionButton() {
    return null; // Placeholder
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  Widget _buildSectionHeader(String title, int count) {
    return Text(
      count > 0 ? '$title ($count)' : title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}