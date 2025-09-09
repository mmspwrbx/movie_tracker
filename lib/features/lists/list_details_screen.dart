import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db_providers.dart';
import '../../db/app_db.dart';

final listMoviesProvider =
    FutureProvider.family<List<Movie>, int>((ref, listId) async {
  final dao = ref.watch(listsDaoProvider);
  return dao.getMoviesInList(listId);
});

class ListDetailsScreen extends ConsumerWidget {
  const ListDetailsScreen({super.key, required this.listId});
  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(listMoviesProvider(listId));
    final listsDao = ref.watch(listsDaoProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Список #$listId')),
      body: movies.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('Пусто'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = items[i];

                  final meta = [
                    m.year?.toString(),
                    (m.genres?.isNotEmpty ?? false)
                        ? m.genres!.join(', ')
                        : null,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

                  return Dismissible(
                    key: ValueKey('${m.id}_$listId'),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      await listsDao.removeMovieFromList(listId, m.id);
                      ref.invalidate(listMoviesProvider(listId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Удалено: ${m.title}')),
                      );
                    },
                    child: ListTile(
                      leading: m.posterUrl != null
                          ? Image.network(m.posterUrl!,
                              width: 48, fit: BoxFit.cover)
                          : const SizedBox(width: 48),
                      title: Text(m.title),
                      subtitle: meta.isNotEmpty ? Text(meta) : null,
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}
