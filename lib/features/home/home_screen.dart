import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/db_providers.dart' show profileStreamProvider;
import '../profile/edit_profile_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureProfile());
  }

  Future<void> _ensureProfile() async {
    if (_checked) return;
    _checked = true;
    final profile =
        await ref.read(profileStreamProvider.future).catchError((_) => null);
    if (!mounted || profile != null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const EditProfileSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // твоя существующая разметка...
    return Scaffold(
      appBar: AppBar(title: const Text('Movie Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NavTile(
              icon: Icons.search,
              title: 'Поиск фильмов',
              onTap: () => context.go('/search')),
          const SizedBox(height: 12),
          _NavTile(
              icon: Icons.auto_awesome,
              title: 'Рекомендации',
              onTap: () => context.go('/recommendations')),
          const SizedBox(height: 12),
          _NavTile(
              icon: Icons.list,
              title: 'Мои списки',
              onTap: () => context.go('/lists')),
          const SizedBox(height: 12),
          _NavTile(
              icon: Icons.person,
              title: 'Профиль',
              onTap: () => context.go('/profile')),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile(
      {required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cardColor =
        Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.15);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}
