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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isInitialized) {
        await _initializeProviders();
      }
    });
  }

  Future<void> _initializeProviders() async {
    try {
      debugPrint('HomeScreen: Initializing providers...');
      final deviceProvider = context.read<DeviceProvider>();
      final transferProvider = context.read<FileTransferProvider>();

      await deviceProvider.initialize();
      await transferProvider.initialize();

      _isInitialized = true;
      debugPrint('HomeScreen: Providers initialized successfully');

      // Start discovery immediately after initialization
      await deviceProvider.startDiscovery();
    } catch (e) {
      debugPrint('HomeScreen: Error initializing providers: $e');
      _showErrorSnackBar('Failed to initialize: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
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
      title: const Text(
        'AirDrop Flutter',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(
            icon: Icon(Icons.send),
            text: 'Send',
          ),
          Tab(
            icon: Icon(Icons.download),
            text: 'Receive',
          ),
          Tab(
            icon: Icon(Icons.history),
            text: 'History',
          ),
        ],
      ),
      actions: [
        Consumer<DeviceProvider>(
          builder: (context, deviceProvider, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Connection status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        deviceProvider.isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: deviceProvider.isDiscovering
                      ? () => _stopDiscovery(deviceProvider)
                      : () => _startDiscovery(deviceProvider),
                  icon: Icon(
                    deviceProvider.isDiscovering ? Icons.stop : Icons.refresh,
                  ),
                  tooltip: deviceProvider.isDiscovering
                      ? 'Stop Discovery'
                      : 'Refresh Devices',
                ),
              ],
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
        final deviceProvider = context.read<DeviceProvider>();
        await _startDiscovery(deviceProvider);
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
            final deviceProvider = context.read<DeviceProvider>();
            await _startDiscovery(deviceProvider);
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
                            decoration: BoxDecoration(
                              color: deviceProvider.isConnected
                                  ? Colors.green
                                  : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            deviceProvider.isConnected
                                ? 'Ready to share'
                                : 'Connecting...',
                            style: TextStyle(
                              color: deviceProvider.isConnected
                                  ? Colors.green
                                  : Colors.orange,
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

  Widget _buildConnectionStatusCard() {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        return Card(
          color: deviceProvider.isConnected
              ? Colors.green.shade50
              : Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  deviceProvider.isConnected
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color:
                      deviceProvider.isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceProvider.isConnected
                            ? 'Connected to Server'
                            : 'Connecting to Server',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: deviceProvider.isConnected
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        deviceProvider.isConnected
                            ? 'Ready for device discovery'
                            : 'Attempting to connect...',
                        style: TextStyle(
                          fontSize: 12,
                          color: deviceProvider.isConnected
                              ? Colors.green.shade600
                              : Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!deviceProvider.isConnected)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                Row(
                  children: [
                    if (deviceProvider.isDiscovering)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        deviceProvider.clearDiscoveredDevices();
                        _startDiscovery(deviceProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              _buildEmptyDeviceState(deviceProvider)
            else
              Column(
                children: devices
                    .map((device) => DeviceListItem(
                          device: device,
                          isSelected: _selectedDevice?.id == device.id,
                          onTap: () => _selectDevice(device),
                        ))
                    .toList(),
              ),
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
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 48,
                  color: deviceProvider.isConnected
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  deviceProvider.isConnected
                      ? 'Ready to Receive'
                      : 'Not Connected',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  deviceProvider.isConnected
                      ? 'Your device is discoverable by nearby devices. Files sent to you will appear here.'
                      : 'Connect to start receiving files from other devices.',
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
      },
    );
  }

  Widget _buildHistoryStatsCard(FileTransferProvider transferProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transfer Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    transferProvider.totalTransfers.toString(),
                    Icons.swap_horiz,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Success',
                    transferProvider.completedTransfers.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Failed',
                    transferProvider.failedTransfers.toString(),
                    Icons.error,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Success Rate',
                    '${(transferProvider.successRate * 100).toStringAsFixed(0)}%',
                    Icons.trending_up,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Data Transferred',
                    _formatBytes(transferProvider.totalBytesTransferred),
                    Icons.data_usage,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
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
              !deviceProvider.isConnected
                  ? 'Not connected to server'
                  : deviceProvider.isDiscovering
                      ? 'Searching for devices...'
                      : 'No devices found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              !deviceProvider.isConnected
                  ? 'Check your internet connection'
                  : deviceProvider.isDiscovering
                      ? 'Make sure other devices have the app open and are connected'
                      : 'Tap refresh to search again or make sure other devices are online',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (!deviceProvider.isConnected) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _startDiscovery(deviceProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
              ),
            ],
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

  Future<void> _sendFiles(List<String> filePaths) async {
    if (_selectedDevice == null) {
      _showErrorSnackBar('Please select a device first');
      return;
    }

    final deviceProvider = context.read<DeviceProvider>();
    final transferProvider = context.read<FileTransferProvider>();
    final currentDevice = deviceProvider.currentDevice;

    if (currentDevice == null) {
      _showErrorSnackBar('Current device not initialized');
      return;
    }

    try {
      for (final filePath in filePaths) {
        await transferProvider.startFileTransfer(
          filePath: filePath,
          fromDevice: currentDevice,
          toDevice: _selectedDevice!,
          direction: TransferDirection.send,
        );
      }

      _showSuccessSnackBar('Transfer started for ${filePaths.length} file(s)');

      // Switch to active transfers view
      _tabController.animateTo(0);
    } catch (e) {
      _showErrorSnackBar('Failed to start transfer: $e');
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        _showSettingsDialog();
        break;
      case 'about':
        _showAboutDialog();
        break;
    }
  }

  void _showActiveTransfersDialog(FileTransferProvider transferProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Transfers'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: transferProvider.activeTransfers.length,
            itemBuilder: (BuildContext context, int index) => index >=
                    transferProvider.activeTransfers.length
                ? const SizedBox.shrink()
                : ListTile(
                    leading: Icon(
                      transferProvider.activeTransfers[index].direction ==
                              TransferDirection.send
                          ? Icons.upload
                          : Icons.download,
                    ),
                    title:
                        Text(transferProvider.activeTransfers[index].fileName),
                    subtitle: Text(
                        '${(transferProvider.activeTransfers[index].progress * 100).toStringAsFixed(0)}%'),
                    trailing: Text(transferProvider
                        .activeTransfers[index].status.displayName),
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(FileTransferProvider transferProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content:
            const Text('Are you sure you want to clear all transfer history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              transferProvider.clearTransferHistory();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notifications'),
              subtitle: Text('Enable transfer notifications'),
              trailing: Switch(value: true, onChanged: null),
            ),
            ListTile(
              leading: Icon(Icons.wifi),
              title: Text('Auto Discovery'),
              subtitle: Text('Automatically discover devices'),
              trailing: Switch(value: true, onChanged: null),
            ),
            ListTile(
              leading: Icon(Icons.folder),
              title: Text('Download Location'),
              subtitle: Text('Choose where files are saved'),
              trailing: Icon(Icons.chevron_right),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'Flutter AirDrop',
        applicationVersion: '1.0.0',
        applicationIcon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.share,
            color: Colors.white,
            size: 32,
          ),
        ),
        children: const [
          Text('A cross-platform file sharing app built with Flutter.'),
          SizedBox(height: 16),
          Text('Features:'),
          Text('• Device discovery'),
          Text('• File transfers'),
          Text('• Transfer progress tracking'),
          Text('• Transfer history'),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    if (bytes < 1024 * 1024) return '${(bytes / 1024.0).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024.0 * 1024.0)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024.0 * 1024.0 * 1024.0)).toStringAsFixed(1)} GB';
  }
}
