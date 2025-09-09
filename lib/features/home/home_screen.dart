import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movie Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: () => context.goNamed('search'),
            icon: const Icon(Icons.search),
            label: const Text('Поиск фильмов'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.goNamed('lists'),
            icon: const Icon(Icons.list),
            label: const Text('Мои списки'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.goNamed('profile'),
            icon: const Icon(Icons.person),
            label: const Text('Профиль'),
          ),
        ],
      ),
    );
  }
}
