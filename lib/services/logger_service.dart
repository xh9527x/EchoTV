import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用内日志服务：内存环形缓冲，用于真机问题诊断。
/// 在 release 包中 debugPrint 不可用，所以用此服务记录关键日志，
/// 用户可在设置页查看/复制，发给开发者分析。
final loggerServiceProvider = Provider((ref) => LoggerService());

class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  LogEntry(this.tag, this.message) : time = DateTime.now();

  @override
  String toString() {
    final t = time.toIso8601String().substring(11, 23);
    return '[$t][$tag] $message';
  }
}

class LoggerService extends ChangeNotifier {
  static const int _maxEntries = 500;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(String tag, String message) {
    _entries.add(LogEntry(tag, message));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    // 同时输出到控制台，方便开发期查看
    debugPrint('[$tag] $message');
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  String exportText() {
    return _entries.map((e) => e.toString()).join('\n');
  }
}
