import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SettingsProvider extends ChangeNotifier {
  int _port = 8080;
  int _threadCount = 4;
  String _downloadPath = '';

  int get port => _port;
  int get threadCount => _threadCount;
  String get downloadPath => _downloadPath;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _port = prefs.getInt('port') ?? 8080;
    _threadCount = prefs.getInt('threadCount') ?? 4;
    _downloadPath = prefs.getString('downloadPath') ?? '';

    if (_downloadPath.isEmpty) {
      final directory = await getApplicationDocumentsDirectory();
      _downloadPath = directory.path;
    }
    notifyListeners();
  }

  Future<void> setPort(int port) async {
    _port = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('port', port);
    notifyListeners();
  }

  Future<void> setThreadCount(int count) async {
    _threadCount = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('threadCount', count);
    notifyListeners();
  }

  Future<void> setDownloadPath(String path) async {
    _downloadPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloadPath', path);
    notifyListeners();
  }
}
