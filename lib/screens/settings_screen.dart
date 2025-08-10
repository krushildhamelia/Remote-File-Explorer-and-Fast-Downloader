import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Port setting
          Card(
            child: ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Server Port'),
              subtitle: Text('Current: ${settingsProvider.port}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showPortDialog(context, settingsProvider),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Thread count setting
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Download Threads'),
              subtitle: Text('Current: ${settingsProvider.threadCount}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showThreadDialog(context, settingsProvider),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Download path setting
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Download Location'),
              subtitle: Text(settingsProvider.downloadPath),
              trailing: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: () => _selectDownloadPath(context, settingsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPortDialog(BuildContext context, SettingsProvider provider) {
    final controller = TextEditingController(text: provider.port.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Server Port'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Port',
            hintText: 'Enter port number (e.g., 8080)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final port = int.tryParse(controller.text);
              if (port != null && port > 0 && port < 65536) {
                provider.setPort(port);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showThreadDialog(BuildContext context, SettingsProvider provider) {
    int selectedCount = provider.threadCount;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Download Threads'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Threads: $selectedCount'),
              Slider(
                value: selectedCount.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: selectedCount.toString(),
                onChanged: (value) {
                  setState(() {
                    selectedCount = value.toInt();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                provider.setThreadCount(selectedCount);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDownloadPath(BuildContext context, SettingsProvider provider) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      provider.setDownloadPath(result);
    }
  }
}
