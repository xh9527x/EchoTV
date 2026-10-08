import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/logger_service.dart';
import '../widgets/zen_ui.dart';

/// 日志查看页：显示应用内日志，支持复制/清空，用于真机问题诊断。
class LogViewerPage extends ConsumerWidget {
  const LogViewerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(loggerServiceProvider);
    final entries = logger.entries.reversed.toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy),
            tooltip: '复制全部',
            onPressed: entries.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: logger.exportText()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板')),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            tooltip: '清空',
            onPressed: entries.isEmpty ? null : () => logger.clear(),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                '暂无日志\n播放视频后会记录 URL、代理、测速等信息',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SelectableText(
                    e.toString(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                );
              },
            ),
    );
  }
}
