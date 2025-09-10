import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db_providers.dart';

class AddReviewSheet extends ConsumerStatefulWidget {
  const AddReviewSheet({super.key, required this.movieDbId});
  final int movieDbId; // локальный Movies.id

  @override
  ConsumerState<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<AddReviewSheet> {
  double _rating = 0; // 0..10, шаг 0.5
  final _textCtrl = TextEditingController();
  bool _spoiler = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final r = await ref
          .read(reviewsDaoProvider)
          .getReviewForMovie(widget.movieDbId);
      if (r != null && mounted) {
        setState(() {
          _rating = (r.rating ?? 0) / 10.0;
          _textCtrl.text = r.reviewText ?? '';
          _spoiler = r.spoiler;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Ваша оценка', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _rating,
            min: 0.0,
            max: 10.0,
            divisions: 20, // шаг 0.5
            label: _rating.toStringAsFixed(1),
            onChanged: (v) => setState(() => _rating = v),
          ),
          TextField(
            controller: _textCtrl,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Рецензия (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _spoiler,
            onChanged: (v) => setState(() => _spoiler = v ?? false),
            title: const Text('Содержит спойлеры'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final ratingX10 = (_rating * 10).round(); // 0..100
                    await ref.read(reviewsDaoProvider).upsertReviewForMovie(
                          movieId: widget.movieDbId,
                          ratingX10: ratingX10,
                          reviewText: _textCtrl.text.trim().isEmpty
                              ? null
                              : _textCtrl.text.trim(),
                          spoiler: _spoiler,
                        );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
