import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/db_providers.dart';
import '../../db/app_db.dart';

final listsProvider = FutureProvider<List<MovieList>>((ref) async {
  final dao = ref.watch(listsDaoProvider);
  return dao.getAllLists();
});

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider);
    final listsDao = ref.watch(listsDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Мои списки')),
      body: lists.when(
        data: (items) => ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final l = items[i];

            return FutureBuilder<int>(
              future: listsDao.countMoviesInList(l.id),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                final icon = switch (l.type) {
                  'watched' => Icons.check_circle,
                  'planned' => Icons.bookmark,
                  _ => Icons.list,
                };

                return ListTile(
                  leading: Icon(icon),
                  title: Text(l.name),
                  subtitle: Text('$count фильмов'),
                  onTap: () => context.go('/lists/${l.id}'),
                );
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showDialog<String>(
            context: context,
            builder: (context) {
              final ctrl = TextEditingController();
              return AlertDialog(
                title: const Text('Новый список'),
                content: TextField(
                  controller: ctrl,
                  decoration:
                      const InputDecoration(hintText: 'Название списка'),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                    child: const Text('Создать'),
                  ),
                ],
              );
            },
          );
          if (name != null && name.isNotEmpty) {
            await listsDao.createList(
              MovieListsCompanion(
                  name: Value(name), type: const Value('custom')),
            );
            ref.invalidate(listsProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
