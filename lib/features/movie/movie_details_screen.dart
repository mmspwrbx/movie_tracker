import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart'; // TMDb/OMDb и movieDetailsProvider
import '../../core/db_providers.dart'; // БД/DAO и review-провайдеры
import '../../db/app_db.dart'; // MoviesCompanion
import '../reviews/add_review_sheet.dart';
import '../../services/tmdb_client.dart' show TmdbMovie;

class MovieDetailsScreen extends ConsumerWidget {
  const MovieDetailsScreen({super.key, required this.movieId});
  final int movieId; // TMDb ID

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(movieDetailsProvider(movieId));

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: const Text('Карточка фильма'),
      ),
      body: details.when(
        data: (m) {
          // 1) Обеспечиваем наличие фильма в БД и получаем локальный ID
          final ensureMovieDbId = _ensureMovieInDb(ref, m);

          return FutureBuilder<int>(
            future: ensureMovieDbId,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final movieDbId = snap.data!;

              // 2) Подтягиваем мою рецензию и среднюю оценку
              final myReview = ref.watch(reviewForMovieProvider(movieDbId));
              final avgX10 = ref.watch(averageRatingX10Provider(movieDbId));

              // 👉 состояния вхождения в списки
              final inWatched = ref.watch(isInWatchedProvider(movieDbId));
              final inPlanned = ref.watch(isInPlannedProvider(movieDbId));

              return SingleChildScrollView(
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
                    Text(m.title,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                        '${m.year ?? '—'} • ${m.runtime ?? '—'} мин • ${m.genres.join(', ')}'),
                    const SizedBox(height: 12),
                    Text(m.overview ?? 'Описание отсутствует.'),
                    const SizedBox(height: 16),

                    // 3) Рейтинги
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      _Chip('TMDb', m.tmdbRating?.toStringAsFixed(1) ?? '—'),
                      _Chip('IMDb', m.imdbRating ?? '—'),
                      _Chip('Rotten Tomatoes', m.rottenTomatoes ?? '—'),
                      avgX10.when(
                        data: (v) => _Chip('Моя база',
                            v != null ? (v / 10).toStringAsFixed(1) : '—'),
                        loading: () => const Chip(label: Text('Моя база: …')),
                        error: (_, __) =>
                            const Chip(label: Text('Моя база: —')),
                      ),
                    ]),

                    const SizedBox(height: 16),
                    // 4) Кнопка «Оценить / Рецензия»
                    ElevatedButton.icon(
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Оценить / Рецензия'),
                      onPressed: () async {
                        final saved = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ProviderScope(
                            parent: ProviderScope.containerOf(context),
                            child: AddReviewSheet(movieDbId: movieDbId),
                          ),
                        );
                        if (saved == true) {
                          ref.invalidate(averageRatingX10Provider(movieDbId));
                          ref.invalidate(reviewForMovieProvider(movieDbId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Сохранено')),
                            );
                          }
                        }
                      },
                    ),

                    // 5) Показ «моей» рецензии (если есть)
                    myReview.when(
                      data: (r) => (r == null)
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text('Ваша рецензия',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                if (r.rating != null)
                                  Text(
                                      'Оценка: ${(r.rating! / 10).toStringAsFixed(1)} / 10'),
                                if ((r.reviewText ?? '').isNotEmpty)
                                  Text(r.reviewText!),
                              ],
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // 6) Кнопки списков — ТOGGLE
                    Row(
                      children: [
                        // Просмотрено
                        Expanded(
                          child: inWatched.when(
                            loading: () => const _BtnLoader(),
                            error: (_, __) => _DisabledBtn(
                                icon: Icons.check, text: 'Просмотрено'),
                            data: (isIn) {
                              final onToggle = () async {
                                final dao = ref.read(listsDaoProvider);
                                if (isIn) {
                                  await dao.removeMovieFromList(1, movieDbId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Удалено из «Просмотрено»')),
                                    );
                                  }
                                } else {
                                  await dao.addMovieToList(1, movieDbId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Добавлено в «Просмотрено»')),
                                    );
                                  }
                                }
                                ref.invalidate(isInWatchedProvider(movieDbId));
                              };

                              return isIn
                                  ? ElevatedButton.icon(
                                      icon: const Icon(Icons.check),
                                      label: const Text('В «Просмотрено»'),
                                      onPressed: onToggle,
                                    )
                                  : OutlinedButton.icon(
                                      icon: const Icon(Icons.check),
                                      label: const Text(
                                          'Добавить в «Просмотрено»'),
                                      onPressed: onToggle,
                                    );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Хочу посмотреть
                        Expanded(
                          child: inPlanned.when(
                            loading: () => const _BtnLoader(),
                            error: (_, __) => _DisabledBtn(
                                icon: Icons.bookmark, text: 'Хочу посмотреть'),
                            data: (isIn) {
                              final onToggle = () async {
                                final dao = ref.read(listsDaoProvider);
                                if (isIn) {
                                  await dao.removeMovieFromList(2, movieDbId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Удалено из «Хочу посмотреть»')),
                                    );
                                  }
                                } else {
                                  await dao.addMovieToList(2, movieDbId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Добавлено в «Хочу посмотреть»')),
                                    );
                                  }
                                }
                                ref.invalidate(isInPlannedProvider(movieDbId));
                              };

                              return isIn
                                  ? ElevatedButton.icon(
                                      icon: const Icon(Icons.bookmark_added),
                                      label: const Text('В «Хочу посмотреть»'),
                                      onPressed: onToggle,
                                    )
                                  : OutlinedButton.icon(
                                      icon: const Icon(
                                          Icons.bookmark_add_outlined),
                                      label: const Text(
                                          'Добавить в «Хочу посмотреть»'),
                                      onPressed: onToggle,
                                    );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }

  /// Гарантируем, что фильм есть в локальной БД, и возвращаем его локальный id.
  Future<int> _ensureMovieInDb(WidgetRef ref, TmdbMovie m) async {
    final moviesDao = ref.read(moviesDaoProvider);
    final existing = await moviesDao.getMovieByTmdb(m.tmdbId);
    if (existing != null) return existing.id;

    final id = await moviesDao.insertMovie(MoviesCompanion(
      tmdbId: Value(m.tmdbId),
      title: Value(m.title),
      year: Value(m.year),
      overview: Value(m.overview),
      posterUrl: Value(m.posterUrl),
      backdropUrl: Value(m.backdropUrl),
      genres: Value(m.genres.isEmpty ? null : m.genres),
      runtime: Value(m.runtime),
    ));
    return id;
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _BtnLoader extends StatelessWidget {
  const _BtnLoader({super.key});
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _DisabledBtn extends StatelessWidget {
  const _DisabledBtn({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
        icon: Icon(icon), label: Text(text), onPressed: null);
  }
}
