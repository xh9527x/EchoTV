class DoubanSubject {
  final String id;
  final String title;
  final String rate;
  final String cover;
  final String? url;
  final String? year;
  final String? pubdate;
  final String? description;
  // 详情/列表扩展字段
  final List<String> directors;
  final List<String> actors;
  final List<String> countries;
  final List<String> genres;
  final List<String> durations;
  final double starCount; // 5星制
  final int ratingCount; // 评分人数

  DoubanSubject({
    required this.id,
    required this.title,
    required this.rate,
    required this.cover,
    this.url,
    this.year,
    this.pubdate,
    this.description,
    this.directors = const [],
    this.actors = const [],
    this.countries = const [],
    this.genres = const [],
    this.durations = const [],
    this.starCount = 0,
    this.ratingCount = 0,
  });

  /// 解析 card_subtitle："2026 / 中国大陆 / 剧情 喜剧 / 周星驰 / 张小斐 迪丽热巴"
  /// 返回 [year, countries, genres, directors, actors]
  static List<List<String>> parseCardSubtitle(String? subtitle) {
    final result = <List<String>>[[], [], [], [], []];
    if (subtitle == null || subtitle.isEmpty) return result;
    final parts = subtitle.split(' / ');
    // part0: 年份
    if (parts.isNotEmpty) {
      final y = parts[0].trim();
      if (RegExp(r'^\d{4}$').hasMatch(y)) result[0] = [y];
    }
    // part1: 地区（空格分隔）
    if (parts.length > 1) {
      result[1] = parts[1].trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    }
    // part2: 类型（空格分隔）
    if (parts.length > 2) {
      result[2] = parts[2].trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    }
    // part3: 导演（空格分隔）
    if (parts.length > 3) {
      result[3] = parts[3].trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    }
    // part4: 主演（空格分隔）
    if (parts.length > 4) {
      result[4] = parts[4].trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    }
    return result;
  }

  factory DoubanSubject.fromJson(Map<String, dynamic> json) {
    // pubdate 可能是 ["2026-07-11"] 列表，取第一个
    String? pubdate;
    final pd = json['pubdate'];
    if (pd is List && pd.isNotEmpty) {
      pubdate = pd.first.toString();
    } else if (pd is String && pd.isNotEmpty) {
      pubdate = pd;
    }

    // card_subtitle 解析（列表接口）
    final cs = parseCardSubtitle(json['card_subtitle']?.toString());

    // 详情接口的结构化字段
    List<String> _names(dynamic list) {
      if (list is! List) return [];
      return list.map((e) => e is Map ? (e['name']?.toString() ?? '') : e.toString()).where((e) => e.isNotEmpty).toList();
    }
    List<String> _strList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      if (v is String && v.isNotEmpty) return [v];
      return [];
    }

    final rating = json['rating'];
    double starCount = 0;
    int ratingCount = 0;
    if (rating is Map) {
      starCount = (rating['star_count'] as num?)?.toDouble() ?? 0;
      ratingCount = (rating['count'] as num?)?.toInt() ?? 0;
    }

    return DoubanSubject(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      rate: json['rate']?.toString() ?? json['rating']?['value']?.toString() ?? '0.0',
      cover: json['cover'] ?? json['pic']?['normal'] ?? json['pic']?['large'] ?? '',
      url: json['url'],
      year: json['year'] ?? (cs[0].isNotEmpty ? cs[0].first : null),
      pubdate: pubdate,
      description: json['description'] ?? json['intro'],
      directors: _names(json['directors']).isNotEmpty ? _names(json['directors']) : cs[3],
      actors: _names(json['actors']).isNotEmpty ? _names(json['actors']) : cs[4],
      countries: _strList(json['countries']).isNotEmpty ? _strList(json['countries']) : cs[1],
      genres: _strList(json['genres']).isNotEmpty ? _strList(json['genres']) : cs[2],
      durations: _strList(json['durations']),
      starCount: starCount,
      ratingCount: ratingCount,
    );
  }
}
