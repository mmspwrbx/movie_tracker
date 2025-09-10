// lib/router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/search/search_screen.dart';
import 'features/lists/lists_screen.dart';
import 'features/lists/list_details_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/movie/movie_details_screen.dart';
import 'features/recs/recommendations_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'search',
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: 'lists',
            name: 'lists',
            builder: (context, state) => const ListsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'listDetails',
                builder: (context, state) {
                  final id =
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  return ListDetailsScreen(listId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'recommendations', // ← добавлено
            name: 'recommendations',
            builder: (context, state) => const RecommendationsScreen(),
          ),
          GoRoute(
            path: 'profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'movie/:id',
            name: 'movie',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return MovieDetailsScreen(movieId: id);
            },
          ),
        ],
      ),
    ],
  );
});
