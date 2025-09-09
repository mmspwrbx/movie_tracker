import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/providers.dart';
import '../../core/db_providers.dart';
import '../../db/app_db.dart';

class MovieDetailsScreen extends ConsumerWidget {
  const MovieDetailsScreen({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(movieDetailsProvider(movieId));
    final moviesDao = ref.watch(moviesDaoProvider);
    final listsDao = ref.watch(listsDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Карточка фильма')),
      body: details.when(
        data: (m) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.backdropUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(m.backdropUrl!),
                ),
              const SizedBox(height: 12),
              Text(m.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                  '${m.year ?? '—'} • ${m.runtime ?? '—'} мин • ${m.genres.join(', ')}'),
              const SizedBox(height: 12),
              Text(m.overview ?? 'Описание отсутствует.'),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Chip('TMDb', m.tmdbRating?.toStringAsFixed(1) ?? '—'),
                _Chip('IMDb', m.imdbRating ?? '—'),
                _Chip('Rotten Tomatoes', m.rottenTomatoes ?? '—'),
              ]),
              const SizedBox(height: 24),

              // 🔹 Кнопки для добавления в списки
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Просмотрено'),
                      onPressed: () async {
                        final movieIdDb =
                            await moviesDao.insertMovie(MoviesCompanion(
                          tmdbId: Value(m.tmdbId),
                          title: Value(m.title),
                          year: Value(m.year),
                          overview: Value(m.overview),
                          posterUrl: Value(m.posterUrl),
                          backdropUrl: Value(m.backdropUrl),
                          genres: Value(m.genres),
                          runtime: Value(m.runtime),
                        ));
                        await listsDao.addMovieToList(1, movieIdDb);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Добавлено в «Просмотрено»')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bookmark),
                      label: const Text('Хочу посмотреть'),
                      onPressed: () async {
                        final movieIdDb =
                            await moviesDao.insertMovie(MoviesCompanion(
                          tmdbId: Value(m.tmdbId),
                          title: Value(m.title),
                          year: Value(m.year),
                          overview: Value(m.overview),
                          posterUrl: Value(m.posterUrl),
                          backdropUrl: Value(m.backdropUrl),
                          genres: Value(m.genres),
                          runtime: Value(m.runtime),
                        ));
                        await listsDao.addMovieToList(2, movieIdDb);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Добавлено в «Хочу посмотреть»')),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text('Скриншоты', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: m.screenshots.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(m.screenshots[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
