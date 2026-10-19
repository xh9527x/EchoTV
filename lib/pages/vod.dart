import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/movie.dart';
import '../models/site.dart';
import '../core/theme.dart';
import '../providers/favorites_provider.dart';
import '../services/cms_service.dart';
import '../services/config_service.dart';
import '../widgets/cover_image.dart';
import 'search.dart';
import 'video_detail.dart';

/// 发现版 · 影视页
/// 单页聚合：顶部两排横滑 chips（视频源 / 该源 CMS 分类），分类跟随所选源变化。
/// 数据层复用现有 CmsService / ConfigService，只做界面层。
class VodPage extends ConsumerStatefulWidget {
  const VodPage({super.key});

  @override
  ConsumerState<VodPage> createState() => _VodPageState();
}

class _VodPageState extends ConsumerState<VodPage> {
  List<SiteConfig> _sites = [];
  SiteConfig? _site;
  List<CmsCategory> _categories = [];
  String _categoryId = ''; // '' = 全部
  final Map<String, String> _siteCategoryMemory = {};

  List<VideoDetail> _videos = [];
  int _page = 1;
  int _pageCount = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadingCats = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final configService = ref.read(configServiceProvider);
    final sites = (await configService.getSites()).where((s) => !s.disabled).toList();
    if (!mounted) return;
    setState(() {
      _sites = sites;
      _loading = sites.isNotEmpty;
    });
    if (sites.isNotEmpty) {
      _selectSite(sites.first, initial: true);
    } else {
      setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_loading &&
        !_loadingMore &&
        _page < _pageCount) {
      _loadVideos(more: true);
    }
  }

  Future<void> _selectSite(SiteConfig site, {bool initial = false}) async {
    if (!initial && _site != null) {
      _siteCategoryMemory[_site!.key] = _categoryId;
    }
    setState(() {
      _site = site;
      _categoryId = _siteCategoryMemory[site.key] ?? '';
      _categories = [];
      _loadingCats = true;
    });
    final cmsService = ref.read(cmsServiceProvider);
    final cats = await cmsService.getCategories(site);
    if (!mounted) return;
    setState(() {
      // 若记忆的分类在新分类列表中不存在，回退到全部
      if (_categoryId.isNotEmpty && !cats.any((c) => c.id == _categoryId)) {
        _categoryId = '';
      }
      _categories = cats;
      _loadingCats = false;
    });
    _loadVideos(reset: true);
  }

  Future<void> _loadVideos({bool reset = false, bool more = false}) async {
    final site = _site;
    if (site == null) return;
    if (more) {
      if (_loadingMore || _page >= _pageCount) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        if (reset) _videos = [];
      });
    }

    final cmsService = ref.read(cmsServiceProvider);
    final targetPage = more ? _page + 1 : 1;
    final result = await cmsService.getVodList(
      site,
      typeId: _categoryId.isEmpty ? null : _categoryId,
      page: targetPage,
    );
    if (!mounted) return;
    setState(() {
      if (more) {
        _videos.addAll(result.videos);
      } else {
        _videos = result.videos;
      }
      _page = result.page;
      _pageCount = result.pageCount;
      _loading = false;
      _loadingMore = false;
    });
  }

  void _onCategorySelected(String id) {
    if (id == _categoryId) return;
    setState(() => _categoryId = id);
    if (_site != null) _siteCategoryMemory[_site!.key] = id;
    _loadVideos(reset: true);
  }

  void _openDetail(VideoDetail video) {
    final subject = DoubanSubject(
      id: '',
      title: video.title,
      rate: '0.0',
      cover: video.poster,
      year: video.year,
      description: video.desc,
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoDetailPage(
        subject: subject,
        initialVideo: video,
        // 不传 lockedSite：聚合搜索所有源，自动找能播的（应对 CDN 地域封锁）
      ),
    ));
  }

  /// zgj式顶栏：站源下拉 + 搜索 + 更多（设置）
  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          // 站源下拉
          PopupMenuButton<SiteConfig>(
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (s) {
              if (_site?.key != s.key) _selectSite(s);
            },
            itemBuilder: (_) => [
              ..._sites.map((s) => PopupMenuItem<SiteConfig>(
                    value: s,
                    child: Row(
                      children: [
                        Expanded(child: Text(s.name, style: const TextStyle(fontSize: 16))),
                        if (_site?.key == s.key)
                          const Icon(Icons.check, size: 18, color: Zjg.red),
                      ],
                    ),
                  )),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _site?.name ?? '选择站源',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: theme.hintColor),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(LucideIcons.search, size: 22),
            tooltip: '搜索',
            onPressed: _site == null
                ? null
                : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SearchPage(lockedSite: _site),
                    ));
                  },
          ),
          IconButton(
            icon: const Icon(LucideIcons.moreVertical, size: 22),
            tooltip: '更多',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  /// zgj式分类 chip（横滑单行）
  Widget _buildCategoryChips(BuildContext context) {
    final chips = <_ChipData>[
      _ChipData(label: '全部', selected: _categoryId.isEmpty, onTap: () => _onCategorySelected('')),
      ..._categories.map((c) => _ChipData(
            label: c.name,
            selected: _categoryId == c.id,
            onTap: () => _onCategorySelected(c.id),
          )),
    ];
    return SizedBox(
      height: 52,
      child: _loadingCats
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = chips[i];
                return GestureDetector(
                  onTap: c.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.selected ? Zjg.chipPink : Colors.white,
                      borderRadius: BorderRadius.circular(Zjg.chipRadius),
                      border: Border.all(color: c.selected ? Zjg.chipPink : Zjg.chipBorder),
                    ),
                    child: Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: c.selected ? FontWeight.w600 : FontWeight.normal,
                        color: c.selected ? Zjg.chipPinkInk : Zjg.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            _buildCategoryChips(context),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sites.isEmpty) {
      return Center(
        child: Text('暂无可用视频源', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Text('该分类暂无内容', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // zgj皮肤：移动端固定 3 列，大屏响应式
        final crossAxisCount = w > 800 ? 5 : (w > 600 ? 4 : 3);

        // 单列用横向卡片列表
        if (crossAxisCount == 1) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _videos.length + 1,
            itemBuilder: (_, i) {
              if (i == _videos.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _loadingMore
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _page >= _pageCount ? '— 到底了 —' : '',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                  ),
                );
              }
              final v = _videos[i];
              return GestureDetector(
                onTap: () => _openDetail(v),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 84,
                          height: 112,
                          child: CoverImage(
                            imageUrl: v.poster,
                            fit: BoxFit.cover,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            if ((v.typeName ?? '').isNotEmpty || (v.uploadTime ?? '').isNotEmpty)
                              Text(
                                [v.uploadTime, v.typeName].where((e) => (e ?? '').isNotEmpty).join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                            if ((v.desc ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                v.desc!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // zgj卡片 = 海报(2:3) + 8px + 标题(2行) + 3px + 分类(1行)
        const horizontalPadding = 32.0; // 16*2
        const spacing = 12.0;
        final itemWidth = (w - horizontalPadding - (crossAxisCount - 1) * spacing) / crossAxisCount;
        const textHeight = 68.0;
        final posterHeight = itemWidth / (2 / 3);
        final childAspectRatio = itemWidth / (posterHeight + textHeight);

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _videos.length + 1,
          itemBuilder: (_, i) {
            if (i == _videos.length) {
              return Center(
                child: _loadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _page >= _pageCount ? '— 到底了 —' : '',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
              );
            }
            final v = _videos[i];
            // 左下角集数：优先 remarks，否则按源站集数推算
            String? epsText;
            if ((v.remarks ?? '').isNotEmpty) {
              epsText = v.remarks;
            } else if (v.playGroups.isNotEmpty && v.playGroups.first.urls.isNotEmpty) {
              epsText = '共 ${v.playGroups.first.urls.length} 集';
            }
            return GestureDetector(
              onTap: () => _openDetail(v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: posterHeight,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Zjg.cardRadius),
                          child: SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: CoverImage(
                              imageUrl: v.poster,
                              fit: BoxFit.cover,
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        ),
                        // 底部渐隐，保证压字可读
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Zjg.cardRadius),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
                                stops: const [0.0, 0.35],
                              ),
                            ),
                          ),
                        ),
                        // 右上 ···
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _showCardMenu(context, v),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('···',
                                    style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1, height: 1)),
                              ),
                            ),
                          ),
                        ),
                        // 左下角集数
                        if (epsText != null)
                          Positioned(
                            left: 10,
                            bottom: 8,
                            child: Text(
                              epsText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.35, color: Zjg.ink),
                  ),
                  if ((v.typeName ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        v.typeName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Zjg.sub),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChipData {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  _ChipData({required this.label, required this.selected, required this.onTap});
}

/// 卡片右上 ··· 操作弹窗（zgj式居中圆角对话框）
extension _CardMenu on _VodPageState {
  void _showCardMenu(BuildContext context, VideoDetail v) {
    final favState = ref.read(favoritesProvider);
    final isFav = favState.maybeWhen(
      data: (list) => list.any((e) => e.title == v.title),
      orElse: () => false,
    );
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.4)),
              const SizedBox(height: 8),
              _menuItem(
                ctx,
                icon: isFav ? LucideIcons.heart : LucideIcons.bookmark,
                label: isFav ? '已在追剧' : '加入追剧',
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(favoritesProvider.notifier).toggle(Favorite(
                        title: v.title,
                        sourceName: v.sourceName,
                        cover: v.poster,
                        year: v.year ?? '',
                        totalEpisodes: v.playGroups.isNotEmpty ? v.playGroups.first.urls.length : 0,
                        saveTime: DateTime.now().millisecondsSinceEpoch,
                        searchTitle: v.title,
                      ));
                },
              ),
              _menuItem(
                ctx,
                icon: LucideIcons.playCircle,
                label: '查看详情',
                onTap: () {
                  Navigator.pop(ctx);
                  _openDetail(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext ctx, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Zjg.ink),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 16.5, color: Zjg.ink)),
          ],
        ),
      ),
    );
  }
}
