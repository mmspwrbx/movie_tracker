// lib/features/recs/recommendations_screen.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/tmdb_client.dart' show TmdbMovie;
import '../../core/providers.dart'; // tmdbClientProvider, omdbClientProvider
import '../../core/db_providers.dart'; // listsDaoProvider, isIn* providers, reviewForMovieProvider
import '../../db/app_db.dart';
import '../../core/nav.dart';

/// =========================
/// Модель и контроллер фильтров
/// =========================
class RecFilters {
  const RecFilters({
    this.genres = const {},
    this.yearFrom = 1900,
    this.yearTo = 2100,
    this.minTmdb = 0.0,
  });

  final Set<String> genres; // мультивыбор по названиям жанров
  final int yearFrom;
  final int yearTo;
  final double minTmdb;

  RecFilters copyWith({
    Set<String>? genres,
    int? yearFrom,
    int? yearTo,
    double? minTmdb,
  }) =>
      RecFilters(
        genres: genres ?? this.genres,
        yearFrom: yearFrom ?? this.yearFrom,
        yearTo: yearTo ?? this.yearTo,
        minTmdb: minTmdb ?? this.minTmdb,
      );

  bool matches(TmdbMovie m) {
    // жанры: если выбрано хоть что-то — требуем пересечение
    if (genres.isNotEmpty) {
      final has = m.genres.any(genres.contains);
      if (!has) return false;
    }
    // год: допускаем null (если у фильма не указан год — не отфильтровываем по диапазону)
    final y = m.year;
    if (y != null && (y < yearFrom || y > yearTo)) return false;

    // TMDb рейтинг
    final r = m.tmdbRating ?? 0;
    if (r < minTmdb) return false;

    return true;
  }

  bool get isDefault => genres.isEmpty && minTmdb == 0 && yearFrom <= 1900;
}

class RecFiltersController extends StateNotifier<RecFilters> {
  RecFiltersController() : super(RecFilters(yearTo: DateTime.now().year));

  void set(RecFilters v) => state = v;
  void reset(int minYear, int maxYear) =>
      state = RecFilters(yearFrom: minYear, yearTo: maxYear, minTmdb: 0.0);
}

final recFiltersProvider =
    StateNotifierProvider<RecFiltersController, RecFilters>(
        (ref) => RecFiltersController());

/// =========================
/// Базовые (нефильтрованные) рекомендации
/// =========================
final _unfilteredRecommendationsProvider =
    FutureProvider.autoDispose<List<TmdbMovie>>((ref) async {
  final tmdb = ref.watch(tmdbClientProvider);
  final listsDao = ref.watch(listsDaoProvider);

  final watched = await listsDao.getMoviesInList(1);
  final planned = await listsDao.getMoviesInList(2);

  final exclude = <int>{
    ...watched.map((m) => m.tmdbId),
    ...planned.map((m) => m.tmdbId),
  };

  final basis = watched.take(10);
  final Map<int, _ScoredMovie> bucket = {};
  for (final base in basis) {
    final recs = await tmdb.recommendations(base.tmdbId);
    for (final r in recs) {
      if (exclude.contains(r.tmdbId)) continue;
      final exist = bucket[r.tmdbId];
      if (exist == null) {
        bucket[r.tmdbId] = _ScoredMovie(movie: r, count: 1);
      } else {
        exist.count += 1;
      }
    }
  }

  final list = bucket.values.toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      final ar = a.movie.tmdbRating ?? 0;
      final br = b.movie.tmdbRating ?? 0;
      return br.compareTo(ar);
    });

  return list.map((e) => e.movie).take(200).toList();
});

class _ScoredMovie {
  _ScoredMovie({required this.movie, required this.count});
  final TmdbMovie movie;
  int count;
}

/// Доступные жанры из текущей выдачи
final availableGenresProvider = Provider<Set<String>>((ref) {
  final base = ref.watch(_unfilteredRecommendationsProvider).maybeWhen(
        data: (v) => v,
        orElse: () => const <TmdbMovie>[],
      );
  return {
    for (final g in base.expand((m) => m.genres))
      if (g.trim().isNotEmpty) g
  };
});

/// Диапазон лет по текущей выдаче (мин/макс)
final yearsBoundsProvider = Provider<(int min, int max)>((ref) {
  final base = ref.watch(_unfilteredRecommendationsProvider).maybeWhen(
        data: (v) => v,
        orElse: () => const <TmdbMovie>[],
      );
  final ys = base.map((m) => m.year).whereType<int>().toList();
  if (ys.isEmpty) return (1950, DateTime.now().year);
  ys.sort();
  return (ys.first, ys.last);
});

/// Фильтрованные рекомендации
final recommendationsFeedProvider =
    FutureProvider.autoDispose<List<TmdbMovie>>((ref) async {
  final base = await ref.watch(_unfilteredRecommendationsProvider.future);
  final filters = ref.watch(recFiltersProvider);
  return base.where(filters.matches).toList();
});

