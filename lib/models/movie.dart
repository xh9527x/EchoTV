class DoubanSubject {
  final String id;
  final String title;
  final String rate;
  final String cover;
  final String? url;
  final String? year;
  final String? pubdate;
  final String? description;

  DoubanSubject({
    required this.id,
    required this.title,
    required this.rate,
    required this.cover,
    this.url,
    this.year,
    this.pubdate,
    this.description,
  });

  factory DoubanSubject.fromJson(Map<String, dynamic> json) {
    // pubdate 可能是 ["2026-07-11"] 列表，取第一个
    String? pubdate;
    final pd = json['pubdate'];
    if (pd is List && pd.isNotEmpty) {
      pubdate = pd.first.toString();
    } else if (pd is String && pd.isNotEmpty) {
      pubdate = pd;
    }
    return DoubanSubject(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      rate: json['rate']?.toString() ?? json['rating']?['value']?.toString() ?? '0.0',
      cover: json['cover'] ?? json['pic']?['normal'] ?? json['pic']?['large'] ?? '',
      url: json['url'],
      year: json['year'],
      pubdate: pubdate,
      description: json['description'] ?? json['intro'],
    );
  }
}
