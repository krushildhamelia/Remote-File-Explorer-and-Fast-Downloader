import 'package:flutter/material.dart' hide Router;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'dart:io';
import 'dart:convert';
import '../models/file_item.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../utils/utils.dart';


class ServerProvider extends ChangeNotifier {
  HttpServer? _server;
  bool _isRunning = false;
  String _serverAddress = '';

  bool get isRunning => _isRunning;
  String get serverAddress => _serverAddress;

  List<String> getWindowsDrives() {
    final drives = <String>[];
    for (var letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      final drivePath = '$letter:\\';
      if (Directory(drivePath).existsSync()) {
        drives.add(drivePath);
      }
    }
    return drives;
  }

  Future<bool> isExternalStoragePresent() async {
    final Directory? directory = await getExternalStorageDirectory();
    if (directory == null) {
      return false;
    }
    return true;
  }

  Future<bool> hasAllFilesAccess() async {
    return await Permission.manageExternalStorage.isGranted;
  }

  Future<void> requestAllFilesAccess() async {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION',
      );
      await intent.launch();
    }
  }

  Future<List<Directory>> getAndroidStorageDirectories() async {
    final dirs = <Directory>[];

    // Primary external storage
    final primary = Directory('/storage/emulated/0');
    if (primary.existsSync()) dirs.add(primary);

    // Other possible external storages (SD cards, USB OTG)
    if (await isExternalStoragePresent() && !(await hasAllFilesAccess())) {
      await grantAllAndroidPermissions();
    }

    if (!(await hasAllFilesAccess())) {
      return dirs;
    }

    final storageRoot = Directory('/storage');
    if (storageRoot.existsSync()) {
      for (var entity in storageRoot.listSync()) {
        if (entity is Directory && entity.path != '/storage/emulated' && entity.path != '/storage/self') {
          dirs.add(entity);
        }
      }
    }

    return dirs;
  }

  Future<void> startServer(int port) async {
    if (_isRunning) return;

    try {
      final router = Router();

      // List directory contents
      router.get('/api/files', (Request request) async {
        String path = request.url.queryParameters['path'] ?? '/';

        try {
          if (Platform.isWindows && path == '/') {
            final drives = getWindowsDrives().map((d) => FileItem(
              name: d,
              path: d,
              isDirectory: true,
              size: 0,
              modifiedDate: DateTime.now(),
            )).toList();
  
            return Response.ok(jsonEncode(drives.map((e) => e.toJson()).toList()),
              headers: {'Content-Type': 'application/json'},
            );
          }
  
          if (Platform.isAndroid && path == '/') {
            final storages = (await getAndroidStorageDirectories()).map((d) => FileItem(
              name: d.path.split('/').last,
              path: d.path,
              isDirectory: true,
              size: 0,
              modifiedDate: DateTime.now(),
            )).toList();
  
            return Response.ok(jsonEncode(storages.map((e) => e.toJson()).toList()),
              headers: {'Content-Type': 'application/json'},
            );
          }
        } catch (e) {
          print("Error get root directories for platform: $e");
          path = path == "/" && Platform.isAndroid ? "/storage/emulated/0" : "/";
        }


        final directory = Directory(path);

        if (!await directory.exists()) {
          return Response.notFound('Directory not found');
        }

        final items = <FileItem>[];
        await for (final entity in directory.list()) {
          final stat = await entity.stat();
          items.add(FileItem(
            name: p.basename(entity.path),
            path: entity.path,
            isDirectory: entity is Directory,
            size: stat.size,
            modifiedDate: stat.modified,
          ));
        }

        return Response.ok(
          jsonEncode(items.map((e) => e.toJson()).toList()),
          headers: {'Content-Type': 'application/json'},
        );
      });


      router.get('/api/server-check', (Request request) async {
        return Response.ok("");
      });

      // Download file with range support
      router.get('/api/download', (Request request) async {
        final filePath = request.url.queryParameters['path'];
        if (filePath == null) {
          return Response.badRequest(body: 'Path parameter required');
        }

        final file = File(filePath);
        if (!await file.exists()) {
          return Response.notFound('File not found');
        }

        final fileSize = await file.length();
        final rangeHeader = request.headers['range'];

        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          final rangeParts = rangeHeader.substring(6).split('-');
          final start = int.parse(rangeParts[0]);
          final end = rangeParts[1].isNotEmpty
              ? int.parse(rangeParts[1])
              : fileSize - 1;

          final stream = file.openRead(start, end + 1);
          final contentLength = end - start + 1;

          return Response(
            206,
            body: stream,
            headers: {
              'Content-Type': lookupMimeType(filePath) ?? 'application/octet-stream',
              'Content-Length': contentLength.toString(),
              'Content-Range': 'bytes $start-$end/$fileSize',
              'Accept-Ranges': 'bytes',
            },
          );
        } else {
          return Response.ok(
            file.openRead(),
            headers: {
              'Content-Type': lookupMimeType(filePath) ?? 'application/octet-stream',
              'Content-Length': fileSize.toString(),
              'Accept-Ranges': 'bytes',
            },
          );
        }
      });

      // Get file info
      router.head('/api/download', (Request request) async {
        final filePath = request.url.queryParameters['path'];
        if (filePath == null) {
          return Response.badRequest(body: 'Path parameter required');
        }

        final file = File(filePath);
        if (!await file.exists()) {
          return Response.notFound('File not found');
        }

        final fileSize = await file.length();
        return Response.ok(
          '',
          headers: {
            'Content-Length': fileSize.toString(),
            'Accept-Ranges': 'bytes',
          },
        );
      });

      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(corsHeaders())
          .addHandler(router);

      _server = await io.serve(handler, '0.0.0.0', port);
      _isRunning = true;

      // Get server IP
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      _serverAddress = 'http://${wifiIP ?? 'localhost'}:$port';

      notifyListeners();
    } catch (e) {
      print('Error starting server: $e');
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      _serverAddress = '';
      notifyListeners();
    }
  }

  Middleware corsHeaders() {
    return (Handler handler) {
      return (Request request) async {
        final response = await handler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Range',
        });
      };
    };
  }
}
