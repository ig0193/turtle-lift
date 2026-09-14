import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workout_templates.dart';

/// The templates the user built themselves.
///
/// **Empty in every shipped build today, and that is not a bug.** Template
/// authoring lives behind the Profile avatar (`docs/00-build-spec.md` §11) and
/// is build-order step 7, so there is currently no way for a user to create
/// one. This provider exists anyway because the Workout landing has to render
/// *something* for them, and the group's real contract — that it disappears
/// entirely when the list is empty, rather than leaving a heading over nothing
/// — is only testable if the rendering path exists.
///
/// **Custom templates sit outside the split filter.** They are shown whichever
/// filter is selected. With no unfiltered "All" value, classifying them by
/// muscle composition would leave a user's own template reachable only from
/// whichever bucket the classifier picked, and an arbitrary catch-all would put
/// a single-muscle custom template under Multi Split while the predefined
/// equivalent sat under 1 Muscle per day.
///
/// When authoring lands this becomes a database read and very likely async;
/// the landing reads it through this one provider either way.
final customTemplatesProvider = Provider<List<WorkoutTemplate>>(
  (ref) => const <WorkoutTemplate>[],
);
