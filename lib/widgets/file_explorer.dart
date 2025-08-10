import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/settings_provider.dart';
import '../providers/download_provider.dart';

class FileExplorer extends StatefulWidget {
  final String serverUrl;

  const FileExplorer({Key? key, required this.serverUrl}) : super(key: key);

  @override
  _FileExplorerState createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final List<FileItem> _items = [];
  final List<String> _pathStack = ['/'];
  final Set<String> _selectedFiles = {};
  bool _isLoading = false;
  final Dio _dio = Dio();
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  String get currentPath => _pathStack.last;

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _items.clear();
    });

    try {
      final response = await _dio.get(
        '${widget.serverUrl}/api/files',
        queryParameters: {'path': currentPath},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        setState(() {
          _items.addAll(data.map((e) => FileItem.fromJson(e)));
          _items.sort((a, b) {
            if (a.isDirectory != b.isDirectory) {
              return a.isDirectory ? -1 : 1;
            }
            return a.name.compareTo(b.name);
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading directory: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDirectory(FileItem item) {
    if (item.isDirectory) {
      setState(() {
        _pathStack.add(item.path);
        _selectedFiles.clear();
        _selectionMode = false;
      });
      _loadDirectory();
    }
  }

  void _navigateBack() {
    if (_pathStack.length > 1) {
      setState(() {
        _pathStack.removeLast();
        _selectedFiles.clear();
        _selectionMode = false;
      });
      _loadDirectory();
    }
  }

  void _toggleSelection(FileItem item) {
    if (!item.isDirectory) {
      setState(() {
        if (_selectedFiles.contains(item.path)) {
          _selectedFiles.remove(item.path);
        } else {
          _selectedFiles.add(item.path);
        }
        if (_selectedFiles.isEmpty) {
          _selectionMode = false;
        }
      });
    }
  }

  void _downloadSelected() async {
    if (_selectedFiles.isEmpty) return;

    final settings = context.read<SettingsProvider>();
    final downloadProvider = context.read<DownloadProvider>();

    for (final filePath in _selectedFiles) {
      final item = _items.firstWhere((i) => i.path == filePath);
      final downloadUrl = '${widget.serverUrl}/api/download?path=${Uri.encodeQueryComponent(filePath)}';

      await downloadProvider.downloadFile(
        url: downloadUrl,
        fileName: item.name,
        savePath: settings.downloadPath,
        threadCount: settings.threadCount,
        contentLength: item.size,
      );
    }

    setState(() {
      _selectedFiles.clear();
      _selectionMode = false;
    });

    Navigator.pop(context);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _pathStack.length > 1 ? _navigateBack : () => Navigator.pop(context),
        ),
        title: Text(currentPath == '/' ? 'Root' : currentPath.split('/').last),
        actions: [
          if (_selectionMode)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFiles.clear();
                  _selectionMode = false;
                });
              },
              child: const Text('Cancel'),
            ),
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadSelected,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isSelected = _selectedFiles.contains(item.path);

          return ListTile(
            leading: Icon(
              item.isDirectory ? Icons.folder : Icons.insert_drive_file,
              color: item.isDirectory ? Colors.amber : Colors.blue,
            ),
            title: Text(item.name),
            subtitle: item.isDirectory
                ? null
                : Text(_formatFileSize(item.size)),
            trailing: _selectionMode && !item.isDirectory
                ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(item),
            )
                : null,
            selected: isSelected,
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(item);
              } else if (item.isDirectory) {
                _navigateToDirectory(item);
              } else {
                setState(() {
                  _selectionMode = true;
                  _selectedFiles.add(item.path);
                });
              }
            },
            onLongPress: !item.isDirectory
                ? () {
              setState(() {
                _selectionMode = true;
                _selectedFiles.add(item.path);
              });
            }
                : null,
          );
        },
      ),
      bottomNavigationBar: _selectedFiles.isNotEmpty
          ? BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_selectedFiles.length} selected'),
              ElevatedButton.icon(
                onPressed: _downloadSelected,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }
}