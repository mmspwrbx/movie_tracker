// lib/features/lists/list_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                      await ref
                          .read(listsDaoProvider)
                          .removeMovieFromList(listId, m.id);
                      ref.invalidate(listMoviesProvider(listId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Удалено: ${m.title}')),
                      );
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: m.posterUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                m.posterUrl!,
                                width: 48,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const SizedBox(width: 48, height: 72),
                      title: Text(m.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: meta.isNotEmpty ? Text(meta) : null,
                      // 👉 по тапу открываем карточку фильма (TMDb id хранится в Movie.tmdbId)
                      onTap: () => context.go('/movie/${m.tmdbId}'),
                      // 👉 справа показываем мою оценку, если есть
                      trailing: _MyRatingPill(movieDbId: m.id),
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

class _MyRatingPill extends ConsumerWidget {
  const _MyRatingPill({required this.movieDbId});
  final int movieDbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myReview = ref.watch(reviewForMovieProvider(movieDbId));

    return myReview.when(
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) {
        final ratingX10 = r?.rating; // int? (0–100 с шагом 5)
        if (ratingX10 == null) return const SizedBox.shrink();

        final value = (ratingX10 / 10).toStringAsFixed(1);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
