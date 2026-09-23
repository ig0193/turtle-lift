import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/load_type.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';

/// One set, as a row in its exercise's table.
///
/// **One widget for all four load types, not four widgets** — the same rule the
/// pushed `SetRow` was built on, and for the same reason: the completion rule
/// and the assisted inversion must have exactly one home. What changes here is
/// only the shape, from a stacked card to Hevy's table (`adr/0004`).
///
/// | type | cells |
/// |---|---|
/// | `weighted` | `KG` · `REPS` |
/// | `bodyweight` | `+KG` (optional) · `REPS` |
/// | `assisted` | `ASSIST` · `REPS` |
/// | `timed` | `TIME` |
///
/// **The sign is the load type's job, never the number's.** `ASSIST` holds a
/// positive number that means weight taken *off*; nothing in this app ever asks
/// the user to type a minus.
class SetTableRow extends StatefulWidget {
  const SetTableRow({
    required this.exerciseRowId,
    required this.index,
    required this.loadType,
    required this.entry,
    required this.previous,
    required this.onChanged,
    required this.onToggleComplete,
    required this.onDelete,
    this.isPersonalBest = false,
    super.key,
  });

  /// The `SessionExercises` row this set hangs off. Part of every key, because
  /// several exercises render their set 1 on the same screen.
  final String exerciseRowId;

  /// Zero-based; rendered one-based as the set number.
  final int index;

  final LoadType loadType;
  final SetEntry entry;

  /// What was done on this set last time, already formatted, or null for never.
  final String? previous;

  final ValueChanged<SetEntry> onChanged;

  /// Asked to tick the set. Refused, with the empty field focused, when the
  /// required value is missing — so this fires only on a real request.
  final VoidCallback onToggleComplete;

  final VoidCallback onDelete;

  /// Whether this set is the exercise's best ever. Earns the medal.
  final bool isPersonalBest;

  static Key rowKey(String exerciseRowId, int index) =>
      ValueKey<String>('set-row-$exerciseRowId-$index');
  static Key checkKey(String exerciseRowId, int index) =>
      ValueKey<String>('set-check-$exerciseRowId-$index');
  static Key previousKey(String exerciseRowId, int index) =>
      ValueKey<String>('set-previous-$exerciseRowId-$index');
  static Key weightFieldKey(String exerciseRowId, int index) =>
      ValueKey<String>('set-weight-$exerciseRowId-$index');
  static Key repsFieldKey(String exerciseRowId, int index) =>
      ValueKey<String>('set-reps-$exerciseRowId-$index');
  static Key durationFieldKey(String exerciseRowId, int index) =>
      ValueKey<String>('set-duration-$exerciseRowId-$index');

  /// The column headings this load type's table carries, after `SET` and
  /// `PREVIOUS` and before the tick. Public so the block's header row and the
  /// cells below it can never disagree about how many columns there are.
  static List<String> headingsFor(LoadType type) => switch (type) {
        LoadType.weighted => const <String>['KG', 'REPS'],
        LoadType.bodyweight => const <String>['+KG', 'REPS'],
        LoadType.assisted => const <String>['ASSIST', 'REPS'],
        LoadType.timed => const <String>['TIME'],
      };

  @override
  State<SetTableRow> createState() => _SetTableRowState();
}