/// ---------- внешние рейтинги для карточки ----------
class _ExtRatings {
  const _ExtRatings({this.imdb, this.rt});
  final String? imdb; // "7.8/10"
  final String? rt; // "91%"
}

final externalRatingsProvider =
    FutureProvider.autoDispose.family<_ExtRatings, int>((ref, tmdbId) async {
  final tmdb = ref.watch(tmdbClientProvider);
  final omdb = ref.watch(omdbClientProvider);

  if (!omdb.isConfigured) return const _ExtRatings();

  try {
    final imdbId = await tmdb.imdbIdFor(tmdbId);
    if (imdbId == null) return const _ExtRatings();

    final r = await omdb.ratings(imdbId: imdbId);
    return _ExtRatings(imdb: r['imdb'], rt: r['rt']);
  } catch (_) {
    return const _ExtRatings();
  }
});

/// =========================
/// UI
/// =========================
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsFeedProvider);
    final bounds = ref.watch(yearsBoundsProvider);
    final filters = ref.watch(recFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рекомендации'),
        actions: [
          // Индикатор: если фильтры активны — точка на иконке
          Stack(
            children: [
              IconButton(
                tooltip: 'Фильтры',
                icon: const Icon(Icons.filter_list),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ProviderScope(
                    parent: ProviderScope.containerOf(context),
                    child: _FiltersSheet(bounds: bounds),
                  ),
                ),
              ),
              if (!filters.isDefault)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: recs.when(
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
            const targetTileWidth = 320.0;
            final maxWidth = constraints.maxWidth.clamp(320.0, 5000.0);
            final rawCols = (maxWidth / targetTileWidth).floor();
            final cols = rawCols.clamp(1, 6);
            final maxExtent = maxWidth / cols;
            const childAspect = 0.57; // чуть выше карточка

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_unfilteredRecommendationsProvider);
                await ref.read(_unfilteredRecommendationsProvider.future);
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: childAspect,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _RecCard(movie: items[i]),
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

class _RecCard extends ConsumerStatefulWidget {
  const _RecCard({required this.movie, super.key});
  final TmdbMovie movie;

  @override
  ConsumerState<_RecCard> createState() => _RecCardState();
}

class _RecCardState extends ConsumerState<_RecCard> {
  int? _movieDbId;

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  Future<void> _ensure() async {
    final id = await _ensureMovieInDb(ref, widget.movie);
    if (mounted) setState(() => _movieDbId = id);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final radius = BorderRadius.circular(12);

    return InkWell(
      onTap: () => openMovie(context, m.tmdbId),
      borderRadius: radius,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: m.posterUrl != null
                        ? Image.network(m.posterUrl!, fit: BoxFit.cover)
                        : Container(color: Colors.black12),
                  ),
                  if (_movieDbId != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _ListToggleIcon(
                            movieDbId: _movieDbId!,
                            listId: 1,
                            provider: isInWatchedProvider,
                            iconOn: Icons.check,
                            iconOff: Icons.check,
                            tooltipOn: 'В «Просмотрено»',
                            tooltipOff: 'Добавить в «Просмотрено»',
                          ),
                          const SizedBox(height: 8),
                          _ListToggleIcon(
                            movieDbId: _movieDbId!,
                            listId: 2,
                            provider: isInPlannedProvider,
                            iconOn: Icons.bookmark_added,
                            iconOff: Icons.bookmark_add_outlined,
                            tooltipOn: 'В «Хочу посмотреть»',
                            tooltipOff: 'Добавить в «Хочу посмотреть»',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                child: Text(
                  m.title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: _RatingsRow(movie: m, movieDbId: _movieDbId),
            ),
          ],
        ),
      ),
    );
  }

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

class _RatingsRow extends ConsumerWidget {
  const _RatingsRow({required this.movie, required this.movieDbId, super.key});
  final TmdbMovie movie;
  final int? movieDbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = movie;
    return Row(
      children: [
        _TmdbBadge(value: (m.tmdbRating ?? 0).toStringAsFixed(1)),
        const SizedBox(width: 6),
        Consumer(
          builder: (context, ref, _) {
            final ext = ref.watch(externalRatingsProvider(m.tmdbId));
            return ext.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (r) => Row(
                children: [
                  if (r.imdb != null) _ImdbBadge(value: r.imdb!),
                  if (r.rt != null) ...[
                    const SizedBox(width: 6),
                    _RtBadge(value: r.rt!),
                  ],
                ],
              ),
            );
          },
        ),
        const Spacer(),
        if (movieDbId != null) _MyRatingBadge(movieDbId: movieDbId!),
      ],
    );
  }
}

