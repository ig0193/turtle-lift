import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/ui/history_session_row.dart';

/// QA (second pass, date boundaries): the History row's "Today" / "Yesterday"
/// counted days as `today.difference(performedOn).inDays` between two local
/// midnights. Across a daylight-saving change one of those days is 23 hours
/// long, so on the Monday after the clocks went forward Sunday's workout read
/// "Today" and Saturday's read "Yesterday".
///
/// Meaningful only in a zone with daylight saving: `tool/qa.sh` runs this file
/// a second time under `TZ=America/New_York` (2026's change is 8 March). In a
/// zone without one it passes trivially.
void main() {
  final monday = DateTime(2026, 3, 9, 9);

  test('the day before is Yesterday across the spring change', () {
    expect(historyDateLabel(DateTime(2026, 3, 8), now: monday), 'Yesterday');
  });

  test('two days before is a date, not Yesterday', () {
    expect(historyDateLabel(DateTime(2026, 3, 7), now: monday), '7 Mar');
  });

  test('the same day is Today', () {
    expect(historyDateLabel(DateTime(2026, 3, 9), now: monday), 'Today');
  });

  test('across the autumn change too', () {
    final after = DateTime(2026, 11, 2, 9);
    expect(historyDateLabel(DateTime(2026, 11, 1), now: after), 'Yesterday');
    expect(historyDateLabel(DateTime(2026, 10, 31), now: after), '31 Oct');
  });
}
