import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/routine_store.dart';
import '../data/routines.dart';
import '../theme/app_palette.dart';
import 'destructive_confirmation.dart';
import 'name_prompt.dart';
import 'routine_builder_screen.dart';
import 'routine_card.dart';

/// One folder of routines on the landing, collapsible.
///
/// **Collapsed state is per-widget and deliberately not stored.** It is a
/// glance-level preference that costs one tap to redo, and `app_database.dart`
/// keeps only what cannot be derived or cheaply retaken — a column per folder
/// for "was it open" is exactly the kind of state that rots.
class RoutineFolderSection extends ConsumerStatefulWidget {
  const RoutineFolderSection({
    required this.folder,
    required this.routines,
    super.key,
  });

  final RoutineFolder folder;
  final List<Routine> routines;

  static Key headerKey(String folderId) =>
      ValueKey<String>('folder-header-$folderId');
  static Key menuKey(String folderId) =>
      ValueKey<String>('folder-menu-$folderId');

  @override
  ConsumerState<RoutineFolderSection> createState() =>
      _RoutineFolderSectionState();
}

class _RoutineFolderSectionState extends ConsumerState<RoutineFolderSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                key: RoutineFolderSection.headerKey(widget.folder.id),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      color: AppPalette.textSecondary,
                    ),
                    Text(
                      '${widget.folder.name} (${widget.routines.length})',
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _FolderMenu(folder: widget.folder),
          ],
        ),
        if (_expanded) ...<Widget>[
          const SizedBox(height: 8),
          if (widget.routines.isEmpty)
            _AddToFolder(folderId: widget.folder.id)
          else
            for (final routine in widget.routines)
              RoutineCard(routine: routine),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

/// The dashed "+ Add new routine" slot an empty folder shows, so a folder the
/// user just made is not a heading over nothing.
class _AddToFolder extends StatelessWidget {
  const _AddToFolder({required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoutineBuilderScreen(folderId: folderId),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.border),
          ),
          child: const Text(
            '+ Add new routine',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.accentLight),
          ),
        ),
      );
}

class _FolderMenu extends ConsumerWidget {
  const _FolderMenu({required this.folder});

  final RoutineFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: RoutineFolderSection.menuKey(folder.id),
      icon: const Icon(Icons.more_horiz, color: AppPalette.textSecondary),
      color: AppPalette.surface,
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'add', child: Text('Add routine')),
        const PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete folder',
              style: TextStyle(color: AppPalette.danger)),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'add':
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RoutineBuilderScreen(folderId: folder.id),
              ),
            );
          case 'rename':
            final name = await promptForName(
              context,
              title: 'Rename folder',
              initial: folder.name,
              confirmLabel: 'Rename',
            );
            if (name != null && name.isNotEmpty) {
              await ref
                  .read(routineFolderListProvider.notifier)
                  .rename(folder.id, name);
            }
          case 'delete':
            final confirmed = await confirmDestructive(
              context,
              title: 'Delete ${folder.name}?',
              // The one destructive action in this app that destroys less than
              // it appears to, so it says so plainly.
              message: 'The folder is removed. Routines inside it are kept and '
                  'move back to My routines.',
              confirmLabel: 'Delete folder',
            );
            if (confirmed) {
              await ref
                  .read(routineFolderListProvider.notifier)
                  .delete(folder.id);
            }
        }
      },
    );
  }
}
