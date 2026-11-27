// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workoutTemplateFilterMeta =
      const VerificationMeta('workoutTemplateFilter');
  @override
  late final GeneratedColumn<String> workoutTemplateFilter =
      GeneratedColumn<String>(
        'workout_template_filter',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bodyGenderMeta = const VerificationMeta(
    'bodyGender',
  );
  @override
  late final GeneratedColumn<String> bodyGender = GeneratedColumn<String>(
    'body_gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinTargetGMeta = const VerificationMeta(
    'proteinTargetG',
  );
  @override
  late final GeneratedColumn<int> proteinTargetG = GeneratedColumn<int>(
    'protein_target_g',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (protein_target_g IS NULL OR protein_target_g BETWEEN 1 AND 400)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutTemplateFilter,
    bodyGender,
    proteinTargetG,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('workout_template_filter')) {
      context.handle(
        _workoutTemplateFilterMeta,
        workoutTemplateFilter.isAcceptableOrUnknown(
          data['workout_template_filter']!,
          _workoutTemplateFilterMeta,
        ),
      );
    }
    if (data.containsKey('body_gender')) {
      context.handle(
        _bodyGenderMeta,
        bodyGender.isAcceptableOrUnknown(data['body_gender']!, _bodyGenderMeta),
      );
    }
    if (data.containsKey('protein_target_g')) {
      context.handle(
        _proteinTargetGMeta,
        proteinTargetG.isAcceptableOrUnknown(
          data['protein_target_g']!,
          _proteinTargetGMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      workoutTemplateFilter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_template_filter'],
      ),
      bodyGender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_gender'],
      ),
      proteinTargetG: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protein_target_g'],
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final int id;

  /// The stable key of the split filter the Workout landing last showed —
  /// `single`, `multi` or `ppl`.
  ///
  /// **Nullable on purpose: null means "never chosen".** That is what the
  /// first-launch default keys off, so it must stay distinguishable from a
  /// stored value. Giving this column a default would erase the distinction
  /// and every install would look like a returning user.
  ///
  /// Stores the key, never the display label — a copy change must not strand
  /// what is already on disk.
  final String? workoutTemplateFilter;

  /// Which body-diagram artwork every diagram in the app renders in — the name
  /// of a `BodyGender` value, or null when the user has never answered.
  ///
  /// **Nullable for the same reason [workoutTemplateFilter] is.** `docs/04`
  /// gives an unset field the male artwork, and `BodyGender.preferNotToSay`
  /// resolves to that same artwork — but "I declined" and "I have not reached
  /// this screen" are different answers, and only a null tells them apart.
  /// A default here would make every fresh install look like a user who chose.
  ///
  /// Stores the enum's name, not its index: reordering the enum must not
  /// repaint a user's diagrams.
  final String? bodyGender;

  /// The user's daily protein target in grams, 1 to 400, or null when they
  /// have never set one (`docs/adr/0007-diet-in-profile.md`).
  ///
  /// **One value, not a dated series** like [BodyweightEntries]: no screen
  /// shows a past week's target, so a series would buy nothing visible.
  /// Nullable for the reason [bodyGender] is.
  ///
  /// **The CHECK is on the column, not in a table-level constraint.** This
  /// column reaches an existing install through `ALTER TABLE ADD COLUMN`,
  /// which carries a column's own constraints and never a table's, so a
  /// table-level CHECK would guard fresh installs only. A custom constraint
  /// rather than drift's `check()`, because `check()` naming its own column is
  /// the recursive getter [SetEntries] explains.
  final int? proteinTargetG;
  const SettingsRow({
    required this.id,
    this.workoutTemplateFilter,
    this.bodyGender,
    this.proteinTargetG,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || workoutTemplateFilter != null) {
      map['workout_template_filter'] = Variable<String>(workoutTemplateFilter);
    }
    if (!nullToAbsent || bodyGender != null) {
      map['body_gender'] = Variable<String>(bodyGender);
    }
    if (!nullToAbsent || proteinTargetG != null) {
      map['protein_target_g'] = Variable<int>(proteinTargetG);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      workoutTemplateFilter: workoutTemplateFilter == null && nullToAbsent
          ? const Value.absent()
          : Value(workoutTemplateFilter),
      bodyGender: bodyGender == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyGender),
      proteinTargetG: proteinTargetG == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinTargetG),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      workoutTemplateFilter: serializer.fromJson<String?>(
        json['workoutTemplateFilter'],
      ),
      bodyGender: serializer.fromJson<String?>(json['bodyGender']),
      proteinTargetG: serializer.fromJson<int?>(json['proteinTargetG']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workoutTemplateFilter': serializer.toJson<String?>(
        workoutTemplateFilter,
      ),
      'bodyGender': serializer.toJson<String?>(bodyGender),
      'proteinTargetG': serializer.toJson<int?>(proteinTargetG),
    };
  }

  SettingsRow copyWith({
    int? id,
    Value<String?> workoutTemplateFilter = const Value.absent(),
    Value<String?> bodyGender = const Value.absent(),
    Value<int?> proteinTargetG = const Value.absent(),
  }) => SettingsRow(
    id: id ?? this.id,
    workoutTemplateFilter: workoutTemplateFilter.present
        ? workoutTemplateFilter.value
        : this.workoutTemplateFilter,
    bodyGender: bodyGender.present ? bodyGender.value : this.bodyGender,
    proteinTargetG: proteinTargetG.present
        ? proteinTargetG.value
        : this.proteinTargetG,
  );
  SettingsRow copyWithCompanion(SettingsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      workoutTemplateFilter: data.workoutTemplateFilter.present
          ? data.workoutTemplateFilter.value
          : this.workoutTemplateFilter,
      bodyGender: data.bodyGender.present
          ? data.bodyGender.value
          : this.bodyGender,
      proteinTargetG: data.proteinTargetG.present
          ? data.proteinTargetG.value
          : this.proteinTargetG,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('workoutTemplateFilter: $workoutTemplateFilter, ')
          ..write('bodyGender: $bodyGender, ')
          ..write('proteinTargetG: $proteinTargetG')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, workoutTemplateFilter, bodyGender, proteinTargetG);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.workoutTemplateFilter == this.workoutTemplateFilter &&
          other.bodyGender == this.bodyGender &&
          other.proteinTargetG == this.proteinTargetG);
}

class SettingsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<String?> workoutTemplateFilter;
  final Value<String?> bodyGender;
  final Value<int?> proteinTargetG;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.workoutTemplateFilter = const Value.absent(),
    this.bodyGender = const Value.absent(),
    this.proteinTargetG = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.workoutTemplateFilter = const Value.absent(),
    this.bodyGender = const Value.absent(),
    this.proteinTargetG = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? workoutTemplateFilter,
    Expression<String>? bodyGender,
    Expression<int>? proteinTargetG,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutTemplateFilter != null)
        'workout_template_filter': workoutTemplateFilter,
      if (bodyGender != null) 'body_gender': bodyGender,
      if (proteinTargetG != null) 'protein_target_g': proteinTargetG,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? workoutTemplateFilter,
    Value<String?>? bodyGender,
    Value<int?>? proteinTargetG,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      workoutTemplateFilter:
          workoutTemplateFilter ?? this.workoutTemplateFilter,
      bodyGender: bodyGender ?? this.bodyGender,
      proteinTargetG: proteinTargetG ?? this.proteinTargetG,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workoutTemplateFilter.present) {
      map['workout_template_filter'] = Variable<String>(
        workoutTemplateFilter.value,
      );
    }
    if (bodyGender.present) {
      map['body_gender'] = Variable<String>(bodyGender.value);
    }
    if (proteinTargetG.present) {
      map['protein_target_g'] = Variable<int>(proteinTargetG.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('workoutTemplateFilter: $workoutTemplateFilter, ')
          ..write('bodyGender: $bodyGender, ')
          ..write('proteinTargetG: $proteinTargetG')
          ..write(')'))
        .toString();
  }
}

class $BodyweightEntriesTable extends BodyweightEntries
    with TableInfo<$BodyweightEntriesTable, BodyweightEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyweightEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, weightKg];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bodyweight_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyweightEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  BodyweightEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyweightEntryRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
    );
  }

  @override
  $BodyweightEntriesTable createAlias(String alias) {
    return $BodyweightEntriesTable(attachedDatabase, alias);
  }
}

