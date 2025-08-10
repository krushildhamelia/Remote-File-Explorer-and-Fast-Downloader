import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import '../models/download_task.dart';
import 'package:path/path.dart' as p;

class DownloadProvider extends ChangeNotifier {
  final List<DownloadTask> _downloads = [];
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};

  List<DownloadTask> get downloads => _downloads;

  Future<void> downloadFile({
    required String url,
    required String fileName,
    required String savePath,
    required int threadCount,
    required int contentLength,
  }) async {
    try {
      // Get file size
      // final response = await _dio.head(url);
      // final contentLength = int.parse(response.headers.value('content-length') ?? '0');

      if (contentLength == 0) {
        throw Exception('Unable to determine file size');
      }

      // Create download task
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final chunkSize = (contentLength / threadCount).ceil();
      final chunks = <ChunkProgress>[];

      for (int i = 0; i < threadCount; i++) {
        final startByte = i * chunkSize;
        final endByte = (i == threadCount - 1)
            ? contentLength - 1
            : (i + 1) * chunkSize - 1;

        chunks.add(ChunkProgress(
          index: i,
          startByte: startByte,
          endByte: endByte,
          chunkFilePath: p.join(savePath, '${fileName}.part$i'),
        ));
      }

      final task = DownloadTask(
        id: taskId,
        fileName: fileName,
        url: url,
        savePath: savePath,
        totalSize: contentLength,
        threadCount: threadCount,
        chunks: chunks,
      );

      _downloads.add(task);
      notifyListeners();

      // Start downloading chunks
      task.status = DownloadStatus.downloading;
      notifyListeners();

      final futures = <Future>[];
      for (final chunk in chunks) {
        futures.add(_downloadChunk(task, chunk));
      }

      await Future.wait(futures);

      // Combine chunks
      task.status = DownloadStatus.combining;
      notifyListeners();

      await _combineChunks(task);

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      notifyListeners();

    } catch (e) {
      print('Download error: $e');
      if (_downloads.isNotEmpty) {
        _downloads.last.status = DownloadStatus.failed;
        _downloads.last.error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> _downloadChunk(DownloadTask task, ChunkProgress chunk) async {
    try {
      final cancelToken = CancelToken();
      _cancelTokens['${task.id}_${chunk.index}'] = cancelToken;

      final options = Options(
        headers: {
          'Range': 'bytes=${chunk.startByte}-${chunk.endByte}',
        },
        responseType: ResponseType.stream,
      );

      final response = await _dio.get(
        task.url,
        options: options,
        cancelToken: cancelToken,
      );

      final file = File(chunk.chunkFilePath!);
      final sink = file.openWrite();

      await for (final data in response.data.stream) {
        sink.add(data);

        // Ensure data is treated as a byte array
        if (data is List<int>) {
          chunk.downloadedBytes += data.length;
        } else {
          // Fallback if data is not a List<int>
          chunk.downloadedBytes += data.toString().length;
        }

        // Update overall progress
        task.progress = task.downloadedBytes / task.totalSize;
        notifyListeners();
      }

      await sink.close();
      chunk.isComplete = true;

    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        throw e;
      }
    }
  }

  Future<void> _combineChunks(DownloadTask task) async {
    final outputFile = File(p.join(task.savePath, task.fileName));
    final sink = outputFile.openWrite();

    for (final chunk in task.chunks) {
      if (chunk.chunkFilePath != null) {
        final chunkFile = File(chunk.chunkFilePath!);
        if (await chunkFile.exists()) {
          final data = await chunkFile.readAsBytes();
          sink.add(data);
          await chunkFile.delete(); // Clean up chunk file
        }
      }
    }

    await sink.close();
  }

  void cancelDownload(String taskId) {
    final task = _downloads.firstWhere((t) => t.id == taskId);
    task.status = DownloadStatus.paused;

    // Cancel all chunk downloads
    for (int i = 0; i < task.threadCount; i++) {
      final token = _cancelTokens['${taskId}_$i'];
      token?.cancel();
    }

    notifyListeners();
  }

  void removeDownload(String taskId) {
    _downloads.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }
}
