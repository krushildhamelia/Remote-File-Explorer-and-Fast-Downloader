import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/download_task.dart';
import '../providers/settings_provider.dart';
import '../providers/download_provider.dart';
import '../models/file_item.dart';
import '../widgets/file_explorer.dart';
import 'package:network_info_plus/network_info_plus.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _discoveredServers = [];
  bool _isScanning = false;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  Future<void> _discoverServers() async {
    setState(() {
      _isScanning = true;
      _discoveredServers.clear();
    });

    try {
      final settings = context.read<SettingsProvider>();
      final port = settings.port;

      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null) {
        final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
        final futures = <Future>[];

        for (int i = 1; i <= 254; i++) {
          final ip = '$subnet.$i';
          futures.add(_checkServer(ip, port));
        }

        await Future.wait(futures);
      }
    } catch (e) {
      print('Discovery error: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _checkServer(String ip, int port) async {
    try {
      final response = await _dio.get('http://$ip:$port/api/server-check');
      if (response.statusCode == 200) {
        setState(() {
          _discoveredServers.add('http://$ip:$port');
        });
      }
    } catch (e) {
      // Server not found at this IP
    }
  }

  void _openFileExplorer(String serverUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileExplorer(serverUrl: serverUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadProvider = context.watch<DownloadProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote File Explorer'),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.search),
            onPressed: _isScanning ? null : _discoverServers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Download tasks
          if (downloadProvider.downloads.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Downloads',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: downloadProvider.downloads.length,
                itemBuilder: (context, index) {
                  final task = downloadProvider.downloads[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  task.fileName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(_getStatusText(task.status)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: task.progress),
                          const SizedBox(height: 4),
                          Text('${(task.progress * 100).toStringAsFixed(1)}%'),
                          const SizedBox(height: 8),
                          // Thread progress indicators
                          Wrap(
                            spacing: 8,
                            children: task.chunks.map((chunk) {
                              return Chip(
                                label: Text(
                                  'T${chunk.index + 1}: ${(chunk.progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: chunk.isComplete
                                    ? Colors.green.shade100
                                    : Colors.blue.shade100,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
          ],

          // Discovered servers
          Container(
            padding: const EdgeInsets.all(8),
            child: const Text(
              'Discovered Servers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: _discoveredServers.isEmpty && !_isScanning
                ? const Center(
              child: Text('No servers found. Tap search to discover.'),
            )
                : ListView.builder(
              itemCount: _discoveredServers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.dns),
                  title: Text(_discoveredServers[index]),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _openFileExplorer(_discoveredServers[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return 'Pending';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.combining:
        return 'Combining';
    }
  }
}
