import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/history_provider.dart';
import '../widgets/zen_ui.dart';
import '../widgets/cover_image.dart';

/// 观看历史完整列表
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('观看历史'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 20),
            tooltip: '清空历史',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('清空历史'),
                  content: const Text('确定要清空所有观看记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(historyProvider.notifier).clearHistory();
                        Navigator.pop(context);
                      },
                      child: const Text('清空', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (history) {
          if (history.isEmpty) {
            return const Center(child: Text('暂无观看记录'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, i) {
              final r = history[i];
              final progress = r.totalTime > 0 ? r.playTime / r.totalTime : 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60,
                      height: 80,
                      child: CoverImage(imageUrl: r.cover, fit: BoxFit.cover),
                    ),
                  ),
                  title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('观看至第 ${r.index + 1} 集', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                    ],
                  ),
                  onTap: () {
                    // TODO: 跳转到详情页继续播放
                    context.pop();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
