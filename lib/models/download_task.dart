class DownloadTask {
  final String id;
  final String fileName;
  final String url;
  final String savePath;
  final int totalSize;
  final int threadCount;
  final List<ChunkProgress> chunks;
  DownloadStatus status;
  double progress;
  String? error;

  DownloadTask({
    required this.id,
    required this.fileName,
    required this.url,
    required this.savePath,
    required this.totalSize,
    required this.threadCount,
    required this.chunks,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.error,
  });

  int get downloadedBytes => chunks.fold(0, (sum, chunk) => sum + chunk.downloadedBytes);
}

class ChunkProgress {
  final int index;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  bool isComplete;
  String? chunkFilePath;

  ChunkProgress({
    required this.index,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.isComplete = false,
    this.chunkFilePath,
  });

  double get progress => (endByte - startByte) > 0
      ? downloadedBytes / (endByte - startByte + 1)
      : 0.0;
}

enum DownloadStatus { pending, downloading, paused, completed, failed, combining }
