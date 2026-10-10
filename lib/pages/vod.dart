import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/movie.dart';
import '../models/site.dart';
import '../services/cms_service.dart';
import '../services/config_service.dart';
import '../providers/settings_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('影视'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search),
            tooltip: '搜索当前源',
            onPressed: _site == null
                ? null
                : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SearchPage(lockedSite: _site),
                    ));
                  },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipSection(
            context,
            label: '视频源',
            loading: false,
            chips: _sites
                .map((s) => _ChipData(
                      label: s.name,
                      selected: _site?.key == s.key,
                      onTap: () {
                        if (_site?.key != s.key) _selectSite(s);
                      },
                    ))
                .toList(),
            emptyHint: '未配置视频源，请先到设置添加',
          ),
          _buildChipSection(
            context,
            label: '分类',
            loading: _loadingCats,
            chips: [
              _ChipData(
                label: '全部',
                selected: _categoryId.isEmpty,
                onTap: () => _onCategorySelected(''),
              ),
              ..._categories.map((c) => _ChipData(
                    label: c.name,
                    selected: _categoryId == c.id,
                    onTap: () => _onCategorySelected(c.id),
                  )),
            ],
            emptyHint: _site == null ? '' : '该源暂无分类',
          ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildChipSection(
    BuildContext context, {
    required String label,
    required bool loading,
    required List<_ChipData> chips,
    required String emptyHint,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
        ),
        SizedBox(
          height: 40,
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : chips.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(emptyHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: chips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = chips[i];
                        return ChoiceChip(
                          label: Text(c.label),
                          selected: c.selected,
                          onSelected: (_) => c.onTap(),
                        );
                      },
                    ),
        ),
      ],
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
    final userColumns = ref.watch(gridColumnsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // 移动端用用户设置的列数，大屏保持响应式
        final crossAxisCount = w > 800 ? 5 : (w > 600 ? 4 : userColumns);
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
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
            return GestureDetector(
              onTap: () => _openDetail(v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CoverImage(
                        imageUrl: v.poster,
                        fit: BoxFit.cover,
                        // 横图取左半（F方案：书封面类）
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if ((v.typeName ?? '').isNotEmpty || (v.year ?? '').isNotEmpty)
                    Text(
                      [v.year, v.typeName].where((e) => (e ?? '').isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