class BodyweightEntryRow extends DataClass
    implements Insertable<BodyweightEntryRow> {
  /// The local calendar date the weight took effect, as `YYYY-MM-DD`.
  ///
  /// **Text, not drift's `dateTime()`.** `CLAUDE.md` is explicit that a
  /// calendar date is not a timestamp: a weight recorded at 11pm must not land
  /// on the next day because the value round-tripped through UTC. Text in
  /// ISO order also sorts and compares correctly as a string, which is the
  /// whole of what resolution needs.
  final String date;

  /// Kilograms. `docs/04` picks one unit for V1 and does not offer a toggle.
  final double weightKg;
  const BodyweightEntryRow({required this.date, required this.weightKg});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['weight_kg'] = Variable<double>(weightKg);
    return map;
  }

  BodyweightEntriesCompanion toCompanion(bool nullToAbsent) {
    return BodyweightEntriesCompanion(
      date: Value(date),
      weightKg: Value(weightKg),
    );
  }

  factory BodyweightEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyweightEntryRow(
      date: serializer.fromJson<String>(json['date']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'weightKg': serializer.toJson<double>(weightKg),
    };
  }

  BodyweightEntryRow copyWith({String? date, double? weightKg}) =>
      BodyweightEntryRow(
        date: date ?? this.date,
        weightKg: weightKg ?? this.weightKg,
      );
  BodyweightEntryRow copyWithCompanion(BodyweightEntriesCompanion data) {
    return BodyweightEntryRow(
      date: data.date.present ? data.date.value : this.date,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyweightEntryRow(')
          ..write('date: $date, ')
          ..write('weightKg: $weightKg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, weightKg);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyweightEntryRow &&
          other.date == this.date &&
          other.weightKg == this.weightKg);
}

class BodyweightEntriesCompanion extends UpdateCompanion<BodyweightEntryRow> {
  final Value<String> date;
  final Value<double> weightKg;
  final Value<int> rowid;
  const BodyweightEntriesCompanion({
    this.date = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BodyweightEntriesCompanion.insert({
    required String date,
    required double weightKg,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       weightKg = Value(weightKg);
  static Insertable<BodyweightEntryRow> custom({
    Expression<String>? date,
    Expression<double>? weightKg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (weightKg != null) 'weight_kg': weightKg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BodyweightEntriesCompanion copyWith({
    Value<String>? date,
    Value<double>? weightKg,
    Value<int>? rowid,
  }) {
    return BodyweightEntriesCompanion(
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyweightEntriesCompanion(')
          ..write('date: $date, ')
          ..write('weightKg: $weightKg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomTemplatesTable extends CustomTemplates
    with TableInfo<$CustomTemplatesTable, CustomTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdsMeta = const VerificationMeta(
    'groupIds',
  );
  @override
  late final GeneratedColumn<String> groupIds = GeneratedColumn<String>(
    'group_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _exerciseIdsMeta = const VerificationMeta(
    'exerciseIds',
  );
  @override
  late final GeneratedColumn<String> exerciseIds = GeneratedColumn<String>(
    'exercise_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceTemplateIdMeta = const VerificationMeta(
    'sourceTemplateId',
  );
  @override
  late final GeneratedColumn<String> sourceTemplateId = GeneratedColumn<String>(
    'source_template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    groupIds,
    exerciseIds,
    sourceTemplateId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group_ids')) {
      context.handle(
        _groupIdsMeta,
        groupIds.isAcceptableOrUnknown(data['group_ids']!, _groupIdsMeta),
      );
    }
    if (data.containsKey('exercise_ids')) {
      context.handle(
        _exerciseIdsMeta,
        exerciseIds.isAcceptableOrUnknown(
          data['exercise_ids']!,
          _exerciseIdsMeta,
        ),
      );
    }
    if (data.containsKey('source_template_id')) {
      context.handle(
        _sourceTemplateIdMeta,
        sourceTemplateId.isAcceptableOrUnknown(
          data['source_template_id']!,
          _sourceTemplateIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      groupIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_ids'],
      )!,
      exerciseIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_ids'],
      )!,
      sourceTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_template_id'],
      ),
    );
  }

  @override
  $CustomTemplatesTable createAlias(String alias) {
    return $CustomTemplatesTable(attachedDatabase, alias);
  }
}

class CustomTemplateRow extends DataClass
    implements Insertable<CustomTemplateRow> {
  /// Stable across renames, exactly like a predefined template's id — this is
  /// what a session will reference once sessions exist.
  final String id;
  final String name;

  /// **Legacy: no longer written or read.** Templates were a list of parent
  /// muscle group ids before `docs/adr/0006-workout-tab-is-exercise-first.md`.
  /// The column stays because SQLite cannot drop a `NOT NULL` column without
  /// rebuilding the table, and a rebuild is a worse trade than one empty string
  /// per row. New rows write `''`.
  final String groupIds;

  /// Library exercise ids, comma-joined in session order.
  ///
  /// **A joined string rather than a child table**, because the app never
  /// queries templates *by* exercise: it loads the whole template and renders
  /// it. A second table would buy a join for a list that is read whole and is a
  /// dozen short ids long at most. Exercise ids are lower-case words and hyphens,
  /// so the separator cannot collide with one.
  ///
  /// **Order is the point**, unlike the group ids this replaces: it is the order
  /// the session lists the exercises in.
  final String exerciseIds;

  /// The predefined template this was duplicated from, so the row can say
  /// "Duplicated from Push day" without guessing. Null once that template no
  /// longer ships.
  final String? sourceTemplateId;
  const CustomTemplateRow({
    required this.id,
    required this.name,
    required this.groupIds,
    required this.exerciseIds,
    this.sourceTemplateId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['group_ids'] = Variable<String>(groupIds);
    map['exercise_ids'] = Variable<String>(exerciseIds);
    if (!nullToAbsent || sourceTemplateId != null) {
      map['source_template_id'] = Variable<String>(sourceTemplateId);
    }
    return map;
  }

  CustomTemplatesCompanion toCompanion(bool nullToAbsent) {
    return CustomTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      groupIds: Value(groupIds),
      exerciseIds: Value(exerciseIds),
      sourceTemplateId: sourceTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTemplateId),
    );
  }

  factory CustomTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomTemplateRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      groupIds: serializer.fromJson<String>(json['groupIds']),
      exerciseIds: serializer.fromJson<String>(json['exerciseIds']),
      sourceTemplateId: serializer.fromJson<String?>(json['sourceTemplateId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'groupIds': serializer.toJson<String>(groupIds),
      'exerciseIds': serializer.toJson<String>(exerciseIds),
      'sourceTemplateId': serializer.toJson<String?>(sourceTemplateId),
    };
  }

  CustomTemplateRow copyWith({
    String? id,
    String? name,
    String? groupIds,
    String? exerciseIds,
    Value<String?> sourceTemplateId = const Value.absent(),
  }) => CustomTemplateRow(
    id: id ?? this.id,
    name: name ?? this.name,
    groupIds: groupIds ?? this.groupIds,
    exerciseIds: exerciseIds ?? this.exerciseIds,
    sourceTemplateId: sourceTemplateId.present
        ? sourceTemplateId.value
        : this.sourceTemplateId,
  );
  CustomTemplateRow copyWithCompanion(CustomTemplatesCompanion data) {
    return CustomTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      groupIds: data.groupIds.present ? data.groupIds.value : this.groupIds,
      exerciseIds: data.exerciseIds.present
          ? data.exerciseIds.value
          : this.exerciseIds,
      sourceTemplateId: data.sourceTemplateId.present
          ? data.sourceTemplateId.value
          : this.sourceTemplateId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomTemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupIds: $groupIds, ')
          ..write('exerciseIds: $exerciseIds, ')
          ..write('sourceTemplateId: $sourceTemplateId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, groupIds, exerciseIds, sourceTemplateId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomTemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.groupIds == this.groupIds &&
          other.exerciseIds == this.exerciseIds &&
          other.sourceTemplateId == this.sourceTemplateId);
}

class CustomTemplatesCompanion extends UpdateCompanion<CustomTemplateRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> groupIds;
  final Value<String> exerciseIds;
  final Value<String?> sourceTemplateId;
  final Value<int> rowid;
  const CustomTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.groupIds = const Value.absent(),
    this.exerciseIds = const Value.absent(),
    this.sourceTemplateId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomTemplatesCompanion.insert({
    required String id,
    required String name,
    this.groupIds = const Value.absent(),
    this.exerciseIds = const Value.absent(),
    this.sourceTemplateId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CustomTemplateRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? groupIds,
    Expression<String>? exerciseIds,
    Expression<String>? sourceTemplateId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (groupIds != null) 'group_ids': groupIds,
      if (exerciseIds != null) 'exercise_ids': exerciseIds,
      if (sourceTemplateId != null) 'source_template_id': sourceTemplateId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? groupIds,
    Value<String>? exerciseIds,
    Value<String?>? sourceTemplateId,
    Value<int>? rowid,
  }) {
    return CustomTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      groupIds: groupIds ?? this.groupIds,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (groupIds.present) {
      map['group_ids'] = Variable<String>(groupIds.value);
    }
    if (exerciseIds.present) {
      map['exercise_ids'] = Variable<String>(exerciseIds.value);
    }
    if (sourceTemplateId.present) {
      map['source_template_id'] = Variable<String>(sourceTemplateId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupIds: $groupIds, ')
          ..write('exerciseIds: $exerciseIds, ')
          ..write('sourceTemplateId: $sourceTemplateId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> performedOn =
      GeneratedColumn<String>(
        'performed_on',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($SessionsTable.$converterperformedOn);
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateNameMeta = const VerificationMeta(
    'templateName',
  );
  @override
  late final GeneratedColumn<String> templateName = GeneratedColumn<String>(
    'template_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupIdsMeta = const VerificationMeta(
    'groupIds',
  );
  @override
  late final GeneratedColumn<String> groupIds = GeneratedColumn<String>(
    'group_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openMarkerMeta = const VerificationMeta(
    'openMarker',
  );
  @override
  late final GeneratedColumn<int> openMarker = GeneratedColumn<int>(
    'open_marker',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    performedOn,
    loggedAt,
    templateId,
    templateName,
    groupIds,
    openMarker,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('template_name')) {
      context.handle(
        _templateNameMeta,
        templateName.isAcceptableOrUnknown(
          data['template_name']!,
          _templateNameMeta,
        ),
      );
    }
    if (data.containsKey('group_ids')) {
      context.handle(
        _groupIdsMeta,
        groupIds.isAcceptableOrUnknown(data['group_ids']!, _groupIdsMeta),
      );
    }
    if (data.containsKey('open_marker')) {
      context.handle(
        _openMarkerMeta,
        openMarker.isAcceptableOrUnknown(data['open_marker']!, _openMarkerMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      performedOn: $SessionsTable.$converterperformedOn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}performed_on'],
        )!,
      ),
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
      templateName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_name'],
      ),
      groupIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_ids'],
      ),
      openMarker: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}open_marker'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converterperformedOn =
      const LocalDateConverter();
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;

  /// Optional, at most 40 characters — it is the hero text on a share card.
  /// May be empty in storage and is never displayed empty; the fallback chain
  /// in `docs/00` §6 resolves it on read.
  final String? title;

  /// The local calendar day the workout happened, as `YYYY-MM-DD`.
  final LocalDate performedOn;

  /// Internal only. Never rendered, and never re-stamped by an edit — two
  /// sessions on the same day would otherwise reorder under the user.
  final DateTime loggedAt;

  /// Null for an ad-hoc session. **No foreign key**: eleven of the twelve
  /// template ids are `const` Dart in `workout_templates.dart` rather than
  /// rows, so a reference here cannot be one.
  final String? templateId;

  /// The template's name as it was when the session started.
  ///
  /// Snapshotted because the title fallback chain's second step is the template
  /// name, and a custom template the user later deletes no longer has one. Not
  /// an aggregate over the user's data, so it cannot go stale the way a stored
  /// count would — it records what was true when the session began.
  final String? templateName;

  /// **Legacy: no longer written or read.** It snapshotted the muscle groups a
  /// template session was locked to, and the lock is gone
  /// (`docs/adr/0006-workout-tab-is-exercise-first.md`). The column stays for the
  /// reason `CustomTemplates.groupIds` does: dropping it means rebuilding a table
  /// that carries the open-session unique index.
  final String? groupIds;

  /// Set on the one open session, null on every saved one.
  ///
  /// **A nullable column with a unique index, so "one at a time" is the
  /// database's rule rather than a promise the app has to keep forever.** SQLite
  /// treats nulls as distinct in a unique index, so any number of saved sessions
  /// coexist while a second open row is rejected outright. Without it, a partial
  /// write during auto-save leaves two open sessions, the loader picks one, and
  /// the other becomes permanently invisible and permanently unfinishable with
  /// its sets still on disk — and a local-only app has no repair path.
  final int? openMarker;
  const SessionRow({
    required this.id,
    this.title,
    required this.performedOn,
    required this.loggedAt,
    this.templateId,
    this.templateName,
    this.groupIds,
    this.openMarker,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    {
      map['performed_on'] = Variable<String>(
        $SessionsTable.$converterperformedOn.toSql(performedOn),
      );
    }
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    if (!nullToAbsent || templateName != null) {
      map['template_name'] = Variable<String>(templateName);
    }
    if (!nullToAbsent || groupIds != null) {
      map['group_ids'] = Variable<String>(groupIds);
    }
    if (!nullToAbsent || openMarker != null) {
      map['open_marker'] = Variable<int>(openMarker);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      performedOn: Value(performedOn),
      loggedAt: Value(loggedAt),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      templateName: templateName == null && nullToAbsent
          ? const Value.absent()
          : Value(templateName),
      groupIds: groupIds == null && nullToAbsent
          ? const Value.absent()
          : Value(groupIds),
      openMarker: openMarker == null && nullToAbsent
          ? const Value.absent()
          : Value(openMarker),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      performedOn: serializer.fromJson<LocalDate>(json['performedOn']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      templateId: serializer.fromJson<String?>(json['templateId']),
      templateName: serializer.fromJson<String?>(json['templateName']),
      groupIds: serializer.fromJson<String?>(json['groupIds']),
      openMarker: serializer.fromJson<int?>(json['openMarker']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String?>(title),
      'performedOn': serializer.toJson<LocalDate>(performedOn),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'templateId': serializer.toJson<String?>(templateId),
      'templateName': serializer.toJson<String?>(templateName),
      'groupIds': serializer.toJson<String?>(groupIds),
      'openMarker': serializer.toJson<int?>(openMarker),
    };
  }

  SessionRow copyWith({
    String? id,
    Value<String?> title = const Value.absent(),
    LocalDate? performedOn,
    DateTime? loggedAt,
    Value<String?> templateId = const Value.absent(),
    Value<String?> templateName = const Value.absent(),
    Value<String?> groupIds = const Value.absent(),
    Value<int?> openMarker = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    title: title.present ? title.value : this.title,
    performedOn: performedOn ?? this.performedOn,
    loggedAt: loggedAt ?? this.loggedAt,
    templateId: templateId.present ? templateId.value : this.templateId,
    templateName: templateName.present ? templateName.value : this.templateName,
    groupIds: groupIds.present ? groupIds.value : this.groupIds,
    openMarker: openMarker.present ? openMarker.value : this.openMarker,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      performedOn: data.performedOn.present
          ? data.performedOn.value
          : this.performedOn,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      templateName: data.templateName.present
          ? data.templateName.value
          : this.templateName,
      groupIds: data.groupIds.present ? data.groupIds.value : this.groupIds,
      openMarker: data.openMarker.present
          ? data.openMarker.value
          : this.openMarker,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('performedOn: $performedOn, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('templateId: $templateId, ')
          ..write('templateName: $templateName, ')
          ..write('groupIds: $groupIds, ')
          ..write('openMarker: $openMarker')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    performedOn,
    loggedAt,
    templateId,
    templateName,
    groupIds,
    openMarker,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.performedOn == this.performedOn &&
          other.loggedAt == this.loggedAt &&
          other.templateId == this.templateId &&
          other.templateName == this.templateName &&
          other.groupIds == this.groupIds &&
          other.openMarker == this.openMarker);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String?> title;
  final Value<LocalDate> performedOn;
  final Value<DateTime> loggedAt;
  final Value<String?> templateId;
  final Value<String?> templateName;
  final Value<String?> groupIds;
  final Value<int?> openMarker;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.performedOn = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.templateId = const Value.absent(),
    this.templateName = const Value.absent(),
    this.groupIds = const Value.absent(),
    this.openMarker = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    required LocalDate performedOn,
    required DateTime loggedAt,
    this.templateId = const Value.absent(),
    this.templateName = const Value.absent(),
    this.groupIds = const Value.absent(),
    this.openMarker = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       performedOn = Value(performedOn),
       loggedAt = Value(loggedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? performedOn,
    Expression<DateTime>? loggedAt,
    Expression<String>? templateId,
    Expression<String>? templateName,
    Expression<String>? groupIds,
    Expression<int>? openMarker,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (performedOn != null) 'performed_on': performedOn,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (templateId != null) 'template_id': templateId,
      if (templateName != null) 'template_name': templateName,
      if (groupIds != null) 'group_ids': groupIds,
      if (openMarker != null) 'open_marker': openMarker,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? title,
    Value<LocalDate>? performedOn,
    Value<DateTime>? loggedAt,
    Value<String?>? templateId,
    Value<String?>? templateName,
    Value<String?>? groupIds,
    Value<int?>? openMarker,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      performedOn: performedOn ?? this.performedOn,
      loggedAt: loggedAt ?? this.loggedAt,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      groupIds: groupIds ?? this.groupIds,
      openMarker: openMarker ?? this.openMarker,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (performedOn.present) {
      map['performed_on'] = Variable<String>(
        $SessionsTable.$converterperformedOn.toSql(performedOn.value),
      );
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (templateName.present) {
      map['template_name'] = Variable<String>(templateName.value);
    }
    if (groupIds.present) {
      map['group_ids'] = Variable<String>(groupIds.value);
    }
    if (openMarker.present) {
      map['open_marker'] = Variable<int>(openMarker.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('performedOn: $performedOn, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('templateId: $templateId, ')
          ..write('templateName: $templateName, ')
          ..write('groupIds: $groupIds, ')
          ..write('openMarker: $openMarker, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionExercisesTable extends SessionExercises
    with TableInfo<$SessionExercisesTable, SessionExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loadTypeMeta = const VerificationMeta(
    'loadType',
  );
  @override
  late final GeneratedColumn<String> loadType = GeneratedColumn<String>(
    'load_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markedDoneMeta = const VerificationMeta(
    'markedDone',
  );
  @override
  late final GeneratedColumn<bool> markedDone = GeneratedColumn<bool>(
    'marked_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("marked_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    exerciseId,
    position,
    loadType,
    markedDone,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('load_type')) {
      context.handle(
        _loadTypeMeta,
        loadType.isAcceptableOrUnknown(data['load_type']!, _loadTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_loadTypeMeta);
    }
    if (data.containsKey('marked_done')) {
      context.handle(
        _markedDoneMeta,
        markedDone.isAcceptableOrUnknown(data['marked_done']!, _markedDoneMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      loadType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}load_type'],
      )!,
      markedDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marked_done'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $SessionExercisesTable createAlias(String alias) {
    return $SessionExercisesTable(attachedDatabase, alias);
  }
}

class SessionExerciseRow extends DataClass
    implements Insertable<SessionExerciseRow> {
  final String id;
  final String sessionId;

  /// The library exercise this row logs.
  final String exerciseId;
  final int position;

  /// The exercise's load type, by name, as it was when this row was added.
  ///
  /// **Snapshotted, and this is the column that stops a record shipping
  /// backwards.** Load types live in `assets/exercises/exercises.json`, which
  /// ships in the binary and is regenerated by a generator. A set row is
  /// otherwise a bag of nullable numbers whose meaning is resolved at read time
  /// against content a later build can change: reclassify one of the three
  /// assisted exercises and every historical set of it is reinterpreted, so a
  /// record that is a *minimum* is read as a maximum. Nothing fails; the number
  /// is just wrong.
  ///
  /// Stored by name, not index, so appending a variant cannot remap old rows.
  final String loadType;

  /// Whether the user tapped "Mark exercise done".
  ///
  /// **The only per-exercise state stored.** The `not started / in progress /
  /// done` value the UI shows is derived: deleting every set from an
  /// in-progress exercise would otherwise leave a stored state that is simply
  /// wrong, which is exactly what `docs/01` §Derived values exists to prevent.
  final bool markedDone;

  /// The user's one free-text note for this exercise in this session ("seat
  /// 4"), schema step 9. `null` when there is none; never an empty string —
  /// the store trims and writes `null` for a blank note.
  ///
  /// Entered data, not derived: the "last time" hint in set logging is read
  /// from the most recent earlier row that has one.
  final String? note;
  const SessionExerciseRow({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.position,
    required this.loadType,
    required this.markedDone,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['position'] = Variable<int>(position);
    map['load_type'] = Variable<String>(loadType);
    map['marked_done'] = Variable<bool>(markedDone);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SessionExercisesCompanion toCompanion(bool nullToAbsent) {
    return SessionExercisesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exerciseId: Value(exerciseId),
      position: Value(position),
      loadType: Value(loadType),
      markedDone: Value(markedDone),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SessionExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      position: serializer.fromJson<int>(json['position']),
      loadType: serializer.fromJson<String>(json['loadType']),
      markedDone: serializer.fromJson<bool>(json['markedDone']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'position': serializer.toJson<int>(position),
      'loadType': serializer.toJson<String>(loadType),
      'markedDone': serializer.toJson<bool>(markedDone),
      'note': serializer.toJson<String?>(note),
    };
  }

  SessionExerciseRow copyWith({
    String? id,
    String? sessionId,
    String? exerciseId,
    int? position,
    String? loadType,
    bool? markedDone,
    Value<String?> note = const Value.absent(),
  }) => SessionExerciseRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    exerciseId: exerciseId ?? this.exerciseId,
    position: position ?? this.position,
    loadType: loadType ?? this.loadType,
    markedDone: markedDone ?? this.markedDone,
    note: note.present ? note.value : this.note,
  );
  SessionExerciseRow copyWithCompanion(SessionExercisesCompanion data) {
    return SessionExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      position: data.position.present ? data.position.value : this.position,
      loadType: data.loadType.present ? data.loadType.value : this.loadType,
      markedDone: data.markedDone.present
          ? data.markedDone.value
          : this.markedDone,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionExerciseRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('loadType: $loadType, ')
          ..write('markedDone: $markedDone, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseId,
    position,
    loadType,
    markedDone,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionExerciseRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseId == this.exerciseId &&
          other.position == this.position &&
          other.loadType == this.loadType &&
          other.markedDone == this.markedDone &&
          other.note == this.note);
}

class SessionExercisesCompanion extends UpdateCompanion<SessionExerciseRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> exerciseId;
  final Value<int> position;
  final Value<String> loadType;
  final Value<bool> markedDone;
  final Value<String?> note;
  final Value<int> rowid;
  const SessionExercisesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.position = const Value.absent(),
    this.loadType = const Value.absent(),
    this.markedDone = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionExercisesCompanion.insert({
    required String id,
    required String sessionId,
    required String exerciseId,
    required int position,
    required String loadType,
    this.markedDone = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       exerciseId = Value(exerciseId),
       position = Value(position),
       loadType = Value(loadType);
  static Insertable<SessionExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? exerciseId,
    Expression<int>? position,
    Expression<String>? loadType,
    Expression<bool>? markedDone,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (position != null) 'position': position,
      if (loadType != null) 'load_type': loadType,
      if (markedDone != null) 'marked_done': markedDone,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? exerciseId,
    Value<int>? position,
    Value<String>? loadType,
    Value<bool>? markedDone,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return SessionExercisesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      loadType: loadType ?? this.loadType,
      markedDone: markedDone ?? this.markedDone,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (loadType.present) {
      map['load_type'] = Variable<String>(loadType.value);
    }
    if (markedDone.present) {
      map['marked_done'] = Variable<bool>(markedDone.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionExercisesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('loadType: $loadType, ')
          ..write('markedDone: $markedDone, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetEntriesTable extends SetEntries
    with TableInfo<$SetEntriesTable, SetEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionExerciseIdMeta = const VerificationMeta(
    'sessionExerciseId',
  );
  @override
  late final GeneratedColumn<String> sessionExerciseId =
      GeneratedColumn<String>(
        'session_exercise_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES session_exercises (id) ON DELETE CASCADE',
        ),
      );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedKgMeta = const VerificationMeta(
    'addedKg',
  );
  @override
  late final GeneratedColumn<double> addedKg = GeneratedColumn<double>(
    'added_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assistKgMeta = const VerificationMeta(
    'assistKg',
  );
  @override
  late final GeneratedColumn<double> assistKg = GeneratedColumn<double>(
    'assist_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionExerciseId,
    position,
    completed,
    weightKg,
    reps,
    addedKg,
    assistKg,
    durationSec,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_exercise_id')) {
      context.handle(
        _sessionExerciseIdMeta,
        sessionExerciseId.isAcceptableOrUnknown(
          data['session_exercise_id']!,
          _sessionExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionExerciseIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('added_kg')) {
      context.handle(
        _addedKgMeta,
        addedKg.isAcceptableOrUnknown(data['added_kg']!, _addedKgMeta),
      );
    }
    if (data.containsKey('assist_kg')) {
      context.handle(
        _assistKgMeta,
        assistKg.isAcceptableOrUnknown(data['assist_kg']!, _assistKgMeta),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionExerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_exercise_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      addedKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}added_kg'],
      ),
      assistKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}assist_kg'],
      ),
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
    );
  }

  @override
  $SetEntriesTable createAlias(String alias) {
    return $SetEntriesTable(attachedDatabase, alias);
  }
}

class SetEntryRow extends DataClass implements Insertable<SetEntryRow> {
  final String id;
  final String sessionExerciseId;
  final int position;
  final bool completed;
  final double? weightKg;
  final int? reps;
  final double? addedKg;
  final double? assistKg;
  final int? durationSec;
  const SetEntryRow({
    required this.id,
    required this.sessionExerciseId,
    required this.position,
    required this.completed,
    this.weightKg,
    this.reps,
    this.addedKg,
    this.assistKg,
    this.durationSec,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_exercise_id'] = Variable<String>(sessionExerciseId);
    map['position'] = Variable<int>(position);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || addedKg != null) {
      map['added_kg'] = Variable<double>(addedKg);
    }
    if (!nullToAbsent || assistKg != null) {
      map['assist_kg'] = Variable<double>(assistKg);
    }
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    return map;
  }

  SetEntriesCompanion toCompanion(bool nullToAbsent) {
    return SetEntriesCompanion(
      id: Value(id),
      sessionExerciseId: Value(sessionExerciseId),
      position: Value(position),
      completed: Value(completed),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      addedKg: addedKg == null && nullToAbsent
          ? const Value.absent()
          : Value(addedKg),
      assistKg: assistKg == null && nullToAbsent
          ? const Value.absent()
          : Value(assistKg),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
    );
  }

  factory SetEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetEntryRow(
      id: serializer.fromJson<String>(json['id']),
      sessionExerciseId: serializer.fromJson<String>(json['sessionExerciseId']),
      position: serializer.fromJson<int>(json['position']),
      completed: serializer.fromJson<bool>(json['completed']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      reps: serializer.fromJson<int?>(json['reps']),
      addedKg: serializer.fromJson<double?>(json['addedKg']),
      assistKg: serializer.fromJson<double?>(json['assistKg']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionExerciseId': serializer.toJson<String>(sessionExerciseId),
      'position': serializer.toJson<int>(position),
      'completed': serializer.toJson<bool>(completed),
      'weightKg': serializer.toJson<double?>(weightKg),
      'reps': serializer.toJson<int?>(reps),
      'addedKg': serializer.toJson<double?>(addedKg),
      'assistKg': serializer.toJson<double?>(assistKg),
      'durationSec': serializer.toJson<int?>(durationSec),
    };
  }

  SetEntryRow copyWith({
    String? id,
    String? sessionExerciseId,
    int? position,
    bool? completed,
    Value<double?> weightKg = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<double?> addedKg = const Value.absent(),
    Value<double?> assistKg = const Value.absent(),
    Value<int?> durationSec = const Value.absent(),
  }) => SetEntryRow(
    id: id ?? this.id,
    sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
    position: position ?? this.position,
    completed: completed ?? this.completed,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    reps: reps.present ? reps.value : this.reps,
    addedKg: addedKg.present ? addedKg.value : this.addedKg,
    assistKg: assistKg.present ? assistKg.value : this.assistKg,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
  );
  SetEntryRow copyWithCompanion(SetEntriesCompanion data) {
    return SetEntryRow(
      id: data.id.present ? data.id.value : this.id,
      sessionExerciseId: data.sessionExerciseId.present
          ? data.sessionExerciseId.value
          : this.sessionExerciseId,
      position: data.position.present ? data.position.value : this.position,
      completed: data.completed.present ? data.completed.value : this.completed,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      reps: data.reps.present ? data.reps.value : this.reps,
      addedKg: data.addedKg.present ? data.addedKg.value : this.addedKg,
      assistKg: data.assistKg.present ? data.assistKg.value : this.assistKg,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetEntryRow(')
          ..write('id: $id, ')
          ..write('sessionExerciseId: $sessionExerciseId, ')
          ..write('position: $position, ')
          ..write('completed: $completed, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('addedKg: $addedKg, ')
          ..write('assistKg: $assistKg, ')
          ..write('durationSec: $durationSec')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionExerciseId,
    position,
    completed,
    weightKg,
    reps,
    addedKg,
    assistKg,
    durationSec,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetEntryRow &&
          other.id == this.id &&
          other.sessionExerciseId == this.sessionExerciseId &&
          other.position == this.position &&
          other.completed == this.completed &&
          other.weightKg == this.weightKg &&
          other.reps == this.reps &&
          other.addedKg == this.addedKg &&
          other.assistKg == this.assistKg &&
          other.durationSec == this.durationSec);
}

class SetEntriesCompanion extends UpdateCompanion<SetEntryRow> {
  final Value<String> id;
  final Value<String> sessionExerciseId;
  final Value<int> position;
  final Value<bool> completed;
  final Value<double?> weightKg;
  final Value<int?> reps;
  final Value<double?> addedKg;
  final Value<double?> assistKg;
  final Value<int?> durationSec;
  final Value<int> rowid;
  const SetEntriesCompanion({
    this.id = const Value.absent(),
    this.sessionExerciseId = const Value.absent(),
    this.position = const Value.absent(),
    this.completed = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.addedKg = const Value.absent(),
    this.assistKg = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetEntriesCompanion.insert({
    required String id,
    required String sessionExerciseId,
    required int position,
    this.completed = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.addedKg = const Value.absent(),
    this.assistKg = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionExerciseId = Value(sessionExerciseId),
       position = Value(position);
  static Insertable<SetEntryRow> custom({
    Expression<String>? id,
    Expression<String>? sessionExerciseId,
    Expression<int>? position,
    Expression<bool>? completed,
    Expression<double>? weightKg,
    Expression<int>? reps,
    Expression<double>? addedKg,
    Expression<double>? assistKg,
    Expression<int>? durationSec,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionExerciseId != null) 'session_exercise_id': sessionExerciseId,
      if (position != null) 'position': position,
      if (completed != null) 'completed': completed,
      if (weightKg != null) 'weight_kg': weightKg,
      if (reps != null) 'reps': reps,
      if (addedKg != null) 'added_kg': addedKg,
      if (assistKg != null) 'assist_kg': assistKg,
      if (durationSec != null) 'duration_sec': durationSec,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionExerciseId,
    Value<int>? position,
    Value<bool>? completed,
    Value<double?>? weightKg,
    Value<int?>? reps,
    Value<double?>? addedKg,
    Value<double?>? assistKg,
    Value<int?>? durationSec,
    Value<int>? rowid,
  }) {
    return SetEntriesCompanion(
      id: id ?? this.id,
      sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
      position: position ?? this.position,
      completed: completed ?? this.completed,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      addedKg: addedKg ?? this.addedKg,
      assistKg: assistKg ?? this.assistKg,
      durationSec: durationSec ?? this.durationSec,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionExerciseId.present) {
      map['session_exercise_id'] = Variable<String>(sessionExerciseId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (addedKg.present) {
      map['added_kg'] = Variable<double>(addedKg.value);
    }
    if (assistKg.present) {
      map['assist_kg'] = Variable<double>(assistKg.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sessionExerciseId: $sessionExerciseId, ')
          ..write('position: $position, ')
          ..write('completed: $completed, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('addedKg: $addedKg, ')
          ..write('assistKg: $assistKg, ')
          ..write('durationSec: $durationSec, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DietLogEntriesTable extends DietLogEntries
    with TableInfo<$DietLogEntriesTable, DietLogEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DietLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($DietLogEntriesTable.$converterdate);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<String> foodId = GeneratedColumn<String>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _servingsHalvesMeta = const VerificationMeta(
    'servingsHalves',
  );
  @override
  late final GeneratedColumn<int> servingsHalves = GeneratedColumn<int>(
    'servings_halves',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    slot,
    foodId,
    servingsHalves,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diet_log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DietLogEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('servings_halves')) {
      context.handle(
        _servingsHalvesMeta,
        servingsHalves.isAcceptableOrUnknown(
          data['servings_halves']!,
          _servingsHalvesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_servingsHalvesMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DietLogEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DietLogEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: $DietLogEntriesTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_id'],
      )!,
      servingsHalves: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servings_halves'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $DietLogEntriesTable createAlias(String alias) {
    return $DietLogEntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converterdate =
      const LocalDateConverter();
}

class DietLogEntryRow extends DataClass implements Insertable<DietLogEntryRow> {
  final String id;

  /// The local calendar day, as `YYYY-MM-DD`. Text for the reason
  /// [BodyweightEntries.date] is.
  final LocalDate date;

  /// `breakfast`, `lunch`, `snack` or `dinner`. Stored by name, never index.
  final String slot;

  /// The bundled food's id. **No foreign key**: the food list is an asset,
  /// not a table, which is the `Sessions.templateId` precedent.
  final String foodId;

  /// Servings as a count of halves, 1 to 8, so 0.5 to 4 servings with no
  /// floating-point drift.
  final int servingsHalves;

  /// Order within the slot, as the user added the foods.
  final int position;
  const DietLogEntryRow({
    required this.id,
    required this.date,
    required this.slot,
    required this.foodId,
    required this.servingsHalves,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['date'] = Variable<String>(
        $DietLogEntriesTable.$converterdate.toSql(date),
      );
    }
    map['slot'] = Variable<String>(slot);
    map['food_id'] = Variable<String>(foodId);
    map['servings_halves'] = Variable<int>(servingsHalves);
    map['position'] = Variable<int>(position);
    return map;
  }

  DietLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return DietLogEntriesCompanion(
      id: Value(id),
      date: Value(date),
      slot: Value(slot),
      foodId: Value(foodId),
      servingsHalves: Value(servingsHalves),
      position: Value(position),
    );
  }

  factory DietLogEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DietLogEntryRow(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<LocalDate>(json['date']),
      slot: serializer.fromJson<String>(json['slot']),
      foodId: serializer.fromJson<String>(json['foodId']),
      servingsHalves: serializer.fromJson<int>(json['servingsHalves']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<LocalDate>(date),
      'slot': serializer.toJson<String>(slot),
      'foodId': serializer.toJson<String>(foodId),
      'servingsHalves': serializer.toJson<int>(servingsHalves),
      'position': serializer.toJson<int>(position),
    };
  }

  DietLogEntryRow copyWith({
    String? id,
    LocalDate? date,
    String? slot,
    String? foodId,
    int? servingsHalves,
    int? position,
  }) => DietLogEntryRow(
    id: id ?? this.id,
    date: date ?? this.date,
    slot: slot ?? this.slot,
    foodId: foodId ?? this.foodId,
    servingsHalves: servingsHalves ?? this.servingsHalves,
    position: position ?? this.position,
  );
  DietLogEntryRow copyWithCompanion(DietLogEntriesCompanion data) {
    return DietLogEntryRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      slot: data.slot.present ? data.slot.value : this.slot,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      servingsHalves: data.servingsHalves.present
          ? data.servingsHalves.value
          : this.servingsHalves,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DietLogEntryRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('slot: $slot, ')
          ..write('foodId: $foodId, ')
          ..write('servingsHalves: $servingsHalves, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, slot, foodId, servingsHalves, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DietLogEntryRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.slot == this.slot &&
          other.foodId == this.foodId &&
          other.servingsHalves == this.servingsHalves &&
          other.position == this.position);
}

class DietLogEntriesCompanion extends UpdateCompanion<DietLogEntryRow> {
  final Value<String> id;
  final Value<LocalDate> date;
  final Value<String> slot;
  final Value<String> foodId;
  final Value<int> servingsHalves;
  final Value<int> position;
  final Value<int> rowid;
  const DietLogEntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.slot = const Value.absent(),
    this.foodId = const Value.absent(),
    this.servingsHalves = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DietLogEntriesCompanion.insert({
    required String id,
    required LocalDate date,
    required String slot,
    required String foodId,
    required int servingsHalves,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       slot = Value(slot),
       foodId = Value(foodId),
       servingsHalves = Value(servingsHalves),
       position = Value(position);
  static Insertable<DietLogEntryRow> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? slot,
    Expression<String>? foodId,
    Expression<int>? servingsHalves,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (slot != null) 'slot': slot,
      if (foodId != null) 'food_id': foodId,
      if (servingsHalves != null) 'servings_halves': servingsHalves,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DietLogEntriesCompanion copyWith({
    Value<String>? id,
    Value<LocalDate>? date,
    Value<String>? slot,
    Value<String>? foodId,
    Value<int>? servingsHalves,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return DietLogEntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      slot: slot ?? this.slot,
      foodId: foodId ?? this.foodId,
      servingsHalves: servingsHalves ?? this.servingsHalves,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $DietLogEntriesTable.$converterdate.toSql(date.value),
      );
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<String>(foodId.value);
    }
    if (servingsHalves.present) {
      map['servings_halves'] = Variable<int>(servingsHalves.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DietLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('slot: $slot, ')
          ..write('foodId: $foodId, ')
          ..write('servingsHalves: $servingsHalves, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderPrefsTable extends ReminderPrefs
    with TableInfo<$ReminderPrefsTable, ReminderPrefsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderPrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduleOnMeta = const VerificationMeta(
    'scheduleOn',
  );
  @override
  late final GeneratedColumn<bool> scheduleOn = GeneratedColumn<bool>(
    'schedule_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("schedule_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _scheduleMinuteMeta = const VerificationMeta(
    'scheduleMinute',
  );
  @override
  late final GeneratedColumn<int> scheduleMinute = GeneratedColumn<int>(
    'schedule_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultScheduleReminderMinute),
  );
  static const VerificationMeta _dietOnMeta = const VerificationMeta('dietOn');
  @override
  late final GeneratedColumn<bool> dietOn = GeneratedColumn<bool>(
    'diet_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("diet_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _summaryOnMeta = const VerificationMeta(
    'summaryOn',
  );
  @override
  late final GeneratedColumn<bool> summaryOn = GeneratedColumn<bool>(
    'summary_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("summary_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _summaryMinuteMeta = const VerificationMeta(
    'summaryMinute',
  );
  @override
  late final GeneratedColumn<int> summaryMinute = GeneratedColumn<int>(
    'summary_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7 * 60 + 30),
  );
  static const VerificationMeta _breakfastOnMeta = const VerificationMeta(
    'breakfastOn',
  );
  @override
  late final GeneratedColumn<bool> breakfastOn = GeneratedColumn<bool>(
    'breakfast_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("breakfast_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _breakfastMinuteMeta = const VerificationMeta(
    'breakfastMinute',
  );
  @override
  late final GeneratedColumn<int> breakfastMinute = GeneratedColumn<int>(
    'breakfast_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8 * 60),
  );
  static const VerificationMeta _lunchOnMeta = const VerificationMeta(
    'lunchOn',
  );
  @override
  late final GeneratedColumn<bool> lunchOn = GeneratedColumn<bool>(
    'lunch_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lunch_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lunchMinuteMeta = const VerificationMeta(
    'lunchMinute',
  );
  @override
  late final GeneratedColumn<int> lunchMinute = GeneratedColumn<int>(
    'lunch_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(13 * 60),
  );
  static const VerificationMeta _snackOnMeta = const VerificationMeta(
    'snackOn',
  );
  @override
  late final GeneratedColumn<bool> snackOn = GeneratedColumn<bool>(
    'snack_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("snack_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _snackMinuteMeta = const VerificationMeta(
    'snackMinute',
  );
  @override
  late final GeneratedColumn<int> snackMinute = GeneratedColumn<int>(
    'snack_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(17 * 60),
  );
  static const VerificationMeta _dinnerOnMeta = const VerificationMeta(
    'dinnerOn',
  );
  @override
  late final GeneratedColumn<bool> dinnerOn = GeneratedColumn<bool>(
    'dinner_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dinner_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dinnerMinuteMeta = const VerificationMeta(
    'dinnerMinute',
  );
  @override
  late final GeneratedColumn<int> dinnerMinute = GeneratedColumn<int>(
    'dinner_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20 * 60 + 30),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scheduleOn,
    scheduleMinute,
    dietOn,
    summaryOn,
    summaryMinute,
    breakfastOn,
    breakfastMinute,
    lunchOn,
    lunchMinute,
    snackOn,
    snackMinute,
    dinnerOn,
    dinnerMinute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderPrefsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('schedule_on')) {
      context.handle(
        _scheduleOnMeta,
        scheduleOn.isAcceptableOrUnknown(data['schedule_on']!, _scheduleOnMeta),
      );
    }
    if (data.containsKey('schedule_minute')) {
      context.handle(
        _scheduleMinuteMeta,
        scheduleMinute.isAcceptableOrUnknown(
          data['schedule_minute']!,
          _scheduleMinuteMeta,
        ),
      );
    }
    if (data.containsKey('diet_on')) {
      context.handle(
        _dietOnMeta,
        dietOn.isAcceptableOrUnknown(data['diet_on']!, _dietOnMeta),
      );
    }
    if (data.containsKey('summary_on')) {
      context.handle(
        _summaryOnMeta,
        summaryOn.isAcceptableOrUnknown(data['summary_on']!, _summaryOnMeta),
      );
    }
    if (data.containsKey('summary_minute')) {
      context.handle(
        _summaryMinuteMeta,
        summaryMinute.isAcceptableOrUnknown(
          data['summary_minute']!,
          _summaryMinuteMeta,
        ),
      );
    }
    if (data.containsKey('breakfast_on')) {
      context.handle(
        _breakfastOnMeta,
        breakfastOn.isAcceptableOrUnknown(
          data['breakfast_on']!,
          _breakfastOnMeta,
        ),
      );
    }
    if (data.containsKey('breakfast_minute')) {
      context.handle(
        _breakfastMinuteMeta,
        breakfastMinute.isAcceptableOrUnknown(
          data['breakfast_minute']!,
          _breakfastMinuteMeta,
        ),
      );
    }
    if (data.containsKey('lunch_on')) {
      context.handle(
        _lunchOnMeta,
        lunchOn.isAcceptableOrUnknown(data['lunch_on']!, _lunchOnMeta),
      );
    }
    if (data.containsKey('lunch_minute')) {
      context.handle(
        _lunchMinuteMeta,
        lunchMinute.isAcceptableOrUnknown(
          data['lunch_minute']!,
          _lunchMinuteMeta,
        ),
      );
    }
    if (data.containsKey('snack_on')) {
      context.handle(
        _snackOnMeta,
        snackOn.isAcceptableOrUnknown(data['snack_on']!, _snackOnMeta),
      );
    }
    if (data.containsKey('snack_minute')) {
      context.handle(
        _snackMinuteMeta,
        snackMinute.isAcceptableOrUnknown(
          data['snack_minute']!,
          _snackMinuteMeta,
        ),
      );
    }
    if (data.containsKey('dinner_on')) {
      context.handle(
        _dinnerOnMeta,
        dinnerOn.isAcceptableOrUnknown(data['dinner_on']!, _dinnerOnMeta),
      );
    }
    if (data.containsKey('dinner_minute')) {
      context.handle(
        _dinnerMinuteMeta,
        dinnerMinute.isAcceptableOrUnknown(
          data['dinner_minute']!,
          _dinnerMinuteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderPrefsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderPrefsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scheduleOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}schedule_on'],
      )!,
      scheduleMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_minute'],
      )!,
      dietOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}diet_on'],
      )!,
      summaryOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}summary_on'],
      )!,
      summaryMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}summary_minute'],
      )!,
      breakfastOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}breakfast_on'],
      )!,
      breakfastMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}breakfast_minute'],
      )!,
      lunchOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lunch_on'],
      )!,
      lunchMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lunch_minute'],
      )!,
      snackOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}snack_on'],
      )!,
      snackMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snack_minute'],
      )!,
      dinnerOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dinner_on'],
      )!,
      dinnerMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dinner_minute'],
      )!,
    );
  }

  @override
  $ReminderPrefsTable createAlias(String alias) {
    return $ReminderPrefsTable(attachedDatabase, alias);
  }
}

class ReminderPrefsRow extends DataClass
    implements Insertable<ReminderPrefsRow> {
  final int id;

  /// Retired: the Schedule's training-day reminder (ADR 0005, ADR 0015).
  final bool scheduleOn;
  final int scheduleMinute;

  /// The Diet master switch. Off silences every diet reminder below while
  /// keeping each one's own switch and time for when it comes back on.
  final bool dietOn;

  /// The morning summary of the day's plan.
  final bool summaryOn;
  final int summaryMinute;
  final bool breakfastOn;
  final int breakfastMinute;
  final bool lunchOn;
  final int lunchMinute;
  final bool snackOn;
  final int snackMinute;
  final bool dinnerOn;
  final int dinnerMinute;
  const ReminderPrefsRow({
    required this.id,
    required this.scheduleOn,
    required this.scheduleMinute,
    required this.dietOn,
    required this.summaryOn,
    required this.summaryMinute,
    required this.breakfastOn,
    required this.breakfastMinute,
    required this.lunchOn,
    required this.lunchMinute,
    required this.snackOn,
    required this.snackMinute,
    required this.dinnerOn,
    required this.dinnerMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['schedule_on'] = Variable<bool>(scheduleOn);
    map['schedule_minute'] = Variable<int>(scheduleMinute);
    map['diet_on'] = Variable<bool>(dietOn);
    map['summary_on'] = Variable<bool>(summaryOn);
    map['summary_minute'] = Variable<int>(summaryMinute);
    map['breakfast_on'] = Variable<bool>(breakfastOn);
    map['breakfast_minute'] = Variable<int>(breakfastMinute);
    map['lunch_on'] = Variable<bool>(lunchOn);
    map['lunch_minute'] = Variable<int>(lunchMinute);
    map['snack_on'] = Variable<bool>(snackOn);
    map['snack_minute'] = Variable<int>(snackMinute);
    map['dinner_on'] = Variable<bool>(dinnerOn);
    map['dinner_minute'] = Variable<int>(dinnerMinute);
    return map;
  }

  ReminderPrefsCompanion toCompanion(bool nullToAbsent) {
    return ReminderPrefsCompanion(
      id: Value(id),
      scheduleOn: Value(scheduleOn),
      scheduleMinute: Value(scheduleMinute),
      dietOn: Value(dietOn),
      summaryOn: Value(summaryOn),
      summaryMinute: Value(summaryMinute),
      breakfastOn: Value(breakfastOn),
      breakfastMinute: Value(breakfastMinute),
      lunchOn: Value(lunchOn),
      lunchMinute: Value(lunchMinute),
      snackOn: Value(snackOn),
      snackMinute: Value(snackMinute),
      dinnerOn: Value(dinnerOn),
      dinnerMinute: Value(dinnerMinute),
    );
  }

  factory ReminderPrefsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderPrefsRow(
      id: serializer.fromJson<int>(json['id']),
      scheduleOn: serializer.fromJson<bool>(json['scheduleOn']),
      scheduleMinute: serializer.fromJson<int>(json['scheduleMinute']),
      dietOn: serializer.fromJson<bool>(json['dietOn']),
      summaryOn: serializer.fromJson<bool>(json['summaryOn']),
      summaryMinute: serializer.fromJson<int>(json['summaryMinute']),
      breakfastOn: serializer.fromJson<bool>(json['breakfastOn']),
      breakfastMinute: serializer.fromJson<int>(json['breakfastMinute']),
      lunchOn: serializer.fromJson<bool>(json['lunchOn']),
      lunchMinute: serializer.fromJson<int>(json['lunchMinute']),
      snackOn: serializer.fromJson<bool>(json['snackOn']),
      snackMinute: serializer.fromJson<int>(json['snackMinute']),
      dinnerOn: serializer.fromJson<bool>(json['dinnerOn']),
      dinnerMinute: serializer.fromJson<int>(json['dinnerMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scheduleOn': serializer.toJson<bool>(scheduleOn),
      'scheduleMinute': serializer.toJson<int>(scheduleMinute),
      'dietOn': serializer.toJson<bool>(dietOn),
      'summaryOn': serializer.toJson<bool>(summaryOn),
      'summaryMinute': serializer.toJson<int>(summaryMinute),
      'breakfastOn': serializer.toJson<bool>(breakfastOn),
      'breakfastMinute': serializer.toJson<int>(breakfastMinute),
      'lunchOn': serializer.toJson<bool>(lunchOn),
      'lunchMinute': serializer.toJson<int>(lunchMinute),
      'snackOn': serializer.toJson<bool>(snackOn),
      'snackMinute': serializer.toJson<int>(snackMinute),
      'dinnerOn': serializer.toJson<bool>(dinnerOn),
      'dinnerMinute': serializer.toJson<int>(dinnerMinute),
    };
  }

  ReminderPrefsRow copyWith({
    int? id,
    bool? scheduleOn,
    int? scheduleMinute,
    bool? dietOn,
    bool? summaryOn,
    int? summaryMinute,
    bool? breakfastOn,
    int? breakfastMinute,
    bool? lunchOn,
    int? lunchMinute,
    bool? snackOn,
    int? snackMinute,
    bool? dinnerOn,
    int? dinnerMinute,
  }) => ReminderPrefsRow(
    id: id ?? this.id,
    scheduleOn: scheduleOn ?? this.scheduleOn,
    scheduleMinute: scheduleMinute ?? this.scheduleMinute,
    dietOn: dietOn ?? this.dietOn,
    summaryOn: summaryOn ?? this.summaryOn,
    summaryMinute: summaryMinute ?? this.summaryMinute,
    breakfastOn: breakfastOn ?? this.breakfastOn,
    breakfastMinute: breakfastMinute ?? this.breakfastMinute,
    lunchOn: lunchOn ?? this.lunchOn,
    lunchMinute: lunchMinute ?? this.lunchMinute,
    snackOn: snackOn ?? this.snackOn,
    snackMinute: snackMinute ?? this.snackMinute,
    dinnerOn: dinnerOn ?? this.dinnerOn,
    dinnerMinute: dinnerMinute ?? this.dinnerMinute,
  );
  ReminderPrefsRow copyWithCompanion(ReminderPrefsCompanion data) {
    return ReminderPrefsRow(
      id: data.id.present ? data.id.value : this.id,
      scheduleOn: data.scheduleOn.present
          ? data.scheduleOn.value
          : this.scheduleOn,
      scheduleMinute: data.scheduleMinute.present
          ? data.scheduleMinute.value
          : this.scheduleMinute,
      dietOn: data.dietOn.present ? data.dietOn.value : this.dietOn,
      summaryOn: data.summaryOn.present ? data.summaryOn.value : this.summaryOn,
      summaryMinute: data.summaryMinute.present
          ? data.summaryMinute.value
          : this.summaryMinute,
      breakfastOn: data.breakfastOn.present
          ? data.breakfastOn.value
          : this.breakfastOn,
      breakfastMinute: data.breakfastMinute.present
          ? data.breakfastMinute.value
          : this.breakfastMinute,
      lunchOn: data.lunchOn.present ? data.lunchOn.value : this.lunchOn,
      lunchMinute: data.lunchMinute.present
          ? data.lunchMinute.value
          : this.lunchMinute,
      snackOn: data.snackOn.present ? data.snackOn.value : this.snackOn,
      snackMinute: data.snackMinute.present
          ? data.snackMinute.value
          : this.snackMinute,
      dinnerOn: data.dinnerOn.present ? data.dinnerOn.value : this.dinnerOn,
      dinnerMinute: data.dinnerMinute.present
          ? data.dinnerMinute.value
          : this.dinnerMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderPrefsRow(')
          ..write('id: $id, ')
          ..write('scheduleOn: $scheduleOn, ')
          ..write('scheduleMinute: $scheduleMinute, ')
          ..write('dietOn: $dietOn, ')
          ..write('summaryOn: $summaryOn, ')
          ..write('summaryMinute: $summaryMinute, ')
          ..write('breakfastOn: $breakfastOn, ')
          ..write('breakfastMinute: $breakfastMinute, ')
          ..write('lunchOn: $lunchOn, ')
          ..write('lunchMinute: $lunchMinute, ')
          ..write('snackOn: $snackOn, ')
          ..write('snackMinute: $snackMinute, ')
          ..write('dinnerOn: $dinnerOn, ')
          ..write('dinnerMinute: $dinnerMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scheduleOn,
    scheduleMinute,
    dietOn,
    summaryOn,
    summaryMinute,
    breakfastOn,
    breakfastMinute,
    lunchOn,
    lunchMinute,
    snackOn,
    snackMinute,
    dinnerOn,
    dinnerMinute,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderPrefsRow &&
          other.id == this.id &&
          other.scheduleOn == this.scheduleOn &&
          other.scheduleMinute == this.scheduleMinute &&
          other.dietOn == this.dietOn &&
          other.summaryOn == this.summaryOn &&
          other.summaryMinute == this.summaryMinute &&
          other.breakfastOn == this.breakfastOn &&
          other.breakfastMinute == this.breakfastMinute &&
          other.lunchOn == this.lunchOn &&
          other.lunchMinute == this.lunchMinute &&
          other.snackOn == this.snackOn &&
          other.snackMinute == this.snackMinute &&
          other.dinnerOn == this.dinnerOn &&
          other.dinnerMinute == this.dinnerMinute);
}

class ReminderPrefsCompanion extends UpdateCompanion<ReminderPrefsRow> {
  final Value<int> id;
  final Value<bool> scheduleOn;
  final Value<int> scheduleMinute;
  final Value<bool> dietOn;
  final Value<bool> summaryOn;
  final Value<int> summaryMinute;
  final Value<bool> breakfastOn;
  final Value<int> breakfastMinute;
  final Value<bool> lunchOn;
  final Value<int> lunchMinute;
  final Value<bool> snackOn;
  final Value<int> snackMinute;
  final Value<bool> dinnerOn;
  final Value<int> dinnerMinute;
  const ReminderPrefsCompanion({
    this.id = const Value.absent(),
    this.scheduleOn = const Value.absent(),
    this.scheduleMinute = const Value.absent(),
    this.dietOn = const Value.absent(),
    this.summaryOn = const Value.absent(),
    this.summaryMinute = const Value.absent(),
    this.breakfastOn = const Value.absent(),
    this.breakfastMinute = const Value.absent(),
    this.lunchOn = const Value.absent(),
    this.lunchMinute = const Value.absent(),
    this.snackOn = const Value.absent(),
    this.snackMinute = const Value.absent(),
    this.dinnerOn = const Value.absent(),
    this.dinnerMinute = const Value.absent(),
  });
  ReminderPrefsCompanion.insert({
    this.id = const Value.absent(),
    this.scheduleOn = const Value.absent(),
    this.scheduleMinute = const Value.absent(),
    this.dietOn = const Value.absent(),
    this.summaryOn = const Value.absent(),
    this.summaryMinute = const Value.absent(),
    this.breakfastOn = const Value.absent(),
    this.breakfastMinute = const Value.absent(),
    this.lunchOn = const Value.absent(),
    this.lunchMinute = const Value.absent(),
    this.snackOn = const Value.absent(),
    this.snackMinute = const Value.absent(),
    this.dinnerOn = const Value.absent(),
    this.dinnerMinute = const Value.absent(),
  });
  static Insertable<ReminderPrefsRow> custom({
    Expression<int>? id,
    Expression<bool>? scheduleOn,
    Expression<int>? scheduleMinute,
    Expression<bool>? dietOn,
    Expression<bool>? summaryOn,
    Expression<int>? summaryMinute,
    Expression<bool>? breakfastOn,
    Expression<int>? breakfastMinute,
    Expression<bool>? lunchOn,
    Expression<int>? lunchMinute,
    Expression<bool>? snackOn,
    Expression<int>? snackMinute,
    Expression<bool>? dinnerOn,
    Expression<int>? dinnerMinute,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleOn != null) 'schedule_on': scheduleOn,
      if (scheduleMinute != null) 'schedule_minute': scheduleMinute,
      if (dietOn != null) 'diet_on': dietOn,
      if (summaryOn != null) 'summary_on': summaryOn,
      if (summaryMinute != null) 'summary_minute': summaryMinute,
      if (breakfastOn != null) 'breakfast_on': breakfastOn,
      if (breakfastMinute != null) 'breakfast_minute': breakfastMinute,
      if (lunchOn != null) 'lunch_on': lunchOn,
      if (lunchMinute != null) 'lunch_minute': lunchMinute,
      if (snackOn != null) 'snack_on': snackOn,
      if (snackMinute != null) 'snack_minute': snackMinute,
      if (dinnerOn != null) 'dinner_on': dinnerOn,
      if (dinnerMinute != null) 'dinner_minute': dinnerMinute,
    });
  }

  ReminderPrefsCompanion copyWith({
    Value<int>? id,
    Value<bool>? scheduleOn,
    Value<int>? scheduleMinute,
    Value<bool>? dietOn,
    Value<bool>? summaryOn,
    Value<int>? summaryMinute,
    Value<bool>? breakfastOn,
    Value<int>? breakfastMinute,
    Value<bool>? lunchOn,
    Value<int>? lunchMinute,
    Value<bool>? snackOn,
    Value<int>? snackMinute,
    Value<bool>? dinnerOn,
    Value<int>? dinnerMinute,
  }) {
    return ReminderPrefsCompanion(
      id: id ?? this.id,
      scheduleOn: scheduleOn ?? this.scheduleOn,
      scheduleMinute: scheduleMinute ?? this.scheduleMinute,
      dietOn: dietOn ?? this.dietOn,
      summaryOn: summaryOn ?? this.summaryOn,
      summaryMinute: summaryMinute ?? this.summaryMinute,
      breakfastOn: breakfastOn ?? this.breakfastOn,
      breakfastMinute: breakfastMinute ?? this.breakfastMinute,
      lunchOn: lunchOn ?? this.lunchOn,
      lunchMinute: lunchMinute ?? this.lunchMinute,
      snackOn: snackOn ?? this.snackOn,
      snackMinute: snackMinute ?? this.snackMinute,
      dinnerOn: dinnerOn ?? this.dinnerOn,
      dinnerMinute: dinnerMinute ?? this.dinnerMinute,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scheduleOn.present) {
      map['schedule_on'] = Variable<bool>(scheduleOn.value);
    }
    if (scheduleMinute.present) {
      map['schedule_minute'] = Variable<int>(scheduleMinute.value);
    }
    if (dietOn.present) {
      map['diet_on'] = Variable<bool>(dietOn.value);
    }
    if (summaryOn.present) {
      map['summary_on'] = Variable<bool>(summaryOn.value);
    }
    if (summaryMinute.present) {
      map['summary_minute'] = Variable<int>(summaryMinute.value);
    }
    if (breakfastOn.present) {
      map['breakfast_on'] = Variable<bool>(breakfastOn.value);
    }
    if (breakfastMinute.present) {
      map['breakfast_minute'] = Variable<int>(breakfastMinute.value);
    }
    if (lunchOn.present) {
      map['lunch_on'] = Variable<bool>(lunchOn.value);
    }
    if (lunchMinute.present) {
      map['lunch_minute'] = Variable<int>(lunchMinute.value);
    }
    if (snackOn.present) {
      map['snack_on'] = Variable<bool>(snackOn.value);
    }
    if (snackMinute.present) {
      map['snack_minute'] = Variable<int>(snackMinute.value);
    }
    if (dinnerOn.present) {
      map['dinner_on'] = Variable<bool>(dinnerOn.value);
    }
    if (dinnerMinute.present) {
      map['dinner_minute'] = Variable<int>(dinnerMinute.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderPrefsCompanion(')
          ..write('id: $id, ')
          ..write('scheduleOn: $scheduleOn, ')
          ..write('scheduleMinute: $scheduleMinute, ')
          ..write('dietOn: $dietOn, ')
          ..write('summaryOn: $summaryOn, ')
          ..write('summaryMinute: $summaryMinute, ')
          ..write('breakfastOn: $breakfastOn, ')
          ..write('breakfastMinute: $breakfastMinute, ')
          ..write('lunchOn: $lunchOn, ')
          ..write('lunchMinute: $lunchMinute, ')
          ..write('snackOn: $snackOn, ')
          ..write('snackMinute: $snackMinute, ')
          ..write('dinnerOn: $dinnerOn, ')
          ..write('dinnerMinute: $dinnerMinute')
          ..write(')'))
        .toString();
  }
}

class $CustomExercisesTable extends CustomExercises
    with TableInfo<$CustomExercisesTable, CustomExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loadTypeMeta = const VerificationMeta(
    'loadType',
  );
  @override
  late final GeneratedColumn<String> loadType = GeneratedColumn<String>(
    'load_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryIdsMeta = const VerificationMeta(
    'primaryIds',
  );
  @override
  late final GeneratedColumn<String> primaryIds = GeneratedColumn<String>(
    'primary_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secondaryIdsMeta = const VerificationMeta(
    'secondaryIds',
  );
  @override
  late final GeneratedColumn<String> secondaryIds = GeneratedColumn<String>(
    'secondary_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    equipment,
    loadType,
    primaryIds,
    secondaryIds,
    hidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    } else if (isInserting) {
      context.missing(_equipmentMeta);
    }
    if (data.containsKey('load_type')) {
      context.handle(
        _loadTypeMeta,
        loadType.isAcceptableOrUnknown(data['load_type']!, _loadTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_loadTypeMeta);
    }
    if (data.containsKey('primary_ids')) {
      context.handle(
        _primaryIdsMeta,
        primaryIds.isAcceptableOrUnknown(data['primary_ids']!, _primaryIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_primaryIdsMeta);
    }
    if (data.containsKey('secondary_ids')) {
      context.handle(
        _secondaryIdsMeta,
        secondaryIds.isAcceptableOrUnknown(
          data['secondary_ids']!,
          _secondaryIdsMeta,
        ),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      )!,
      loadType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}load_type'],
      )!,
      primaryIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_ids'],
      )!,
      secondaryIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_ids'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $CustomExercisesTable createAlias(String alias) {
    return $CustomExercisesTable(attachedDatabase, alias);
  }
}

class CustomExerciseRow extends DataClass
    implements Insertable<CustomExerciseRow> {
  final String id;
  final String name;

  /// One of the library's equipment values (`barbell`, `dumbbell`, ...).
  final String equipment;

  /// One of `weighted`, `bodyweight`, `assisted`, `timed`, by name.
  final String loadType;

  /// Primary sub-muscle-group ids, comma-joined. Never empty.
  final String primaryIds;

  /// Secondary sub-muscle-group ids, comma-joined. May be empty.
  final String secondaryIds;

  /// Hidden from the exercise picker (schema step 9). A logged custom
  /// exercise cannot be deleted — history must never show "Unknown exercise"
  /// — so hiding is how the user retires one. It stays in History, records,
  /// the Muscles tab's lists of what was trained, and export.
  final bool hidden;
  const CustomExerciseRow({
    required this.id,
    required this.name,
    required this.equipment,
    required this.loadType,
    required this.primaryIds,
    required this.secondaryIds,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['equipment'] = Variable<String>(equipment);
    map['load_type'] = Variable<String>(loadType);
    map['primary_ids'] = Variable<String>(primaryIds);
    map['secondary_ids'] = Variable<String>(secondaryIds);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  CustomExercisesCompanion toCompanion(bool nullToAbsent) {
    return CustomExercisesCompanion(
      id: Value(id),
      name: Value(name),
      equipment: Value(equipment),
      loadType: Value(loadType),
      primaryIds: Value(primaryIds),
      secondaryIds: Value(secondaryIds),
      hidden: Value(hidden),
    );
  }

  factory CustomExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      equipment: serializer.fromJson<String>(json['equipment']),
      loadType: serializer.fromJson<String>(json['loadType']),
      primaryIds: serializer.fromJson<String>(json['primaryIds']),
      secondaryIds: serializer.fromJson<String>(json['secondaryIds']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'equipment': serializer.toJson<String>(equipment),
      'loadType': serializer.toJson<String>(loadType),
      'primaryIds': serializer.toJson<String>(primaryIds),
      'secondaryIds': serializer.toJson<String>(secondaryIds),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  CustomExerciseRow copyWith({
    String? id,
    String? name,
    String? equipment,
    String? loadType,
    String? primaryIds,
    String? secondaryIds,
    bool? hidden,
  }) => CustomExerciseRow(
    id: id ?? this.id,
    name: name ?? this.name,
    equipment: equipment ?? this.equipment,
    loadType: loadType ?? this.loadType,
    primaryIds: primaryIds ?? this.primaryIds,
    secondaryIds: secondaryIds ?? this.secondaryIds,
    hidden: hidden ?? this.hidden,
  );
  CustomExerciseRow copyWithCompanion(CustomExercisesCompanion data) {
    return CustomExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      loadType: data.loadType.present ? data.loadType.value : this.loadType,
      primaryIds: data.primaryIds.present
          ? data.primaryIds.value
          : this.primaryIds,
      secondaryIds: data.secondaryIds.present
          ? data.secondaryIds.value
          : this.secondaryIds,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomExerciseRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('equipment: $equipment, ')
          ..write('loadType: $loadType, ')
          ..write('primaryIds: $primaryIds, ')
          ..write('secondaryIds: $secondaryIds, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    equipment,
    loadType,
    primaryIds,
    secondaryIds,
    hidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomExerciseRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.equipment == this.equipment &&
          other.loadType == this.loadType &&
          other.primaryIds == this.primaryIds &&
          other.secondaryIds == this.secondaryIds &&
          other.hidden == this.hidden);
}

class CustomExercisesCompanion extends UpdateCompanion<CustomExerciseRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> equipment;
  final Value<String> loadType;
  final Value<String> primaryIds;
  final Value<String> secondaryIds;
  final Value<bool> hidden;
  final Value<int> rowid;
  const CustomExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.equipment = const Value.absent(),
    this.loadType = const Value.absent(),
    this.primaryIds = const Value.absent(),
    this.secondaryIds = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomExercisesCompanion.insert({
    required String id,
    required String name,
    required String equipment,
    required String loadType,
    required String primaryIds,
    this.secondaryIds = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       equipment = Value(equipment),
       loadType = Value(loadType),
       primaryIds = Value(primaryIds);
  static Insertable<CustomExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? equipment,
    Expression<String>? loadType,
    Expression<String>? primaryIds,
    Expression<String>? secondaryIds,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (equipment != null) 'equipment': equipment,
      if (loadType != null) 'load_type': loadType,
      if (primaryIds != null) 'primary_ids': primaryIds,
      if (secondaryIds != null) 'secondary_ids': secondaryIds,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? equipment,
    Value<String>? loadType,
    Value<String>? primaryIds,
    Value<String>? secondaryIds,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return CustomExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      equipment: equipment ?? this.equipment,
      loadType: loadType ?? this.loadType,
      primaryIds: primaryIds ?? this.primaryIds,
      secondaryIds: secondaryIds ?? this.secondaryIds,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (loadType.present) {
      map['load_type'] = Variable<String>(loadType.value);
    }
    if (primaryIds.present) {
      map['primary_ids'] = Variable<String>(primaryIds.value);
    }
    if (secondaryIds.present) {
      map['secondary_ids'] = Variable<String>(secondaryIds.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('equipment: $equipment, ')
          ..write('loadType: $loadType, ')
          ..write('primaryIds: $primaryIds, ')
          ..write('secondaryIds: $secondaryIds, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $BodyweightEntriesTable bodyweightEntries =
      $BodyweightEntriesTable(this);
  late final $CustomTemplatesTable customTemplates = $CustomTemplatesTable(
    this,
  );
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionExercisesTable sessionExercises = $SessionExercisesTable(
    this,
  );
  late final $SetEntriesTable setEntries = $SetEntriesTable(this);
  late final $DietLogEntriesTable dietLogEntries = $DietLogEntriesTable(this);
  late final $ReminderPrefsTable reminderPrefs = $ReminderPrefsTable(this);
  late final $CustomExercisesTable customExercises = $CustomExercisesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    bodyweightEntries,
    customTemplates,
    sessions,
    sessionExercises,
    setEntries,
    dietLogEntries,
    reminderPrefs,
    customExercises,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_exercises', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'session_exercises',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('set_entries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  Value<String?> workoutTemplateFilter,
  Value<String?> bodyGender,
  Value<int?> proteinTargetG,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  Value<String?> workoutTemplateFilter,
  Value<String?> bodyGender,
  Value<int?> proteinTargetG,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workoutTemplateFilter => $composableBuilder(
    column: $table.workoutTemplateFilter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyGender => $composableBuilder(
    column: $table.bodyGender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proteinTargetG => $composableBuilder(
    column: $table.proteinTargetG,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workoutTemplateFilter => $composableBuilder(
    column: $table.workoutTemplateFilter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyGender => $composableBuilder(
    column: $table.bodyGender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proteinTargetG => $composableBuilder(
    column: $table.proteinTargetG,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workoutTemplateFilter => $composableBuilder(
    column: $table.workoutTemplateFilter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyGender => $composableBuilder(
    column: $table.bodyGender,
    builder: (column) => column,
  );

  GeneratedColumn<int> get proteinTargetG => $composableBuilder(
    column: $table.proteinTargetG,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingsRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> workoutTemplateFilter = const Value.absent(),
                Value<String?> bodyGender = const Value.absent(),
                Value<int?> proteinTargetG = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                workoutTemplateFilter: workoutTemplateFilter,
                bodyGender: bodyGender,
                proteinTargetG: proteinTargetG,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> workoutTemplateFilter = const Value.absent(),
                Value<String?> bodyGender = const Value.absent(),
                Value<int?> proteinTargetG = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                workoutTemplateFilter: workoutTemplateFilter,
                bodyGender: bodyGender,
                proteinTargetG: proteinTargetG,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingsRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingsRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingsRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>),
      SettingsRow,
      PrefetchHooks Function()
    >;
typedef $$BodyweightEntriesTableCreateCompanionBuilder =
    BodyweightEntriesCompanion Function({
      required String date,
      required double weightKg,
      Value<int> rowid,
    });
typedef $$BodyweightEntriesTableUpdateCompanionBuilder =
    BodyweightEntriesCompanion Function({
      Value<String> date,
      Value<double> weightKg,
      Value<int> rowid,
    });

class $$BodyweightEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyweightEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyweightEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);
}

class $$BodyweightEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyweightEntriesTable,
          BodyweightEntryRow,
          $$BodyweightEntriesTableFilterComposer,
          $$BodyweightEntriesTableOrderingComposer,
          $$BodyweightEntriesTableAnnotationComposer,
          $$BodyweightEntriesTableCreateCompanionBuilder,
          $$BodyweightEntriesTableUpdateCompanionBuilder,
          (
            BodyweightEntryRow,
            BaseReferences<
              _$AppDatabase,
              $BodyweightEntriesTable,
              BodyweightEntryRow
            >,
          ),
          BodyweightEntryRow,
          PrefetchHooks Function()
        > {
  $$BodyweightEntriesTableTableManager(
    _$AppDatabase db,
    $BodyweightEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyweightEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyweightEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyweightEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyweightEntriesCompanion(
                date: date,
                weightKg: weightKg,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                required double weightKg,
                Value<int> rowid = const Value.absent(),
              }) => BodyweightEntriesCompanion.insert(
                date: date,
                weightKg: weightKg,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BodyweightEntriesTable, BodyweightEntryRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $BodyweightEntriesTable,
                    BodyweightEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyweightEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyweightEntriesTable,
      BodyweightEntryRow,
      $$BodyweightEntriesTableFilterComposer,
      $$BodyweightEntriesTableOrderingComposer,
      $$BodyweightEntriesTableAnnotationComposer,
      $$BodyweightEntriesTableCreateCompanionBuilder,
      $$BodyweightEntriesTableUpdateCompanionBuilder,
      (
        BodyweightEntryRow,
        BaseReferences<
          _$AppDatabase,
          $BodyweightEntriesTable,
          BodyweightEntryRow
        >,
      ),
      BodyweightEntryRow,
      PrefetchHooks Function()
    >;
typedef $$CustomTemplatesTableCreateCompanionBuilder =
    CustomTemplatesCompanion Function({
      required String id,
      required String name,
      Value<String> groupIds,
      Value<String> exerciseIds,
      Value<String?> sourceTemplateId,
      Value<int> rowid,
    });
typedef $$CustomTemplatesTableUpdateCompanionBuilder =
    CustomTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> groupIds,
      Value<String> exerciseIds,
      Value<String?> sourceTemplateId,
      Value<int> rowid,
    });

class $$CustomTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomTemplatesTable> {
  $$CustomTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupIds => $composableBuilder(
    column: $table.groupIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseIds => $composableBuilder(
    column: $table.exerciseIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomTemplatesTable> {
  $$CustomTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupIds => $composableBuilder(
    column: $table.groupIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseIds => $composableBuilder(
    column: $table.exerciseIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomTemplatesTable> {
  $$CustomTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get groupIds =>
      $composableBuilder(column: $table.groupIds, builder: (column) => column);

  GeneratedColumn<String> get exerciseIds => $composableBuilder(
    column: $table.exerciseIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => column,
  );
}

class $$CustomTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomTemplatesTable,
          CustomTemplateRow,
          $$CustomTemplatesTableFilterComposer,
          $$CustomTemplatesTableOrderingComposer,
          $$CustomTemplatesTableAnnotationComposer,
          $$CustomTemplatesTableCreateCompanionBuilder,
          $$CustomTemplatesTableUpdateCompanionBuilder,
          (
            CustomTemplateRow,
            BaseReferences<
              _$AppDatabase,
              $CustomTemplatesTable,
              CustomTemplateRow
            >,
          ),
          CustomTemplateRow,
          PrefetchHooks Function()
        > {
  $$CustomTemplatesTableTableManager(
    _$AppDatabase db,
    $CustomTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> groupIds = const Value.absent(),
                Value<String> exerciseIds = const Value.absent(),
                Value<String?> sourceTemplateId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomTemplatesCompanion(
                id: id,
                name: name,
                groupIds: groupIds,
                exerciseIds: exerciseIds,
                sourceTemplateId: sourceTemplateId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> groupIds = const Value.absent(),
                Value<String> exerciseIds = const Value.absent(),
                Value<String?> sourceTemplateId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomTemplatesCompanion.insert(
                id: id,
                name: name,
                groupIds: groupIds,
                exerciseIds: exerciseIds,
                sourceTemplateId: sourceTemplateId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomTemplatesTable, CustomTemplateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CustomTemplatesTable,
                    CustomTemplateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomTemplatesTable,
      CustomTemplateRow,
      $$CustomTemplatesTableFilterComposer,
      $$CustomTemplatesTableOrderingComposer,
      $$CustomTemplatesTableAnnotationComposer,
      $$CustomTemplatesTableCreateCompanionBuilder,
      $$CustomTemplatesTableUpdateCompanionBuilder,
      (
        CustomTemplateRow,
        BaseReferences<_$AppDatabase, $CustomTemplatesTable, CustomTemplateRow>,
      ),
      CustomTemplateRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  Value<String?> title,
  required LocalDate performedOn,
  required DateTime loggedAt,
  Value<String?> templateId,
  Value<String?> templateName,
  Value<String?> groupIds,
  Value<int?> openMarker,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String?> title,
  Value<LocalDate> performedOn,
  Value<DateTime> loggedAt,
  Value<String?> templateId,
  Value<String?> templateName,
  Value<String?> groupIds,
  Value<int?> openMarker,
  Value<int> rowid,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, SessionRow> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionExercisesTable, List<SessionExerciseRow>>
  _sessionExercisesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionExercises,
    aliasName: 'sessions__id__session_exercises__session_id',
  );

  $$SessionExercisesTableProcessedTableManager get sessionExercisesRefs {
    final manager = $$SessionExercisesTableTableManager(
      $_db,
      $_db.sessionExercises,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sessionExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String>
  get performedOn => $composableBuilder(
    column: $table.performedOn,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateName => $composableBuilder(
    column: $table.templateName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupIds => $composableBuilder(
    column: $table.groupIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openMarker => $composableBuilder(
    column: $table.openMarker,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionExercisesRefs(
    Expression<bool> Function($$SessionExercisesTableFilterComposer f) f,
  ) {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableFilterComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get performedOn => $composableBuilder(
    column: $table.performedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateName => $composableBuilder(
    column: $table.templateName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupIds => $composableBuilder(
    column: $table.groupIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openMarker => $composableBuilder(
    column: $table.openMarker,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get performedOn =>
      $composableBuilder(
        column: $table.performedOn,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateName => $composableBuilder(
    column: $table.templateName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupIds =>
      $composableBuilder(column: $table.groupIds, builder: (column) => column);

  GeneratedColumn<int> get openMarker => $composableBuilder(
    column: $table.openMarker,
    builder: (column) => column,
  );

  Expression<T> sessionExercisesRefs<T extends Object>(
    Expression<T> Function($$SessionExercisesTableAnnotationComposer a) f,
  ) {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (SessionRow, $$SessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({bool sessionExercisesRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<LocalDate> performedOn = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<String?> templateName = const Value.absent(),
                Value<String?> groupIds = const Value.absent(),
                Value<int?> openMarker = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                title: title,
                performedOn: performedOn,
                loggedAt: loggedAt,
                templateId: templateId,
                templateName: templateName,
                groupIds: groupIds,
                openMarker: openMarker,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> title = const Value.absent(),
                required LocalDate performedOn,
                required DateTime loggedAt,
                Value<String?> templateId = const Value.absent(),
                Value<String?> templateName = const Value.absent(),
                Value<String?> groupIds = const Value.absent(),
                Value<int?> openMarker = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                title: title,
                performedOn: performedOn,
                loggedAt: loggedAt,
                templateId: templateId,
                templateName: templateName,
                groupIds: groupIds,
                openMarker: openMarker,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionExercisesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionExercisesRefs) db.sessionExercises,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionExercisesRefs)
                    await $_getPrefetchedData<
                      SessionRow,
                      $SessionsTable,
                      SessionExerciseRow
                    >(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences
                          ._sessionExercisesRefsTable(db),
                      managerFromTypedResult: (p0) => $$SessionsTableReferences(
                        db,
                        table,
                        p0,
                      ).sessionExercisesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, $$SessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({bool sessionExercisesRefs})
    >;
typedef $$SessionExercisesTableCreateCompanionBuilder =
    SessionExercisesCompanion Function({
      required String id,
      required String sessionId,
      required String exerciseId,
      required int position,
      required String loadType,
      Value<bool> markedDone,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$SessionExercisesTableUpdateCompanionBuilder =
    SessionExercisesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> exerciseId,
      Value<int> position,
      Value<String> loadType,
      Value<bool> markedDone,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$SessionExercisesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SessionExercisesTable,
          SessionExerciseRow
        > {
  $$SessionExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('session_exercises__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SetEntriesTable, List<SetEntryRow>>
  _setEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setEntries,
    aliasName: 'session_exercises__id__set_entries__session_exercise_id',
  );

  $$SetEntriesTableProcessedTableManager get setEntriesRefs {
    final manager = $$SetEntriesTableTableManager($_db, $_db.setEntries).filter(
      (f) => f.sessionExerciseId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_setEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loadType => $composableBuilder(
    column: $table.loadType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get markedDone => $composableBuilder(
    column: $table.markedDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> setEntriesRefs(
    Expression<bool> Function($$SetEntriesTableFilterComposer f) f,
  ) {
    final $$SetEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setEntries,
      getReferencedColumn: (t) => t.sessionExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetEntriesTableFilterComposer(
            $db: $db,
            $table: $db.setEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loadType => $composableBuilder(
    column: $table.loadType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get markedDone => $composableBuilder(
    column: $table.markedDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get loadType =>
      $composableBuilder(column: $table.loadType, builder: (column) => column);

  GeneratedColumn<bool> get markedDone => $composableBuilder(
    column: $table.markedDone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> setEntriesRefs<T extends Object>(
    Expression<T> Function($$SetEntriesTableAnnotationComposer a) f,
  ) {
    final $$SetEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setEntries,
      getReferencedColumn: (t) => t.sessionExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.setEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionExercisesTable,
          SessionExerciseRow,
          $$SessionExercisesTableFilterComposer,
          $$SessionExercisesTableOrderingComposer,
          $$SessionExercisesTableAnnotationComposer,
          $$SessionExercisesTableCreateCompanionBuilder,
          $$SessionExercisesTableUpdateCompanionBuilder,
          (SessionExerciseRow, $$SessionExercisesTableReferences),
          SessionExerciseRow,
          PrefetchHooks Function({bool sessionId, bool setEntriesRefs})
        > {
  $$SessionExercisesTableTableManager(
    _$AppDatabase db,
    $SessionExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> loadType = const Value.absent(),
                Value<bool> markedDone = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionExercisesCompanion(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                position: position,
                loadType: loadType,
                markedDone: markedDone,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String exerciseId,
                required int position,
                required String loadType,
                Value<bool> markedDone = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionExercisesCompanion.insert(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                position: position,
                loadType: loadType,
                markedDone: markedDone,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionExercisesTable, SessionExerciseRow>(
                    table,
                  ),
                  $$SessionExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, setEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (setEntriesRefs) db.setEntries],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$SessionExercisesTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$SessionExercisesTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setEntriesRefs)
                    await $_getPrefetchedData<
                      SessionExerciseRow,
                      $SessionExercisesTable,
                      SetEntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$SessionExercisesTableReferences
                          ._setEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SessionExercisesTableReferences(
                            db,
                            table,
                            p0,
                          ).setEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.sessionExerciseId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionExercisesTable,
      SessionExerciseRow,
      $$SessionExercisesTableFilterComposer,
      $$SessionExercisesTableOrderingComposer,
      $$SessionExercisesTableAnnotationComposer,
      $$SessionExercisesTableCreateCompanionBuilder,
      $$SessionExercisesTableUpdateCompanionBuilder,
      (SessionExerciseRow, $$SessionExercisesTableReferences),
      SessionExerciseRow,
      PrefetchHooks Function({bool sessionId, bool setEntriesRefs})
    >;
typedef $$SetEntriesTableCreateCompanionBuilder = SetEntriesCompanion Function({
  required String id,
  required String sessionExerciseId,
  required int position,
  Value<bool> completed,
  Value<double?> weightKg,
  Value<int?> reps,
  Value<double?> addedKg,
  Value<double?> assistKg,
  Value<int?> durationSec,
  Value<int> rowid,
});
typedef $$SetEntriesTableUpdateCompanionBuilder = SetEntriesCompanion Function({
  Value<String> id,
  Value<String> sessionExerciseId,
  Value<int> position,
  Value<bool> completed,
  Value<double?> weightKg,
  Value<int?> reps,
  Value<double?> addedKg,
  Value<double?> assistKg,
  Value<int?> durationSec,
  Value<int> rowid,
});

final class $$SetEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $SetEntriesTable, SetEntryRow> {
  $$SetEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionExercisesTable _sessionExerciseIdTable(_$AppDatabase db) => db
      .sessionExercises
      .createAlias('set_entries__session_exercise_id__session_exercises__id');

  $$SessionExercisesTableProcessedTableManager get sessionExerciseId {
    final $_column = $_itemColumn<String>('session_exercise_id')!;

    final manager = $$SessionExercisesTableTableManager(
      $_db,
      $_db.sessionExercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionExerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get addedKg => $composableBuilder(
    column: $table.addedKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get assistKg => $composableBuilder(
    column: $table.assistKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionExercisesTableFilterComposer get sessionExerciseId {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseId,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableFilterComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get addedKg => $composableBuilder(
    column: $table.addedKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get assistKg => $composableBuilder(
    column: $table.assistKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionExercisesTableOrderingComposer get sessionExerciseId {
    final $$SessionExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseId,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get addedKg =>
      $composableBuilder(column: $table.addedKg, builder: (column) => column);

  GeneratedColumn<double> get assistKg =>
      $composableBuilder(column: $table.assistKg, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  $$SessionExercisesTableAnnotationComposer get sessionExerciseId {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseId,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetEntriesTable,
          SetEntryRow,
          $$SetEntriesTableFilterComposer,
          $$SetEntriesTableOrderingComposer,
          $$SetEntriesTableAnnotationComposer,
          $$SetEntriesTableCreateCompanionBuilder,
          $$SetEntriesTableUpdateCompanionBuilder,
          (SetEntryRow, $$SetEntriesTableReferences),
          SetEntryRow,
          PrefetchHooks Function({bool sessionExerciseId})
        > {
  $$SetEntriesTableTableManager(_$AppDatabase db, $SetEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionExerciseId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> addedKg = const Value.absent(),
                Value<double?> assistKg = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetEntriesCompanion(
                id: id,
                sessionExerciseId: sessionExerciseId,
                position: position,
                completed: completed,
                weightKg: weightKg,
                reps: reps,
                addedKg: addedKg,
                assistKg: assistKg,
                durationSec: durationSec,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionExerciseId,
                required int position,
                Value<bool> completed = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> addedKg = const Value.absent(),
                Value<double?> assistKg = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetEntriesCompanion.insert(
                id: id,
                sessionExerciseId: sessionExerciseId,
                position: position,
                completed: completed,
                weightKg: weightKg,
                reps: reps,
                addedKg: addedKg,
                assistKg: assistKg,
                durationSec: durationSec,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SetEntriesTable, SetEntryRow>(table),
                  $$SetEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionExerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionExerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionExerciseId,
                        referencedTable: $$SetEntriesTableReferences
                            ._sessionExerciseIdTable(db),
                        referencedColumn: $$SetEntriesTableReferences
                            ._sessionExerciseIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SetEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetEntriesTable,
      SetEntryRow,
      $$SetEntriesTableFilterComposer,
      $$SetEntriesTableOrderingComposer,
      $$SetEntriesTableAnnotationComposer,
      $$SetEntriesTableCreateCompanionBuilder,
      $$SetEntriesTableUpdateCompanionBuilder,
      (SetEntryRow, $$SetEntriesTableReferences),
      SetEntryRow,
      PrefetchHooks Function({bool sessionExerciseId})
    >;
typedef $$DietLogEntriesTableCreateCompanionBuilder =
    DietLogEntriesCompanion Function({
      required String id,
      required LocalDate date,
      required String slot,
      required String foodId,
      required int servingsHalves,
      required int position,
      Value<int> rowid,
    });
typedef $$DietLogEntriesTableUpdateCompanionBuilder =
    DietLogEntriesCompanion Function({
      Value<String> id,
      Value<LocalDate> date,
      Value<String> slot,
      Value<String> foodId,
      Value<int> servingsHalves,
      Value<int> position,
      Value<int> rowid,
    });

class $$DietLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DietLogEntriesTable> {
  $$DietLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servingsHalves => $composableBuilder(
    column: $table.servingsHalves,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DietLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DietLogEntriesTable> {
  $$DietLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servingsHalves => $composableBuilder(
    column: $table.servingsHalves,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DietLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DietLogEntriesTable> {
  $$DietLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get foodId =>
      $composableBuilder(column: $table.foodId, builder: (column) => column);

  GeneratedColumn<int> get servingsHalves => $composableBuilder(
    column: $table.servingsHalves,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$DietLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DietLogEntriesTable,
          DietLogEntryRow,
          $$DietLogEntriesTableFilterComposer,
          $$DietLogEntriesTableOrderingComposer,
          $$DietLogEntriesTableAnnotationComposer,
          $$DietLogEntriesTableCreateCompanionBuilder,
          $$DietLogEntriesTableUpdateCompanionBuilder,
          (
            DietLogEntryRow,
            BaseReferences<
              _$AppDatabase,
              $DietLogEntriesTable,
              DietLogEntryRow
            >,
          ),
          DietLogEntryRow,
          PrefetchHooks Function()
        > {
  $$DietLogEntriesTableTableManager(
    _$AppDatabase db,
    $DietLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DietLogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DietLogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DietLogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<LocalDate> date = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String> foodId = const Value.absent(),
                Value<int> servingsHalves = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DietLogEntriesCompanion(
                id: id,
                date: date,
                slot: slot,
                foodId: foodId,
                servingsHalves: servingsHalves,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required LocalDate date,
                required String slot,
                required String foodId,
                required int servingsHalves,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => DietLogEntriesCompanion.insert(
                id: id,
                date: date,
                slot: slot,
                foodId: foodId,
                servingsHalves: servingsHalves,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DietLogEntriesTable, DietLogEntryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DietLogEntriesTable,
                    DietLogEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DietLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DietLogEntriesTable,
      DietLogEntryRow,
      $$DietLogEntriesTableFilterComposer,
      $$DietLogEntriesTableOrderingComposer,
      $$DietLogEntriesTableAnnotationComposer,
      $$DietLogEntriesTableCreateCompanionBuilder,
      $$DietLogEntriesTableUpdateCompanionBuilder,
      (
        DietLogEntryRow,
        BaseReferences<_$AppDatabase, $DietLogEntriesTable, DietLogEntryRow>,
      ),
      DietLogEntryRow,
      PrefetchHooks Function()
    >;
typedef $$ReminderPrefsTableCreateCompanionBuilder =
    ReminderPrefsCompanion Function({
      Value<int> id,
      Value<bool> scheduleOn,
      Value<int> scheduleMinute,
      Value<bool> dietOn,
      Value<bool> summaryOn,
      Value<int> summaryMinute,
      Value<bool> breakfastOn,
      Value<int> breakfastMinute,
      Value<bool> lunchOn,
      Value<int> lunchMinute,
      Value<bool> snackOn,
      Value<int> snackMinute,
      Value<bool> dinnerOn,
      Value<int> dinnerMinute,
    });
typedef $$ReminderPrefsTableUpdateCompanionBuilder =
    ReminderPrefsCompanion Function({
      Value<int> id,
      Value<bool> scheduleOn,
      Value<int> scheduleMinute,
      Value<bool> dietOn,
      Value<bool> summaryOn,
      Value<int> summaryMinute,
      Value<bool> breakfastOn,
      Value<int> breakfastMinute,
      Value<bool> lunchOn,
      Value<int> lunchMinute,
      Value<bool> snackOn,
      Value<int> snackMinute,
      Value<bool> dinnerOn,
      Value<int> dinnerMinute,
    });

class $$ReminderPrefsTableFilterComposer
    extends Composer<_$AppDatabase, $ReminderPrefsTable> {
  $$ReminderPrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get scheduleOn => $composableBuilder(
    column: $table.scheduleOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleMinute => $composableBuilder(
    column: $table.scheduleMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dietOn => $composableBuilder(
    column: $table.dietOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get summaryOn => $composableBuilder(
    column: $table.summaryOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get summaryMinute => $composableBuilder(
    column: $table.summaryMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get breakfastOn => $composableBuilder(
    column: $table.breakfastOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breakfastMinute => $composableBuilder(
    column: $table.breakfastMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lunchOn => $composableBuilder(
    column: $table.lunchOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lunchMinute => $composableBuilder(
    column: $table.lunchMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get snackOn => $composableBuilder(
    column: $table.snackOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snackMinute => $composableBuilder(
    column: $table.snackMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dinnerOn => $composableBuilder(
    column: $table.dinnerOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dinnerMinute => $composableBuilder(
    column: $table.dinnerMinute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderPrefsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReminderPrefsTable> {
  $$ReminderPrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get scheduleOn => $composableBuilder(
    column: $table.scheduleOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleMinute => $composableBuilder(
    column: $table.scheduleMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dietOn => $composableBuilder(
    column: $table.dietOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get summaryOn => $composableBuilder(
    column: $table.summaryOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get summaryMinute => $composableBuilder(
    column: $table.summaryMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get breakfastOn => $composableBuilder(
    column: $table.breakfastOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breakfastMinute => $composableBuilder(
    column: $table.breakfastMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lunchOn => $composableBuilder(
    column: $table.lunchOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lunchMinute => $composableBuilder(
    column: $table.lunchMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get snackOn => $composableBuilder(
    column: $table.snackOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snackMinute => $composableBuilder(
    column: $table.snackMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dinnerOn => $composableBuilder(
    column: $table.dinnerOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dinnerMinute => $composableBuilder(
    column: $table.dinnerMinute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderPrefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReminderPrefsTable> {
  $$ReminderPrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get scheduleOn => $composableBuilder(
    column: $table.scheduleOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleMinute => $composableBuilder(
    column: $table.scheduleMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dietOn =>
      $composableBuilder(column: $table.dietOn, builder: (column) => column);

  GeneratedColumn<bool> get summaryOn =>
      $composableBuilder(column: $table.summaryOn, builder: (column) => column);

  GeneratedColumn<int> get summaryMinute => $composableBuilder(
    column: $table.summaryMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get breakfastOn => $composableBuilder(
    column: $table.breakfastOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get breakfastMinute => $composableBuilder(
    column: $table.breakfastMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lunchOn =>
      $composableBuilder(column: $table.lunchOn, builder: (column) => column);

  GeneratedColumn<int> get lunchMinute => $composableBuilder(
    column: $table.lunchMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get snackOn =>
      $composableBuilder(column: $table.snackOn, builder: (column) => column);

  GeneratedColumn<int> get snackMinute => $composableBuilder(
    column: $table.snackMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dinnerOn =>
      $composableBuilder(column: $table.dinnerOn, builder: (column) => column);

  GeneratedColumn<int> get dinnerMinute => $composableBuilder(
    column: $table.dinnerMinute,
    builder: (column) => column,
  );
}

class $$ReminderPrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReminderPrefsTable,
          ReminderPrefsRow,
          $$ReminderPrefsTableFilterComposer,
          $$ReminderPrefsTableOrderingComposer,
          $$ReminderPrefsTableAnnotationComposer,
          $$ReminderPrefsTableCreateCompanionBuilder,
          $$ReminderPrefsTableUpdateCompanionBuilder,
          (
            ReminderPrefsRow,
            BaseReferences<
              _$AppDatabase,
              $ReminderPrefsTable,
              ReminderPrefsRow
            >,
          ),
          ReminderPrefsRow,
          PrefetchHooks Function()
        > {
  $$ReminderPrefsTableTableManager(_$AppDatabase db, $ReminderPrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderPrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderPrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderPrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> scheduleOn = const Value.absent(),
                Value<int> scheduleMinute = const Value.absent(),
                Value<bool> dietOn = const Value.absent(),
                Value<bool> summaryOn = const Value.absent(),
                Value<int> summaryMinute = const Value.absent(),
                Value<bool> breakfastOn = const Value.absent(),
                Value<int> breakfastMinute = const Value.absent(),
                Value<bool> lunchOn = const Value.absent(),
                Value<int> lunchMinute = const Value.absent(),
                Value<bool> snackOn = const Value.absent(),
                Value<int> snackMinute = const Value.absent(),
                Value<bool> dinnerOn = const Value.absent(),
                Value<int> dinnerMinute = const Value.absent(),
              }) => ReminderPrefsCompanion(
                id: id,
                scheduleOn: scheduleOn,
                scheduleMinute: scheduleMinute,
                dietOn: dietOn,
                summaryOn: summaryOn,
                summaryMinute: summaryMinute,
                breakfastOn: breakfastOn,
                breakfastMinute: breakfastMinute,
                lunchOn: lunchOn,
                lunchMinute: lunchMinute,
                snackOn: snackOn,
                snackMinute: snackMinute,
                dinnerOn: dinnerOn,
                dinnerMinute: dinnerMinute,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> scheduleOn = const Value.absent(),
                Value<int> scheduleMinute = const Value.absent(),
                Value<bool> dietOn = const Value.absent(),
                Value<bool> summaryOn = const Value.absent(),
                Value<int> summaryMinute = const Value.absent(),
                Value<bool> breakfastOn = const Value.absent(),
                Value<int> breakfastMinute = const Value.absent(),
                Value<bool> lunchOn = const Value.absent(),
                Value<int> lunchMinute = const Value.absent(),
                Value<bool> snackOn = const Value.absent(),
                Value<int> snackMinute = const Value.absent(),
                Value<bool> dinnerOn = const Value.absent(),
                Value<int> dinnerMinute = const Value.absent(),
              }) => ReminderPrefsCompanion.insert(
                id: id,
                scheduleOn: scheduleOn,
                scheduleMinute: scheduleMinute,
                dietOn: dietOn,
                summaryOn: summaryOn,
                summaryMinute: summaryMinute,
                breakfastOn: breakfastOn,
                breakfastMinute: breakfastMinute,
                lunchOn: lunchOn,
                lunchMinute: lunchMinute,
                snackOn: snackOn,
                snackMinute: snackMinute,
                dinnerOn: dinnerOn,
                dinnerMinute: dinnerMinute,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderPrefsTable, ReminderPrefsRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReminderPrefsTable,
                    ReminderPrefsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderPrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReminderPrefsTable,
      ReminderPrefsRow,
      $$ReminderPrefsTableFilterComposer,
      $$ReminderPrefsTableOrderingComposer,
      $$ReminderPrefsTableAnnotationComposer,
      $$ReminderPrefsTableCreateCompanionBuilder,
      $$ReminderPrefsTableUpdateCompanionBuilder,
      (
        ReminderPrefsRow,
        BaseReferences<_$AppDatabase, $ReminderPrefsTable, ReminderPrefsRow>,
      ),
      ReminderPrefsRow,
      PrefetchHooks Function()
    >;
typedef $$CustomExercisesTableCreateCompanionBuilder =
    CustomExercisesCompanion Function({
      required String id,
      required String name,
      required String equipment,
      required String loadType,
      required String primaryIds,
      Value<String> secondaryIds,
      Value<bool> hidden,
      Value<int> rowid,
    });
typedef $$CustomExercisesTableUpdateCompanionBuilder =
    CustomExercisesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> equipment,
      Value<String> loadType,
      Value<String> primaryIds,
      Value<String> secondaryIds,
      Value<bool> hidden,
      Value<int> rowid,
    });

class $$CustomExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomExercisesTable> {
  $$CustomExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loadType => $composableBuilder(
    column: $table.loadType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryIds => $composableBuilder(
    column: $table.primaryIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryIds => $composableBuilder(
    column: $table.secondaryIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomExercisesTable> {
  $$CustomExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loadType => $composableBuilder(
    column: $table.loadType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryIds => $composableBuilder(
    column: $table.primaryIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryIds => $composableBuilder(
    column: $table.secondaryIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomExercisesTable> {
  $$CustomExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get loadType =>
      $composableBuilder(column: $table.loadType, builder: (column) => column);

  GeneratedColumn<String> get primaryIds => $composableBuilder(
    column: $table.primaryIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryIds => $composableBuilder(
    column: $table.secondaryIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);
}

class $$CustomExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomExercisesTable,
          CustomExerciseRow,
          $$CustomExercisesTableFilterComposer,
          $$CustomExercisesTableOrderingComposer,
          $$CustomExercisesTableAnnotationComposer,
          $$CustomExercisesTableCreateCompanionBuilder,
          $$CustomExercisesTableUpdateCompanionBuilder,
          (
            CustomExerciseRow,
            BaseReferences<
              _$AppDatabase,
              $CustomExercisesTable,
              CustomExerciseRow
            >,
          ),
          CustomExerciseRow,
          PrefetchHooks Function()
        > {
  $$CustomExercisesTableTableManager(
    _$AppDatabase db,
    $CustomExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String> loadType = const Value.absent(),
                Value<String> primaryIds = const Value.absent(),
                Value<String> secondaryIds = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomExercisesCompanion(
                id: id,
                name: name,
                equipment: equipment,
                loadType: loadType,
                primaryIds: primaryIds,
                secondaryIds: secondaryIds,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String equipment,
                required String loadType,
                required String primaryIds,
                Value<String> secondaryIds = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomExercisesCompanion.insert(
                id: id,
                name: name,
                equipment: equipment,
                loadType: loadType,
                primaryIds: primaryIds,
                secondaryIds: secondaryIds,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomExercisesTable, CustomExerciseRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CustomExercisesTable,
                    CustomExerciseRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomExercisesTable,
      CustomExerciseRow,
      $$CustomExercisesTableFilterComposer,
      $$CustomExercisesTableOrderingComposer,
      $$CustomExercisesTableAnnotationComposer,
      $$CustomExercisesTableCreateCompanionBuilder,
      $$CustomExercisesTableUpdateCompanionBuilder,
      (
        CustomExerciseRow,
        BaseReferences<_$AppDatabase, $CustomExercisesTable, CustomExerciseRow>,
      ),
      CustomExerciseRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$BodyweightEntriesTableTableManager get bodyweightEntries =>
      $$BodyweightEntriesTableTableManager(_db, _db.bodyweightEntries);
  $$CustomTemplatesTableTableManager get customTemplates =>
      $$CustomTemplatesTableTableManager(_db, _db.customTemplates);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionExercisesTableTableManager get sessionExercises =>
      $$SessionExercisesTableTableManager(_db, _db.sessionExercises);
  $$SetEntriesTableTableManager get setEntries =>
      $$SetEntriesTableTableManager(_db, _db.setEntries);
  $$DietLogEntriesTableTableManager get dietLogEntries =>
      $$DietLogEntriesTableTableManager(_db, _db.dietLogEntries);
  $$ReminderPrefsTableTableManager get reminderPrefs =>
      $$ReminderPrefsTableTableManager(_db, _db.reminderPrefs);
  $$CustomExercisesTableTableManager get customExercises =>
      $$CustomExercisesTableTableManager(_db, _db.customExercises);
}
