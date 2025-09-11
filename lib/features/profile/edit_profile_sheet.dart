// lib/features/profile/edit_profile_sheet.dart
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db_providers.dart'; // profileDaoProvider, profileStreamProvider
import '../../db/app_db.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String? _pickedAvatarPath;

  @override
  void initState() {
    super.initState();
    // Предзаполним
    Future.microtask(() async {
      final p = await ref.read(profileDaoProvider).getProfile();
      _name.text = p?.displayName ?? '';
      _email.text = p?.email ?? '';
      _pickedAvatarPath = p?.avatarPath;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _pickedAvatarPath;
    ImageProvider? avatarImage;
    if (avatar != null &&
        avatar.trim().isNotEmpty &&
        File(avatar).existsSync()) {
      avatarImage = FileImage(File(avatar));
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: avatarImage,
                child: avatarImage == null ? const Icon(Icons.person) : null,
              ),
              title: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                ),
              ),
              subtitle: TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.photo),
                tooltip: 'Выбрать аватар',
                onPressed: _pickAvatar,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Сохранить'),
                onPressed: _save,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    setState(() => _pickedAvatarPath = result.files.single.path);
  }

  Future<void> _save() async {
    final dao = ref.read(profileDaoProvider);

    final name = _name.text.trim();
    final email = _email.text.trim();

    await dao.upsertProfile(UserProfilesCompanion(
      displayName: Value(name.isEmpty ? null : name),
      email: Value(email.isEmpty ? null : email),
      avatarPath: Value(_pickedAvatarPath),
    ));

    // Можно и не делать: стрим сам эмитит, но пнём для мгновенного рефреша
    ref.invalidate(profileStreamProvider);

    if (mounted) Navigator.pop(context, true);
  }
}
