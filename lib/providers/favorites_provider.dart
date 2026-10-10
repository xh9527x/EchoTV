import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/site.dart';
import '../services/config_service.dart';

final favoritesProvider = NotifierProvider<FavoritesNotifier, AsyncValue<List<Favorite>>>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<AsyncValue<List<Favorite>>> {
  @override
  AsyncValue<List<Favorite>> build() {
    _load();
    return const AsyncLoading();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(configServiceProvider).getFavorites();
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> toggle(Favorite fav) async {
    final service = ref.read(configServiceProvider);
    final current = <Favorite>[...(state.value ?? <Favorite>[])];
    final idx = current.indexWhere((e) => e.title == fav.title && e.sourceName == fav.sourceName);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.insert(0, fav);
    }
    await service.saveFavorites(current);
    state = AsyncData(current);
  }

  bool isFavorite(String title, String sourceName) {
    return (state.value ?? []).any((e) => e.title == title && e.sourceName == sourceName);
  }

  Future<void> remove(Favorite fav) async {
    final service = ref.read(configServiceProvider);
    final current = <Favorite>[...(state.value ?? <Favorite>[])]..removeWhere((e) => e.title == fav.title && e.sourceName == fav.sourceName);
    await service.saveFavorites(current);
    state = AsyncData(current);
  }
}
