import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/favorites_provider.dart';
import '../widgets/cover_image.dart';

/// 收藏列表
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: favAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.heart, size: 48, color: theme.hintColor),
                  const SizedBox(height: 12),
                  const Text('暂无收藏'),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final f = list[i];
              return GestureDetector(
                onTap: () {
                  // TODO: 跳转到详情页
                  context.pop();
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('取消收藏'),
                      content: Text('确定取消收藏「${f.title}」吗？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                        TextButton(
                          onPressed: () {
                            ref.read(favoritesProvider.notifier).remove(f);
                            Navigator.pop(context);
                          },
                          child: const Text('确定', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CoverImage(imageUrl: f.cover, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (f.year.isNotEmpty)
                      Text(f.year, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
