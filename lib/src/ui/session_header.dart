import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/session_store.dart';
import '../theme/app_palette.dart';

/// The workout's name, editable in the pinned header.
///
/// **It owns its controller and writes on commit, not per keystroke.** The
/// header lives in the shell, which also renders the tab bar; rebuilding this
/// field from session state on every character would lose the caret and the
/// selection mid-word. So the field holds the text, and the session is told
/// when editing finishes.
///
/// **It carries its own semantics label.** The header wraps whatever it is
/// given in a header node, which would otherwise swallow the field's own
/// semantics and leave typing unannounced.
///
/// Capped at 40 characters: it is the hero text on a card about 300 points
/// wide, and a longer name has nowhere to go.
class SessionTitleField extends ConsumerStatefulWidget {
  const SessionTitleField({super.key});

  /// What an unnamed ad-hoc workout shows until the user names it, which they
  /// never have to.
  static const String placeholder = 'Name this workout';

  /// The most a title can be.
  static const int maxLength = 40;

  @override
  ConsumerState<SessionTitleField> createState() => _SessionTitleFieldState();
}

class _SessionTitleFieldState extends ConsumerState<SessionTitleField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _lastPushed = '';

  /// Which workout the field is currently showing the name of.
  ///
  /// **The header widget outlives the workout in it.** The shell hands the same
  /// field to every open session, so `initState` runs once and would otherwise
  /// leave the previous workout's name — or an empty box where a template's
  /// name belongs — on screen for the next one.
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_commitOnBlur);
  }

  /// Loads [session]'s name when the field is showing a different workout.
  ///
  /// Never while the user is typing: that would fight the caret.
  void _syncTo(WorkoutSession? session) {
    if (session == null || session.id == _sessionId) return;
    if (_focusNode.hasFocus) return;
    _sessionId = session.id;
    _lastPushed = session.title ?? '';
    _controller.text = _lastPushed;
  }

  void _commitOnBlur() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text == _lastPushed) return;
    _lastPushed = text;
    ref
        .read(activeSessionProvider.notifier)
        .rename(text.isEmpty ? null : text);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_commitOnBlur)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncTo(ref.watch(activeSessionProvider));

    return Semantics(
      textField: true,
      label: 'Workout name',
      excludeSemantics: true,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLength: SessionTitleField.maxLength,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _focusNode.unfocus(),
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppPalette.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: SessionTitleField.placeholder,
          hintStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppPalette.textMuted,
          ),
        ),
      ),
    );
  }
}
