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
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().initialize();
      context.read<FileTransferProvider>().initialize();
    });
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
      actions: [
        Consumer<DeviceProvider>(
          builder: (context, deviceProvider, child) {
            return IconButton(
              onPressed: deviceProvider.isDiscovering
                  ? deviceProvider.stopDiscovery
                  : deviceProvider.startDiscovery,
              icon: Icon(
                deviceProvider.isDiscovering ? Icons.stop : Icons.refresh,
              ),
              tooltip: deviceProvider.isDiscovering
                  ? 'Stop Discovery'
                  : 'Refresh Devices',
            );
          },
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'about',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('About'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startDiscovery(DeviceProvider deviceProvider) async {
    try {
      debugPrint('HomeScreen: Starting discovery...');
      await deviceProvider.startDiscovery();
      _showSuccessSnackBar('Device discovery started');
    } catch (e) {
      debugPrint('HomeScreen: Error starting discovery: $e');
      _showErrorSnackBar('Failed to start discovery: $e');
    }
  }

  Future<void> _stopDiscovery(DeviceProvider deviceProvider) async {
    try {
      debugPrint('HomeScreen: Stopping discovery...');
      await deviceProvider.stopDiscovery();
      _showSuccessSnackBar('Device discovery stopped');
    } catch (e) {
      debugPrint('HomeScreen: Error stopping discovery: $e');
      _showErrorSnackBar('Failed to stop discovery: $e');
    }
  }

  Widget _buildSendTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<DeviceProvider>().startDiscovery();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentDeviceCard(),
            const SizedBox(height: 20),
            _buildConnectionStatusCard(),
            const SizedBox(height: 20),
            _buildDeviceDiscoverySection(),
            const SizedBox(height: 20),
            if (_selectedDevice != null) ...[
              _buildFilePickerSection(),
              const SizedBox(height: 20),
            ],
            _buildActiveTransfersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveTab() {
    return Consumer<FileTransferProvider>(
      builder: (context, transferProvider, child) {
        final incomingTransfers = transferProvider.transfers
            .where((t) => t.direction == TransferDirection.receive)
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            await context.read<DeviceProvider>().startDiscovery();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReceiveStatusCard(),
                const SizedBox(height: 20),
                if (incomingTransfers.isNotEmpty) ...[
                  _buildSectionHeader(
                      'Incoming Transfers', incomingTransfers.length),
                  const SizedBox(height: 12),
                  ...incomingTransfers.map((transfer) => TransferProgressWidget(
                        transfer: transfer,
                        showDetails: true,
                      )),
                ] else
                  _buildEmptyReceiveState(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<FileTransferProvider>(
      builder: (context, transferProvider, child) {
        final history = transferProvider.transferHistory;

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh logic if needed
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHistoryStatsCard(transferProvider),
                const SizedBox(height: 20),
                if (history.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('Transfer History', history.length),
                      TextButton.icon(
                        onPressed: () =>
                            _showClearHistoryDialog(transferProvider),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...history.take(20).map((transfer) => TransferProgressWidget(
                        transfer: transfer,
                        showDetails: false,
                      )),
                ] else
                  _buildEmptyHistoryState(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentDeviceCard() {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final currentDevice = deviceProvider.currentDevice;

        if (currentDevice == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Loading device information...'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(
                      currentDevice.type.iconAsset,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentDevice.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currentDevice.type.displayName} • ${currentDevice.ipAddress}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Ready to share',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceDiscoverySection() {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final devices = deviceProvider.discoveredDevices;

        debugPrint(
            'HomeScreen: Building device discovery section with ${devices.length} devices');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Available Devices', devices.length),
                if (deviceProvider.isDiscovering)
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
                    onTap: () => _selectDevice(device),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildFilePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Select Files to Send', 0),
        const SizedBox(height: 12),
        FilePickerWidget(
          onFilesSelected: _sendFiles,
          allowMultiple: true,
        ),
      ],
    );
  }

  Widget _buildActiveTransfersSection() {
    return Consumer<FileTransferProvider>(
      builder: (context, transferProvider, child) {
        final activeTransfers = transferProvider.activeTransfers
            .where((t) => t.direction == TransferDirection.send)
            .toList();

        if (activeTransfers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Active Transfers', activeTransfers.length),
            const SizedBox(height: 12),
            ...activeTransfers.map((transfer) => TransferProgressWidget(
                  transfer: transfer,
                  showDetails: true,
                )),
          ],
        );
      },
    );
  }

  Widget _buildReceiveStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.download_rounded,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ready to Receive',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your device is discoverable by nearby devices. Files sent to you will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
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

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Text(
      count > 0 ? '$title ($count)' : title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyDeviceState(DeviceProvider deviceProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.devices,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              deviceProvider.isDiscovering
                  ? 'Searching for devices...'
                  : 'No devices found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deviceProvider.isDiscovering
                  ? 'Make sure other devices have the app open'
                  : 'Tap refresh to search again',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReceiveState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            const Text(
              'No incoming transfers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Files sent to your device will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            const Text(
              'No transfer history',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed and failed transfers will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return Consumer<FileTransferProvider>(
      builder: (context, transferProvider, child) {
        final activeTransfersCount = transferProvider.activeTransfers.length;

        if (activeTransfersCount == 0) return const SizedBox.shrink();

        return FloatingActionButton.extended(
          onPressed: () => _showActiveTransfersDialog(transferProvider),
          icon: const Icon(Icons.sync),
          label: Text('$activeTransfersCount Active'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        );
      },
    );
  }

  void _selectDevice(DeviceModel device) {
    setState(() {
      _selectedDevice = _selectedDevice?.id == device.id ? null : device;
    });
    debugPrint('HomeScreen: Selected device: ${device.name} (${device.id})');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}