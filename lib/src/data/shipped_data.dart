/// Counts derived from the generated data.
///
/// These live here rather than in `generated/` because that directory is
/// generator output and is never hand-edited (CLAUDE.md). They exist so the
/// same fold is not written out at each call site.
library;

import 'generated/body_paths.dart';
import 'generated/muscle_taxonomy.dart';

/// Sub-muscle groups across all 12 parent groups. 19, per `00` §1.
int get kSubMuscleGroupCount =>
    kMuscleTaxonomy.values.fold<int>(0, (n, subs) => n + subs.length);

/// Traced body assets: male/female x front/back. 4, per `00` §1.
int get kBodyAssetCount => kBodyAssets.length;

/// Parent muscle groups. 12, per `00` §1.
int get kMuscleGroupCount => kMuscleTaxonomy.length;

/// Hit-testable segments across all four body assets. 42, per `00` §1.
int get kBodySegmentCount =>
    kBodyAssets.values.fold<int>(0, (n, a) => n + a.segments.length);
