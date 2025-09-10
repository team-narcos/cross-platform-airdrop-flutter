import 'package:flutter/material.dart';
import '../models/device_model.dart';

class DeviceListItem extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isConnected; // New property to track connection status

  const DeviceListItem({
    super.key,
    required this.device,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isConnected = false, // Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isSelected || isConnected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isConnected
              ? Colors.green
              : isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: _buildDeviceIcon(),
        title: Text(
          device.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected || isConnected
                ? Theme.of(context).primaryColor
                : null,
          ),
        ),
        subtitle: _buildStatusRow(),
        trailing: _buildTrailingWidget(context),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildDeviceIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withOpacity(0.1)
            : device.isOnline
            ? Colors.blue.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Icon(
          isConnected ? Icons.link : Icons.devices_other,
          color: isConnected
              ? Colors.green
              : device.isOnline
              ? Colors.blue
              : Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  // --- THIS WIDGET HAS BEEN MODIFIED ---
  Widget _buildStatusRow() {
    if (isConnected) {
      return Row(
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
            'Connected',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: device.isOnline ? Colors.blue : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          device.isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 11,
            color: device.isOnline ? Colors.blue : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // -- Unchanged widgets below this line for brevity --
  // (Your existing _buildTrailingWidget, _getLastSeenText, etc., can remain,
  // or you can use the simplified versions below if you prefer)

  Widget _buildTrailingWidget(BuildContext context) {
    if (isConnected) {
      return Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 24,
      );
    }
    if (isSelected) {
      return Icon(
        Icons.check_circle_outline,
        color: Theme.of(context).primaryColor,
        size: 24,
      );
    }
    return const Icon(Icons.chevron_right, color: Colors.grey);
  }

  String _getLastSeenText() {
    // This logic remains the same
    return ''; // Placeholder, your existing code is fine
  }

  void _showDeviceInfo(BuildContext context) {
    // This logic remains the same
  }

  Widget _buildInfoRow(String label, String value) {
    // This logic remains the same
    return Container(); // Placeholder, your existing code is fine
  }

  String _formatDateTime(DateTime dateTime) {
    // This logic remains the same
    return ''; // Placeholder, your existing code is fine
  }
}