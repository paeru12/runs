import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/running_session.dart';

class ExportService {
  /// ===============================================================
  /// EXPORT DATA POINTS TO CSV
  /// ===============================================================
  static Future<File> exportToCSV(RunningSession session) async {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln("index,time,steps,speed,latitude,longitude");

    for (int i = 0; i < session.dataPoints.length; i++) {
      final dp = session.dataPoints[i];
      final rp = session.routePoints.isNotEmpty && i < session.routePoints.length
          ? session.routePoints[i]
          : null;

      buffer.writeln(
        "$i,"
        "${dp.timestamp.toIso8601String()},"
        "${dp.steps},"
        "${dp.speed},"
        "${rp?.latitude ?? ''},"
        "${rp?.longitude ?? ''}",
      );
    }

    final file = await _writeFile(
      fileName: "run_${session.id}.csv",
      content: buffer.toString(),
    );

    return file;
  }

  /// ===============================================================
  /// EXPORT SUMMARY (TXT)
  /// ===============================================================
  static Future<File> exportSessionSummary(RunningSession session) async {
    final summary = StringBuffer();

    summary.writeln("=== RUN SESSION SUMMARY ===");
    summary.writeln("ID: ${session.id}");
    summary.writeln("Date: ${session.startTime}");
    summary.writeln("Duration: ${session.formattedDuration}");
    summary.writeln("Distance: ${session.totalDistance.toStringAsFixed(2)} km");
    summary.writeln("Steps: ${session.totalSteps}");
    summary.writeln("Average Pace: ${session.formattedPace}");
    summary.writeln("===========================");
    summary.writeln("");

    final file = await _writeFile(
      fileName: "run_summary_${session.id}.txt",
      content: summary.toString(),
    );

    return file;
  }

  /// ===============================================================
  /// SHARE FILES + SIMPLE TEXT
  /// ===============================================================
  static Future<void> shareSession(RunningSession session) async {
    final csvFile = await exportToCSV(session);
    final summaryFile = await exportSessionSummary(session);

    await Share.shareXFiles(
      [
        XFile(csvFile.path),
        XFile(summaryFile.path),
      ],
      text:
          "Run Session:\nDistance: ${session.totalDistance.toStringAsFixed(2)} km\nDuration: ${session.formattedDuration}",
    );
  }

  /// ===============================================================
  /// INTERNAL HELPER: WRITE FILE
  /// ===============================================================
  static Future<File> _writeFile({
    required String fileName,
    required String content,
  }) async {
    final dir = await _getExportDirectory();

    final file = File("${dir.path}/$fileName");
    return file.writeAsString(content);
  }

  /// Folder untuk ekspor file
  static Future<Directory> _getExportDirectory() async {
    Directory dir;

    if (Platform.isAndroid || Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getTemporaryDirectory(); // Web / Desktop
    }

    return dir;
  }
}
