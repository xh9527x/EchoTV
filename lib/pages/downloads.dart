import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme.dart';

/// 下载管理（真果鉴皮肤 v1 占位：仅空状态，后续版本接入下载能力）
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.download, size: 56, color: Zjg.faint),
            const SizedBox(height: 16),
            const Text('暂无下载任务', style: TextStyle(fontSize: 16, color: Zjg.sub)),
            const SizedBox(height: 8),
            const Text('下载功能将在后续版本加入', style: TextStyle(fontSize: 13, color: Zjg.faint)),
          ],
        ),
      ),
    );
  }
}
