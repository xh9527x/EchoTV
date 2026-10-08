import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logger_service.dart';
import 'config_service.dart';

/// DoH 安全解析服务：通过 DNS over HTTPS 解析域名，绕过本地 DNS 劫持。
/// 用于视频源域名解析（CMS API、视频 CDN）。
final dohServiceProvider = Provider((ref) => DohService(ref));

/// 预设 DoH 服务器
class DohServer {
  final String name;
  final String url;
  const DohServer(this.name, this.url);

  static const List<DohServer> presets = [
    DohServer('阿里', 'https://dns.alidns.com/dns-query'),
    DohServer('腾讯', 'https://doh.pub/dns-query'),
    DohServer('Cloudflare', 'https://1.1.1.1/dns-query'),
    DohServer('Google', 'https://8.8.8.8/dns-query'),
  ];
}

class DohService {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
    headers: {'Accept': 'application/dns-json'},
  ));

  /// host -> ip 缓存，附带过期时间
  final Map<String, _DohCacheEntry> _cache = {};

  DohService(this._ref);

  /// 通过 DoH 解析域名，返回 IPv4 地址。失败返回 null（调用方回退系统 DNS）。
  Future<String?> resolve(String host) async {
    // IP 直接返回
    if (_isIp(host)) return host;

    // 查缓存
    final cached = _cache[host];
    if (cached != null && !cached.isExpired) return cached.ip;

    final logger = _ref.read(loggerServiceProvider);
    try {
      // 从设置读取 DoH 服务器
      final serverUrl = await _getDohServerUrl();
      final resp = await _dio.get(
        serverUrl,
        queryParameters: {'name': host, 'type': 'A'},
      );
      final data = resp.data;
      if (data is Map) {
        final answers = (data['Answer'] as List?) ?? [];
        for (final a in answers) {
          // type 1 = A 记录
          if (a['type'] == 1 && a['data'] is String) {
            final ip = a['data'] as String;
            if (_isIp(ip)) {
              _cache[host] = _DohCacheEntry(ip);
              logger.log('DoH', '$host -> $ip');
              return ip;
            }
          }
        }
      }
      logger.log('DoH', '$host 解析无结果');
    } catch (e) {
      _ref.read(loggerServiceProvider).log('DoH', '$host 解析失败：$e');
    }
    return null;
  }

  void clearCache() => _cache.clear();

  bool _isIp(String s) {
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(s);
  }

  Future<String> _getDohServerUrl() async {
    // 从 ConfigService 读取用户选择的服务器，默认 Cloudflare
    try {
      final configService = _ref.read(configServiceProvider);
      final url = await configService.getDohServer();
      if (url.isNotEmpty) return url;
    } catch (_) {}
    return DohServer.presets[0].url;
  }
}

class _DohCacheEntry {
  final String ip;
  final DateTime expiresAt;
  _DohCacheEntry(this.ip) : expiresAt = DateTime.now().add(const Duration(minutes: 10));
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
