import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/site.dart';
import '../providers/settings_provider.dart';

final cmsServiceProvider = Provider((ref) => CmsService(ref));

/// CMS 源的分类（来自 `?ac=list` 的 class 数组）
class CmsCategory {
  final String id;
  final String name;
  const CmsCategory({required this.id, required this.name});
}

/// 视频列表分页结果
class VodListResult {
  final List<VideoDetail> videos;
  final int page;
  final int pageCount;
  final int total;
  const VodListResult({
    required this.videos,
    required this.page,
    required this.pageCount,
    required this.total,
  });
}

class CmsService {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
    },
  ));

  CmsService(this._ref);

  Future<List<VideoDetail>> search(SiteConfig site, String query, {int page = 1}) async {
    try {
      final url = '${site.api}?ac=videolist&wd=${Uri.encodeComponent(query)}&pg=$page';
      final response = await _dio.get(url);

      if (response.data == null) {
        return [];
      }

      // Web 平台兼容：确保 data 是 Map
      Map<String, dynamic> data;
      if (response.data is String) {
        try {
          data = jsonDecode(response.data);
        } catch (e) {
          return [];
        }
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else {
        return [];
      }

      // 兼容性处理：list 字段可能是数组或字符串，统一解析
      final List<VideoDetail> results = _parseVideoList(data['list'], site);

      // 第一页请求成功后，如果是搜索且有多页，全并发抓取后续页
      if (page == 1) {
        try {
          final pageCountData = data['pagecount'];
          if (pageCountData != null) {
            int pageCount = 1;
            if (pageCountData is int) {
              pageCount = pageCountData;
            } else if (pageCountData is String) {
              pageCount = int.tryParse(pageCountData) ?? 1;
            }

            if (pageCount > 1) {
              int limit = pageCount > 3 ? 3 : pageCount;
              final futures = <Future<List<VideoDetail>>>[];
              for (int i = 2; i <= limit; i++) {
                futures.add(search(site, query, page: i));
              }
              final moreResults = await Future.wait(futures);
              for (var extra in moreResults) {
                results.addAll(extra);
              }
            }
          }
        } catch (e) {
          // Ignore pagination errors
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<List<VideoDetail>> searchAll(List<SiteConfig> sites, String query) async {
    final activeSites = sites.where((s) => !s.disabled).toList();
    if (activeSites.isEmpty) {
      return [];
    }

    // 真正的全并发搜索所有站点
    final results = await Future.wait(
      activeSites.map((site) async {
        try {
          final siteResults = await search(site, query);
          return siteResults;
        } catch (e) {
          return <VideoDetail>[];
        }
      })
    );

    // 过滤掉没有任何集数的无效资源
    final allResults = results.expand((x) => x).where((res) => res.playGroups.isNotEmpty).toList();

    return allResults;
  }

  /// 流式搜索：并发搜索所有站点，每个站点有结果就立即返回
  /// 返回的 Stream 会持续发送累积的结果列表
  Stream<List<VideoDetail>> searchAllStream(List<SiteConfig> sites, String query) async* {
    final activeSites = sites.where((s) => !s.disabled).toList();
    if (activeSites.isEmpty) {
      yield [];
      return;
    }

    final allResults = <VideoDetail>[];
    final controller = StreamController<List<VideoDetail>>();
    int completedCount = 0;

    // 并发搜索所有站点
    for (var site in activeSites) {
      search(site, query).then((siteResults) {
        if (siteResults.isNotEmpty) {
          // 过滤掉没有任何集数的无效资源
          final validResults = siteResults.where((res) => res.playGroups.isNotEmpty).toList();
          if (validResults.isNotEmpty) {
            allResults.addAll(validResults);
            controller.add(List.from(allResults));
          }
        }
        completedCount++;
        if (completedCount == activeSites.length) {
          controller.close();
        }
      }).catchError((_) {
        completedCount++;
        if (completedCount == activeSites.length) {
          controller.close();
        }
      });
    }

    yield* controller.stream;
  }

  Future<VideoDetail?> getDetail(SiteConfig site, String id) async {
    try {
      final url = '${site.api}?ac=videolist&ids=$id';
      final response = await _dio.get(url);

      if (response.data == null) return null;

      // Web 平台兼容：确保 data 是 Map
      Map<String, dynamic> data;
      if (response.data is String) {
        try {
          data = jsonDecode(response.data);
        } catch (e) {
          return null;
        }
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else {
        return null;
      }

      final list = _parseVideoList(data['list'], site);
      if (list.isEmpty) return null;

      return list[0];
    } catch (e) {
      return null;
    }
  }

  /// Web 平台兼容：把 response.data 统一成 Map
  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return null;
      } catch (e) {
        return null;
      }
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  /// 统一解析 list 字段（数组或 JSON 字符串），过滤无播放源/青少年模式条目
  List<VideoDetail> _parseVideoList(dynamic listData, SiteConfig site) {
    if (listData == null) return [];

    List list;
    if (listData is String) {
      try {
        final decoded = jsonDecode(listData);
        if (decoded is List) {
          list = decoded;
        } else {
          return [];
        }
      } catch (e) {
        return [];
      }
    } else if (listData is List) {
      list = listData;
    } else {
      return [];
    }

    final List<VideoDetail> results = [];
    final isTeenageMode = _ref.read(teenageModeProvider);
    final filteredKeywords = _ref.read(filteredKeywordsProvider);

    for (var item in list) {
      try {
        final detail = _parseVideoItem(item, site);
        if (detail.playGroups.isNotEmpty) {
          bool shouldFilter = false;
          if (isTeenageMode) {
            final content = '${detail.title}${detail.typeName ?? ''}${detail.sourceName}'.toLowerCase();
            if (filteredKeywords.any((kw) => content.contains(kw.toLowerCase()))) {
              shouldFilter = true;
            }
          }
          if (!shouldFilter) {
            results.add(detail);
          }
        }
      } catch (e) {
        // Skip invalid items
      }
    }
    return results;
  }

  /// 获取指定源的 CMS 分类（`?ac=list` 的 class 数组）
  Future<List<CmsCategory>> getCategories(SiteConfig site) async {
    try {
      final url = '${site.api}?ac=list';
      final response = await _dio.get(url);
      final data = _asMap(response.data);
      if (data == null) return [];

      final classData = data['class'];
      if (classData is! List) return [];

      return classData
          .whereType<Map>()
          .map((e) => CmsCategory(
                id: (e['type_id'] ?? '').toString(),
                name: (e['type_name'] ?? '').toString(),
              ))
          .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 按源 + 分类分页拉取视频列表；typeId 为空表示全部（最新）
  Future<VodListResult> getVodList(SiteConfig site, {String? typeId, int page = 1}) async {
    try {
      final t = (typeId != null && typeId.isNotEmpty) ? '&t=$typeId' : '';
      final url = '${site.api}?ac=videolist$t&pg=$page';
      final response = await _dio.get(url);
      final data = _asMap(response.data);
      if (data == null) {
        return const VodListResult(videos: [], page: 1, pageCount: 1, total: 0);
      }

      final videos = _parseVideoList(data['list'], site);

      int pageCount = 1;
      final pc = data['pagecount'];
      if (pc is int) {
        pageCount = pc;
      } else if (pc is String) {
        pageCount = int.tryParse(pc) ?? 1;
      }

      int total = 0;
      final tt = data['total'];
      if (tt is int) {
        total = tt;
      } else if (tt is String) {
        total = int.tryParse(tt) ?? 0;
      }

      return VodListResult(videos: videos, page: page, pageCount: pageCount, total: total);
    } catch (e) {
      return VodListResult(videos: const [], page: page, pageCount: 1, total: 0);
    }
  }

  VideoDetail _parseVideoItem(Map<String, dynamic> item, SiteConfig site) {
    List<PlayGroup> playGroups = [];
    final String playFrom = (item['vod_play_from'] ?? '').toString();
    final String playUrl = (item['vod_play_url'] ?? '').toString();

    if (playFrom.isNotEmpty && playUrl.isNotEmpty) {
      final froms = playFrom.split('\$\$\$');
      final urlsGroups = playUrl.split('\$\$\$');

      for (int i = 0; i < froms.length; i++) {
        if (i >= urlsGroups.length) break;
        List<String> urls = [];
        List<String> titles = [];
        final episodesList = urlsGroups[i].split('#');
        for (var ep in episodesList) {
          final parts = ep.split('\$');
          if (parts.length == 2) {
            titles.add(parts[0].trim());
            urls.add(parts[1].trim());
          } else if (parts.length == 1 && parts[0].isNotEmpty) {
            titles.add('正片');
            urls.add(parts[0].trim());
          }
        }
        if (urls.isNotEmpty) {
          playGroups.add(PlayGroup(name: froms[i], urls: urls, titles: titles));
        }
      }
    }

    // 单个资源条目下只选取最长的一条线路
    if (playGroups.isNotEmpty) {
      playGroups.sort((a, b) => b.urls.length.compareTo(a.urls.length));
      playGroups = [playGroups.first];
    }

    return VideoDetail(
      id: item['vod_id'].toString(),
      title: (item['vod_name'] ?? '').toString().trim(),
      poster: item['vod_pic'] ?? '',
      playGroups: playGroups,
      source: site.key,
      sourceName: site.name,
      year: item['vod_year']?.toString(),
      desc: _cleanHtml((item['vod_content'] ?? '').toString()),
      typeName: item['type_name'],
      actor: (item['vod_actor'] ?? '').toString().trim().isEmpty ? null : (item['vod_actor']).toString().trim(),
      director: (item['vod_director'] ?? '').toString().trim().isEmpty ? null : (item['vod_director']).toString().trim(),
      area: (item['vod_area'] ?? '').toString().trim().isEmpty ? null : (item['vod_area']).toString().trim(),
      remarks: (item['vod_remarks'] ?? '').toString().trim().isEmpty ? null : (item['vod_remarks']).toString().trim(),
      score: _parseScore(item['vod_douban_score'] ?? item['vod_score']),
      duration: (item['vod_duration'] ?? '').toString().trim().isEmpty ? null : item['vod_duration'].toString().trim(),
      uploadTime: _parseDate(item['vod_time']),
    );
  }

  /// 解析日期（取 YYYY-MM-DD 部分）
  static String? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    // "2026-10-10 16:53:31" -> "2026-10-10"
    final match = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(s);
    return match?.group(0);
  }

  /// 解析评分（>0 才返回）
  static double? _parseScore(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString()) ?? 0;
    return d > 0 ? d : null;
  }

  /// 清理 HTML：去标签 + 反转义实体
  static String _cleanHtml(String html) {
    var text = html.replaceAll(RegExp(r'<[^>]*>'), '');
    // HTML 实体反转义
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'&#(\d+);'), ''); // 其他数字实体直接去掉
    return text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }
}