/// =========================
/// Шторка настроек фильтров
/// =========================
class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.bounds, super.key});
  final (int min, int max) bounds;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late Set<String> _genres;
  late RangeValues _years;
  double _minTmdb = 0;

  @override
  void initState() {
    super.initState();
    final current = ref.read(recFiltersProvider);
    final (minY, maxY) = widget.bounds;
    _genres = {...current.genres};
    _years = RangeValues(
      current.yearFrom.clamp(minY, maxY).toDouble(),
      current.yearTo.clamp(minY, maxY).toDouble(),
    );
    _minTmdb = current.minTmdb;
  }

  @override
  Widget build(BuildContext context) {
    final genresAvail = ref.watch(availableGenresProvider).toList()..sort();
    final (minY, maxY) = widget.bounds;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Фильтры',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _genres.clear();
                          _years =
                              RangeValues(minY.toDouble(), maxY.toDouble());
                          _minTmdb = 0;
                        });
                      },
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ЖАНРЫ
                const Text('Жанры',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in genresAvail)
                      FilterChip(
                        label: Text(g),
                        selected: _genres.contains(g),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _genres.add(g);
                          } else {
                            _genres.remove(g);
                          }
                        }),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // ГОДЫ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Годы выпуска',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      '${_years.start.round()} – ${_years.end.round()}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                RangeSlider(
                  min: minY.toDouble(),
                  max: maxY.toDouble(),
                  divisions: (maxY - minY),
                  values: _years,
                  labels: RangeLabels(
                    _years.start.round().toString(),
                    _years.end.round().toString(),
                  ),
                  onChanged: (v) => setState(() => _years = v),
                ),

                const SizedBox(height: 12),

                // TMDb рейтинг
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Минимальная TMDb-оценка',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      _minTmdb.toStringAsFixed(1),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  min: 0,
                  max: 10,
                  divisions: 20, // по 0.5
                  value: _minTmdb,
                  label: _minTmdb.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _minTmdb = v),
                ),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Применить'),
                    onPressed: () {
                      ref.read(recFiltersProvider.notifier).set(
                            RecFilters(
                              genres: _genres,
                              yearFrom: _years.start.round(),
                              yearTo: _years.end.round(),
                              minTmdb: _minTmdb,
                            ),
                          );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------- бейджи ----------
class _TmdbBadge extends StatelessWidget {
  const _TmdbBadge({required this.value, super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7);
    final fg = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style:
              TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

class _ImdbBadge extends StatelessWidget {
  const _ImdbBadge({required this.value, super.key});
  final String value; // "7.8/10"
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade700,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'IMDb $value',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RtBadge extends StatelessWidget {
  const _RtBadge({required this.value, super.key});
  final String value; // "92%"

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7);
    final fg = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('🍅', style: TextStyle(fontSize: 12, height: 1.0)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MyRatingBadge extends ConsumerWidget {
  const _MyRatingBadge({required this.movieDbId, super.key});
  final int movieDbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myReview = ref.watch(reviewForMovieProvider(movieDbId));
    return myReview.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) {
        final ratingX10 = r?.rating;
        if (ratingX10 == null) return const SizedBox.shrink();
        final value = (ratingX10 / 10).toStringAsFixed(1);
        final bg = Theme.of(context).colorScheme.secondaryContainer;
        final fg = Theme.of(context).colorScheme.onSecondaryContainer;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          ]),
        );
      },
    );
  }
}

class _ListToggleIcon extends ConsumerWidget {
  const _ListToggleIcon({
    super.key,
    required this.movieDbId,
    required this.listId,
    required this.provider,
    required this.iconOn,
    required this.iconOff,
    required this.tooltipOn,
    required this.tooltipOff,
  });

  final int movieDbId;
  final int listId;
  final FutureProviderFamily<bool, int> provider;
  final IconData iconOn;
  final IconData iconOff;
  final String tooltipOn;
  final String tooltipOff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsDao = ref.watch(listsDaoProvider);
    final state = ref.watch(provider(movieDbId));

    final bgOn = Theme.of(context).colorScheme.primaryContainer;
    final fgOn = Theme.of(context).colorScheme.onPrimaryContainer;
    final bgOff = Colors.black38;
    final fgOff = Colors.white;

    return state.when(
      loading: () => const _TinyLoader(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isIn) => IconButton(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(isIn ? bgOn : bgOff),
          foregroundColor: WidgetStatePropertyAll(isIn ? fgOn : fgOff),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(isIn ? iconOn : iconOff, size: 18),
        tooltip: isIn ? tooltipOn : tooltipOff,
        onPressed: () async {
          if (isIn) {
            await listsDao.removeMovieFromList(listId, movieDbId);
          } else {
            await listsDao.addMovieToList(listId, movieDbId);
          }
          ref.invalidate(provider(movieDbId));
        },
      ),
    );
  }
}

class _TinyLoader extends StatelessWidget {
  const _TinyLoader({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Colors.black38,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
