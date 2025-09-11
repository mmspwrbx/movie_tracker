import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db_providers.dart'
    show listsDaoProvider, reviewsDaoProvider, profileStreamProvider;

import '../../db/app_db.dart';
import 'edit_profile_sheet.dart';

class ProfileStats {
  const ProfileStats({
    required this.watchedCount,
    required this.plannedCount,
    required this.totalMinutes,
    required this.topGenres,
    required this.avgMyRatingX10,
  });

  final int watchedCount;
  final int plannedCount;
  final int totalMinutes;
  final List<MapEntry<String, int>> topGenres;
  final double? avgMyRatingX10;

  String get totalHoursLabel {
    final h = (totalMinutes / 60).floor();
    final m = totalMinutes % 60;
    if (h == 0) return '$m мин';
    return '$h ч $m мин';
  }

  String get avgMyRatingLabel =>
      avgMyRatingX10 == null ? '—' : (avgMyRatingX10! / 10).toStringAsFixed(1);
}

final profileStatsProvider = FutureProvider<ProfileStats?>((ref) async {
  final profile =
      await ref.watch(profileStreamProvider.future).catchError((_) => null);
  if (profile == null) return null;

  final listsDao = ref.watch(listsDaoProvider);
  final reviewsDao = ref.watch(reviewsDaoProvider);

  final watchedCount = await listsDao.countMoviesInList(1);
  final plannedCount = await listsDao.countMoviesInList(2);
  final totalMinutes = await listsDao.totalRuntimeInList(1);
  final topGenres = await listsDao.topGenresInList(1, limit: 3);
  final avgX10 = await reviewsDao.averageRatingX10();

  return ProfileStats(
    watchedCount: watchedCount,
    plannedCount: plannedCount,
    totalMinutes: totalMinutes,
    topGenres: topGenres,
    avgMyRatingX10: avgX10,
  );
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _askedOnce = false;

  @override
  Widget build(BuildContext context) {
    final profileA = ref.watch(profileStreamProvider);
    final statsA = ref.watch(profileStatsProvider);

    _maybeAskCreate(profileA);

    final p = profileA.asData?.value;
    ImageProvider? avatarImage;
    final path = p?.avatarPath;
    if (path != null && path.trim().isNotEmpty && File(path).existsSync()) {
      avatarImage = FileImage(File(path));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: avatarImage,
                  child: avatarImage == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: profileA.when(
                    loading: () => const Text('Загрузка…'),
                    error: (e, _) => Text('Ошибка: $e'),
                    data: (prof) {
                      final name = (prof?.displayName?.trim().isNotEmpty ??
                              false)
                          ? prof!.displayName!.trim()
                          : (prof == null ? 'Профиль не создан' : 'Без имени');
                      final email = (prof?.email?.trim().isNotEmpty ?? false)
                          ? prof!.email!.trim()
                          : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name,
                              style: Theme.of(context).textTheme.titleLarge),
                          if (email != null)
                            Text(
                              email,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: profileA.asData?.value == null
                      ? 'Создать'
                      : 'Редактировать',
                  onPressed: () => _openEditSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          profileA.maybeWhen(
            data: (prof) => prof == null
                ? const SizedBox.shrink()
                : _statsAndGenres(context, statsA),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _statsAndGenres(
      BuildContext context, AsyncValue<ProfileStats?> statsA) {
    return statsA.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => _SectionCard(child: Text('Ошибка статистики: $e')),
      data: (s) {
        if (s == null) return const SizedBox.shrink();
        return Column(
          children: [
            _SectionCard(
              title: 'Статистика',
              child: Column(
                children: [
                  _StatRow(
                      icon: Icons.check_circle,
                      label: 'Просмотрено',
                      value: s.watchedCount.toString()),
                  _StatRow(
                      icon: Icons.bookmark,
                      label: 'Хочу посмотреть',
                      value: s.plannedCount.toString()),
                  _StatRow(
                      icon: Icons.timer,
                      label: 'Суммарно времени',
                      value: s.totalHoursLabel),
                  _StatRow(
                      icon: Icons.star_rate_rounded,
                      label: 'Средняя моя оценка',
                      value: '${s.avgMyRatingLabel} / 10'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Топ жанры (из просмотренного)',
              child: s.topGenres.isEmpty
                  ? const Text('Ещё нет просмотренных фильмов')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in s.topGenres)
                          Chip(
                            label: Text('${e.key} • ${e.value}'),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  void _maybeAskCreate(AsyncValue<UserProfile?> profileA) {
    if (_askedOnce) return;
    profileA.whenOrNull(
      data: (p) {
        if (p == null) {
          _askedOnce = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _openEditSheet(context));
        }
      },
    );
  }

  Future<void> _openEditSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const EditProfileSheet(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final titleW = title == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [if (titleW != null) titleW!, child],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
