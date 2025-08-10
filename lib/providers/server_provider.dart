import 'package:flutter/material.dart' hide Router;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'dart:io';
import 'dart:convert';
import '../models/file_item.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';

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


  Future<void> startServer(int port) async {
    if (_isRunning) return;

    try {
      final router = Router();

      // List directory contents
      router.get('/api/files', (Request request) async {
        final path = request.url.queryParameters['path'] ?? '/';
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
