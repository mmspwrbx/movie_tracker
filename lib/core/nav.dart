import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void openMovie(BuildContext context, int tmdbId) =>
    context.push('/movie/$tmdbId');
void openList(BuildContext context, int listId) =>
    context.push('/lists/$listId');
