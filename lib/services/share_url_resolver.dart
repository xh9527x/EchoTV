import 'package:dio/dio.dart';

/// 分享页解析结果：真实可播地址 + 建议携带的 Referer。
class ResolvedPlayUrl {
  final String url;
  final String? referer;

  const ResolvedPlayUrl({required this.url, this.referer});
}

/// 将第三方采集站常见的「分享页 / 网页链接」（如 /share/）解析为播放器可播的真实地址（多为 m3u8）。
///
/// 纯逻辑类，不依赖任何业务 Model；调用方只取 [ResolvedPlayUrl.url] / [referer]。
/// 算法借鉴 lemonTV-Film 的 ThirdPartyPlayUrlResolver（MIT），按 Dart 重写。
/// 未搬运其 MacCMS 解析接口（parse endpoint）部分——本项目暂无该配置。
class ShareUrlResolver {
  ShareUrlResolver({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {'User-Agent': _defaultUa, 'Accept': 'text/html,*/*'},
            ));

  final Dio _dio;

  /// 解析分享页。返回 null 表示抓取失败或未找到可播地址，
  /// 调用方应回退直接播放原地址。
  Future<ResolvedPlayUrl?> resolveSharePage(String pageUrl) async {
    final html = await _fetchText(pageUrl);
    if (html == null || html.isEmpty) return null;
    final streamUrl = extractStreamUrlFromHtml(html, pageUrl);
    if (streamUrl == null) return null;
    return ResolvedPlayUrl(url: streamUrl, referer: pageUrl);
  }

  /// 从分享页 HTML 中提取真实流地址。暴露为实例方法以便单测。
  ///
  /// 提取优先级：`var main = "..."` → `url/playurl/play_url/video = "..."` → 页内首个 m3u8。
  String? extractStreamUrlFromHtml(String html, String pageUrl) {
    final mainRaw = _mainJsPattern.firstMatch(html)?.group(1);
    if (mainRaw != null) {
      final candidate = resolveUrl(pageUrl, _unescape(mainRaw));
      if (isDirectPlayableUrl(candidate)) return candidate;
    }

    final playerRaw = _playerUrlPattern.firstMatch(html)?.group(1);
    if (playerRaw != null) {
      final candidate = resolveUrl(pageUrl, _unescape(playerRaw));
      if (isDirectPlayableUrl(candidate)) return candidate;
    }

    for (final m in _m3u8Pattern.allMatches(html)) {
      final candidate = resolveUrl(pageUrl, _unescape(m.group(1)!));
      if (isDirectPlayableUrl(candidate)) return candidate;
    }
    return null;
  }

  Future<String?> _fetchText(String url) async {
    try {
      final resp = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (resp.statusCode == 200) return resp.data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 去首尾空白，并还原 HTML 转义的 &amp;（分享页常见，签名参数不能断）。
  static String _unescape(String s) => s.trim().replaceAll('&amp;', '&');

  /// 相对地址按页面 URL 补全为绝对地址。
  static String resolveUrl(String baseUrl, String candidate) {
    final value = candidate.trim();
    if (value.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return value;
    }
    try {
      return Uri.parse(baseUrl).resolve(value).toString();
    } catch (_) {
      return value;
    }
  }

  static bool isDirectPlayableUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('file://') || lower.startsWith('content://')) {
      return true;
    }
    for (final ext in _directPlayableExtensions) {
      if (lower.contains(ext)) return true;
    }
    if (lower.contains('format=m3u8') || lower.contains('type=m3u8')) {
      return true;
    }
    return false;
  }

  static bool looksLikeShareOrPageUrl(String url) {
    final lower = url.toLowerCase();
    if (isDirectPlayableUrl(lower)) return false;
    return lower.contains('/share/') ||
        lower.contains('/play/') ||
        lower.contains('/video/') ||
        lower.contains('/vod/') ||
        lower.contains('url=') ||
        !lower.contains('.');
  }

  static const _defaultUa =
      'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static final _mainJsPattern = RegExp(
    r'''var\s+main\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final _playerUrlPattern = RegExp(
    r'''(?:url|playurl|play_url|video)\s*[:=]\s*["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final _m3u8Pattern = RegExp(
    r'''(https?://[^\s"'<>]+\.m3u8(?:\?[^\s"'<>]*)?)''',
    caseSensitive: false,
  );

  static const _directPlayableExtensions = [
    '.m3u8',
    '.mp4',
    '.mkv',
    '.flv',
    '.mov',
    '.webm',
    '.ts',
    '.m4v',
    '.avi',
  ];
}