class _SetTableRowState extends State<SetTableRow> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();
  final FocusNode _firstFocus = FocusNode();
  final FocusNode _secondFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(SetTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the user is not mid-edit: overwriting a field under a typing
    // finger loses the keystroke and moves the caret.
    if (!_firstFocus.hasFocus && !_secondFocus.hasFocus) _syncControllers();
  }

  void _syncControllers() {
    _first.text = _firstText();
    _second.text = widget.entry.reps?.toString() ?? '';
  }

  String _firstText() => switch (widget.loadType) {
        LoadType.weighted => _number(widget.entry.weightKg),
        LoadType.bodyweight => _number(widget.entry.addedKg),
        LoadType.assisted => _number(widget.entry.assistKg),
        LoadType.timed => widget.entry.durationSec == null
            ? ''
            : formatDuration(widget.entry.durationSec!),
      };

  static String _number(double? value) =>
      value == null ? '' : formatWeight(value);

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _firstFocus.dispose();
    _secondFocus.dispose();
    super.dispose();
  }

  SetEntry get _entry => widget.entry;

  void _writeFirst(String raw) {
    final value = widget.loadType == LoadType.timed
        ? _parseDuration(raw)?.toDouble()
        : double.tryParse(raw);
    widget.onChanged(
      SetEntry(
        id: _entry.id,
        position: _entry.position,
        completed: _entry.completed,
        weightKg: widget.loadType == LoadType.weighted ? value : _entry.weightKg,
        reps: _entry.reps,
        addedKg:
            widget.loadType == LoadType.bodyweight ? value : _entry.addedKg,
        assistKg:
            widget.loadType == LoadType.assisted ? value : _entry.assistKg,
        durationSec:
            widget.loadType == LoadType.timed ? value?.round() : _entry.durationSec,
      ),
    );
  }

  void _writeSecond(String raw) {
    widget.onChanged(
      SetEntry(
        id: _entry.id,
        position: _entry.position,
        completed: _entry.completed,
        weightKg: _entry.weightKg,
        reps: int.tryParse(raw),
        addedKg: _entry.addedKg,
        assistKg: _entry.assistKg,
        durationSec: _entry.durationSec,
      ),
    );
  }

  /// Accepts `90`, `1:30` and `01:30` alike — the user types whichever is
  /// quicker and both mean ninety seconds.
  static int? _parseDuration(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains(':')) return int.tryParse(text);
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    return minutes * 60 + seconds;
  }

  /// Refuses an empty required field rather than completing a blank set, and
  /// puts the cursor where the user has to go next.
  void _handleTick() {
    if (!_entry.completed && !hasRequiredValue(widget.loadType, _entry)) {
      final needsSecond = widget.loadType != LoadType.timed &&
          (_entry.reps == null || _entry.reps == 0);
      (needsSecond ? _secondFocus : _firstFocus).requestFocus();
      return;
    }
    widget.onToggleComplete();
  }

  @override
  Widget build(BuildContext context) {
    final headings = SetTableRow.headingsFor(widget.loadType);
    final done = isSetComplete(widget.loadType, _entry);

    return Dismissible(
      key: ValueKey<String>('dismiss-${_entry.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: ColoredBox(
        color: AppPalette.danger,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.delete_outline, color: AppPalette.textPrimary),
          ),
        ),
      ),
      child: Container(
        key: SetTableRow.rowKey(widget.exerciseRowId, widget.index),
        // A completed row fills accent, which here means exactly what the
        // palette says it means everywhere: this has been worked.
        color: done ? AppPalette.accentStrong.withValues(alpha: 0.18) : null,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                '${widget.index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.previous ?? '-',
                key: SetTableRow.previousKey(widget.exerciseRowId, widget.index),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppPalette.textMuted),
              ),
            ),
            Expanded(
              flex: 3,
              child: _Cell(
                controller: _first,
                focusNode: _firstFocus,
                fieldKey: widget.loadType == LoadType.timed
                    ? SetTableRow.durationFieldKey(
                        widget.exerciseRowId, widget.index)
                    : SetTableRow.weightFieldKey(
                        widget.exerciseRowId, widget.index),
                onChanged: _writeFirst,
                allowsColon: widget.loadType == LoadType.timed,
                allowsDecimal: widget.loadType != LoadType.timed,
                semanticsLabel: headings.first,
              ),
            ),
            if (headings.length > 1)
              Expanded(
                flex: 3,
                child: _Cell(
                  controller: _second,
                  focusNode: _secondFocus,
                  fieldKey: SetTableRow.repsFieldKey(
                      widget.exerciseRowId, widget.index),
                  onChanged: _writeSecond,
                  semanticsLabel: headings.last,
                ),
              ),
            SizedBox(
              width: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (widget.isPersonalBest)
                    const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(Icons.emoji_events_outlined,
                          size: 16, color: AppPalette.accentLight),
                    ),
                  IconButton(
                    key: SetTableRow.checkKey(
                        widget.exerciseRowId, widget.index),
                    onPressed: _handleTick,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      done ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20,
                      color:
                          done ? AppPalette.accentStrong : AppPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One editable cell. Compact by design — this row repeats a dozen times on a
/// screen the user is reading between sets.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.controller,
    required this.focusNode,
    required this.fieldKey,
    required this.onChanged,
    required this.semanticsLabel,
    this.allowsDecimal = false,
    this.allowsColon = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Key fieldKey;
  final ValueChanged<String> onChanged;
  final String semanticsLabel;
  final bool allowsDecimal;
  final bool allowsColon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: allowsDecimal),
        inputFormatters: <TextInputFormatter>[
          // No minus sign, anywhere in the app. The load type carries the sign.
          FilteringTextInputFormatter.allow(
            RegExp(allowsColon
                ? r'[0-9:]'
                : allowsDecimal
                    ? r'[0-9.]'
                    : r'[0-9]'),
          ),
        ],
        style: const TextStyle(color: AppPalette.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          filled: true,
          fillColor: AppPalette.mutedSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
          hintText: '-',
          hintStyle: const TextStyle(color: AppPalette.textMuted),
        ),
      ),
    );
  }
}
