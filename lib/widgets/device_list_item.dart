import 'package:flutter/material.dart';
import '../models/device_model.dart';

class DeviceListItem extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const DeviceListItem({
    super.key,
    required this.device,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 8 : 2,
      color: isSelected 
          ? Theme.of(context).primaryColor.withOpacity(0.1)
          : null,
      child: ListTile(
        leading: _buildDeviceIcon(),
        title: Text(
          device.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected 
                ? Theme.of(context).primaryColor
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${device.type.displayName} • ${device.ipAddress}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            _buildStatusRow(),
          ],
        ),
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
        color: device.isOnline 
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: device.isOnline 
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          device.type.iconAsset,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: device.isOnline ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          device.isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 11,
            color: device.isOnline ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _getLastSeenText(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingWidget(BuildContext context) {
    if (isSelected) {
      return Icon(
        Icons.check_circle,
        color: Theme.of(context).primaryColor,
        size: 24,
      );
    }

    return IconButton(
      icon: Icon(
        Icons.more_vert,
        color: Colors.grey[600],
      ),
      onPressed: () => _showDeviceInfo(context),
    );
  }

  String _getLastSeenText() {
    final now = DateTime.now();
    final difference = now.difference(device.lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showDeviceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Device Type', device.type.displayName),
            _buildInfoRow('IP Address', device.ipAddress),
            _buildInfoRow('Port', device.port.toString()),
            _buildInfoRow('Status', device.isOnline ? 'Online' : 'Offline'),
            _buildInfoRow('Last Seen', _formatDateTime(device.lastSeen)),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}