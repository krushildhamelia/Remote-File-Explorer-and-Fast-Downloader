import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../providers/settings_provider.dart';

class ServerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<ServerProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                serverProvider.isRunning ? Icons.dns : Icons.dns_outlined,
                size: 100,
                color: serverProvider.isRunning ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                serverProvider.isRunning ? 'Server Running' : 'Server Stopped',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (serverProvider.isRunning) ...[
                const SizedBox(height: 10),
                SelectableText(
                  serverProvider.serverAddress,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Port: ${settingsProvider.port}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  if (serverProvider.isRunning) {
                    await serverProvider.stopServer();
                  } else {
                    await serverProvider.startServer(settingsProvider.port);
                  }
                },
                icon: Icon(serverProvider.isRunning ? Icons.stop : Icons.play_arrow),
                label: Text(serverProvider.isRunning ? 'Stop Server' : 'Start Server'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: serverProvider.isRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
