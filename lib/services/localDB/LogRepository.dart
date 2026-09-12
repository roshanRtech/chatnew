import 'dart:async';
import 'package:chat/centralized_import.dart';

class LogRepository {
  static late SqliteMethods dbObject;
  static final StreamController<List<LogModel>> _logStreamController =
      StreamController<List<LogModel>>.broadcast();

  static init({required String dbName}) async {
    dbObject = SqliteMethods();
    await dbObject.openDb(dbName);
    await dbObject.init();
    await _emitLogs(); // emit initial logs
  }

  static Future<void> _emitLogs() async {
    final logs = await dbObject.getLogs();
    if (!_logStreamController.isClosed) {
      _logStreamController.add(logs ?? []);
    }
  }

  static Stream<List<LogModel>> watchLogs() => _logStreamController.stream;

  static Future<void> addLogs(LogModel log) async {
    await dbObject.addLogs(log);
    await _emitLogs(); // refresh stream
  }

  static Future<void> deleteLogs(int? logId) async {
    if (logId != null) {
      await dbObject.deleteLogs(logId);
      await _emitLogs();
    }
  }

  static Future<void> deleteAllLogs() async {
    await dbObject.deleteAllLogs();
    await _emitLogs();
  }

  static Future<List<LogModel>?> getLogs() => dbObject.getLogs();

  static close() {
    _logStreamController.close();
    dbObject.close();
  }
}
