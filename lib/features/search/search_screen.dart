import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../services/tmdb_client.dart';

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<TmdbMovie>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final client = ref.watch(tmdbClientProvider);
  return client.searchMovies(query);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final results = ref.watch(searchResultsProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Введите название фильма...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _controller.clear()),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: results.when(
            data: (list) => ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = list[i];
                return ListTile(
                  leading: m.posterUrl != null
                      ? Image.network(m.posterUrl!,
                          width: 48, fit: BoxFit.cover)
                      : const SizedBox(width: 48),
                  title: Text(m.title),
                  subtitle: Text(m.year != null ? m.year.toString() : '—'),
                  onTap: () => context.go('/movie/${m.tmdbId}'),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Ошибка: $e')),
          ),
        )
      ]),
    );
  }
}
