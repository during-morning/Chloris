// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookUrlMeta = const VerificationMeta(
    'bookUrl',
  );
  @override
  late final GeneratedColumn<String> bookUrl = GeneratedColumn<String>(
    'book_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originNameMeta = const VerificationMeta(
    'originName',
  );
  @override
  late final GeneratedColumn<String> originName = GeneratedColumn<String>(
    'origin_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durChapterIndexMeta = const VerificationMeta(
    'durChapterIndex',
  );
  @override
  late final GeneratedColumn<int> durChapterIndex = GeneratedColumn<int>(
    'dur_chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durChapterTitleMeta = const VerificationMeta(
    'durChapterTitle',
  );
  @override
  late final GeneratedColumn<String> durChapterTitle = GeneratedColumn<String>(
    'dur_chapter_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durChapterPosMeta = const VerificationMeta(
    'durChapterPos',
  );
  @override
  late final GeneratedColumn<int> durChapterPos = GeneratedColumn<int>(
    'dur_chapter_pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durChapterPosEndMeta = const VerificationMeta(
    'durChapterPosEnd',
  );
  @override
  late final GeneratedColumn<int> durChapterPosEnd = GeneratedColumn<int>(
    'dur_chapter_pos_end',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _latestChapterTitleMeta =
      const VerificationMeta('latestChapterTitle');
  @override
  late final GeneratedColumn<String> latestChapterTitle =
      GeneratedColumn<String>(
        'latest_chapter_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _totalChapterNumMeta = const VerificationMeta(
    'totalChapterNum',
  );
  @override
  late final GeneratedColumn<int> totalChapterNum = GeneratedColumn<int>(
    'total_chapter_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<int> group = GeneratedColumn<int>(
    'group',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _customOrderMeta = const VerificationMeta(
    'customOrder',
  );
  @override
  late final GeneratedColumn<int> customOrder = GeneratedColumn<int>(
    'custom_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReadTimeMeta = const VerificationMeta(
    'lastReadTime',
  );
  @override
  late final GeneratedColumn<int> lastReadTime = GeneratedColumn<int>(
    'last_read_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUpdateTimeMeta = const VerificationMeta(
    'lastUpdateTime',
  );
  @override
  late final GeneratedColumn<int> lastUpdateTime = GeneratedColumn<int>(
    'last_update_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookUrl,
    name,
    author,
    intro,
    coverUrl,
    origin,
    originName,
    kind,
    durChapterIndex,
    durChapterTitle,
    durChapterPos,
    durChapterPosEnd,
    latestChapterTitle,
    totalChapterNum,
    type,
    group,
    customOrder,
    lastReadTime,
    lastUpdateTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_url')) {
      context.handle(
        _bookUrlMeta,
        bookUrl.isAcceptableOrUnknown(data['book_url']!, _bookUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUrlMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('origin_name')) {
      context.handle(
        _originNameMeta,
        originName.isAcceptableOrUnknown(data['origin_name']!, _originNameMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('dur_chapter_index')) {
      context.handle(
        _durChapterIndexMeta,
        durChapterIndex.isAcceptableOrUnknown(
          data['dur_chapter_index']!,
          _durChapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('dur_chapter_title')) {
      context.handle(
        _durChapterTitleMeta,
        durChapterTitle.isAcceptableOrUnknown(
          data['dur_chapter_title']!,
          _durChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('dur_chapter_pos')) {
      context.handle(
        _durChapterPosMeta,
        durChapterPos.isAcceptableOrUnknown(
          data['dur_chapter_pos']!,
          _durChapterPosMeta,
        ),
      );
    }
    if (data.containsKey('dur_chapter_pos_end')) {
      context.handle(
        _durChapterPosEndMeta,
        durChapterPosEnd.isAcceptableOrUnknown(
          data['dur_chapter_pos_end']!,
          _durChapterPosEndMeta,
        ),
      );
    }
    if (data.containsKey('latest_chapter_title')) {
      context.handle(
        _latestChapterTitleMeta,
        latestChapterTitle.isAcceptableOrUnknown(
          data['latest_chapter_title']!,
          _latestChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('total_chapter_num')) {
      context.handle(
        _totalChapterNumMeta,
        totalChapterNum.isAcceptableOrUnknown(
          data['total_chapter_num']!,
          _totalChapterNumMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('group')) {
      context.handle(
        _groupMeta,
        group.isAcceptableOrUnknown(data['group']!, _groupMeta),
      );
    }
    if (data.containsKey('custom_order')) {
      context.handle(
        _customOrderMeta,
        customOrder.isAcceptableOrUnknown(
          data['custom_order']!,
          _customOrderMeta,
        ),
      );
    }
    if (data.containsKey('last_read_time')) {
      context.handle(
        _lastReadTimeMeta,
        lastReadTime.isAcceptableOrUnknown(
          data['last_read_time']!,
          _lastReadTimeMeta,
        ),
      );
    }
    if (data.containsKey('last_update_time')) {
      context.handle(
        _lastUpdateTimeMeta,
        lastUpdateTime.isAcceptableOrUnknown(
          data['last_update_time']!,
          _lastUpdateTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, author},
  ];
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_url'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      originName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_name'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      durChapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dur_chapter_index'],
      )!,
      durChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dur_chapter_title'],
      ),
      durChapterPos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dur_chapter_pos'],
      )!,
      durChapterPosEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dur_chapter_pos_end'],
      )!,
      latestChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_chapter_title'],
      ),
      totalChapterNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapter_num'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      group: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group'],
      )!,
      customOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_order'],
      )!,
      lastReadTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_time'],
      )!,
      lastUpdateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_update_time'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String bookUrl;
  final String name;
  final String author;
  final String? intro;
  final String? coverUrl;
  final String? origin;
  final String? originName;
  final String? kind;
  final int durChapterIndex;
  final String? durChapterTitle;
  final int durChapterPos;
  final int durChapterPosEnd;
  final String? latestChapterTitle;
  final int totalChapterNum;
  final int type;

  /// Legado `Book.group`：用户分组 id 的位或，0 表示未分组。
  final int group;
  final int customOrder;
  final int lastReadTime;
  final int lastUpdateTime;
  const Book({
    required this.id,
    required this.bookUrl,
    required this.name,
    required this.author,
    this.intro,
    this.coverUrl,
    this.origin,
    this.originName,
    this.kind,
    required this.durChapterIndex,
    this.durChapterTitle,
    required this.durChapterPos,
    required this.durChapterPosEnd,
    this.latestChapterTitle,
    required this.totalChapterNum,
    required this.type,
    required this.group,
    required this.customOrder,
    required this.lastReadTime,
    required this.lastUpdateTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_url'] = Variable<String>(bookUrl);
    map['name'] = Variable<String>(name);
    map['author'] = Variable<String>(author);
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || originName != null) {
      map['origin_name'] = Variable<String>(originName);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    map['dur_chapter_index'] = Variable<int>(durChapterIndex);
    if (!nullToAbsent || durChapterTitle != null) {
      map['dur_chapter_title'] = Variable<String>(durChapterTitle);
    }
    map['dur_chapter_pos'] = Variable<int>(durChapterPos);
    map['dur_chapter_pos_end'] = Variable<int>(durChapterPosEnd);
    if (!nullToAbsent || latestChapterTitle != null) {
      map['latest_chapter_title'] = Variable<String>(latestChapterTitle);
    }
    map['total_chapter_num'] = Variable<int>(totalChapterNum);
    map['type'] = Variable<int>(type);
    map['group'] = Variable<int>(group);
    map['custom_order'] = Variable<int>(customOrder);
    map['last_read_time'] = Variable<int>(lastReadTime);
    map['last_update_time'] = Variable<int>(lastUpdateTime);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      bookUrl: Value(bookUrl),
      name: Value(name),
      author: Value(author),
      intro: intro == null && nullToAbsent
          ? const Value.absent()
          : Value(intro),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      originName: originName == null && nullToAbsent
          ? const Value.absent()
          : Value(originName),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      durChapterIndex: Value(durChapterIndex),
      durChapterTitle: durChapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(durChapterTitle),
      durChapterPos: Value(durChapterPos),
      durChapterPosEnd: Value(durChapterPosEnd),
      latestChapterTitle: latestChapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(latestChapterTitle),
      totalChapterNum: Value(totalChapterNum),
      type: Value(type),
      group: Value(group),
      customOrder: Value(customOrder),
      lastReadTime: Value(lastReadTime),
      lastUpdateTime: Value(lastUpdateTime),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      name: serializer.fromJson<String>(json['name']),
      author: serializer.fromJson<String>(json['author']),
      intro: serializer.fromJson<String?>(json['intro']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      origin: serializer.fromJson<String?>(json['origin']),
      originName: serializer.fromJson<String?>(json['originName']),
      kind: serializer.fromJson<String?>(json['kind']),
      durChapterIndex: serializer.fromJson<int>(json['durChapterIndex']),
      durChapterTitle: serializer.fromJson<String?>(json['durChapterTitle']),
      durChapterPos: serializer.fromJson<int>(json['durChapterPos']),
      durChapterPosEnd: serializer.fromJson<int>(json['durChapterPosEnd']),
      latestChapterTitle: serializer.fromJson<String?>(
        json['latestChapterTitle'],
      ),
      totalChapterNum: serializer.fromJson<int>(json['totalChapterNum']),
      type: serializer.fromJson<int>(json['type']),
      group: serializer.fromJson<int>(json['group']),
      customOrder: serializer.fromJson<int>(json['customOrder']),
      lastReadTime: serializer.fromJson<int>(json['lastReadTime']),
      lastUpdateTime: serializer.fromJson<int>(json['lastUpdateTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookUrl': serializer.toJson<String>(bookUrl),
      'name': serializer.toJson<String>(name),
      'author': serializer.toJson<String>(author),
      'intro': serializer.toJson<String?>(intro),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'origin': serializer.toJson<String?>(origin),
      'originName': serializer.toJson<String?>(originName),
      'kind': serializer.toJson<String?>(kind),
      'durChapterIndex': serializer.toJson<int>(durChapterIndex),
      'durChapterTitle': serializer.toJson<String?>(durChapterTitle),
      'durChapterPos': serializer.toJson<int>(durChapterPos),
      'durChapterPosEnd': serializer.toJson<int>(durChapterPosEnd),
      'latestChapterTitle': serializer.toJson<String?>(latestChapterTitle),
      'totalChapterNum': serializer.toJson<int>(totalChapterNum),
      'type': serializer.toJson<int>(type),
      'group': serializer.toJson<int>(group),
      'customOrder': serializer.toJson<int>(customOrder),
      'lastReadTime': serializer.toJson<int>(lastReadTime),
      'lastUpdateTime': serializer.toJson<int>(lastUpdateTime),
    };
  }

  Book copyWith({
    int? id,
    String? bookUrl,
    String? name,
    String? author,
    Value<String?> intro = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> originName = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    int? durChapterIndex,
    Value<String?> durChapterTitle = const Value.absent(),
    int? durChapterPos,
    int? durChapterPosEnd,
    Value<String?> latestChapterTitle = const Value.absent(),
    int? totalChapterNum,
    int? type,
    int? group,
    int? customOrder,
    int? lastReadTime,
    int? lastUpdateTime,
  }) => Book(
    id: id ?? this.id,
    bookUrl: bookUrl ?? this.bookUrl,
    name: name ?? this.name,
    author: author ?? this.author,
    intro: intro.present ? intro.value : this.intro,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    origin: origin.present ? origin.value : this.origin,
    originName: originName.present ? originName.value : this.originName,
    kind: kind.present ? kind.value : this.kind,
    durChapterIndex: durChapterIndex ?? this.durChapterIndex,
    durChapterTitle: durChapterTitle.present
        ? durChapterTitle.value
        : this.durChapterTitle,
    durChapterPos: durChapterPos ?? this.durChapterPos,
    durChapterPosEnd: durChapterPosEnd ?? this.durChapterPosEnd,
    latestChapterTitle: latestChapterTitle.present
        ? latestChapterTitle.value
        : this.latestChapterTitle,
    totalChapterNum: totalChapterNum ?? this.totalChapterNum,
    type: type ?? this.type,
    group: group ?? this.group,
    customOrder: customOrder ?? this.customOrder,
    lastReadTime: lastReadTime ?? this.lastReadTime,
    lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      name: data.name.present ? data.name.value : this.name,
      author: data.author.present ? data.author.value : this.author,
      intro: data.intro.present ? data.intro.value : this.intro,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      origin: data.origin.present ? data.origin.value : this.origin,
      originName: data.originName.present
          ? data.originName.value
          : this.originName,
      kind: data.kind.present ? data.kind.value : this.kind,
      durChapterIndex: data.durChapterIndex.present
          ? data.durChapterIndex.value
          : this.durChapterIndex,
      durChapterTitle: data.durChapterTitle.present
          ? data.durChapterTitle.value
          : this.durChapterTitle,
      durChapterPos: data.durChapterPos.present
          ? data.durChapterPos.value
          : this.durChapterPos,
      durChapterPosEnd: data.durChapterPosEnd.present
          ? data.durChapterPosEnd.value
          : this.durChapterPosEnd,
      latestChapterTitle: data.latestChapterTitle.present
          ? data.latestChapterTitle.value
          : this.latestChapterTitle,
      totalChapterNum: data.totalChapterNum.present
          ? data.totalChapterNum.value
          : this.totalChapterNum,
      type: data.type.present ? data.type.value : this.type,
      group: data.group.present ? data.group.value : this.group,
      customOrder: data.customOrder.present
          ? data.customOrder.value
          : this.customOrder,
      lastReadTime: data.lastReadTime.present
          ? data.lastReadTime.value
          : this.lastReadTime,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('intro: $intro, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('origin: $origin, ')
          ..write('originName: $originName, ')
          ..write('kind: $kind, ')
          ..write('durChapterIndex: $durChapterIndex, ')
          ..write('durChapterTitle: $durChapterTitle, ')
          ..write('durChapterPos: $durChapterPos, ')
          ..write('durChapterPosEnd: $durChapterPosEnd, ')
          ..write('latestChapterTitle: $latestChapterTitle, ')
          ..write('totalChapterNum: $totalChapterNum, ')
          ..write('type: $type, ')
          ..write('group: $group, ')
          ..write('customOrder: $customOrder, ')
          ..write('lastReadTime: $lastReadTime, ')
          ..write('lastUpdateTime: $lastUpdateTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookUrl,
    name,
    author,
    intro,
    coverUrl,
    origin,
    originName,
    kind,
    durChapterIndex,
    durChapterTitle,
    durChapterPos,
    durChapterPosEnd,
    latestChapterTitle,
    totalChapterNum,
    type,
    group,
    customOrder,
    lastReadTime,
    lastUpdateTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.bookUrl == this.bookUrl &&
          other.name == this.name &&
          other.author == this.author &&
          other.intro == this.intro &&
          other.coverUrl == this.coverUrl &&
          other.origin == this.origin &&
          other.originName == this.originName &&
          other.kind == this.kind &&
          other.durChapterIndex == this.durChapterIndex &&
          other.durChapterTitle == this.durChapterTitle &&
          other.durChapterPos == this.durChapterPos &&
          other.durChapterPosEnd == this.durChapterPosEnd &&
          other.latestChapterTitle == this.latestChapterTitle &&
          other.totalChapterNum == this.totalChapterNum &&
          other.type == this.type &&
          other.group == this.group &&
          other.customOrder == this.customOrder &&
          other.lastReadTime == this.lastReadTime &&
          other.lastUpdateTime == this.lastUpdateTime);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String> bookUrl;
  final Value<String> name;
  final Value<String> author;
  final Value<String?> intro;
  final Value<String?> coverUrl;
  final Value<String?> origin;
  final Value<String?> originName;
  final Value<String?> kind;
  final Value<int> durChapterIndex;
  final Value<String?> durChapterTitle;
  final Value<int> durChapterPos;
  final Value<int> durChapterPosEnd;
  final Value<String?> latestChapterTitle;
  final Value<int> totalChapterNum;
  final Value<int> type;
  final Value<int> group;
  final Value<int> customOrder;
  final Value<int> lastReadTime;
  final Value<int> lastUpdateTime;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.bookUrl = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.intro = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.origin = const Value.absent(),
    this.originName = const Value.absent(),
    this.kind = const Value.absent(),
    this.durChapterIndex = const Value.absent(),
    this.durChapterTitle = const Value.absent(),
    this.durChapterPos = const Value.absent(),
    this.durChapterPosEnd = const Value.absent(),
    this.latestChapterTitle = const Value.absent(),
    this.totalChapterNum = const Value.absent(),
    this.type = const Value.absent(),
    this.group = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.lastReadTime = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String bookUrl,
    required String name,
    this.author = const Value.absent(),
    this.intro = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.origin = const Value.absent(),
    this.originName = const Value.absent(),
    this.kind = const Value.absent(),
    this.durChapterIndex = const Value.absent(),
    this.durChapterTitle = const Value.absent(),
    this.durChapterPos = const Value.absent(),
    this.durChapterPosEnd = const Value.absent(),
    this.latestChapterTitle = const Value.absent(),
    this.totalChapterNum = const Value.absent(),
    this.type = const Value.absent(),
    this.group = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.lastReadTime = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
  }) : bookUrl = Value(bookUrl),
       name = Value(name);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? bookUrl,
    Expression<String>? name,
    Expression<String>? author,
    Expression<String>? intro,
    Expression<String>? coverUrl,
    Expression<String>? origin,
    Expression<String>? originName,
    Expression<String>? kind,
    Expression<int>? durChapterIndex,
    Expression<String>? durChapterTitle,
    Expression<int>? durChapterPos,
    Expression<int>? durChapterPosEnd,
    Expression<String>? latestChapterTitle,
    Expression<int>? totalChapterNum,
    Expression<int>? type,
    Expression<int>? group,
    Expression<int>? customOrder,
    Expression<int>? lastReadTime,
    Expression<int>? lastUpdateTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookUrl != null) 'book_url': bookUrl,
      if (name != null) 'name': name,
      if (author != null) 'author': author,
      if (intro != null) 'intro': intro,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (origin != null) 'origin': origin,
      if (originName != null) 'origin_name': originName,
      if (kind != null) 'kind': kind,
      if (durChapterIndex != null) 'dur_chapter_index': durChapterIndex,
      if (durChapterTitle != null) 'dur_chapter_title': durChapterTitle,
      if (durChapterPos != null) 'dur_chapter_pos': durChapterPos,
      if (durChapterPosEnd != null) 'dur_chapter_pos_end': durChapterPosEnd,
      if (latestChapterTitle != null)
        'latest_chapter_title': latestChapterTitle,
      if (totalChapterNum != null) 'total_chapter_num': totalChapterNum,
      if (type != null) 'type': type,
      if (group != null) 'group': group,
      if (customOrder != null) 'custom_order': customOrder,
      if (lastReadTime != null) 'last_read_time': lastReadTime,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? bookUrl,
    Value<String>? name,
    Value<String>? author,
    Value<String?>? intro,
    Value<String?>? coverUrl,
    Value<String?>? origin,
    Value<String?>? originName,
    Value<String?>? kind,
    Value<int>? durChapterIndex,
    Value<String?>? durChapterTitle,
    Value<int>? durChapterPos,
    Value<int>? durChapterPosEnd,
    Value<String?>? latestChapterTitle,
    Value<int>? totalChapterNum,
    Value<int>? type,
    Value<int>? group,
    Value<int>? customOrder,
    Value<int>? lastReadTime,
    Value<int>? lastUpdateTime,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      bookUrl: bookUrl ?? this.bookUrl,
      name: name ?? this.name,
      author: author ?? this.author,
      intro: intro ?? this.intro,
      coverUrl: coverUrl ?? this.coverUrl,
      origin: origin ?? this.origin,
      originName: originName ?? this.originName,
      kind: kind ?? this.kind,
      durChapterIndex: durChapterIndex ?? this.durChapterIndex,
      durChapterTitle: durChapterTitle ?? this.durChapterTitle,
      durChapterPos: durChapterPos ?? this.durChapterPos,
      durChapterPosEnd: durChapterPosEnd ?? this.durChapterPosEnd,
      latestChapterTitle: latestChapterTitle ?? this.latestChapterTitle,
      totalChapterNum: totalChapterNum ?? this.totalChapterNum,
      type: type ?? this.type,
      group: group ?? this.group,
      customOrder: customOrder ?? this.customOrder,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookUrl.present) {
      map['book_url'] = Variable<String>(bookUrl.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (originName.present) {
      map['origin_name'] = Variable<String>(originName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (durChapterIndex.present) {
      map['dur_chapter_index'] = Variable<int>(durChapterIndex.value);
    }
    if (durChapterTitle.present) {
      map['dur_chapter_title'] = Variable<String>(durChapterTitle.value);
    }
    if (durChapterPos.present) {
      map['dur_chapter_pos'] = Variable<int>(durChapterPos.value);
    }
    if (durChapterPosEnd.present) {
      map['dur_chapter_pos_end'] = Variable<int>(durChapterPosEnd.value);
    }
    if (latestChapterTitle.present) {
      map['latest_chapter_title'] = Variable<String>(latestChapterTitle.value);
    }
    if (totalChapterNum.present) {
      map['total_chapter_num'] = Variable<int>(totalChapterNum.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (group.present) {
      map['group'] = Variable<int>(group.value);
    }
    if (customOrder.present) {
      map['custom_order'] = Variable<int>(customOrder.value);
    }
    if (lastReadTime.present) {
      map['last_read_time'] = Variable<int>(lastReadTime.value);
    }
    if (lastUpdateTime.present) {
      map['last_update_time'] = Variable<int>(lastUpdateTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('intro: $intro, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('origin: $origin, ')
          ..write('originName: $originName, ')
          ..write('kind: $kind, ')
          ..write('durChapterIndex: $durChapterIndex, ')
          ..write('durChapterTitle: $durChapterTitle, ')
          ..write('durChapterPos: $durChapterPos, ')
          ..write('durChapterPosEnd: $durChapterPosEnd, ')
          ..write('latestChapterTitle: $latestChapterTitle, ')
          ..write('totalChapterNum: $totalChapterNum, ')
          ..write('type: $type, ')
          ..write('group: $group, ')
          ..write('customOrder: $customOrder, ')
          ..write('lastReadTime: $lastReadTime, ')
          ..write('lastUpdateTime: $lastUpdateTime')
          ..write(')'))
        .toString();
  }
}

class $BookSourcesTable extends BookSources
    with TableInfo<$BookSourcesTable, BookSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookSourceUrlMeta = const VerificationMeta(
    'bookSourceUrl',
  );
  @override
  late final GeneratedColumn<String> bookSourceUrl = GeneratedColumn<String>(
    'book_source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _bookSourceNameMeta = const VerificationMeta(
    'bookSourceName',
  );
  @override
  late final GeneratedColumn<String> bookSourceName = GeneratedColumn<String>(
    'book_source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookSourceGroupMeta = const VerificationMeta(
    'bookSourceGroup',
  );
  @override
  late final GeneratedColumn<String> bookSourceGroup = GeneratedColumn<String>(
    'book_source_group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookSourceTypeMeta = const VerificationMeta(
    'bookSourceType',
  );
  @override
  late final GeneratedColumn<int> bookSourceType = GeneratedColumn<int>(
    'book_source_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _enabledExploreMeta = const VerificationMeta(
    'enabledExplore',
  );
  @override
  late final GeneratedColumn<bool> enabledExplore = GeneratedColumn<bool>(
    'enabled_explore',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled_explore" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _customOrderMeta = const VerificationMeta(
    'customOrder',
  );
  @override
  late final GeneratedColumn<int> customOrder = GeneratedColumn<int>(
    'custom_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUpdateTimeMeta = const VerificationMeta(
    'lastUpdateTime',
  );
  @override
  late final GeneratedColumn<int> lastUpdateTime = GeneratedColumn<int>(
    'last_update_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _respondTimeMeta = const VerificationMeta(
    'respondTime',
  );
  @override
  late final GeneratedColumn<int> respondTime = GeneratedColumn<int>(
    'respond_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(180000),
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<int> weight = GeneratedColumn<int>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<String> raw = GeneratedColumn<String>(
    'raw',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookSourceUrl,
    bookSourceName,
    bookSourceGroup,
    bookSourceType,
    enabled,
    enabledExplore,
    customOrder,
    lastUpdateTime,
    respondTime,
    weight,
    raw,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_source_url')) {
      context.handle(
        _bookSourceUrlMeta,
        bookSourceUrl.isAcceptableOrUnknown(
          data['book_source_url']!,
          _bookSourceUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookSourceUrlMeta);
    }
    if (data.containsKey('book_source_name')) {
      context.handle(
        _bookSourceNameMeta,
        bookSourceName.isAcceptableOrUnknown(
          data['book_source_name']!,
          _bookSourceNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookSourceNameMeta);
    }
    if (data.containsKey('book_source_group')) {
      context.handle(
        _bookSourceGroupMeta,
        bookSourceGroup.isAcceptableOrUnknown(
          data['book_source_group']!,
          _bookSourceGroupMeta,
        ),
      );
    }
    if (data.containsKey('book_source_type')) {
      context.handle(
        _bookSourceTypeMeta,
        bookSourceType.isAcceptableOrUnknown(
          data['book_source_type']!,
          _bookSourceTypeMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('enabled_explore')) {
      context.handle(
        _enabledExploreMeta,
        enabledExplore.isAcceptableOrUnknown(
          data['enabled_explore']!,
          _enabledExploreMeta,
        ),
      );
    }
    if (data.containsKey('custom_order')) {
      context.handle(
        _customOrderMeta,
        customOrder.isAcceptableOrUnknown(
          data['custom_order']!,
          _customOrderMeta,
        ),
      );
    }
    if (data.containsKey('last_update_time')) {
      context.handle(
        _lastUpdateTimeMeta,
        lastUpdateTime.isAcceptableOrUnknown(
          data['last_update_time']!,
          _lastUpdateTimeMeta,
        ),
      );
    }
    if (data.containsKey('respond_time')) {
      context.handle(
        _respondTimeMeta,
        respondTime.isAcceptableOrUnknown(
          data['respond_time']!,
          _respondTimeMeta,
        ),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('raw')) {
      context.handle(
        _rawMeta,
        raw.isAcceptableOrUnknown(data['raw']!, _rawMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookSourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_source_url'],
      )!,
      bookSourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_source_name'],
      )!,
      bookSourceGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_source_group'],
      ),
      bookSourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_source_type'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      enabledExplore: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled_explore'],
      )!,
      customOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_order'],
      )!,
      lastUpdateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_update_time'],
      )!,
      respondTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}respond_time'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight'],
      )!,
      raw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw'],
      ),
    );
  }

  @override
  $BookSourcesTable createAlias(String alias) {
    return $BookSourcesTable(attachedDatabase, alias);
  }
}

class BookSource extends DataClass implements Insertable<BookSource> {
  final int id;
  final String bookSourceUrl;
  final String bookSourceName;
  final String? bookSourceGroup;
  final int bookSourceType;
  final bool enabled;
  final bool enabledExplore;
  final int customOrder;
  final int lastUpdateTime;
  final int respondTime;
  final int weight;
  final String? raw;
  const BookSource({
    required this.id,
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    required this.bookSourceType,
    required this.enabled,
    required this.enabledExplore,
    required this.customOrder,
    required this.lastUpdateTime,
    required this.respondTime,
    required this.weight,
    this.raw,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_source_url'] = Variable<String>(bookSourceUrl);
    map['book_source_name'] = Variable<String>(bookSourceName);
    if (!nullToAbsent || bookSourceGroup != null) {
      map['book_source_group'] = Variable<String>(bookSourceGroup);
    }
    map['book_source_type'] = Variable<int>(bookSourceType);
    map['enabled'] = Variable<bool>(enabled);
    map['enabled_explore'] = Variable<bool>(enabledExplore);
    map['custom_order'] = Variable<int>(customOrder);
    map['last_update_time'] = Variable<int>(lastUpdateTime);
    map['respond_time'] = Variable<int>(respondTime);
    map['weight'] = Variable<int>(weight);
    if (!nullToAbsent || raw != null) {
      map['raw'] = Variable<String>(raw);
    }
    return map;
  }

  BookSourcesCompanion toCompanion(bool nullToAbsent) {
    return BookSourcesCompanion(
      id: Value(id),
      bookSourceUrl: Value(bookSourceUrl),
      bookSourceName: Value(bookSourceName),
      bookSourceGroup: bookSourceGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(bookSourceGroup),
      bookSourceType: Value(bookSourceType),
      enabled: Value(enabled),
      enabledExplore: Value(enabledExplore),
      customOrder: Value(customOrder),
      lastUpdateTime: Value(lastUpdateTime),
      respondTime: Value(respondTime),
      weight: Value(weight),
      raw: raw == null && nullToAbsent ? const Value.absent() : Value(raw),
    );
  }

  factory BookSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookSource(
      id: serializer.fromJson<int>(json['id']),
      bookSourceUrl: serializer.fromJson<String>(json['bookSourceUrl']),
      bookSourceName: serializer.fromJson<String>(json['bookSourceName']),
      bookSourceGroup: serializer.fromJson<String?>(json['bookSourceGroup']),
      bookSourceType: serializer.fromJson<int>(json['bookSourceType']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      enabledExplore: serializer.fromJson<bool>(json['enabledExplore']),
      customOrder: serializer.fromJson<int>(json['customOrder']),
      lastUpdateTime: serializer.fromJson<int>(json['lastUpdateTime']),
      respondTime: serializer.fromJson<int>(json['respondTime']),
      weight: serializer.fromJson<int>(json['weight']),
      raw: serializer.fromJson<String?>(json['raw']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookSourceUrl': serializer.toJson<String>(bookSourceUrl),
      'bookSourceName': serializer.toJson<String>(bookSourceName),
      'bookSourceGroup': serializer.toJson<String?>(bookSourceGroup),
      'bookSourceType': serializer.toJson<int>(bookSourceType),
      'enabled': serializer.toJson<bool>(enabled),
      'enabledExplore': serializer.toJson<bool>(enabledExplore),
      'customOrder': serializer.toJson<int>(customOrder),
      'lastUpdateTime': serializer.toJson<int>(lastUpdateTime),
      'respondTime': serializer.toJson<int>(respondTime),
      'weight': serializer.toJson<int>(weight),
      'raw': serializer.toJson<String?>(raw),
    };
  }

  BookSource copyWith({
    int? id,
    String? bookSourceUrl,
    String? bookSourceName,
    Value<String?> bookSourceGroup = const Value.absent(),
    int? bookSourceType,
    bool? enabled,
    bool? enabledExplore,
    int? customOrder,
    int? lastUpdateTime,
    int? respondTime,
    int? weight,
    Value<String?> raw = const Value.absent(),
  }) => BookSource(
    id: id ?? this.id,
    bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
    bookSourceName: bookSourceName ?? this.bookSourceName,
    bookSourceGroup: bookSourceGroup.present
        ? bookSourceGroup.value
        : this.bookSourceGroup,
    bookSourceType: bookSourceType ?? this.bookSourceType,
    enabled: enabled ?? this.enabled,
    enabledExplore: enabledExplore ?? this.enabledExplore,
    customOrder: customOrder ?? this.customOrder,
    lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    respondTime: respondTime ?? this.respondTime,
    weight: weight ?? this.weight,
    raw: raw.present ? raw.value : this.raw,
  );
  BookSource copyWithCompanion(BookSourcesCompanion data) {
    return BookSource(
      id: data.id.present ? data.id.value : this.id,
      bookSourceUrl: data.bookSourceUrl.present
          ? data.bookSourceUrl.value
          : this.bookSourceUrl,
      bookSourceName: data.bookSourceName.present
          ? data.bookSourceName.value
          : this.bookSourceName,
      bookSourceGroup: data.bookSourceGroup.present
          ? data.bookSourceGroup.value
          : this.bookSourceGroup,
      bookSourceType: data.bookSourceType.present
          ? data.bookSourceType.value
          : this.bookSourceType,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      enabledExplore: data.enabledExplore.present
          ? data.enabledExplore.value
          : this.enabledExplore,
      customOrder: data.customOrder.present
          ? data.customOrder.value
          : this.customOrder,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
      respondTime: data.respondTime.present
          ? data.respondTime.value
          : this.respondTime,
      weight: data.weight.present ? data.weight.value : this.weight,
      raw: data.raw.present ? data.raw.value : this.raw,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookSource(')
          ..write('id: $id, ')
          ..write('bookSourceUrl: $bookSourceUrl, ')
          ..write('bookSourceName: $bookSourceName, ')
          ..write('bookSourceGroup: $bookSourceGroup, ')
          ..write('bookSourceType: $bookSourceType, ')
          ..write('enabled: $enabled, ')
          ..write('enabledExplore: $enabledExplore, ')
          ..write('customOrder: $customOrder, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('respondTime: $respondTime, ')
          ..write('weight: $weight, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookSourceUrl,
    bookSourceName,
    bookSourceGroup,
    bookSourceType,
    enabled,
    enabledExplore,
    customOrder,
    lastUpdateTime,
    respondTime,
    weight,
    raw,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookSource &&
          other.id == this.id &&
          other.bookSourceUrl == this.bookSourceUrl &&
          other.bookSourceName == this.bookSourceName &&
          other.bookSourceGroup == this.bookSourceGroup &&
          other.bookSourceType == this.bookSourceType &&
          other.enabled == this.enabled &&
          other.enabledExplore == this.enabledExplore &&
          other.customOrder == this.customOrder &&
          other.lastUpdateTime == this.lastUpdateTime &&
          other.respondTime == this.respondTime &&
          other.weight == this.weight &&
          other.raw == this.raw);
}

class BookSourcesCompanion extends UpdateCompanion<BookSource> {
  final Value<int> id;
  final Value<String> bookSourceUrl;
  final Value<String> bookSourceName;
  final Value<String?> bookSourceGroup;
  final Value<int> bookSourceType;
  final Value<bool> enabled;
  final Value<bool> enabledExplore;
  final Value<int> customOrder;
  final Value<int> lastUpdateTime;
  final Value<int> respondTime;
  final Value<int> weight;
  final Value<String?> raw;
  const BookSourcesCompanion({
    this.id = const Value.absent(),
    this.bookSourceUrl = const Value.absent(),
    this.bookSourceName = const Value.absent(),
    this.bookSourceGroup = const Value.absent(),
    this.bookSourceType = const Value.absent(),
    this.enabled = const Value.absent(),
    this.enabledExplore = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.weight = const Value.absent(),
    this.raw = const Value.absent(),
  });
  BookSourcesCompanion.insert({
    this.id = const Value.absent(),
    required String bookSourceUrl,
    required String bookSourceName,
    this.bookSourceGroup = const Value.absent(),
    this.bookSourceType = const Value.absent(),
    this.enabled = const Value.absent(),
    this.enabledExplore = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.weight = const Value.absent(),
    this.raw = const Value.absent(),
  }) : bookSourceUrl = Value(bookSourceUrl),
       bookSourceName = Value(bookSourceName);
  static Insertable<BookSource> custom({
    Expression<int>? id,
    Expression<String>? bookSourceUrl,
    Expression<String>? bookSourceName,
    Expression<String>? bookSourceGroup,
    Expression<int>? bookSourceType,
    Expression<bool>? enabled,
    Expression<bool>? enabledExplore,
    Expression<int>? customOrder,
    Expression<int>? lastUpdateTime,
    Expression<int>? respondTime,
    Expression<int>? weight,
    Expression<String>? raw,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookSourceUrl != null) 'book_source_url': bookSourceUrl,
      if (bookSourceName != null) 'book_source_name': bookSourceName,
      if (bookSourceGroup != null) 'book_source_group': bookSourceGroup,
      if (bookSourceType != null) 'book_source_type': bookSourceType,
      if (enabled != null) 'enabled': enabled,
      if (enabledExplore != null) 'enabled_explore': enabledExplore,
      if (customOrder != null) 'custom_order': customOrder,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
      if (respondTime != null) 'respond_time': respondTime,
      if (weight != null) 'weight': weight,
      if (raw != null) 'raw': raw,
    });
  }

  BookSourcesCompanion copyWith({
    Value<int>? id,
    Value<String>? bookSourceUrl,
    Value<String>? bookSourceName,
    Value<String?>? bookSourceGroup,
    Value<int>? bookSourceType,
    Value<bool>? enabled,
    Value<bool>? enabledExplore,
    Value<int>? customOrder,
    Value<int>? lastUpdateTime,
    Value<int>? respondTime,
    Value<int>? weight,
    Value<String?>? raw,
  }) {
    return BookSourcesCompanion(
      id: id ?? this.id,
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
      bookSourceName: bookSourceName ?? this.bookSourceName,
      bookSourceGroup: bookSourceGroup ?? this.bookSourceGroup,
      bookSourceType: bookSourceType ?? this.bookSourceType,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore ?? this.enabledExplore,
      customOrder: customOrder ?? this.customOrder,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      respondTime: respondTime ?? this.respondTime,
      weight: weight ?? this.weight,
      raw: raw ?? this.raw,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookSourceUrl.present) {
      map['book_source_url'] = Variable<String>(bookSourceUrl.value);
    }
    if (bookSourceName.present) {
      map['book_source_name'] = Variable<String>(bookSourceName.value);
    }
    if (bookSourceGroup.present) {
      map['book_source_group'] = Variable<String>(bookSourceGroup.value);
    }
    if (bookSourceType.present) {
      map['book_source_type'] = Variable<int>(bookSourceType.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (enabledExplore.present) {
      map['enabled_explore'] = Variable<bool>(enabledExplore.value);
    }
    if (customOrder.present) {
      map['custom_order'] = Variable<int>(customOrder.value);
    }
    if (lastUpdateTime.present) {
      map['last_update_time'] = Variable<int>(lastUpdateTime.value);
    }
    if (respondTime.present) {
      map['respond_time'] = Variable<int>(respondTime.value);
    }
    if (weight.present) {
      map['weight'] = Variable<int>(weight.value);
    }
    if (raw.present) {
      map['raw'] = Variable<String>(raw.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookSourcesCompanion(')
          ..write('id: $id, ')
          ..write('bookSourceUrl: $bookSourceUrl, ')
          ..write('bookSourceName: $bookSourceName, ')
          ..write('bookSourceGroup: $bookSourceGroup, ')
          ..write('bookSourceType: $bookSourceType, ')
          ..write('enabled: $enabled, ')
          ..write('enabledExplore: $enabledExplore, ')
          ..write('customOrder: $customOrder, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('respondTime: $respondTime, ')
          ..write('weight: $weight, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }
}

class $SearchBooksTable extends SearchBooks
    with TableInfo<$SearchBooksTable, SearchBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookUrlMeta = const VerificationMeta(
    'bookUrl',
  );
  @override
  late final GeneratedColumn<String> bookUrl = GeneratedColumn<String>(
    'book_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES book_sources (book_source_url) ON DELETE CASCADE',
  );
  static const VerificationMeta _originNameMeta = const VerificationMeta(
    'originName',
  );
  @override
  late final GeneratedColumn<String> originName = GeneratedColumn<String>(
    'origin_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<String> wordCount = GeneratedColumn<String>(
    'word_count',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestChapterTitleMeta =
      const VerificationMeta('latestChapterTitle');
  @override
  late final GeneratedColumn<String> latestChapterTitle =
      GeneratedColumn<String>(
        'latest_chapter_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tocUrlMeta = const VerificationMeta('tocUrl');
  @override
  late final GeneratedColumn<String> tocUrl = GeneratedColumn<String>(
    'toc_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _variableMeta = const VerificationMeta(
    'variable',
  );
  @override
  late final GeneratedColumn<String> variable = GeneratedColumn<String>(
    'variable',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originOrderMeta = const VerificationMeta(
    'originOrder',
  );
  @override
  late final GeneratedColumn<int> originOrder = GeneratedColumn<int>(
    'origin_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _chapterWordCountTextMeta =
      const VerificationMeta('chapterWordCountText');
  @override
  late final GeneratedColumn<String> chapterWordCountText =
      GeneratedColumn<String>(
        'chapter_word_count_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _chapterWordCountMeta = const VerificationMeta(
    'chapterWordCount',
  );
  @override
  late final GeneratedColumn<int> chapterWordCount = GeneratedColumn<int>(
    'chapter_word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _respondTimeMeta = const VerificationMeta(
    'respondTime',
  );
  @override
  late final GeneratedColumn<int> respondTime = GeneratedColumn<int>(
    'respond_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookUrl,
    origin,
    originName,
    name,
    author,
    type,
    kind,
    coverUrl,
    intro,
    wordCount,
    latestChapterTitle,
    tocUrl,
    time,
    variable,
    originOrder,
    chapterWordCountText,
    chapterWordCount,
    respondTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_url')) {
      context.handle(
        _bookUrlMeta,
        bookUrl.isAcceptableOrUnknown(data['book_url']!, _bookUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUrlMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('origin_name')) {
      context.handle(
        _originNameMeta,
        originName.isAcceptableOrUnknown(data['origin_name']!, _originNameMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('latest_chapter_title')) {
      context.handle(
        _latestChapterTitleMeta,
        latestChapterTitle.isAcceptableOrUnknown(
          data['latest_chapter_title']!,
          _latestChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('toc_url')) {
      context.handle(
        _tocUrlMeta,
        tocUrl.isAcceptableOrUnknown(data['toc_url']!, _tocUrlMeta),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    if (data.containsKey('variable')) {
      context.handle(
        _variableMeta,
        variable.isAcceptableOrUnknown(data['variable']!, _variableMeta),
      );
    }
    if (data.containsKey('origin_order')) {
      context.handle(
        _originOrderMeta,
        originOrder.isAcceptableOrUnknown(
          data['origin_order']!,
          _originOrderMeta,
        ),
      );
    }
    if (data.containsKey('chapter_word_count_text')) {
      context.handle(
        _chapterWordCountTextMeta,
        chapterWordCountText.isAcceptableOrUnknown(
          data['chapter_word_count_text']!,
          _chapterWordCountTextMeta,
        ),
      );
    }
    if (data.containsKey('chapter_word_count')) {
      context.handle(
        _chapterWordCountMeta,
        chapterWordCount.isAcceptableOrUnknown(
          data['chapter_word_count']!,
          _chapterWordCountMeta,
        ),
      );
    }
    if (data.containsKey('respond_time')) {
      context.handle(
        _respondTimeMeta,
        respondTime.isAcceptableOrUnknown(
          data['respond_time']!,
          _respondTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookUrl, origin};
  @override
  SearchBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchBook(
      bookUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_url'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      originName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_name'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      ),
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_count'],
      ),
      latestChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_chapter_title'],
      ),
      tocUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toc_url'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
      variable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variable'],
      ),
      originOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}origin_order'],
      )!,
      chapterWordCountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_word_count_text'],
      ),
      chapterWordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_word_count'],
      )!,
      respondTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}respond_time'],
      )!,
    );
  }

  @override
  $SearchBooksTable createAlias(String alias) {
    return $SearchBooksTable(attachedDatabase, alias);
  }
}

class SearchBook extends DataClass implements Insertable<SearchBook> {
  final String bookUrl;
  final String origin;
  final String originName;
  final String name;
  final String author;
  final int type;
  final String? kind;
  final String? coverUrl;
  final String? intro;
  final String? wordCount;
  final String? latestChapterTitle;
  final String tocUrl;
  final int time;
  final String? variable;
  final int originOrder;
  final String? chapterWordCountText;
  final int chapterWordCount;
  final int respondTime;
  const SearchBook({
    required this.bookUrl,
    required this.origin,
    required this.originName,
    required this.name,
    required this.author,
    required this.type,
    this.kind,
    this.coverUrl,
    this.intro,
    this.wordCount,
    this.latestChapterTitle,
    required this.tocUrl,
    required this.time,
    this.variable,
    required this.originOrder,
    this.chapterWordCountText,
    required this.chapterWordCount,
    required this.respondTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_url'] = Variable<String>(bookUrl);
    map['origin'] = Variable<String>(origin);
    map['origin_name'] = Variable<String>(originName);
    map['name'] = Variable<String>(name);
    map['author'] = Variable<String>(author);
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    if (!nullToAbsent || wordCount != null) {
      map['word_count'] = Variable<String>(wordCount);
    }
    if (!nullToAbsent || latestChapterTitle != null) {
      map['latest_chapter_title'] = Variable<String>(latestChapterTitle);
    }
    map['toc_url'] = Variable<String>(tocUrl);
    map['time'] = Variable<int>(time);
    if (!nullToAbsent || variable != null) {
      map['variable'] = Variable<String>(variable);
    }
    map['origin_order'] = Variable<int>(originOrder);
    if (!nullToAbsent || chapterWordCountText != null) {
      map['chapter_word_count_text'] = Variable<String>(chapterWordCountText);
    }
    map['chapter_word_count'] = Variable<int>(chapterWordCount);
    map['respond_time'] = Variable<int>(respondTime);
    return map;
  }

  SearchBooksCompanion toCompanion(bool nullToAbsent) {
    return SearchBooksCompanion(
      bookUrl: Value(bookUrl),
      origin: Value(origin),
      originName: Value(originName),
      name: Value(name),
      author: Value(author),
      type: Value(type),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      intro: intro == null && nullToAbsent
          ? const Value.absent()
          : Value(intro),
      wordCount: wordCount == null && nullToAbsent
          ? const Value.absent()
          : Value(wordCount),
      latestChapterTitle: latestChapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(latestChapterTitle),
      tocUrl: Value(tocUrl),
      time: Value(time),
      variable: variable == null && nullToAbsent
          ? const Value.absent()
          : Value(variable),
      originOrder: Value(originOrder),
      chapterWordCountText: chapterWordCountText == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterWordCountText),
      chapterWordCount: Value(chapterWordCount),
      respondTime: Value(respondTime),
    );
  }

  factory SearchBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchBook(
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      origin: serializer.fromJson<String>(json['origin']),
      originName: serializer.fromJson<String>(json['originName']),
      name: serializer.fromJson<String>(json['name']),
      author: serializer.fromJson<String>(json['author']),
      type: serializer.fromJson<int>(json['type']),
      kind: serializer.fromJson<String?>(json['kind']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      intro: serializer.fromJson<String?>(json['intro']),
      wordCount: serializer.fromJson<String?>(json['wordCount']),
      latestChapterTitle: serializer.fromJson<String?>(
        json['latestChapterTitle'],
      ),
      tocUrl: serializer.fromJson<String>(json['tocUrl']),
      time: serializer.fromJson<int>(json['time']),
      variable: serializer.fromJson<String?>(json['variable']),
      originOrder: serializer.fromJson<int>(json['originOrder']),
      chapterWordCountText: serializer.fromJson<String?>(
        json['chapterWordCountText'],
      ),
      chapterWordCount: serializer.fromJson<int>(json['chapterWordCount']),
      respondTime: serializer.fromJson<int>(json['respondTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookUrl': serializer.toJson<String>(bookUrl),
      'origin': serializer.toJson<String>(origin),
      'originName': serializer.toJson<String>(originName),
      'name': serializer.toJson<String>(name),
      'author': serializer.toJson<String>(author),
      'type': serializer.toJson<int>(type),
      'kind': serializer.toJson<String?>(kind),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'intro': serializer.toJson<String?>(intro),
      'wordCount': serializer.toJson<String?>(wordCount),
      'latestChapterTitle': serializer.toJson<String?>(latestChapterTitle),
      'tocUrl': serializer.toJson<String>(tocUrl),
      'time': serializer.toJson<int>(time),
      'variable': serializer.toJson<String?>(variable),
      'originOrder': serializer.toJson<int>(originOrder),
      'chapterWordCountText': serializer.toJson<String?>(chapterWordCountText),
      'chapterWordCount': serializer.toJson<int>(chapterWordCount),
      'respondTime': serializer.toJson<int>(respondTime),
    };
  }

  SearchBook copyWith({
    String? bookUrl,
    String? origin,
    String? originName,
    String? name,
    String? author,
    int? type,
    Value<String?> kind = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> intro = const Value.absent(),
    Value<String?> wordCount = const Value.absent(),
    Value<String?> latestChapterTitle = const Value.absent(),
    String? tocUrl,
    int? time,
    Value<String?> variable = const Value.absent(),
    int? originOrder,
    Value<String?> chapterWordCountText = const Value.absent(),
    int? chapterWordCount,
    int? respondTime,
  }) => SearchBook(
    bookUrl: bookUrl ?? this.bookUrl,
    origin: origin ?? this.origin,
    originName: originName ?? this.originName,
    name: name ?? this.name,
    author: author ?? this.author,
    type: type ?? this.type,
    kind: kind.present ? kind.value : this.kind,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    intro: intro.present ? intro.value : this.intro,
    wordCount: wordCount.present ? wordCount.value : this.wordCount,
    latestChapterTitle: latestChapterTitle.present
        ? latestChapterTitle.value
        : this.latestChapterTitle,
    tocUrl: tocUrl ?? this.tocUrl,
    time: time ?? this.time,
    variable: variable.present ? variable.value : this.variable,
    originOrder: originOrder ?? this.originOrder,
    chapterWordCountText: chapterWordCountText.present
        ? chapterWordCountText.value
        : this.chapterWordCountText,
    chapterWordCount: chapterWordCount ?? this.chapterWordCount,
    respondTime: respondTime ?? this.respondTime,
  );
  SearchBook copyWithCompanion(SearchBooksCompanion data) {
    return SearchBook(
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      origin: data.origin.present ? data.origin.value : this.origin,
      originName: data.originName.present
          ? data.originName.value
          : this.originName,
      name: data.name.present ? data.name.value : this.name,
      author: data.author.present ? data.author.value : this.author,
      type: data.type.present ? data.type.value : this.type,
      kind: data.kind.present ? data.kind.value : this.kind,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      intro: data.intro.present ? data.intro.value : this.intro,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      latestChapterTitle: data.latestChapterTitle.present
          ? data.latestChapterTitle.value
          : this.latestChapterTitle,
      tocUrl: data.tocUrl.present ? data.tocUrl.value : this.tocUrl,
      time: data.time.present ? data.time.value : this.time,
      variable: data.variable.present ? data.variable.value : this.variable,
      originOrder: data.originOrder.present
          ? data.originOrder.value
          : this.originOrder,
      chapterWordCountText: data.chapterWordCountText.present
          ? data.chapterWordCountText.value
          : this.chapterWordCountText,
      chapterWordCount: data.chapterWordCount.present
          ? data.chapterWordCount.value
          : this.chapterWordCount,
      respondTime: data.respondTime.present
          ? data.respondTime.value
          : this.respondTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchBook(')
          ..write('bookUrl: $bookUrl, ')
          ..write('origin: $origin, ')
          ..write('originName: $originName, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('type: $type, ')
          ..write('kind: $kind, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('wordCount: $wordCount, ')
          ..write('latestChapterTitle: $latestChapterTitle, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('time: $time, ')
          ..write('variable: $variable, ')
          ..write('originOrder: $originOrder, ')
          ..write('chapterWordCountText: $chapterWordCountText, ')
          ..write('chapterWordCount: $chapterWordCount, ')
          ..write('respondTime: $respondTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookUrl,
    origin,
    originName,
    name,
    author,
    type,
    kind,
    coverUrl,
    intro,
    wordCount,
    latestChapterTitle,
    tocUrl,
    time,
    variable,
    originOrder,
    chapterWordCountText,
    chapterWordCount,
    respondTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchBook &&
          other.bookUrl == this.bookUrl &&
          other.origin == this.origin &&
          other.originName == this.originName &&
          other.name == this.name &&
          other.author == this.author &&
          other.type == this.type &&
          other.kind == this.kind &&
          other.coverUrl == this.coverUrl &&
          other.intro == this.intro &&
          other.wordCount == this.wordCount &&
          other.latestChapterTitle == this.latestChapterTitle &&
          other.tocUrl == this.tocUrl &&
          other.time == this.time &&
          other.variable == this.variable &&
          other.originOrder == this.originOrder &&
          other.chapterWordCountText == this.chapterWordCountText &&
          other.chapterWordCount == this.chapterWordCount &&
          other.respondTime == this.respondTime);
}

class SearchBooksCompanion extends UpdateCompanion<SearchBook> {
  final Value<String> bookUrl;
  final Value<String> origin;
  final Value<String> originName;
  final Value<String> name;
  final Value<String> author;
  final Value<int> type;
  final Value<String?> kind;
  final Value<String?> coverUrl;
  final Value<String?> intro;
  final Value<String?> wordCount;
  final Value<String?> latestChapterTitle;
  final Value<String> tocUrl;
  final Value<int> time;
  final Value<String?> variable;
  final Value<int> originOrder;
  final Value<String?> chapterWordCountText;
  final Value<int> chapterWordCount;
  final Value<int> respondTime;
  final Value<int> rowid;
  const SearchBooksCompanion({
    this.bookUrl = const Value.absent(),
    this.origin = const Value.absent(),
    this.originName = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.type = const Value.absent(),
    this.kind = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.latestChapterTitle = const Value.absent(),
    this.tocUrl = const Value.absent(),
    this.time = const Value.absent(),
    this.variable = const Value.absent(),
    this.originOrder = const Value.absent(),
    this.chapterWordCountText = const Value.absent(),
    this.chapterWordCount = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchBooksCompanion.insert({
    required String bookUrl,
    required String origin,
    this.originName = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.type = const Value.absent(),
    this.kind = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.latestChapterTitle = const Value.absent(),
    this.tocUrl = const Value.absent(),
    this.time = const Value.absent(),
    this.variable = const Value.absent(),
    this.originOrder = const Value.absent(),
    this.chapterWordCountText = const Value.absent(),
    this.chapterWordCount = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookUrl = Value(bookUrl),
       origin = Value(origin);
  static Insertable<SearchBook> custom({
    Expression<String>? bookUrl,
    Expression<String>? origin,
    Expression<String>? originName,
    Expression<String>? name,
    Expression<String>? author,
    Expression<int>? type,
    Expression<String>? kind,
    Expression<String>? coverUrl,
    Expression<String>? intro,
    Expression<String>? wordCount,
    Expression<String>? latestChapterTitle,
    Expression<String>? tocUrl,
    Expression<int>? time,
    Expression<String>? variable,
    Expression<int>? originOrder,
    Expression<String>? chapterWordCountText,
    Expression<int>? chapterWordCount,
    Expression<int>? respondTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookUrl != null) 'book_url': bookUrl,
      if (origin != null) 'origin': origin,
      if (originName != null) 'origin_name': originName,
      if (name != null) 'name': name,
      if (author != null) 'author': author,
      if (type != null) 'type': type,
      if (kind != null) 'kind': kind,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (intro != null) 'intro': intro,
      if (wordCount != null) 'word_count': wordCount,
      if (latestChapterTitle != null)
        'latest_chapter_title': latestChapterTitle,
      if (tocUrl != null) 'toc_url': tocUrl,
      if (time != null) 'time': time,
      if (variable != null) 'variable': variable,
      if (originOrder != null) 'origin_order': originOrder,
      if (chapterWordCountText != null)
        'chapter_word_count_text': chapterWordCountText,
      if (chapterWordCount != null) 'chapter_word_count': chapterWordCount,
      if (respondTime != null) 'respond_time': respondTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchBooksCompanion copyWith({
    Value<String>? bookUrl,
    Value<String>? origin,
    Value<String>? originName,
    Value<String>? name,
    Value<String>? author,
    Value<int>? type,
    Value<String?>? kind,
    Value<String?>? coverUrl,
    Value<String?>? intro,
    Value<String?>? wordCount,
    Value<String?>? latestChapterTitle,
    Value<String>? tocUrl,
    Value<int>? time,
    Value<String?>? variable,
    Value<int>? originOrder,
    Value<String?>? chapterWordCountText,
    Value<int>? chapterWordCount,
    Value<int>? respondTime,
    Value<int>? rowid,
  }) {
    return SearchBooksCompanion(
      bookUrl: bookUrl ?? this.bookUrl,
      origin: origin ?? this.origin,
      originName: originName ?? this.originName,
      name: name ?? this.name,
      author: author ?? this.author,
      type: type ?? this.type,
      kind: kind ?? this.kind,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      wordCount: wordCount ?? this.wordCount,
      latestChapterTitle: latestChapterTitle ?? this.latestChapterTitle,
      tocUrl: tocUrl ?? this.tocUrl,
      time: time ?? this.time,
      variable: variable ?? this.variable,
      originOrder: originOrder ?? this.originOrder,
      chapterWordCountText: chapterWordCountText ?? this.chapterWordCountText,
      chapterWordCount: chapterWordCount ?? this.chapterWordCount,
      respondTime: respondTime ?? this.respondTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookUrl.present) {
      map['book_url'] = Variable<String>(bookUrl.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (originName.present) {
      map['origin_name'] = Variable<String>(originName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<String>(wordCount.value);
    }
    if (latestChapterTitle.present) {
      map['latest_chapter_title'] = Variable<String>(latestChapterTitle.value);
    }
    if (tocUrl.present) {
      map['toc_url'] = Variable<String>(tocUrl.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (variable.present) {
      map['variable'] = Variable<String>(variable.value);
    }
    if (originOrder.present) {
      map['origin_order'] = Variable<int>(originOrder.value);
    }
    if (chapterWordCountText.present) {
      map['chapter_word_count_text'] = Variable<String>(
        chapterWordCountText.value,
      );
    }
    if (chapterWordCount.present) {
      map['chapter_word_count'] = Variable<int>(chapterWordCount.value);
    }
    if (respondTime.present) {
      map['respond_time'] = Variable<int>(respondTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchBooksCompanion(')
          ..write('bookUrl: $bookUrl, ')
          ..write('origin: $origin, ')
          ..write('originName: $originName, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('type: $type, ')
          ..write('kind: $kind, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('wordCount: $wordCount, ')
          ..write('latestChapterTitle: $latestChapterTitle, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('time: $time, ')
          ..write('variable: $variable, ')
          ..write('originOrder: $originOrder, ')
          ..write('chapterWordCountText: $chapterWordCountText, ')
          ..write('chapterWordCount: $chapterWordCount, ')
          ..write('respondTime: $respondTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReplaceRulesTable extends ReplaceRules
    with TableInfo<$ReplaceRulesTable, ReplaceRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReplaceRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replacementMeta = const VerificationMeta(
    'replacement',
  );
  @override
  late final GeneratedColumn<String> replacement = GeneratedColumn<String>(
    'replacement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopeTitleMeta = const VerificationMeta(
    'scopeTitle',
  );
  @override
  late final GeneratedColumn<bool> scopeTitle = GeneratedColumn<bool>(
    'scope_title',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("scope_title" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _scopeContentMeta = const VerificationMeta(
    'scopeContent',
  );
  @override
  late final GeneratedColumn<bool> scopeContent = GeneratedColumn<bool>(
    'scope_content',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("scope_content" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _excludeScopeMeta = const VerificationMeta(
    'excludeScope',
  );
  @override
  late final GeneratedColumn<String> excludeScope = GeneratedColumn<String>(
    'exclude_scope',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isRegexMeta = const VerificationMeta(
    'isRegex',
  );
  @override
  late final GeneratedColumn<bool> isRegex = GeneratedColumn<bool>(
    'is_regex',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_regex" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _timeoutMillisecondMeta =
      const VerificationMeta('timeoutMillisecond');
  @override
  late final GeneratedColumn<int> timeoutMillisecond = GeneratedColumn<int>(
    'timeout_millisecond',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3000),
  );
  static const VerificationMeta _orderValueMeta = const VerificationMeta(
    'orderValue',
  );
  @override
  late final GeneratedColumn<int> orderValue = GeneratedColumn<int>(
    'order_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    groupName,
    pattern,
    replacement,
    scope,
    scopeTitle,
    scopeContent,
    excludeScope,
    enabled,
    isRegex,
    timeoutMillisecond,
    orderValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'replace_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReplaceRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('replacement')) {
      context.handle(
        _replacementMeta,
        replacement.isAcceptableOrUnknown(
          data['replacement']!,
          _replacementMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_replacementMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('scope_title')) {
      context.handle(
        _scopeTitleMeta,
        scopeTitle.isAcceptableOrUnknown(data['scope_title']!, _scopeTitleMeta),
      );
    }
    if (data.containsKey('scope_content')) {
      context.handle(
        _scopeContentMeta,
        scopeContent.isAcceptableOrUnknown(
          data['scope_content']!,
          _scopeContentMeta,
        ),
      );
    }
    if (data.containsKey('exclude_scope')) {
      context.handle(
        _excludeScopeMeta,
        excludeScope.isAcceptableOrUnknown(
          data['exclude_scope']!,
          _excludeScopeMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('is_regex')) {
      context.handle(
        _isRegexMeta,
        isRegex.isAcceptableOrUnknown(data['is_regex']!, _isRegexMeta),
      );
    }
    if (data.containsKey('timeout_millisecond')) {
      context.handle(
        _timeoutMillisecondMeta,
        timeoutMillisecond.isAcceptableOrUnknown(
          data['timeout_millisecond']!,
          _timeoutMillisecondMeta,
        ),
      );
    }
    if (data.containsKey('order_value')) {
      context.handle(
        _orderValueMeta,
        orderValue.isAcceptableOrUnknown(data['order_value']!, _orderValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReplaceRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReplaceRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      replacement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      ),
      scopeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}scope_title'],
      )!,
      scopeContent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}scope_content'],
      )!,
      excludeScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exclude_scope'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      isRegex: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_regex'],
      )!,
      timeoutMillisecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timeout_millisecond'],
      )!,
      orderValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_value'],
      )!,
    );
  }

  @override
  $ReplaceRulesTable createAlias(String alias) {
    return $ReplaceRulesTable(attachedDatabase, alias);
  }
}

class ReplaceRule extends DataClass implements Insertable<ReplaceRule> {
  final int id;
  final String name;
  final String? groupName;
  final String pattern;
  final String replacement;
  final String? scope;
  final bool scopeTitle;
  final bool scopeContent;
  final String? excludeScope;
  final bool enabled;
  final bool isRegex;
  final int timeoutMillisecond;
  final int orderValue;
  const ReplaceRule({
    required this.id,
    required this.name,
    this.groupName,
    required this.pattern,
    required this.replacement,
    this.scope,
    required this.scopeTitle,
    required this.scopeContent,
    this.excludeScope,
    required this.enabled,
    required this.isRegex,
    required this.timeoutMillisecond,
    required this.orderValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    map['pattern'] = Variable<String>(pattern);
    map['replacement'] = Variable<String>(replacement);
    if (!nullToAbsent || scope != null) {
      map['scope'] = Variable<String>(scope);
    }
    map['scope_title'] = Variable<bool>(scopeTitle);
    map['scope_content'] = Variable<bool>(scopeContent);
    if (!nullToAbsent || excludeScope != null) {
      map['exclude_scope'] = Variable<String>(excludeScope);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['is_regex'] = Variable<bool>(isRegex);
    map['timeout_millisecond'] = Variable<int>(timeoutMillisecond);
    map['order_value'] = Variable<int>(orderValue);
    return map;
  }

  ReplaceRulesCompanion toCompanion(bool nullToAbsent) {
    return ReplaceRulesCompanion(
      id: Value(id),
      name: Value(name),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      pattern: Value(pattern),
      replacement: Value(replacement),
      scope: scope == null && nullToAbsent
          ? const Value.absent()
          : Value(scope),
      scopeTitle: Value(scopeTitle),
      scopeContent: Value(scopeContent),
      excludeScope: excludeScope == null && nullToAbsent
          ? const Value.absent()
          : Value(excludeScope),
      enabled: Value(enabled),
      isRegex: Value(isRegex),
      timeoutMillisecond: Value(timeoutMillisecond),
      orderValue: Value(orderValue),
    );
  }

  factory ReplaceRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReplaceRule(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      pattern: serializer.fromJson<String>(json['pattern']),
      replacement: serializer.fromJson<String>(json['replacement']),
      scope: serializer.fromJson<String?>(json['scope']),
      scopeTitle: serializer.fromJson<bool>(json['scopeTitle']),
      scopeContent: serializer.fromJson<bool>(json['scopeContent']),
      excludeScope: serializer.fromJson<String?>(json['excludeScope']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      isRegex: serializer.fromJson<bool>(json['isRegex']),
      timeoutMillisecond: serializer.fromJson<int>(json['timeoutMillisecond']),
      orderValue: serializer.fromJson<int>(json['orderValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'groupName': serializer.toJson<String?>(groupName),
      'pattern': serializer.toJson<String>(pattern),
      'replacement': serializer.toJson<String>(replacement),
      'scope': serializer.toJson<String?>(scope),
      'scopeTitle': serializer.toJson<bool>(scopeTitle),
      'scopeContent': serializer.toJson<bool>(scopeContent),
      'excludeScope': serializer.toJson<String?>(excludeScope),
      'enabled': serializer.toJson<bool>(enabled),
      'isRegex': serializer.toJson<bool>(isRegex),
      'timeoutMillisecond': serializer.toJson<int>(timeoutMillisecond),
      'orderValue': serializer.toJson<int>(orderValue),
    };
  }

  ReplaceRule copyWith({
    int? id,
    String? name,
    Value<String?> groupName = const Value.absent(),
    String? pattern,
    String? replacement,
    Value<String?> scope = const Value.absent(),
    bool? scopeTitle,
    bool? scopeContent,
    Value<String?> excludeScope = const Value.absent(),
    bool? enabled,
    bool? isRegex,
    int? timeoutMillisecond,
    int? orderValue,
  }) => ReplaceRule(
    id: id ?? this.id,
    name: name ?? this.name,
    groupName: groupName.present ? groupName.value : this.groupName,
    pattern: pattern ?? this.pattern,
    replacement: replacement ?? this.replacement,
    scope: scope.present ? scope.value : this.scope,
    scopeTitle: scopeTitle ?? this.scopeTitle,
    scopeContent: scopeContent ?? this.scopeContent,
    excludeScope: excludeScope.present ? excludeScope.value : this.excludeScope,
    enabled: enabled ?? this.enabled,
    isRegex: isRegex ?? this.isRegex,
    timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
    orderValue: orderValue ?? this.orderValue,
  );
  ReplaceRule copyWithCompanion(ReplaceRulesCompanion data) {
    return ReplaceRule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      replacement: data.replacement.present
          ? data.replacement.value
          : this.replacement,
      scope: data.scope.present ? data.scope.value : this.scope,
      scopeTitle: data.scopeTitle.present
          ? data.scopeTitle.value
          : this.scopeTitle,
      scopeContent: data.scopeContent.present
          ? data.scopeContent.value
          : this.scopeContent,
      excludeScope: data.excludeScope.present
          ? data.excludeScope.value
          : this.excludeScope,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      isRegex: data.isRegex.present ? data.isRegex.value : this.isRegex,
      timeoutMillisecond: data.timeoutMillisecond.present
          ? data.timeoutMillisecond.value
          : this.timeoutMillisecond,
      orderValue: data.orderValue.present
          ? data.orderValue.value
          : this.orderValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReplaceRule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('pattern: $pattern, ')
          ..write('replacement: $replacement, ')
          ..write('scope: $scope, ')
          ..write('scopeTitle: $scopeTitle, ')
          ..write('scopeContent: $scopeContent, ')
          ..write('excludeScope: $excludeScope, ')
          ..write('enabled: $enabled, ')
          ..write('isRegex: $isRegex, ')
          ..write('timeoutMillisecond: $timeoutMillisecond, ')
          ..write('orderValue: $orderValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    groupName,
    pattern,
    replacement,
    scope,
    scopeTitle,
    scopeContent,
    excludeScope,
    enabled,
    isRegex,
    timeoutMillisecond,
    orderValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReplaceRule &&
          other.id == this.id &&
          other.name == this.name &&
          other.groupName == this.groupName &&
          other.pattern == this.pattern &&
          other.replacement == this.replacement &&
          other.scope == this.scope &&
          other.scopeTitle == this.scopeTitle &&
          other.scopeContent == this.scopeContent &&
          other.excludeScope == this.excludeScope &&
          other.enabled == this.enabled &&
          other.isRegex == this.isRegex &&
          other.timeoutMillisecond == this.timeoutMillisecond &&
          other.orderValue == this.orderValue);
}

class ReplaceRulesCompanion extends UpdateCompanion<ReplaceRule> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> groupName;
  final Value<String> pattern;
  final Value<String> replacement;
  final Value<String?> scope;
  final Value<bool> scopeTitle;
  final Value<bool> scopeContent;
  final Value<String?> excludeScope;
  final Value<bool> enabled;
  final Value<bool> isRegex;
  final Value<int> timeoutMillisecond;
  final Value<int> orderValue;
  const ReplaceRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.groupName = const Value.absent(),
    this.pattern = const Value.absent(),
    this.replacement = const Value.absent(),
    this.scope = const Value.absent(),
    this.scopeTitle = const Value.absent(),
    this.scopeContent = const Value.absent(),
    this.excludeScope = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isRegex = const Value.absent(),
    this.timeoutMillisecond = const Value.absent(),
    this.orderValue = const Value.absent(),
  });
  ReplaceRulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.groupName = const Value.absent(),
    required String pattern,
    required String replacement,
    this.scope = const Value.absent(),
    this.scopeTitle = const Value.absent(),
    this.scopeContent = const Value.absent(),
    this.excludeScope = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isRegex = const Value.absent(),
    this.timeoutMillisecond = const Value.absent(),
    this.orderValue = const Value.absent(),
  }) : name = Value(name),
       pattern = Value(pattern),
       replacement = Value(replacement);
  static Insertable<ReplaceRule> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? groupName,
    Expression<String>? pattern,
    Expression<String>? replacement,
    Expression<String>? scope,
    Expression<bool>? scopeTitle,
    Expression<bool>? scopeContent,
    Expression<String>? excludeScope,
    Expression<bool>? enabled,
    Expression<bool>? isRegex,
    Expression<int>? timeoutMillisecond,
    Expression<int>? orderValue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (groupName != null) 'group_name': groupName,
      if (pattern != null) 'pattern': pattern,
      if (replacement != null) 'replacement': replacement,
      if (scope != null) 'scope': scope,
      if (scopeTitle != null) 'scope_title': scopeTitle,
      if (scopeContent != null) 'scope_content': scopeContent,
      if (excludeScope != null) 'exclude_scope': excludeScope,
      if (enabled != null) 'enabled': enabled,
      if (isRegex != null) 'is_regex': isRegex,
      if (timeoutMillisecond != null) 'timeout_millisecond': timeoutMillisecond,
      if (orderValue != null) 'order_value': orderValue,
    });
  }

  ReplaceRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? groupName,
    Value<String>? pattern,
    Value<String>? replacement,
    Value<String?>? scope,
    Value<bool>? scopeTitle,
    Value<bool>? scopeContent,
    Value<String?>? excludeScope,
    Value<bool>? enabled,
    Value<bool>? isRegex,
    Value<int>? timeoutMillisecond,
    Value<int>? orderValue,
  }) {
    return ReplaceRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      groupName: groupName ?? this.groupName,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      scope: scope ?? this.scope,
      scopeTitle: scopeTitle ?? this.scopeTitle,
      scopeContent: scopeContent ?? this.scopeContent,
      excludeScope: excludeScope ?? this.excludeScope,
      enabled: enabled ?? this.enabled,
      isRegex: isRegex ?? this.isRegex,
      timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
      orderValue: orderValue ?? this.orderValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (replacement.present) {
      map['replacement'] = Variable<String>(replacement.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (scopeTitle.present) {
      map['scope_title'] = Variable<bool>(scopeTitle.value);
    }
    if (scopeContent.present) {
      map['scope_content'] = Variable<bool>(scopeContent.value);
    }
    if (excludeScope.present) {
      map['exclude_scope'] = Variable<String>(excludeScope.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (isRegex.present) {
      map['is_regex'] = Variable<bool>(isRegex.value);
    }
    if (timeoutMillisecond.present) {
      map['timeout_millisecond'] = Variable<int>(timeoutMillisecond.value);
    }
    if (orderValue.present) {
      map['order_value'] = Variable<int>(orderValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReplaceRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('pattern: $pattern, ')
          ..write('replacement: $replacement, ')
          ..write('scope: $scope, ')
          ..write('scopeTitle: $scopeTitle, ')
          ..write('scopeContent: $scopeContent, ')
          ..write('excludeScope: $excludeScope, ')
          ..write('enabled: $enabled, ')
          ..write('isRegex: $isRegex, ')
          ..write('timeoutMillisecond: $timeoutMillisecond, ')
          ..write('orderValue: $orderValue')
          ..write(')'))
        .toString();
  }
}

class $BookChaptersTable extends BookChapters
    with TableInfo<$BookChaptersTable, BookChapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookUrlMeta = const VerificationMeta(
    'bookUrl',
  );
  @override
  late final GeneratedColumn<String> bookUrl = GeneratedColumn<String>(
    'book_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES books (book_url) ON DELETE CASCADE',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _indexMeta = const VerificationMeta('index');
  @override
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isVolumeMeta = const VerificationMeta(
    'isVolume',
  );
  @override
  late final GeneratedColumn<bool> isVolume = GeneratedColumn<bool>(
    'is_volume',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_volume" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isVipMeta = const VerificationMeta('isVip');
  @override
  late final GeneratedColumn<bool> isVip = GeneratedColumn<bool>(
    'is_vip',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_vip" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPayMeta = const VerificationMeta('isPay');
  @override
  late final GeneratedColumn<bool> isPay = GeneratedColumn<bool>(
    'is_pay',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pay" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<String> wordCount = GeneratedColumn<String>(
    'word_count',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<int> start = GeneratedColumn<int>(
    'start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<int> end = GeneratedColumn<int>(
    'end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startFragmentIdMeta = const VerificationMeta(
    'startFragmentId',
  );
  @override
  late final GeneratedColumn<String> startFragmentId = GeneratedColumn<String>(
    'start_fragment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endFragmentIdMeta = const VerificationMeta(
    'endFragmentId',
  );
  @override
  late final GeneratedColumn<String> endFragmentId = GeneratedColumn<String>(
    'end_fragment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variableMeta = const VerificationMeta(
    'variable',
  );
  @override
  late final GeneratedColumn<String> variable = GeneratedColumn<String>(
    'variable',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imgUrlMeta = const VerificationMeta('imgUrl');
  @override
  late final GeneratedColumn<String> imgUrl = GeneratedColumn<String>(
    'img_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resourceUrlMeta = const VerificationMeta(
    'resourceUrl',
  );
  @override
  late final GeneratedColumn<String> resourceUrl = GeneratedColumn<String>(
    'resource_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    url,
    bookUrl,
    title,
    index,
    baseUrl,
    isVolume,
    isVip,
    isPay,
    tag,
    wordCount,
    start,
    end,
    startFragmentId,
    endFragmentId,
    variable,
    imgUrl,
    resourceUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookChapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('book_url')) {
      context.handle(
        _bookUrlMeta,
        bookUrl.isAcceptableOrUnknown(data['book_url']!, _bookUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('index')) {
      context.handle(
        _indexMeta,
        index.isAcceptableOrUnknown(data['index']!, _indexMeta),
      );
    } else if (isInserting) {
      context.missing(_indexMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('is_volume')) {
      context.handle(
        _isVolumeMeta,
        isVolume.isAcceptableOrUnknown(data['is_volume']!, _isVolumeMeta),
      );
    }
    if (data.containsKey('is_vip')) {
      context.handle(
        _isVipMeta,
        isVip.isAcceptableOrUnknown(data['is_vip']!, _isVipMeta),
      );
    }
    if (data.containsKey('is_pay')) {
      context.handle(
        _isPayMeta,
        isPay.isAcceptableOrUnknown(data['is_pay']!, _isPayMeta),
      );
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    }
    if (data.containsKey('end')) {
      context.handle(
        _endMeta,
        end.isAcceptableOrUnknown(data['end']!, _endMeta),
      );
    }
    if (data.containsKey('start_fragment_id')) {
      context.handle(
        _startFragmentIdMeta,
        startFragmentId.isAcceptableOrUnknown(
          data['start_fragment_id']!,
          _startFragmentIdMeta,
        ),
      );
    }
    if (data.containsKey('end_fragment_id')) {
      context.handle(
        _endFragmentIdMeta,
        endFragmentId.isAcceptableOrUnknown(
          data['end_fragment_id']!,
          _endFragmentIdMeta,
        ),
      );
    }
    if (data.containsKey('variable')) {
      context.handle(
        _variableMeta,
        variable.isAcceptableOrUnknown(data['variable']!, _variableMeta),
      );
    }
    if (data.containsKey('img_url')) {
      context.handle(
        _imgUrlMeta,
        imgUrl.isAcceptableOrUnknown(data['img_url']!, _imgUrlMeta),
      );
    }
    if (data.containsKey('resource_url')) {
      context.handle(
        _resourceUrlMeta,
        resourceUrl.isAcceptableOrUnknown(
          data['resource_url']!,
          _resourceUrlMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {url, bookUrl};
  @override
  BookChapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookChapter(
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      bookUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      index: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      isVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_volume'],
      )!,
      isVip: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_vip'],
      )!,
      isPay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pay'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      ),
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_count'],
      ),
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start'],
      ),
      end: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end'],
      ),
      startFragmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_fragment_id'],
      ),
      endFragmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_fragment_id'],
      ),
      variable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variable'],
      ),
      imgUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}img_url'],
      ),
      resourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_url'],
      ),
    );
  }

  @override
  $BookChaptersTable createAlias(String alias) {
    return $BookChaptersTable(attachedDatabase, alias);
  }
}

class BookChapter extends DataClass implements Insertable<BookChapter> {
  final String url;
  final String bookUrl;
  final String title;
  final int index;
  final String baseUrl;
  final bool isVolume;
  final bool isVip;
  final bool isPay;
  final String? tag;
  final String? wordCount;
  final int? start;
  final int? end;
  final String? startFragmentId;
  final String? endFragmentId;
  final String? variable;
  final String? imgUrl;
  final String? resourceUrl;
  const BookChapter({
    required this.url,
    required this.bookUrl,
    required this.title,
    required this.index,
    required this.baseUrl,
    required this.isVolume,
    required this.isVip,
    required this.isPay,
    this.tag,
    this.wordCount,
    this.start,
    this.end,
    this.startFragmentId,
    this.endFragmentId,
    this.variable,
    this.imgUrl,
    this.resourceUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    map['book_url'] = Variable<String>(bookUrl);
    map['title'] = Variable<String>(title);
    map['index'] = Variable<int>(index);
    map['base_url'] = Variable<String>(baseUrl);
    map['is_volume'] = Variable<bool>(isVolume);
    map['is_vip'] = Variable<bool>(isVip);
    map['is_pay'] = Variable<bool>(isPay);
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<String>(tag);
    }
    if (!nullToAbsent || wordCount != null) {
      map['word_count'] = Variable<String>(wordCount);
    }
    if (!nullToAbsent || start != null) {
      map['start'] = Variable<int>(start);
    }
    if (!nullToAbsent || end != null) {
      map['end'] = Variable<int>(end);
    }
    if (!nullToAbsent || startFragmentId != null) {
      map['start_fragment_id'] = Variable<String>(startFragmentId);
    }
    if (!nullToAbsent || endFragmentId != null) {
      map['end_fragment_id'] = Variable<String>(endFragmentId);
    }
    if (!nullToAbsent || variable != null) {
      map['variable'] = Variable<String>(variable);
    }
    if (!nullToAbsent || imgUrl != null) {
      map['img_url'] = Variable<String>(imgUrl);
    }
    if (!nullToAbsent || resourceUrl != null) {
      map['resource_url'] = Variable<String>(resourceUrl);
    }
    return map;
  }

  BookChaptersCompanion toCompanion(bool nullToAbsent) {
    return BookChaptersCompanion(
      url: Value(url),
      bookUrl: Value(bookUrl),
      title: Value(title),
      index: Value(index),
      baseUrl: Value(baseUrl),
      isVolume: Value(isVolume),
      isVip: Value(isVip),
      isPay: Value(isPay),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      wordCount: wordCount == null && nullToAbsent
          ? const Value.absent()
          : Value(wordCount),
      start: start == null && nullToAbsent
          ? const Value.absent()
          : Value(start),
      end: end == null && nullToAbsent ? const Value.absent() : Value(end),
      startFragmentId: startFragmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(startFragmentId),
      endFragmentId: endFragmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(endFragmentId),
      variable: variable == null && nullToAbsent
          ? const Value.absent()
          : Value(variable),
      imgUrl: imgUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imgUrl),
      resourceUrl: resourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceUrl),
    );
  }

  factory BookChapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookChapter(
      url: serializer.fromJson<String>(json['url']),
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      title: serializer.fromJson<String>(json['title']),
      index: serializer.fromJson<int>(json['index']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      isVolume: serializer.fromJson<bool>(json['isVolume']),
      isVip: serializer.fromJson<bool>(json['isVip']),
      isPay: serializer.fromJson<bool>(json['isPay']),
      tag: serializer.fromJson<String?>(json['tag']),
      wordCount: serializer.fromJson<String?>(json['wordCount']),
      start: serializer.fromJson<int?>(json['start']),
      end: serializer.fromJson<int?>(json['end']),
      startFragmentId: serializer.fromJson<String?>(json['startFragmentId']),
      endFragmentId: serializer.fromJson<String?>(json['endFragmentId']),
      variable: serializer.fromJson<String?>(json['variable']),
      imgUrl: serializer.fromJson<String?>(json['imgUrl']),
      resourceUrl: serializer.fromJson<String?>(json['resourceUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'bookUrl': serializer.toJson<String>(bookUrl),
      'title': serializer.toJson<String>(title),
      'index': serializer.toJson<int>(index),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'isVolume': serializer.toJson<bool>(isVolume),
      'isVip': serializer.toJson<bool>(isVip),
      'isPay': serializer.toJson<bool>(isPay),
      'tag': serializer.toJson<String?>(tag),
      'wordCount': serializer.toJson<String?>(wordCount),
      'start': serializer.toJson<int?>(start),
      'end': serializer.toJson<int?>(end),
      'startFragmentId': serializer.toJson<String?>(startFragmentId),
      'endFragmentId': serializer.toJson<String?>(endFragmentId),
      'variable': serializer.toJson<String?>(variable),
      'imgUrl': serializer.toJson<String?>(imgUrl),
      'resourceUrl': serializer.toJson<String?>(resourceUrl),
    };
  }

  BookChapter copyWith({
    String? url,
    String? bookUrl,
    String? title,
    int? index,
    String? baseUrl,
    bool? isVolume,
    bool? isVip,
    bool? isPay,
    Value<String?> tag = const Value.absent(),
    Value<String?> wordCount = const Value.absent(),
    Value<int?> start = const Value.absent(),
    Value<int?> end = const Value.absent(),
    Value<String?> startFragmentId = const Value.absent(),
    Value<String?> endFragmentId = const Value.absent(),
    Value<String?> variable = const Value.absent(),
    Value<String?> imgUrl = const Value.absent(),
    Value<String?> resourceUrl = const Value.absent(),
  }) => BookChapter(
    url: url ?? this.url,
    bookUrl: bookUrl ?? this.bookUrl,
    title: title ?? this.title,
    index: index ?? this.index,
    baseUrl: baseUrl ?? this.baseUrl,
    isVolume: isVolume ?? this.isVolume,
    isVip: isVip ?? this.isVip,
    isPay: isPay ?? this.isPay,
    tag: tag.present ? tag.value : this.tag,
    wordCount: wordCount.present ? wordCount.value : this.wordCount,
    start: start.present ? start.value : this.start,
    end: end.present ? end.value : this.end,
    startFragmentId: startFragmentId.present
        ? startFragmentId.value
        : this.startFragmentId,
    endFragmentId: endFragmentId.present
        ? endFragmentId.value
        : this.endFragmentId,
    variable: variable.present ? variable.value : this.variable,
    imgUrl: imgUrl.present ? imgUrl.value : this.imgUrl,
    resourceUrl: resourceUrl.present ? resourceUrl.value : this.resourceUrl,
  );
  BookChapter copyWithCompanion(BookChaptersCompanion data) {
    return BookChapter(
      url: data.url.present ? data.url.value : this.url,
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      title: data.title.present ? data.title.value : this.title,
      index: data.index.present ? data.index.value : this.index,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      isVolume: data.isVolume.present ? data.isVolume.value : this.isVolume,
      isVip: data.isVip.present ? data.isVip.value : this.isVip,
      isPay: data.isPay.present ? data.isPay.value : this.isPay,
      tag: data.tag.present ? data.tag.value : this.tag,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
      startFragmentId: data.startFragmentId.present
          ? data.startFragmentId.value
          : this.startFragmentId,
      endFragmentId: data.endFragmentId.present
          ? data.endFragmentId.value
          : this.endFragmentId,
      variable: data.variable.present ? data.variable.value : this.variable,
      imgUrl: data.imgUrl.present ? data.imgUrl.value : this.imgUrl,
      resourceUrl: data.resourceUrl.present
          ? data.resourceUrl.value
          : this.resourceUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookChapter(')
          ..write('url: $url, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('title: $title, ')
          ..write('index: $index, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('isVolume: $isVolume, ')
          ..write('isVip: $isVip, ')
          ..write('isPay: $isPay, ')
          ..write('tag: $tag, ')
          ..write('wordCount: $wordCount, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('startFragmentId: $startFragmentId, ')
          ..write('endFragmentId: $endFragmentId, ')
          ..write('variable: $variable, ')
          ..write('imgUrl: $imgUrl, ')
          ..write('resourceUrl: $resourceUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    url,
    bookUrl,
    title,
    index,
    baseUrl,
    isVolume,
    isVip,
    isPay,
    tag,
    wordCount,
    start,
    end,
    startFragmentId,
    endFragmentId,
    variable,
    imgUrl,
    resourceUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookChapter &&
          other.url == this.url &&
          other.bookUrl == this.bookUrl &&
          other.title == this.title &&
          other.index == this.index &&
          other.baseUrl == this.baseUrl &&
          other.isVolume == this.isVolume &&
          other.isVip == this.isVip &&
          other.isPay == this.isPay &&
          other.tag == this.tag &&
          other.wordCount == this.wordCount &&
          other.start == this.start &&
          other.end == this.end &&
          other.startFragmentId == this.startFragmentId &&
          other.endFragmentId == this.endFragmentId &&
          other.variable == this.variable &&
          other.imgUrl == this.imgUrl &&
          other.resourceUrl == this.resourceUrl);
}

class BookChaptersCompanion extends UpdateCompanion<BookChapter> {
  final Value<String> url;
  final Value<String> bookUrl;
  final Value<String> title;
  final Value<int> index;
  final Value<String> baseUrl;
  final Value<bool> isVolume;
  final Value<bool> isVip;
  final Value<bool> isPay;
  final Value<String?> tag;
  final Value<String?> wordCount;
  final Value<int?> start;
  final Value<int?> end;
  final Value<String?> startFragmentId;
  final Value<String?> endFragmentId;
  final Value<String?> variable;
  final Value<String?> imgUrl;
  final Value<String?> resourceUrl;
  final Value<int> rowid;
  const BookChaptersCompanion({
    this.url = const Value.absent(),
    this.bookUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.index = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.isVolume = const Value.absent(),
    this.isVip = const Value.absent(),
    this.isPay = const Value.absent(),
    this.tag = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.startFragmentId = const Value.absent(),
    this.endFragmentId = const Value.absent(),
    this.variable = const Value.absent(),
    this.imgUrl = const Value.absent(),
    this.resourceUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookChaptersCompanion.insert({
    required String url,
    required String bookUrl,
    this.title = const Value.absent(),
    required int index,
    this.baseUrl = const Value.absent(),
    this.isVolume = const Value.absent(),
    this.isVip = const Value.absent(),
    this.isPay = const Value.absent(),
    this.tag = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.startFragmentId = const Value.absent(),
    this.endFragmentId = const Value.absent(),
    this.variable = const Value.absent(),
    this.imgUrl = const Value.absent(),
    this.resourceUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : url = Value(url),
       bookUrl = Value(bookUrl),
       index = Value(index);
  static Insertable<BookChapter> custom({
    Expression<String>? url,
    Expression<String>? bookUrl,
    Expression<String>? title,
    Expression<int>? index,
    Expression<String>? baseUrl,
    Expression<bool>? isVolume,
    Expression<bool>? isVip,
    Expression<bool>? isPay,
    Expression<String>? tag,
    Expression<String>? wordCount,
    Expression<int>? start,
    Expression<int>? end,
    Expression<String>? startFragmentId,
    Expression<String>? endFragmentId,
    Expression<String>? variable,
    Expression<String>? imgUrl,
    Expression<String>? resourceUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (bookUrl != null) 'book_url': bookUrl,
      if (title != null) 'title': title,
      if (index != null) 'index': index,
      if (baseUrl != null) 'base_url': baseUrl,
      if (isVolume != null) 'is_volume': isVolume,
      if (isVip != null) 'is_vip': isVip,
      if (isPay != null) 'is_pay': isPay,
      if (tag != null) 'tag': tag,
      if (wordCount != null) 'word_count': wordCount,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (startFragmentId != null) 'start_fragment_id': startFragmentId,
      if (endFragmentId != null) 'end_fragment_id': endFragmentId,
      if (variable != null) 'variable': variable,
      if (imgUrl != null) 'img_url': imgUrl,
      if (resourceUrl != null) 'resource_url': resourceUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookChaptersCompanion copyWith({
    Value<String>? url,
    Value<String>? bookUrl,
    Value<String>? title,
    Value<int>? index,
    Value<String>? baseUrl,
    Value<bool>? isVolume,
    Value<bool>? isVip,
    Value<bool>? isPay,
    Value<String?>? tag,
    Value<String?>? wordCount,
    Value<int?>? start,
    Value<int?>? end,
    Value<String?>? startFragmentId,
    Value<String?>? endFragmentId,
    Value<String?>? variable,
    Value<String?>? imgUrl,
    Value<String?>? resourceUrl,
    Value<int>? rowid,
  }) {
    return BookChaptersCompanion(
      url: url ?? this.url,
      bookUrl: bookUrl ?? this.bookUrl,
      title: title ?? this.title,
      index: index ?? this.index,
      baseUrl: baseUrl ?? this.baseUrl,
      isVolume: isVolume ?? this.isVolume,
      isVip: isVip ?? this.isVip,
      isPay: isPay ?? this.isPay,
      tag: tag ?? this.tag,
      wordCount: wordCount ?? this.wordCount,
      start: start ?? this.start,
      end: end ?? this.end,
      startFragmentId: startFragmentId ?? this.startFragmentId,
      endFragmentId: endFragmentId ?? this.endFragmentId,
      variable: variable ?? this.variable,
      imgUrl: imgUrl ?? this.imgUrl,
      resourceUrl: resourceUrl ?? this.resourceUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (bookUrl.present) {
      map['book_url'] = Variable<String>(bookUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (isVolume.present) {
      map['is_volume'] = Variable<bool>(isVolume.value);
    }
    if (isVip.present) {
      map['is_vip'] = Variable<bool>(isVip.value);
    }
    if (isPay.present) {
      map['is_pay'] = Variable<bool>(isPay.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<String>(wordCount.value);
    }
    if (start.present) {
      map['start'] = Variable<int>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<int>(end.value);
    }
    if (startFragmentId.present) {
      map['start_fragment_id'] = Variable<String>(startFragmentId.value);
    }
    if (endFragmentId.present) {
      map['end_fragment_id'] = Variable<String>(endFragmentId.value);
    }
    if (variable.present) {
      map['variable'] = Variable<String>(variable.value);
    }
    if (imgUrl.present) {
      map['img_url'] = Variable<String>(imgUrl.value);
    }
    if (resourceUrl.present) {
      map['resource_url'] = Variable<String>(resourceUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookChaptersCompanion(')
          ..write('url: $url, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('title: $title, ')
          ..write('index: $index, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('isVolume: $isVolume, ')
          ..write('isVip: $isVip, ')
          ..write('isPay: $isPay, ')
          ..write('tag: $tag, ')
          ..write('wordCount: $wordCount, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('startFragmentId: $startFragmentId, ')
          ..write('endFragmentId: $endFragmentId, ')
          ..write('variable: $variable, ')
          ..write('imgUrl: $imgUrl, ')
          ..write('resourceUrl: $resourceUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookNameMeta = const VerificationMeta(
    'bookName',
  );
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
    'book_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookAuthorMeta = const VerificationMeta(
    'bookAuthor',
  );
  @override
  late final GeneratedColumn<String> bookAuthor = GeneratedColumn<String>(
    'book_author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterPosMeta = const VerificationMeta(
    'chapterPos',
  );
  @override
  late final GeneratedColumn<int> chapterPos = GeneratedColumn<int>(
    'chapter_pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterNameMeta = const VerificationMeta(
    'chapterName',
  );
  @override
  late final GeneratedColumn<String> chapterName = GeneratedColumn<String>(
    'chapter_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookTextMeta = const VerificationMeta(
    'bookText',
  );
  @override
  late final GeneratedColumn<String> bookText = GeneratedColumn<String>(
    'book_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    time,
    bookName,
    bookAuthor,
    chapterIndex,
    chapterPos,
    chapterName,
    bookText,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bookNameMeta);
    }
    if (data.containsKey('book_author')) {
      context.handle(
        _bookAuthorMeta,
        bookAuthor.isAcceptableOrUnknown(data['book_author']!, _bookAuthorMeta),
      );
    } else if (isInserting) {
      context.missing(_bookAuthorMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('chapter_pos')) {
      context.handle(
        _chapterPosMeta,
        chapterPos.isAcceptableOrUnknown(data['chapter_pos']!, _chapterPosMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterPosMeta);
    }
    if (data.containsKey('chapter_name')) {
      context.handle(
        _chapterNameMeta,
        chapterName.isAcceptableOrUnknown(
          data['chapter_name']!,
          _chapterNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterNameMeta);
    }
    if (data.containsKey('book_text')) {
      context.handle(
        _bookTextMeta,
        bookText.isAcceptableOrUnknown(data['book_text']!, _bookTextMeta),
      );
    } else if (isInserting) {
      context.missing(_bookTextMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {time};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      )!,
      bookAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_author'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      chapterPos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_pos'],
      )!,
      chapterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_name'],
      )!,
      bookText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_text'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final int time;
  final String bookName;
  final String bookAuthor;
  final int chapterIndex;
  final int chapterPos;
  final String chapterName;
  final String bookText;
  final String content;
  const Bookmark({
    required this.time,
    required this.bookName,
    required this.bookAuthor,
    required this.chapterIndex,
    required this.chapterPos,
    required this.chapterName,
    required this.bookText,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['time'] = Variable<int>(time);
    map['book_name'] = Variable<String>(bookName);
    map['book_author'] = Variable<String>(bookAuthor);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['chapter_pos'] = Variable<int>(chapterPos);
    map['chapter_name'] = Variable<String>(chapterName);
    map['book_text'] = Variable<String>(bookText);
    map['content'] = Variable<String>(content);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      time: Value(time),
      bookName: Value(bookName),
      bookAuthor: Value(bookAuthor),
      chapterIndex: Value(chapterIndex),
      chapterPos: Value(chapterPos),
      chapterName: Value(chapterName),
      bookText: Value(bookText),
      content: Value(content),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      time: serializer.fromJson<int>(json['time']),
      bookName: serializer.fromJson<String>(json['bookName']),
      bookAuthor: serializer.fromJson<String>(json['bookAuthor']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterPos: serializer.fromJson<int>(json['chapterPos']),
      chapterName: serializer.fromJson<String>(json['chapterName']),
      bookText: serializer.fromJson<String>(json['bookText']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'time': serializer.toJson<int>(time),
      'bookName': serializer.toJson<String>(bookName),
      'bookAuthor': serializer.toJson<String>(bookAuthor),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterPos': serializer.toJson<int>(chapterPos),
      'chapterName': serializer.toJson<String>(chapterName),
      'bookText': serializer.toJson<String>(bookText),
      'content': serializer.toJson<String>(content),
    };
  }

  Bookmark copyWith({
    int? time,
    String? bookName,
    String? bookAuthor,
    int? chapterIndex,
    int? chapterPos,
    String? chapterName,
    String? bookText,
    String? content,
  }) => Bookmark(
    time: time ?? this.time,
    bookName: bookName ?? this.bookName,
    bookAuthor: bookAuthor ?? this.bookAuthor,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterPos: chapterPos ?? this.chapterPos,
    chapterName: chapterName ?? this.chapterName,
    bookText: bookText ?? this.bookText,
    content: content ?? this.content,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      time: data.time.present ? data.time.value : this.time,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      bookAuthor: data.bookAuthor.present
          ? data.bookAuthor.value
          : this.bookAuthor,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      chapterPos: data.chapterPos.present
          ? data.chapterPos.value
          : this.chapterPos,
      chapterName: data.chapterName.present
          ? data.chapterName.value
          : this.chapterName,
      bookText: data.bookText.present ? data.bookText.value : this.bookText,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('time: $time, ')
          ..write('bookName: $bookName, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterPos: $chapterPos, ')
          ..write('chapterName: $chapterName, ')
          ..write('bookText: $bookText, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    time,
    bookName,
    bookAuthor,
    chapterIndex,
    chapterPos,
    chapterName,
    bookText,
    content,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.time == this.time &&
          other.bookName == this.bookName &&
          other.bookAuthor == this.bookAuthor &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterPos == this.chapterPos &&
          other.chapterName == this.chapterName &&
          other.bookText == this.bookText &&
          other.content == this.content);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> time;
  final Value<String> bookName;
  final Value<String> bookAuthor;
  final Value<int> chapterIndex;
  final Value<int> chapterPos;
  final Value<String> chapterName;
  final Value<String> bookText;
  final Value<String> content;
  const BookmarksCompanion({
    this.time = const Value.absent(),
    this.bookName = const Value.absent(),
    this.bookAuthor = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterPos = const Value.absent(),
    this.chapterName = const Value.absent(),
    this.bookText = const Value.absent(),
    this.content = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.time = const Value.absent(),
    required String bookName,
    required String bookAuthor,
    required int chapterIndex,
    required int chapterPos,
    required String chapterName,
    required String bookText,
    required String content,
  }) : bookName = Value(bookName),
       bookAuthor = Value(bookAuthor),
       chapterIndex = Value(chapterIndex),
       chapterPos = Value(chapterPos),
       chapterName = Value(chapterName),
       bookText = Value(bookText),
       content = Value(content);
  static Insertable<Bookmark> custom({
    Expression<int>? time,
    Expression<String>? bookName,
    Expression<String>? bookAuthor,
    Expression<int>? chapterIndex,
    Expression<int>? chapterPos,
    Expression<String>? chapterName,
    Expression<String>? bookText,
    Expression<String>? content,
  }) {
    return RawValuesInsertable({
      if (time != null) 'time': time,
      if (bookName != null) 'book_name': bookName,
      if (bookAuthor != null) 'book_author': bookAuthor,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterPos != null) 'chapter_pos': chapterPos,
      if (chapterName != null) 'chapter_name': chapterName,
      if (bookText != null) 'book_text': bookText,
      if (content != null) 'content': content,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? time,
    Value<String>? bookName,
    Value<String>? bookAuthor,
    Value<int>? chapterIndex,
    Value<int>? chapterPos,
    Value<String>? chapterName,
    Value<String>? bookText,
    Value<String>? content,
  }) {
    return BookmarksCompanion(
      time: time ?? this.time,
      bookName: bookName ?? this.bookName,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterPos: chapterPos ?? this.chapterPos,
      chapterName: chapterName ?? this.chapterName,
      bookText: bookText ?? this.bookText,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (bookAuthor.present) {
      map['book_author'] = Variable<String>(bookAuthor.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterPos.present) {
      map['chapter_pos'] = Variable<int>(chapterPos.value);
    }
    if (chapterName.present) {
      map['chapter_name'] = Variable<String>(chapterName.value);
    }
    if (bookText.present) {
      map['book_text'] = Variable<String>(bookText.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('time: $time, ')
          ..write('bookName: $bookName, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterPos: $chapterPos, ')
          ..write('chapterName: $chapterName, ')
          ..write('bookText: $bookText, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }
}

class $ReadRecordsTable extends ReadRecords
    with TableInfo<$ReadRecordsTable, ReadRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookNameMeta = const VerificationMeta(
    'bookName',
  );
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
    'book_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readTimeMeta = const VerificationMeta(
    'readTime',
  );
  @override
  late final GeneratedColumn<int> readTime = GeneratedColumn<int>(
    'read_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReadMeta = const VerificationMeta(
    'lastRead',
  );
  @override
  late final GeneratedColumn<int> lastRead = GeneratedColumn<int>(
    'last_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    bookName,
    readTime,
    lastRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'read_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bookNameMeta);
    }
    if (data.containsKey('read_time')) {
      context.handle(
        _readTimeMeta,
        readTime.isAcceptableOrUnknown(data['read_time']!, _readTimeMeta),
      );
    }
    if (data.containsKey('last_read')) {
      context.handle(
        _lastReadMeta,
        lastRead.isAcceptableOrUnknown(data['last_read']!, _lastReadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId, bookName};
  @override
  ReadRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadRecord(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      )!,
      readTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_time'],
      )!,
      lastRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read'],
      )!,
    );
  }

  @override
  $ReadRecordsTable createAlias(String alias) {
    return $ReadRecordsTable(attachedDatabase, alias);
  }
}

class ReadRecord extends DataClass implements Insertable<ReadRecord> {
  final String deviceId;
  final String bookName;
  final int readTime;
  final int lastRead;
  const ReadRecord({
    required this.deviceId,
    required this.bookName,
    required this.readTime,
    required this.lastRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['book_name'] = Variable<String>(bookName);
    map['read_time'] = Variable<int>(readTime);
    map['last_read'] = Variable<int>(lastRead);
    return map;
  }

  ReadRecordsCompanion toCompanion(bool nullToAbsent) {
    return ReadRecordsCompanion(
      deviceId: Value(deviceId),
      bookName: Value(bookName),
      readTime: Value(readTime),
      lastRead: Value(lastRead),
    );
  }

  factory ReadRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadRecord(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      bookName: serializer.fromJson<String>(json['bookName']),
      readTime: serializer.fromJson<int>(json['readTime']),
      lastRead: serializer.fromJson<int>(json['lastRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'bookName': serializer.toJson<String>(bookName),
      'readTime': serializer.toJson<int>(readTime),
      'lastRead': serializer.toJson<int>(lastRead),
    };
  }

  ReadRecord copyWith({
    String? deviceId,
    String? bookName,
    int? readTime,
    int? lastRead,
  }) => ReadRecord(
    deviceId: deviceId ?? this.deviceId,
    bookName: bookName ?? this.bookName,
    readTime: readTime ?? this.readTime,
    lastRead: lastRead ?? this.lastRead,
  );
  ReadRecord copyWithCompanion(ReadRecordsCompanion data) {
    return ReadRecord(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      readTime: data.readTime.present ? data.readTime.value : this.readTime,
      lastRead: data.lastRead.present ? data.lastRead.value : this.lastRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadRecord(')
          ..write('deviceId: $deviceId, ')
          ..write('bookName: $bookName, ')
          ..write('readTime: $readTime, ')
          ..write('lastRead: $lastRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, bookName, readTime, lastRead);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadRecord &&
          other.deviceId == this.deviceId &&
          other.bookName == this.bookName &&
          other.readTime == this.readTime &&
          other.lastRead == this.lastRead);
}

class ReadRecordsCompanion extends UpdateCompanion<ReadRecord> {
  final Value<String> deviceId;
  final Value<String> bookName;
  final Value<int> readTime;
  final Value<int> lastRead;
  final Value<int> rowid;
  const ReadRecordsCompanion({
    this.deviceId = const Value.absent(),
    this.bookName = const Value.absent(),
    this.readTime = const Value.absent(),
    this.lastRead = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadRecordsCompanion.insert({
    required String deviceId,
    required String bookName,
    this.readTime = const Value.absent(),
    this.lastRead = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       bookName = Value(bookName);
  static Insertable<ReadRecord> custom({
    Expression<String>? deviceId,
    Expression<String>? bookName,
    Expression<int>? readTime,
    Expression<int>? lastRead,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (bookName != null) 'book_name': bookName,
      if (readTime != null) 'read_time': readTime,
      if (lastRead != null) 'last_read': lastRead,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadRecordsCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? bookName,
    Value<int>? readTime,
    Value<int>? lastRead,
    Value<int>? rowid,
  }) {
    return ReadRecordsCompanion(
      deviceId: deviceId ?? this.deviceId,
      bookName: bookName ?? this.bookName,
      readTime: readTime ?? this.readTime,
      lastRead: lastRead ?? this.lastRead,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (readTime.present) {
      map['read_time'] = Variable<int>(readTime.value);
    }
    if (lastRead.present) {
      map['last_read'] = Variable<int>(lastRead.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadRecordsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('bookName: $bookName, ')
          ..write('readTime: $readTime, ')
          ..write('lastRead: $lastRead, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookGroupsTable extends BookGroups
    with TableInfo<$BookGroupsTable, BookGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enableRefreshMeta = const VerificationMeta(
    'enableRefresh',
  );
  @override
  late final GeneratedColumn<bool> enableRefresh = GeneratedColumn<bool>(
    'enable_refresh',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enable_refresh" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showMeta = const VerificationMeta('show');
  @override
  late final GeneratedColumn<bool> show = GeneratedColumn<bool>(
    'show',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _bookSortMeta = const VerificationMeta(
    'bookSort',
  );
  @override
  late final GeneratedColumn<int> bookSort = GeneratedColumn<int>(
    'book_sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _onlyUpdateReadMeta = const VerificationMeta(
    'onlyUpdateRead',
  );
  @override
  late final GeneratedColumn<bool> onlyUpdateRead = GeneratedColumn<bool>(
    'only_update_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_update_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    groupName,
    cover,
    order,
    enableRefresh,
    show,
    bookSort,
    onlyUpdateRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    }
    if (data.containsKey('enable_refresh')) {
      context.handle(
        _enableRefreshMeta,
        enableRefresh.isAcceptableOrUnknown(
          data['enable_refresh']!,
          _enableRefreshMeta,
        ),
      );
    }
    if (data.containsKey('show')) {
      context.handle(
        _showMeta,
        show.isAcceptableOrUnknown(data['show']!, _showMeta),
      );
    }
    if (data.containsKey('book_sort')) {
      context.handle(
        _bookSortMeta,
        bookSort.isAcceptableOrUnknown(data['book_sort']!, _bookSortMeta),
      );
    }
    if (data.containsKey('only_update_read')) {
      context.handle(
        _onlyUpdateReadMeta,
        onlyUpdateRead.isAcceptableOrUnknown(
          data['only_update_read']!,
          _onlyUpdateReadMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  BookGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookGroup(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      )!,
      enableRefresh: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enable_refresh'],
      )!,
      show: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show'],
      )!,
      bookSort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_sort'],
      )!,
      onlyUpdateRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_update_read'],
      )!,
    );
  }

  @override
  $BookGroupsTable createAlias(String alias) {
    return $BookGroupsTable(attachedDatabase, alias);
  }
}

class BookGroup extends DataClass implements Insertable<BookGroup> {
  final int groupId;
  final String groupName;
  final String? cover;
  final int order;
  final bool enableRefresh;
  final bool show;
  final int bookSort;
  final bool onlyUpdateRead;
  const BookGroup({
    required this.groupId,
    required this.groupName,
    this.cover,
    required this.order,
    required this.enableRefresh,
    required this.show,
    required this.bookSort,
    required this.onlyUpdateRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<int>(groupId);
    map['group_name'] = Variable<String>(groupName);
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    map['order'] = Variable<int>(order);
    map['enable_refresh'] = Variable<bool>(enableRefresh);
    map['show'] = Variable<bool>(show);
    map['book_sort'] = Variable<int>(bookSort);
    map['only_update_read'] = Variable<bool>(onlyUpdateRead);
    return map;
  }

  BookGroupsCompanion toCompanion(bool nullToAbsent) {
    return BookGroupsCompanion(
      groupId: Value(groupId),
      groupName: Value(groupName),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      order: Value(order),
      enableRefresh: Value(enableRefresh),
      show: Value(show),
      bookSort: Value(bookSort),
      onlyUpdateRead: Value(onlyUpdateRead),
    );
  }

  factory BookGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookGroup(
      groupId: serializer.fromJson<int>(json['groupId']),
      groupName: serializer.fromJson<String>(json['groupName']),
      cover: serializer.fromJson<String?>(json['cover']),
      order: serializer.fromJson<int>(json['order']),
      enableRefresh: serializer.fromJson<bool>(json['enableRefresh']),
      show: serializer.fromJson<bool>(json['show']),
      bookSort: serializer.fromJson<int>(json['bookSort']),
      onlyUpdateRead: serializer.fromJson<bool>(json['onlyUpdateRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<int>(groupId),
      'groupName': serializer.toJson<String>(groupName),
      'cover': serializer.toJson<String?>(cover),
      'order': serializer.toJson<int>(order),
      'enableRefresh': serializer.toJson<bool>(enableRefresh),
      'show': serializer.toJson<bool>(show),
      'bookSort': serializer.toJson<int>(bookSort),
      'onlyUpdateRead': serializer.toJson<bool>(onlyUpdateRead),
    };
  }

  BookGroup copyWith({
    int? groupId,
    String? groupName,
    Value<String?> cover = const Value.absent(),
    int? order,
    bool? enableRefresh,
    bool? show,
    int? bookSort,
    bool? onlyUpdateRead,
  }) => BookGroup(
    groupId: groupId ?? this.groupId,
    groupName: groupName ?? this.groupName,
    cover: cover.present ? cover.value : this.cover,
    order: order ?? this.order,
    enableRefresh: enableRefresh ?? this.enableRefresh,
    show: show ?? this.show,
    bookSort: bookSort ?? this.bookSort,
    onlyUpdateRead: onlyUpdateRead ?? this.onlyUpdateRead,
  );
  BookGroup copyWithCompanion(BookGroupsCompanion data) {
    return BookGroup(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      cover: data.cover.present ? data.cover.value : this.cover,
      order: data.order.present ? data.order.value : this.order,
      enableRefresh: data.enableRefresh.present
          ? data.enableRefresh.value
          : this.enableRefresh,
      show: data.show.present ? data.show.value : this.show,
      bookSort: data.bookSort.present ? data.bookSort.value : this.bookSort,
      onlyUpdateRead: data.onlyUpdateRead.present
          ? data.onlyUpdateRead.value
          : this.onlyUpdateRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookGroup(')
          ..write('groupId: $groupId, ')
          ..write('groupName: $groupName, ')
          ..write('cover: $cover, ')
          ..write('order: $order, ')
          ..write('enableRefresh: $enableRefresh, ')
          ..write('show: $show, ')
          ..write('bookSort: $bookSort, ')
          ..write('onlyUpdateRead: $onlyUpdateRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    groupId,
    groupName,
    cover,
    order,
    enableRefresh,
    show,
    bookSort,
    onlyUpdateRead,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookGroup &&
          other.groupId == this.groupId &&
          other.groupName == this.groupName &&
          other.cover == this.cover &&
          other.order == this.order &&
          other.enableRefresh == this.enableRefresh &&
          other.show == this.show &&
          other.bookSort == this.bookSort &&
          other.onlyUpdateRead == this.onlyUpdateRead);
}

class BookGroupsCompanion extends UpdateCompanion<BookGroup> {
  final Value<int> groupId;
  final Value<String> groupName;
  final Value<String?> cover;
  final Value<int> order;
  final Value<bool> enableRefresh;
  final Value<bool> show;
  final Value<int> bookSort;
  final Value<bool> onlyUpdateRead;
  const BookGroupsCompanion({
    this.groupId = const Value.absent(),
    this.groupName = const Value.absent(),
    this.cover = const Value.absent(),
    this.order = const Value.absent(),
    this.enableRefresh = const Value.absent(),
    this.show = const Value.absent(),
    this.bookSort = const Value.absent(),
    this.onlyUpdateRead = const Value.absent(),
  });
  BookGroupsCompanion.insert({
    this.groupId = const Value.absent(),
    required String groupName,
    this.cover = const Value.absent(),
    this.order = const Value.absent(),
    this.enableRefresh = const Value.absent(),
    this.show = const Value.absent(),
    this.bookSort = const Value.absent(),
    this.onlyUpdateRead = const Value.absent(),
  }) : groupName = Value(groupName);
  static Insertable<BookGroup> custom({
    Expression<int>? groupId,
    Expression<String>? groupName,
    Expression<String>? cover,
    Expression<int>? order,
    Expression<bool>? enableRefresh,
    Expression<bool>? show,
    Expression<int>? bookSort,
    Expression<bool>? onlyUpdateRead,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (groupName != null) 'group_name': groupName,
      if (cover != null) 'cover': cover,
      if (order != null) 'order': order,
      if (enableRefresh != null) 'enable_refresh': enableRefresh,
      if (show != null) 'show': show,
      if (bookSort != null) 'book_sort': bookSort,
      if (onlyUpdateRead != null) 'only_update_read': onlyUpdateRead,
    });
  }

  BookGroupsCompanion copyWith({
    Value<int>? groupId,
    Value<String>? groupName,
    Value<String?>? cover,
    Value<int>? order,
    Value<bool>? enableRefresh,
    Value<bool>? show,
    Value<int>? bookSort,
    Value<bool>? onlyUpdateRead,
  }) {
    return BookGroupsCompanion(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      cover: cover ?? this.cover,
      order: order ?? this.order,
      enableRefresh: enableRefresh ?? this.enableRefresh,
      show: show ?? this.show,
      bookSort: bookSort ?? this.bookSort,
      onlyUpdateRead: onlyUpdateRead ?? this.onlyUpdateRead,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (enableRefresh.present) {
      map['enable_refresh'] = Variable<bool>(enableRefresh.value);
    }
    if (show.present) {
      map['show'] = Variable<bool>(show.value);
    }
    if (bookSort.present) {
      map['book_sort'] = Variable<int>(bookSort.value);
    }
    if (onlyUpdateRead.present) {
      map['only_update_read'] = Variable<bool>(onlyUpdateRead.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookGroupsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('groupName: $groupName, ')
          ..write('cover: $cover, ')
          ..write('order: $order, ')
          ..write('enableRefresh: $enableRefresh, ')
          ..write('show: $show, ')
          ..write('bookSort: $bookSort, ')
          ..write('onlyUpdateRead: $onlyUpdateRead')
          ..write(')'))
        .toString();
  }
}

class $CookiesTable extends Cookies with TableInfo<$CookiesTable, Cooky> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CookiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cookieMeta = const VerificationMeta('cookie');
  @override
  late final GeneratedColumn<String> cookie = GeneratedColumn<String>(
    'cookie',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [url, cookie];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cookies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cooky> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('cookie')) {
      context.handle(
        _cookieMeta,
        cookie.isAcceptableOrUnknown(data['cookie']!, _cookieMeta),
      );
    } else if (isInserting) {
      context.missing(_cookieMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {url};
  @override
  Cooky map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cooky(
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      cookie: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cookie'],
      )!,
    );
  }

  @override
  $CookiesTable createAlias(String alias) {
    return $CookiesTable(attachedDatabase, alias);
  }
}

class Cooky extends DataClass implements Insertable<Cooky> {
  final String url;
  final String cookie;
  const Cooky({required this.url, required this.cookie});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    map['cookie'] = Variable<String>(cookie);
    return map;
  }

  CookiesCompanion toCompanion(bool nullToAbsent) {
    return CookiesCompanion(url: Value(url), cookie: Value(cookie));
  }

  factory Cooky.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cooky(
      url: serializer.fromJson<String>(json['url']),
      cookie: serializer.fromJson<String>(json['cookie']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'cookie': serializer.toJson<String>(cookie),
    };
  }

  Cooky copyWith({String? url, String? cookie}) =>
      Cooky(url: url ?? this.url, cookie: cookie ?? this.cookie);
  Cooky copyWithCompanion(CookiesCompanion data) {
    return Cooky(
      url: data.url.present ? data.url.value : this.url,
      cookie: data.cookie.present ? data.cookie.value : this.cookie,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cooky(')
          ..write('url: $url, ')
          ..write('cookie: $cookie')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(url, cookie);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cooky && other.url == this.url && other.cookie == this.cookie);
}

class CookiesCompanion extends UpdateCompanion<Cooky> {
  final Value<String> url;
  final Value<String> cookie;
  final Value<int> rowid;
  const CookiesCompanion({
    this.url = const Value.absent(),
    this.cookie = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CookiesCompanion.insert({
    required String url,
    required String cookie,
    this.rowid = const Value.absent(),
  }) : url = Value(url),
       cookie = Value(cookie);
  static Insertable<Cooky> custom({
    Expression<String>? url,
    Expression<String>? cookie,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (cookie != null) 'cookie': cookie,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CookiesCompanion copyWith({
    Value<String>? url,
    Value<String>? cookie,
    Value<int>? rowid,
  }) {
    return CookiesCompanion(
      url: url ?? this.url,
      cookie: cookie ?? this.cookie,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (cookie.present) {
      map['cookie'] = Variable<String>(cookie.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CookiesCompanion(')
          ..write('url: $url, ')
          ..write('cookie: $cookie, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<int> deadline = GeneratedColumn<int>(
    'deadline',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, deadline];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deadline'],
      )!,
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntry extends DataClass implements Insertable<CacheEntry> {
  final String key;
  final String? value;
  final int deadline;
  const CacheEntry({required this.key, this.value, required this.deadline});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['deadline'] = Variable<int>(deadline);
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      deadline: Value(deadline),
    );
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      deadline: serializer.fromJson<int>(json['deadline']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'deadline': serializer.toJson<int>(deadline),
    };
  }

  CacheEntry copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
    int? deadline,
  }) => CacheEntry(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    deadline: deadline ?? this.deadline,
  );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('deadline: $deadline')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, deadline);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.deadline == this.deadline);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> deadline;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.deadline = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.deadline = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<CacheEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? deadline,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (deadline != null) 'deadline': deadline,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? deadline,
    Value<int>? rowid,
  }) {
    return CacheEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      deadline: deadline ?? this.deadline,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<int>(deadline.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('deadline: $deadline, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RssSourcesTable extends RssSources
    with TableInfo<$RssSourcesTable, RssSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RssSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceIconMeta = const VerificationMeta(
    'sourceIcon',
  );
  @override
  late final GeneratedColumn<String> sourceIcon = GeneratedColumn<String>(
    'source_icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceGroupMeta = const VerificationMeta(
    'sourceGroup',
  );
  @override
  late final GeneratedColumn<String> sourceGroup = GeneratedColumn<String>(
    'source_group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceCommentMeta = const VerificationMeta(
    'sourceComment',
  );
  @override
  late final GeneratedColumn<String> sourceComment = GeneratedColumn<String>(
    'source_comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variableCommentMeta = const VerificationMeta(
    'variableComment',
  );
  @override
  late final GeneratedColumn<String> variableComment = GeneratedColumn<String>(
    'variable_comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _enabledCookieJarMeta = const VerificationMeta(
    'enabledCookieJar',
  );
  @override
  late final GeneratedColumn<bool> enabledCookieJar = GeneratedColumn<bool>(
    'enabled_cookie_jar',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled_cookie_jar" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _enableJsMeta = const VerificationMeta(
    'enableJs',
  );
  @override
  late final GeneratedColumn<bool> enableJs = GeneratedColumn<bool>(
    'enable_js',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enable_js" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _singleUrlMeta = const VerificationMeta(
    'singleUrl',
  );
  @override
  late final GeneratedColumn<bool> singleUrl = GeneratedColumn<bool>(
    'single_url',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("single_url" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _loadWithBaseUrlMeta = const VerificationMeta(
    'loadWithBaseUrl',
  );
  @override
  late final GeneratedColumn<bool> loadWithBaseUrl = GeneratedColumn<bool>(
    'load_with_base_url',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("load_with_base_url" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _shouldOverrideUrlLoadingMeta =
      const VerificationMeta('shouldOverrideUrlLoading');
  @override
  late final GeneratedColumn<bool> shouldOverrideUrlLoading =
      GeneratedColumn<bool>(
        'should_override_url_loading',
        aliasedName,
        true,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("should_override_url_loading" IN (0, 1))',
        ),
      );
  static const VerificationMeta _articleStyleMeta = const VerificationMeta(
    'articleStyle',
  );
  @override
  late final GeneratedColumn<int> articleStyle = GeneratedColumn<int>(
    'article_style',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _customOrderMeta = const VerificationMeta(
    'customOrder',
  );
  @override
  late final GeneratedColumn<int> customOrder = GeneratedColumn<int>(
    'custom_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUpdateTimeMeta = const VerificationMeta(
    'lastUpdateTime',
  );
  @override
  late final GeneratedColumn<int> lastUpdateTime = GeneratedColumn<int>(
    'last_update_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _showWebLogMeta = const VerificationMeta(
    'showWebLog',
  );
  @override
  late final GeneratedColumn<int> showWebLog = GeneratedColumn<int>(
    'show_web_log',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _preloadMeta = const VerificationMeta(
    'preload',
  );
  @override
  late final GeneratedColumn<int> preload = GeneratedColumn<int>(
    'preload',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cacheFirstMeta = const VerificationMeta(
    'cacheFirst',
  );
  @override
  late final GeneratedColumn<int> cacheFirst = GeneratedColumn<int>(
    'cache_first',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _jsLibMeta = const VerificationMeta('jsLib');
  @override
  late final GeneratedColumn<String> jsLib = GeneratedColumn<String>(
    'js_lib',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _concurrentRateMeta = const VerificationMeta(
    'concurrentRate',
  );
  @override
  late final GeneratedColumn<String> concurrentRate = GeneratedColumn<String>(
    'concurrent_rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headerMeta = const VerificationMeta('header');
  @override
  late final GeneratedColumn<String> header = GeneratedColumn<String>(
    'header',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loginUrlMeta = const VerificationMeta(
    'loginUrl',
  );
  @override
  late final GeneratedColumn<String> loginUrl = GeneratedColumn<String>(
    'login_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loginUiMeta = const VerificationMeta(
    'loginUi',
  );
  @override
  late final GeneratedColumn<String> loginUi = GeneratedColumn<String>(
    'login_ui',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loginCheckJsMeta = const VerificationMeta(
    'loginCheckJs',
  );
  @override
  late final GeneratedColumn<String> loginCheckJs = GeneratedColumn<String>(
    'login_check_js',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverDecodeJsMeta = const VerificationMeta(
    'coverDecodeJs',
  );
  @override
  late final GeneratedColumn<String> coverDecodeJs = GeneratedColumn<String>(
    'cover_decode_js',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortUrlMeta = const VerificationMeta(
    'sortUrl',
  );
  @override
  late final GeneratedColumn<String> sortUrl = GeneratedColumn<String>(
    'sort_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleArticlesMeta = const VerificationMeta(
    'ruleArticles',
  );
  @override
  late final GeneratedColumn<String> ruleArticles = GeneratedColumn<String>(
    'rule_articles',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleNextPageMeta = const VerificationMeta(
    'ruleNextPage',
  );
  @override
  late final GeneratedColumn<String> ruleNextPage = GeneratedColumn<String>(
    'rule_next_page',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleTitleMeta = const VerificationMeta(
    'ruleTitle',
  );
  @override
  late final GeneratedColumn<String> ruleTitle = GeneratedColumn<String>(
    'rule_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rulePubDateMeta = const VerificationMeta(
    'rulePubDate',
  );
  @override
  late final GeneratedColumn<String> rulePubDate = GeneratedColumn<String>(
    'rule_pub_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleDescriptionMeta = const VerificationMeta(
    'ruleDescription',
  );
  @override
  late final GeneratedColumn<String> ruleDescription = GeneratedColumn<String>(
    'rule_description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleImageMeta = const VerificationMeta(
    'ruleImage',
  );
  @override
  late final GeneratedColumn<String> ruleImage = GeneratedColumn<String>(
    'rule_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleLinkMeta = const VerificationMeta(
    'ruleLink',
  );
  @override
  late final GeneratedColumn<String> ruleLink = GeneratedColumn<String>(
    'rule_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleContentMeta = const VerificationMeta(
    'ruleContent',
  );
  @override
  late final GeneratedColumn<String> ruleContent = GeneratedColumn<String>(
    'rule_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentWhitelistMeta = const VerificationMeta(
    'contentWhitelist',
  );
  @override
  late final GeneratedColumn<String> contentWhitelist = GeneratedColumn<String>(
    'content_whitelist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentBlacklistMeta = const VerificationMeta(
    'contentBlacklist',
  );
  @override
  late final GeneratedColumn<String> contentBlacklist = GeneratedColumn<String>(
    'content_blacklist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _injectJsMeta = const VerificationMeta(
    'injectJs',
  );
  @override
  late final GeneratedColumn<String> injectJs = GeneratedColumn<String>(
    'inject_js',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preloadJsMeta = const VerificationMeta(
    'preloadJs',
  );
  @override
  late final GeneratedColumn<String> preloadJs = GeneratedColumn<String>(
    'preload_js',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startHtmlMeta = const VerificationMeta(
    'startHtml',
  );
  @override
  late final GeneratedColumn<String> startHtml = GeneratedColumn<String>(
    'start_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startStyleMeta = const VerificationMeta(
    'startStyle',
  );
  @override
  late final GeneratedColumn<String> startStyle = GeneratedColumn<String>(
    'start_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startJsMeta = const VerificationMeta(
    'startJs',
  );
  @override
  late final GeneratedColumn<String> startJs = GeneratedColumn<String>(
    'start_js',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchUrlMeta = const VerificationMeta(
    'searchUrl',
  );
  @override
  late final GeneratedColumn<String> searchUrl = GeneratedColumn<String>(
    'search_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceUrl,
    sourceName,
    sourceIcon,
    sourceGroup,
    sourceComment,
    variableComment,
    enabled,
    enabledCookieJar,
    enableJs,
    singleUrl,
    loadWithBaseUrl,
    shouldOverrideUrlLoading,
    articleStyle,
    customOrder,
    lastUpdateTime,
    type,
    showWebLog,
    preload,
    cacheFirst,
    jsLib,
    concurrentRate,
    header,
    loginUrl,
    loginUi,
    loginCheckJs,
    coverDecodeJs,
    sortUrl,
    ruleArticles,
    ruleNextPage,
    ruleTitle,
    rulePubDate,
    ruleDescription,
    ruleImage,
    ruleLink,
    ruleContent,
    contentWhitelist,
    contentBlacklist,
    style,
    injectJs,
    preloadJs,
    startHtml,
    startStyle,
    startJs,
    searchUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rss_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<RssSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    }
    if (data.containsKey('source_icon')) {
      context.handle(
        _sourceIconMeta,
        sourceIcon.isAcceptableOrUnknown(data['source_icon']!, _sourceIconMeta),
      );
    }
    if (data.containsKey('source_group')) {
      context.handle(
        _sourceGroupMeta,
        sourceGroup.isAcceptableOrUnknown(
          data['source_group']!,
          _sourceGroupMeta,
        ),
      );
    }
    if (data.containsKey('source_comment')) {
      context.handle(
        _sourceCommentMeta,
        sourceComment.isAcceptableOrUnknown(
          data['source_comment']!,
          _sourceCommentMeta,
        ),
      );
    }
    if (data.containsKey('variable_comment')) {
      context.handle(
        _variableCommentMeta,
        variableComment.isAcceptableOrUnknown(
          data['variable_comment']!,
          _variableCommentMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('enabled_cookie_jar')) {
      context.handle(
        _enabledCookieJarMeta,
        enabledCookieJar.isAcceptableOrUnknown(
          data['enabled_cookie_jar']!,
          _enabledCookieJarMeta,
        ),
      );
    }
    if (data.containsKey('enable_js')) {
      context.handle(
        _enableJsMeta,
        enableJs.isAcceptableOrUnknown(data['enable_js']!, _enableJsMeta),
      );
    }
    if (data.containsKey('single_url')) {
      context.handle(
        _singleUrlMeta,
        singleUrl.isAcceptableOrUnknown(data['single_url']!, _singleUrlMeta),
      );
    }
    if (data.containsKey('load_with_base_url')) {
      context.handle(
        _loadWithBaseUrlMeta,
        loadWithBaseUrl.isAcceptableOrUnknown(
          data['load_with_base_url']!,
          _loadWithBaseUrlMeta,
        ),
      );
    }
    if (data.containsKey('should_override_url_loading')) {
      context.handle(
        _shouldOverrideUrlLoadingMeta,
        shouldOverrideUrlLoading.isAcceptableOrUnknown(
          data['should_override_url_loading']!,
          _shouldOverrideUrlLoadingMeta,
        ),
      );
    }
    if (data.containsKey('article_style')) {
      context.handle(
        _articleStyleMeta,
        articleStyle.isAcceptableOrUnknown(
          data['article_style']!,
          _articleStyleMeta,
        ),
      );
    }
    if (data.containsKey('custom_order')) {
      context.handle(
        _customOrderMeta,
        customOrder.isAcceptableOrUnknown(
          data['custom_order']!,
          _customOrderMeta,
        ),
      );
    }
    if (data.containsKey('last_update_time')) {
      context.handle(
        _lastUpdateTimeMeta,
        lastUpdateTime.isAcceptableOrUnknown(
          data['last_update_time']!,
          _lastUpdateTimeMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('show_web_log')) {
      context.handle(
        _showWebLogMeta,
        showWebLog.isAcceptableOrUnknown(
          data['show_web_log']!,
          _showWebLogMeta,
        ),
      );
    }
    if (data.containsKey('preload')) {
      context.handle(
        _preloadMeta,
        preload.isAcceptableOrUnknown(data['preload']!, _preloadMeta),
      );
    }
    if (data.containsKey('cache_first')) {
      context.handle(
        _cacheFirstMeta,
        cacheFirst.isAcceptableOrUnknown(data['cache_first']!, _cacheFirstMeta),
      );
    }
    if (data.containsKey('js_lib')) {
      context.handle(
        _jsLibMeta,
        jsLib.isAcceptableOrUnknown(data['js_lib']!, _jsLibMeta),
      );
    }
    if (data.containsKey('concurrent_rate')) {
      context.handle(
        _concurrentRateMeta,
        concurrentRate.isAcceptableOrUnknown(
          data['concurrent_rate']!,
          _concurrentRateMeta,
        ),
      );
    }
    if (data.containsKey('header')) {
      context.handle(
        _headerMeta,
        header.isAcceptableOrUnknown(data['header']!, _headerMeta),
      );
    }
    if (data.containsKey('login_url')) {
      context.handle(
        _loginUrlMeta,
        loginUrl.isAcceptableOrUnknown(data['login_url']!, _loginUrlMeta),
      );
    }
    if (data.containsKey('login_ui')) {
      context.handle(
        _loginUiMeta,
        loginUi.isAcceptableOrUnknown(data['login_ui']!, _loginUiMeta),
      );
    }
    if (data.containsKey('login_check_js')) {
      context.handle(
        _loginCheckJsMeta,
        loginCheckJs.isAcceptableOrUnknown(
          data['login_check_js']!,
          _loginCheckJsMeta,
        ),
      );
    }
    if (data.containsKey('cover_decode_js')) {
      context.handle(
        _coverDecodeJsMeta,
        coverDecodeJs.isAcceptableOrUnknown(
          data['cover_decode_js']!,
          _coverDecodeJsMeta,
        ),
      );
    }
    if (data.containsKey('sort_url')) {
      context.handle(
        _sortUrlMeta,
        sortUrl.isAcceptableOrUnknown(data['sort_url']!, _sortUrlMeta),
      );
    }
    if (data.containsKey('rule_articles')) {
      context.handle(
        _ruleArticlesMeta,
        ruleArticles.isAcceptableOrUnknown(
          data['rule_articles']!,
          _ruleArticlesMeta,
        ),
      );
    }
    if (data.containsKey('rule_next_page')) {
      context.handle(
        _ruleNextPageMeta,
        ruleNextPage.isAcceptableOrUnknown(
          data['rule_next_page']!,
          _ruleNextPageMeta,
        ),
      );
    }
    if (data.containsKey('rule_title')) {
      context.handle(
        _ruleTitleMeta,
        ruleTitle.isAcceptableOrUnknown(data['rule_title']!, _ruleTitleMeta),
      );
    }
    if (data.containsKey('rule_pub_date')) {
      context.handle(
        _rulePubDateMeta,
        rulePubDate.isAcceptableOrUnknown(
          data['rule_pub_date']!,
          _rulePubDateMeta,
        ),
      );
    }
    if (data.containsKey('rule_description')) {
      context.handle(
        _ruleDescriptionMeta,
        ruleDescription.isAcceptableOrUnknown(
          data['rule_description']!,
          _ruleDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('rule_image')) {
      context.handle(
        _ruleImageMeta,
        ruleImage.isAcceptableOrUnknown(data['rule_image']!, _ruleImageMeta),
      );
    }
    if (data.containsKey('rule_link')) {
      context.handle(
        _ruleLinkMeta,
        ruleLink.isAcceptableOrUnknown(data['rule_link']!, _ruleLinkMeta),
      );
    }
    if (data.containsKey('rule_content')) {
      context.handle(
        _ruleContentMeta,
        ruleContent.isAcceptableOrUnknown(
          data['rule_content']!,
          _ruleContentMeta,
        ),
      );
    }
    if (data.containsKey('content_whitelist')) {
      context.handle(
        _contentWhitelistMeta,
        contentWhitelist.isAcceptableOrUnknown(
          data['content_whitelist']!,
          _contentWhitelistMeta,
        ),
      );
    }
    if (data.containsKey('content_blacklist')) {
      context.handle(
        _contentBlacklistMeta,
        contentBlacklist.isAcceptableOrUnknown(
          data['content_blacklist']!,
          _contentBlacklistMeta,
        ),
      );
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    }
    if (data.containsKey('inject_js')) {
      context.handle(
        _injectJsMeta,
        injectJs.isAcceptableOrUnknown(data['inject_js']!, _injectJsMeta),
      );
    }
    if (data.containsKey('preload_js')) {
      context.handle(
        _preloadJsMeta,
        preloadJs.isAcceptableOrUnknown(data['preload_js']!, _preloadJsMeta),
      );
    }
    if (data.containsKey('start_html')) {
      context.handle(
        _startHtmlMeta,
        startHtml.isAcceptableOrUnknown(data['start_html']!, _startHtmlMeta),
      );
    }
    if (data.containsKey('start_style')) {
      context.handle(
        _startStyleMeta,
        startStyle.isAcceptableOrUnknown(data['start_style']!, _startStyleMeta),
      );
    }
    if (data.containsKey('start_js')) {
      context.handle(
        _startJsMeta,
        startJs.isAcceptableOrUnknown(data['start_js']!, _startJsMeta),
      );
    }
    if (data.containsKey('search_url')) {
      context.handle(
        _searchUrlMeta,
        searchUrl.isAcceptableOrUnknown(data['search_url']!, _searchUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceUrl};
  @override
  RssSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RssSource(
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      sourceIcon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_icon'],
      )!,
      sourceGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_group'],
      ),
      sourceComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_comment'],
      ),
      variableComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variable_comment'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      enabledCookieJar: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled_cookie_jar'],
      )!,
      enableJs: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enable_js'],
      )!,
      singleUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}single_url'],
      )!,
      loadWithBaseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}load_with_base_url'],
      )!,
      shouldOverrideUrlLoading: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}should_override_url_loading'],
      ),
      articleStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}article_style'],
      )!,
      customOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_order'],
      )!,
      lastUpdateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_update_time'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      showWebLog: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}show_web_log'],
      )!,
      preload: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preload'],
      )!,
      cacheFirst: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cache_first'],
      )!,
      jsLib: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}js_lib'],
      ),
      concurrentRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concurrent_rate'],
      ),
      header: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}header'],
      ),
      loginUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_url'],
      ),
      loginUi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_ui'],
      ),
      loginCheckJs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_check_js'],
      ),
      coverDecodeJs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_decode_js'],
      ),
      sortUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_url'],
      ),
      ruleArticles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_articles'],
      ),
      ruleNextPage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_next_page'],
      ),
      ruleTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_title'],
      ),
      rulePubDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_pub_date'],
      ),
      ruleDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_description'],
      ),
      ruleImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_image'],
      ),
      ruleLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_link'],
      ),
      ruleContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_content'],
      ),
      contentWhitelist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_whitelist'],
      ),
      contentBlacklist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_blacklist'],
      ),
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      ),
      injectJs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inject_js'],
      ),
      preloadJs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preload_js'],
      ),
      startHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_html'],
      ),
      startStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_style'],
      ),
      startJs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_js'],
      ),
      searchUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_url'],
      ),
    );
  }

  @override
  $RssSourcesTable createAlias(String alias) {
    return $RssSourcesTable(attachedDatabase, alias);
  }
}

class RssSource extends DataClass implements Insertable<RssSource> {
  final String sourceUrl;
  final String sourceName;
  final String sourceIcon;
  final String? sourceGroup;
  final String? sourceComment;
  final String? variableComment;
  final bool enabled;
  final bool enabledCookieJar;
  final bool enableJs;
  final bool singleUrl;
  final bool loadWithBaseUrl;
  final bool? shouldOverrideUrlLoading;
  final int articleStyle;
  final int customOrder;
  final int lastUpdateTime;
  final int type;
  final int showWebLog;
  final int preload;
  final int cacheFirst;
  final String? jsLib;
  final String? concurrentRate;
  final String? header;
  final String? loginUrl;
  final String? loginUi;
  final String? loginCheckJs;
  final String? coverDecodeJs;
  final String? sortUrl;
  final String? ruleArticles;
  final String? ruleNextPage;
  final String? ruleTitle;
  final String? rulePubDate;
  final String? ruleDescription;
  final String? ruleImage;
  final String? ruleLink;
  final String? ruleContent;
  final String? contentWhitelist;
  final String? contentBlacklist;
  final String? style;
  final String? injectJs;
  final String? preloadJs;
  final String? startHtml;
  final String? startStyle;
  final String? startJs;
  final String? searchUrl;
  const RssSource({
    required this.sourceUrl,
    required this.sourceName,
    required this.sourceIcon,
    this.sourceGroup,
    this.sourceComment,
    this.variableComment,
    required this.enabled,
    required this.enabledCookieJar,
    required this.enableJs,
    required this.singleUrl,
    required this.loadWithBaseUrl,
    this.shouldOverrideUrlLoading,
    required this.articleStyle,
    required this.customOrder,
    required this.lastUpdateTime,
    required this.type,
    required this.showWebLog,
    required this.preload,
    required this.cacheFirst,
    this.jsLib,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.sortUrl,
    this.ruleArticles,
    this.ruleNextPage,
    this.ruleTitle,
    this.rulePubDate,
    this.ruleDescription,
    this.ruleImage,
    this.ruleLink,
    this.ruleContent,
    this.contentWhitelist,
    this.contentBlacklist,
    this.style,
    this.injectJs,
    this.preloadJs,
    this.startHtml,
    this.startStyle,
    this.startJs,
    this.searchUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_url'] = Variable<String>(sourceUrl);
    map['source_name'] = Variable<String>(sourceName);
    map['source_icon'] = Variable<String>(sourceIcon);
    if (!nullToAbsent || sourceGroup != null) {
      map['source_group'] = Variable<String>(sourceGroup);
    }
    if (!nullToAbsent || sourceComment != null) {
      map['source_comment'] = Variable<String>(sourceComment);
    }
    if (!nullToAbsent || variableComment != null) {
      map['variable_comment'] = Variable<String>(variableComment);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['enabled_cookie_jar'] = Variable<bool>(enabledCookieJar);
    map['enable_js'] = Variable<bool>(enableJs);
    map['single_url'] = Variable<bool>(singleUrl);
    map['load_with_base_url'] = Variable<bool>(loadWithBaseUrl);
    if (!nullToAbsent || shouldOverrideUrlLoading != null) {
      map['should_override_url_loading'] = Variable<bool>(
        shouldOverrideUrlLoading,
      );
    }
    map['article_style'] = Variable<int>(articleStyle);
    map['custom_order'] = Variable<int>(customOrder);
    map['last_update_time'] = Variable<int>(lastUpdateTime);
    map['type'] = Variable<int>(type);
    map['show_web_log'] = Variable<int>(showWebLog);
    map['preload'] = Variable<int>(preload);
    map['cache_first'] = Variable<int>(cacheFirst);
    if (!nullToAbsent || jsLib != null) {
      map['js_lib'] = Variable<String>(jsLib);
    }
    if (!nullToAbsent || concurrentRate != null) {
      map['concurrent_rate'] = Variable<String>(concurrentRate);
    }
    if (!nullToAbsent || header != null) {
      map['header'] = Variable<String>(header);
    }
    if (!nullToAbsent || loginUrl != null) {
      map['login_url'] = Variable<String>(loginUrl);
    }
    if (!nullToAbsent || loginUi != null) {
      map['login_ui'] = Variable<String>(loginUi);
    }
    if (!nullToAbsent || loginCheckJs != null) {
      map['login_check_js'] = Variable<String>(loginCheckJs);
    }
    if (!nullToAbsent || coverDecodeJs != null) {
      map['cover_decode_js'] = Variable<String>(coverDecodeJs);
    }
    if (!nullToAbsent || sortUrl != null) {
      map['sort_url'] = Variable<String>(sortUrl);
    }
    if (!nullToAbsent || ruleArticles != null) {
      map['rule_articles'] = Variable<String>(ruleArticles);
    }
    if (!nullToAbsent || ruleNextPage != null) {
      map['rule_next_page'] = Variable<String>(ruleNextPage);
    }
    if (!nullToAbsent || ruleTitle != null) {
      map['rule_title'] = Variable<String>(ruleTitle);
    }
    if (!nullToAbsent || rulePubDate != null) {
      map['rule_pub_date'] = Variable<String>(rulePubDate);
    }
    if (!nullToAbsent || ruleDescription != null) {
      map['rule_description'] = Variable<String>(ruleDescription);
    }
    if (!nullToAbsent || ruleImage != null) {
      map['rule_image'] = Variable<String>(ruleImage);
    }
    if (!nullToAbsent || ruleLink != null) {
      map['rule_link'] = Variable<String>(ruleLink);
    }
    if (!nullToAbsent || ruleContent != null) {
      map['rule_content'] = Variable<String>(ruleContent);
    }
    if (!nullToAbsent || contentWhitelist != null) {
      map['content_whitelist'] = Variable<String>(contentWhitelist);
    }
    if (!nullToAbsent || contentBlacklist != null) {
      map['content_blacklist'] = Variable<String>(contentBlacklist);
    }
    if (!nullToAbsent || style != null) {
      map['style'] = Variable<String>(style);
    }
    if (!nullToAbsent || injectJs != null) {
      map['inject_js'] = Variable<String>(injectJs);
    }
    if (!nullToAbsent || preloadJs != null) {
      map['preload_js'] = Variable<String>(preloadJs);
    }
    if (!nullToAbsent || startHtml != null) {
      map['start_html'] = Variable<String>(startHtml);
    }
    if (!nullToAbsent || startStyle != null) {
      map['start_style'] = Variable<String>(startStyle);
    }
    if (!nullToAbsent || startJs != null) {
      map['start_js'] = Variable<String>(startJs);
    }
    if (!nullToAbsent || searchUrl != null) {
      map['search_url'] = Variable<String>(searchUrl);
    }
    return map;
  }

  RssSourcesCompanion toCompanion(bool nullToAbsent) {
    return RssSourcesCompanion(
      sourceUrl: Value(sourceUrl),
      sourceName: Value(sourceName),
      sourceIcon: Value(sourceIcon),
      sourceGroup: sourceGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceGroup),
      sourceComment: sourceComment == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceComment),
      variableComment: variableComment == null && nullToAbsent
          ? const Value.absent()
          : Value(variableComment),
      enabled: Value(enabled),
      enabledCookieJar: Value(enabledCookieJar),
      enableJs: Value(enableJs),
      singleUrl: Value(singleUrl),
      loadWithBaseUrl: Value(loadWithBaseUrl),
      shouldOverrideUrlLoading: shouldOverrideUrlLoading == null && nullToAbsent
          ? const Value.absent()
          : Value(shouldOverrideUrlLoading),
      articleStyle: Value(articleStyle),
      customOrder: Value(customOrder),
      lastUpdateTime: Value(lastUpdateTime),
      type: Value(type),
      showWebLog: Value(showWebLog),
      preload: Value(preload),
      cacheFirst: Value(cacheFirst),
      jsLib: jsLib == null && nullToAbsent
          ? const Value.absent()
          : Value(jsLib),
      concurrentRate: concurrentRate == null && nullToAbsent
          ? const Value.absent()
          : Value(concurrentRate),
      header: header == null && nullToAbsent
          ? const Value.absent()
          : Value(header),
      loginUrl: loginUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(loginUrl),
      loginUi: loginUi == null && nullToAbsent
          ? const Value.absent()
          : Value(loginUi),
      loginCheckJs: loginCheckJs == null && nullToAbsent
          ? const Value.absent()
          : Value(loginCheckJs),
      coverDecodeJs: coverDecodeJs == null && nullToAbsent
          ? const Value.absent()
          : Value(coverDecodeJs),
      sortUrl: sortUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sortUrl),
      ruleArticles: ruleArticles == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleArticles),
      ruleNextPage: ruleNextPage == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleNextPage),
      ruleTitle: ruleTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleTitle),
      rulePubDate: rulePubDate == null && nullToAbsent
          ? const Value.absent()
          : Value(rulePubDate),
      ruleDescription: ruleDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleDescription),
      ruleImage: ruleImage == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleImage),
      ruleLink: ruleLink == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleLink),
      ruleContent: ruleContent == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleContent),
      contentWhitelist: contentWhitelist == null && nullToAbsent
          ? const Value.absent()
          : Value(contentWhitelist),
      contentBlacklist: contentBlacklist == null && nullToAbsent
          ? const Value.absent()
          : Value(contentBlacklist),
      style: style == null && nullToAbsent
          ? const Value.absent()
          : Value(style),
      injectJs: injectJs == null && nullToAbsent
          ? const Value.absent()
          : Value(injectJs),
      preloadJs: preloadJs == null && nullToAbsent
          ? const Value.absent()
          : Value(preloadJs),
      startHtml: startHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(startHtml),
      startStyle: startStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(startStyle),
      startJs: startJs == null && nullToAbsent
          ? const Value.absent()
          : Value(startJs),
      searchUrl: searchUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(searchUrl),
    );
  }

  factory RssSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RssSource(
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      sourceIcon: serializer.fromJson<String>(json['sourceIcon']),
      sourceGroup: serializer.fromJson<String?>(json['sourceGroup']),
      sourceComment: serializer.fromJson<String?>(json['sourceComment']),
      variableComment: serializer.fromJson<String?>(json['variableComment']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      enabledCookieJar: serializer.fromJson<bool>(json['enabledCookieJar']),
      enableJs: serializer.fromJson<bool>(json['enableJs']),
      singleUrl: serializer.fromJson<bool>(json['singleUrl']),
      loadWithBaseUrl: serializer.fromJson<bool>(json['loadWithBaseUrl']),
      shouldOverrideUrlLoading: serializer.fromJson<bool?>(
        json['shouldOverrideUrlLoading'],
      ),
      articleStyle: serializer.fromJson<int>(json['articleStyle']),
      customOrder: serializer.fromJson<int>(json['customOrder']),
      lastUpdateTime: serializer.fromJson<int>(json['lastUpdateTime']),
      type: serializer.fromJson<int>(json['type']),
      showWebLog: serializer.fromJson<int>(json['showWebLog']),
      preload: serializer.fromJson<int>(json['preload']),
      cacheFirst: serializer.fromJson<int>(json['cacheFirst']),
      jsLib: serializer.fromJson<String?>(json['jsLib']),
      concurrentRate: serializer.fromJson<String?>(json['concurrentRate']),
      header: serializer.fromJson<String?>(json['header']),
      loginUrl: serializer.fromJson<String?>(json['loginUrl']),
      loginUi: serializer.fromJson<String?>(json['loginUi']),
      loginCheckJs: serializer.fromJson<String?>(json['loginCheckJs']),
      coverDecodeJs: serializer.fromJson<String?>(json['coverDecodeJs']),
      sortUrl: serializer.fromJson<String?>(json['sortUrl']),
      ruleArticles: serializer.fromJson<String?>(json['ruleArticles']),
      ruleNextPage: serializer.fromJson<String?>(json['ruleNextPage']),
      ruleTitle: serializer.fromJson<String?>(json['ruleTitle']),
      rulePubDate: serializer.fromJson<String?>(json['rulePubDate']),
      ruleDescription: serializer.fromJson<String?>(json['ruleDescription']),
      ruleImage: serializer.fromJson<String?>(json['ruleImage']),
      ruleLink: serializer.fromJson<String?>(json['ruleLink']),
      ruleContent: serializer.fromJson<String?>(json['ruleContent']),
      contentWhitelist: serializer.fromJson<String?>(json['contentWhitelist']),
      contentBlacklist: serializer.fromJson<String?>(json['contentBlacklist']),
      style: serializer.fromJson<String?>(json['style']),
      injectJs: serializer.fromJson<String?>(json['injectJs']),
      preloadJs: serializer.fromJson<String?>(json['preloadJs']),
      startHtml: serializer.fromJson<String?>(json['startHtml']),
      startStyle: serializer.fromJson<String?>(json['startStyle']),
      startJs: serializer.fromJson<String?>(json['startJs']),
      searchUrl: serializer.fromJson<String?>(json['searchUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'sourceName': serializer.toJson<String>(sourceName),
      'sourceIcon': serializer.toJson<String>(sourceIcon),
      'sourceGroup': serializer.toJson<String?>(sourceGroup),
      'sourceComment': serializer.toJson<String?>(sourceComment),
      'variableComment': serializer.toJson<String?>(variableComment),
      'enabled': serializer.toJson<bool>(enabled),
      'enabledCookieJar': serializer.toJson<bool>(enabledCookieJar),
      'enableJs': serializer.toJson<bool>(enableJs),
      'singleUrl': serializer.toJson<bool>(singleUrl),
      'loadWithBaseUrl': serializer.toJson<bool>(loadWithBaseUrl),
      'shouldOverrideUrlLoading': serializer.toJson<bool?>(
        shouldOverrideUrlLoading,
      ),
      'articleStyle': serializer.toJson<int>(articleStyle),
      'customOrder': serializer.toJson<int>(customOrder),
      'lastUpdateTime': serializer.toJson<int>(lastUpdateTime),
      'type': serializer.toJson<int>(type),
      'showWebLog': serializer.toJson<int>(showWebLog),
      'preload': serializer.toJson<int>(preload),
      'cacheFirst': serializer.toJson<int>(cacheFirst),
      'jsLib': serializer.toJson<String?>(jsLib),
      'concurrentRate': serializer.toJson<String?>(concurrentRate),
      'header': serializer.toJson<String?>(header),
      'loginUrl': serializer.toJson<String?>(loginUrl),
      'loginUi': serializer.toJson<String?>(loginUi),
      'loginCheckJs': serializer.toJson<String?>(loginCheckJs),
      'coverDecodeJs': serializer.toJson<String?>(coverDecodeJs),
      'sortUrl': serializer.toJson<String?>(sortUrl),
      'ruleArticles': serializer.toJson<String?>(ruleArticles),
      'ruleNextPage': serializer.toJson<String?>(ruleNextPage),
      'ruleTitle': serializer.toJson<String?>(ruleTitle),
      'rulePubDate': serializer.toJson<String?>(rulePubDate),
      'ruleDescription': serializer.toJson<String?>(ruleDescription),
      'ruleImage': serializer.toJson<String?>(ruleImage),
      'ruleLink': serializer.toJson<String?>(ruleLink),
      'ruleContent': serializer.toJson<String?>(ruleContent),
      'contentWhitelist': serializer.toJson<String?>(contentWhitelist),
      'contentBlacklist': serializer.toJson<String?>(contentBlacklist),
      'style': serializer.toJson<String?>(style),
      'injectJs': serializer.toJson<String?>(injectJs),
      'preloadJs': serializer.toJson<String?>(preloadJs),
      'startHtml': serializer.toJson<String?>(startHtml),
      'startStyle': serializer.toJson<String?>(startStyle),
      'startJs': serializer.toJson<String?>(startJs),
      'searchUrl': serializer.toJson<String?>(searchUrl),
    };
  }

  RssSource copyWith({
    String? sourceUrl,
    String? sourceName,
    String? sourceIcon,
    Value<String?> sourceGroup = const Value.absent(),
    Value<String?> sourceComment = const Value.absent(),
    Value<String?> variableComment = const Value.absent(),
    bool? enabled,
    bool? enabledCookieJar,
    bool? enableJs,
    bool? singleUrl,
    bool? loadWithBaseUrl,
    Value<bool?> shouldOverrideUrlLoading = const Value.absent(),
    int? articleStyle,
    int? customOrder,
    int? lastUpdateTime,
    int? type,
    int? showWebLog,
    int? preload,
    int? cacheFirst,
    Value<String?> jsLib = const Value.absent(),
    Value<String?> concurrentRate = const Value.absent(),
    Value<String?> header = const Value.absent(),
    Value<String?> loginUrl = const Value.absent(),
    Value<String?> loginUi = const Value.absent(),
    Value<String?> loginCheckJs = const Value.absent(),
    Value<String?> coverDecodeJs = const Value.absent(),
    Value<String?> sortUrl = const Value.absent(),
    Value<String?> ruleArticles = const Value.absent(),
    Value<String?> ruleNextPage = const Value.absent(),
    Value<String?> ruleTitle = const Value.absent(),
    Value<String?> rulePubDate = const Value.absent(),
    Value<String?> ruleDescription = const Value.absent(),
    Value<String?> ruleImage = const Value.absent(),
    Value<String?> ruleLink = const Value.absent(),
    Value<String?> ruleContent = const Value.absent(),
    Value<String?> contentWhitelist = const Value.absent(),
    Value<String?> contentBlacklist = const Value.absent(),
    Value<String?> style = const Value.absent(),
    Value<String?> injectJs = const Value.absent(),
    Value<String?> preloadJs = const Value.absent(),
    Value<String?> startHtml = const Value.absent(),
    Value<String?> startStyle = const Value.absent(),
    Value<String?> startJs = const Value.absent(),
    Value<String?> searchUrl = const Value.absent(),
  }) => RssSource(
    sourceUrl: sourceUrl ?? this.sourceUrl,
    sourceName: sourceName ?? this.sourceName,
    sourceIcon: sourceIcon ?? this.sourceIcon,
    sourceGroup: sourceGroup.present ? sourceGroup.value : this.sourceGroup,
    sourceComment: sourceComment.present
        ? sourceComment.value
        : this.sourceComment,
    variableComment: variableComment.present
        ? variableComment.value
        : this.variableComment,
    enabled: enabled ?? this.enabled,
    enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
    enableJs: enableJs ?? this.enableJs,
    singleUrl: singleUrl ?? this.singleUrl,
    loadWithBaseUrl: loadWithBaseUrl ?? this.loadWithBaseUrl,
    shouldOverrideUrlLoading: shouldOverrideUrlLoading.present
        ? shouldOverrideUrlLoading.value
        : this.shouldOverrideUrlLoading,
    articleStyle: articleStyle ?? this.articleStyle,
    customOrder: customOrder ?? this.customOrder,
    lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    type: type ?? this.type,
    showWebLog: showWebLog ?? this.showWebLog,
    preload: preload ?? this.preload,
    cacheFirst: cacheFirst ?? this.cacheFirst,
    jsLib: jsLib.present ? jsLib.value : this.jsLib,
    concurrentRate: concurrentRate.present
        ? concurrentRate.value
        : this.concurrentRate,
    header: header.present ? header.value : this.header,
    loginUrl: loginUrl.present ? loginUrl.value : this.loginUrl,
    loginUi: loginUi.present ? loginUi.value : this.loginUi,
    loginCheckJs: loginCheckJs.present ? loginCheckJs.value : this.loginCheckJs,
    coverDecodeJs: coverDecodeJs.present
        ? coverDecodeJs.value
        : this.coverDecodeJs,
    sortUrl: sortUrl.present ? sortUrl.value : this.sortUrl,
    ruleArticles: ruleArticles.present ? ruleArticles.value : this.ruleArticles,
    ruleNextPage: ruleNextPage.present ? ruleNextPage.value : this.ruleNextPage,
    ruleTitle: ruleTitle.present ? ruleTitle.value : this.ruleTitle,
    rulePubDate: rulePubDate.present ? rulePubDate.value : this.rulePubDate,
    ruleDescription: ruleDescription.present
        ? ruleDescription.value
        : this.ruleDescription,
    ruleImage: ruleImage.present ? ruleImage.value : this.ruleImage,
    ruleLink: ruleLink.present ? ruleLink.value : this.ruleLink,
    ruleContent: ruleContent.present ? ruleContent.value : this.ruleContent,
    contentWhitelist: contentWhitelist.present
        ? contentWhitelist.value
        : this.contentWhitelist,
    contentBlacklist: contentBlacklist.present
        ? contentBlacklist.value
        : this.contentBlacklist,
    style: style.present ? style.value : this.style,
    injectJs: injectJs.present ? injectJs.value : this.injectJs,
    preloadJs: preloadJs.present ? preloadJs.value : this.preloadJs,
    startHtml: startHtml.present ? startHtml.value : this.startHtml,
    startStyle: startStyle.present ? startStyle.value : this.startStyle,
    startJs: startJs.present ? startJs.value : this.startJs,
    searchUrl: searchUrl.present ? searchUrl.value : this.searchUrl,
  );
  RssSource copyWithCompanion(RssSourcesCompanion data) {
    return RssSource(
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      sourceIcon: data.sourceIcon.present
          ? data.sourceIcon.value
          : this.sourceIcon,
      sourceGroup: data.sourceGroup.present
          ? data.sourceGroup.value
          : this.sourceGroup,
      sourceComment: data.sourceComment.present
          ? data.sourceComment.value
          : this.sourceComment,
      variableComment: data.variableComment.present
          ? data.variableComment.value
          : this.variableComment,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      enabledCookieJar: data.enabledCookieJar.present
          ? data.enabledCookieJar.value
          : this.enabledCookieJar,
      enableJs: data.enableJs.present ? data.enableJs.value : this.enableJs,
      singleUrl: data.singleUrl.present ? data.singleUrl.value : this.singleUrl,
      loadWithBaseUrl: data.loadWithBaseUrl.present
          ? data.loadWithBaseUrl.value
          : this.loadWithBaseUrl,
      shouldOverrideUrlLoading: data.shouldOverrideUrlLoading.present
          ? data.shouldOverrideUrlLoading.value
          : this.shouldOverrideUrlLoading,
      articleStyle: data.articleStyle.present
          ? data.articleStyle.value
          : this.articleStyle,
      customOrder: data.customOrder.present
          ? data.customOrder.value
          : this.customOrder,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
      type: data.type.present ? data.type.value : this.type,
      showWebLog: data.showWebLog.present
          ? data.showWebLog.value
          : this.showWebLog,
      preload: data.preload.present ? data.preload.value : this.preload,
      cacheFirst: data.cacheFirst.present
          ? data.cacheFirst.value
          : this.cacheFirst,
      jsLib: data.jsLib.present ? data.jsLib.value : this.jsLib,
      concurrentRate: data.concurrentRate.present
          ? data.concurrentRate.value
          : this.concurrentRate,
      header: data.header.present ? data.header.value : this.header,
      loginUrl: data.loginUrl.present ? data.loginUrl.value : this.loginUrl,
      loginUi: data.loginUi.present ? data.loginUi.value : this.loginUi,
      loginCheckJs: data.loginCheckJs.present
          ? data.loginCheckJs.value
          : this.loginCheckJs,
      coverDecodeJs: data.coverDecodeJs.present
          ? data.coverDecodeJs.value
          : this.coverDecodeJs,
      sortUrl: data.sortUrl.present ? data.sortUrl.value : this.sortUrl,
      ruleArticles: data.ruleArticles.present
          ? data.ruleArticles.value
          : this.ruleArticles,
      ruleNextPage: data.ruleNextPage.present
          ? data.ruleNextPage.value
          : this.ruleNextPage,
      ruleTitle: data.ruleTitle.present ? data.ruleTitle.value : this.ruleTitle,
      rulePubDate: data.rulePubDate.present
          ? data.rulePubDate.value
          : this.rulePubDate,
      ruleDescription: data.ruleDescription.present
          ? data.ruleDescription.value
          : this.ruleDescription,
      ruleImage: data.ruleImage.present ? data.ruleImage.value : this.ruleImage,
      ruleLink: data.ruleLink.present ? data.ruleLink.value : this.ruleLink,
      ruleContent: data.ruleContent.present
          ? data.ruleContent.value
          : this.ruleContent,
      contentWhitelist: data.contentWhitelist.present
          ? data.contentWhitelist.value
          : this.contentWhitelist,
      contentBlacklist: data.contentBlacklist.present
          ? data.contentBlacklist.value
          : this.contentBlacklist,
      style: data.style.present ? data.style.value : this.style,
      injectJs: data.injectJs.present ? data.injectJs.value : this.injectJs,
      preloadJs: data.preloadJs.present ? data.preloadJs.value : this.preloadJs,
      startHtml: data.startHtml.present ? data.startHtml.value : this.startHtml,
      startStyle: data.startStyle.present
          ? data.startStyle.value
          : this.startStyle,
      startJs: data.startJs.present ? data.startJs.value : this.startJs,
      searchUrl: data.searchUrl.present ? data.searchUrl.value : this.searchUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RssSource(')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceIcon: $sourceIcon, ')
          ..write('sourceGroup: $sourceGroup, ')
          ..write('sourceComment: $sourceComment, ')
          ..write('variableComment: $variableComment, ')
          ..write('enabled: $enabled, ')
          ..write('enabledCookieJar: $enabledCookieJar, ')
          ..write('enableJs: $enableJs, ')
          ..write('singleUrl: $singleUrl, ')
          ..write('loadWithBaseUrl: $loadWithBaseUrl, ')
          ..write('shouldOverrideUrlLoading: $shouldOverrideUrlLoading, ')
          ..write('articleStyle: $articleStyle, ')
          ..write('customOrder: $customOrder, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('type: $type, ')
          ..write('showWebLog: $showWebLog, ')
          ..write('preload: $preload, ')
          ..write('cacheFirst: $cacheFirst, ')
          ..write('jsLib: $jsLib, ')
          ..write('concurrentRate: $concurrentRate, ')
          ..write('header: $header, ')
          ..write('loginUrl: $loginUrl, ')
          ..write('loginUi: $loginUi, ')
          ..write('loginCheckJs: $loginCheckJs, ')
          ..write('coverDecodeJs: $coverDecodeJs, ')
          ..write('sortUrl: $sortUrl, ')
          ..write('ruleArticles: $ruleArticles, ')
          ..write('ruleNextPage: $ruleNextPage, ')
          ..write('ruleTitle: $ruleTitle, ')
          ..write('rulePubDate: $rulePubDate, ')
          ..write('ruleDescription: $ruleDescription, ')
          ..write('ruleImage: $ruleImage, ')
          ..write('ruleLink: $ruleLink, ')
          ..write('ruleContent: $ruleContent, ')
          ..write('contentWhitelist: $contentWhitelist, ')
          ..write('contentBlacklist: $contentBlacklist, ')
          ..write('style: $style, ')
          ..write('injectJs: $injectJs, ')
          ..write('preloadJs: $preloadJs, ')
          ..write('startHtml: $startHtml, ')
          ..write('startStyle: $startStyle, ')
          ..write('startJs: $startJs, ')
          ..write('searchUrl: $searchUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    sourceUrl,
    sourceName,
    sourceIcon,
    sourceGroup,
    sourceComment,
    variableComment,
    enabled,
    enabledCookieJar,
    enableJs,
    singleUrl,
    loadWithBaseUrl,
    shouldOverrideUrlLoading,
    articleStyle,
    customOrder,
    lastUpdateTime,
    type,
    showWebLog,
    preload,
    cacheFirst,
    jsLib,
    concurrentRate,
    header,
    loginUrl,
    loginUi,
    loginCheckJs,
    coverDecodeJs,
    sortUrl,
    ruleArticles,
    ruleNextPage,
    ruleTitle,
    rulePubDate,
    ruleDescription,
    ruleImage,
    ruleLink,
    ruleContent,
    contentWhitelist,
    contentBlacklist,
    style,
    injectJs,
    preloadJs,
    startHtml,
    startStyle,
    startJs,
    searchUrl,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RssSource &&
          other.sourceUrl == this.sourceUrl &&
          other.sourceName == this.sourceName &&
          other.sourceIcon == this.sourceIcon &&
          other.sourceGroup == this.sourceGroup &&
          other.sourceComment == this.sourceComment &&
          other.variableComment == this.variableComment &&
          other.enabled == this.enabled &&
          other.enabledCookieJar == this.enabledCookieJar &&
          other.enableJs == this.enableJs &&
          other.singleUrl == this.singleUrl &&
          other.loadWithBaseUrl == this.loadWithBaseUrl &&
          other.shouldOverrideUrlLoading == this.shouldOverrideUrlLoading &&
          other.articleStyle == this.articleStyle &&
          other.customOrder == this.customOrder &&
          other.lastUpdateTime == this.lastUpdateTime &&
          other.type == this.type &&
          other.showWebLog == this.showWebLog &&
          other.preload == this.preload &&
          other.cacheFirst == this.cacheFirst &&
          other.jsLib == this.jsLib &&
          other.concurrentRate == this.concurrentRate &&
          other.header == this.header &&
          other.loginUrl == this.loginUrl &&
          other.loginUi == this.loginUi &&
          other.loginCheckJs == this.loginCheckJs &&
          other.coverDecodeJs == this.coverDecodeJs &&
          other.sortUrl == this.sortUrl &&
          other.ruleArticles == this.ruleArticles &&
          other.ruleNextPage == this.ruleNextPage &&
          other.ruleTitle == this.ruleTitle &&
          other.rulePubDate == this.rulePubDate &&
          other.ruleDescription == this.ruleDescription &&
          other.ruleImage == this.ruleImage &&
          other.ruleLink == this.ruleLink &&
          other.ruleContent == this.ruleContent &&
          other.contentWhitelist == this.contentWhitelist &&
          other.contentBlacklist == this.contentBlacklist &&
          other.style == this.style &&
          other.injectJs == this.injectJs &&
          other.preloadJs == this.preloadJs &&
          other.startHtml == this.startHtml &&
          other.startStyle == this.startStyle &&
          other.startJs == this.startJs &&
          other.searchUrl == this.searchUrl);
}

class RssSourcesCompanion extends UpdateCompanion<RssSource> {
  final Value<String> sourceUrl;
  final Value<String> sourceName;
  final Value<String> sourceIcon;
  final Value<String?> sourceGroup;
  final Value<String?> sourceComment;
  final Value<String?> variableComment;
  final Value<bool> enabled;
  final Value<bool> enabledCookieJar;
  final Value<bool> enableJs;
  final Value<bool> singleUrl;
  final Value<bool> loadWithBaseUrl;
  final Value<bool?> shouldOverrideUrlLoading;
  final Value<int> articleStyle;
  final Value<int> customOrder;
  final Value<int> lastUpdateTime;
  final Value<int> type;
  final Value<int> showWebLog;
  final Value<int> preload;
  final Value<int> cacheFirst;
  final Value<String?> jsLib;
  final Value<String?> concurrentRate;
  final Value<String?> header;
  final Value<String?> loginUrl;
  final Value<String?> loginUi;
  final Value<String?> loginCheckJs;
  final Value<String?> coverDecodeJs;
  final Value<String?> sortUrl;
  final Value<String?> ruleArticles;
  final Value<String?> ruleNextPage;
  final Value<String?> ruleTitle;
  final Value<String?> rulePubDate;
  final Value<String?> ruleDescription;
  final Value<String?> ruleImage;
  final Value<String?> ruleLink;
  final Value<String?> ruleContent;
  final Value<String?> contentWhitelist;
  final Value<String?> contentBlacklist;
  final Value<String?> style;
  final Value<String?> injectJs;
  final Value<String?> preloadJs;
  final Value<String?> startHtml;
  final Value<String?> startStyle;
  final Value<String?> startJs;
  final Value<String?> searchUrl;
  final Value<int> rowid;
  const RssSourcesCompanion({
    this.sourceUrl = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.sourceIcon = const Value.absent(),
    this.sourceGroup = const Value.absent(),
    this.sourceComment = const Value.absent(),
    this.variableComment = const Value.absent(),
    this.enabled = const Value.absent(),
    this.enabledCookieJar = const Value.absent(),
    this.enableJs = const Value.absent(),
    this.singleUrl = const Value.absent(),
    this.loadWithBaseUrl = const Value.absent(),
    this.shouldOverrideUrlLoading = const Value.absent(),
    this.articleStyle = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.type = const Value.absent(),
    this.showWebLog = const Value.absent(),
    this.preload = const Value.absent(),
    this.cacheFirst = const Value.absent(),
    this.jsLib = const Value.absent(),
    this.concurrentRate = const Value.absent(),
    this.header = const Value.absent(),
    this.loginUrl = const Value.absent(),
    this.loginUi = const Value.absent(),
    this.loginCheckJs = const Value.absent(),
    this.coverDecodeJs = const Value.absent(),
    this.sortUrl = const Value.absent(),
    this.ruleArticles = const Value.absent(),
    this.ruleNextPage = const Value.absent(),
    this.ruleTitle = const Value.absent(),
    this.rulePubDate = const Value.absent(),
    this.ruleDescription = const Value.absent(),
    this.ruleImage = const Value.absent(),
    this.ruleLink = const Value.absent(),
    this.ruleContent = const Value.absent(),
    this.contentWhitelist = const Value.absent(),
    this.contentBlacklist = const Value.absent(),
    this.style = const Value.absent(),
    this.injectJs = const Value.absent(),
    this.preloadJs = const Value.absent(),
    this.startHtml = const Value.absent(),
    this.startStyle = const Value.absent(),
    this.startJs = const Value.absent(),
    this.searchUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RssSourcesCompanion.insert({
    required String sourceUrl,
    this.sourceName = const Value.absent(),
    this.sourceIcon = const Value.absent(),
    this.sourceGroup = const Value.absent(),
    this.sourceComment = const Value.absent(),
    this.variableComment = const Value.absent(),
    this.enabled = const Value.absent(),
    this.enabledCookieJar = const Value.absent(),
    this.enableJs = const Value.absent(),
    this.singleUrl = const Value.absent(),
    this.loadWithBaseUrl = const Value.absent(),
    this.shouldOverrideUrlLoading = const Value.absent(),
    this.articleStyle = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.type = const Value.absent(),
    this.showWebLog = const Value.absent(),
    this.preload = const Value.absent(),
    this.cacheFirst = const Value.absent(),
    this.jsLib = const Value.absent(),
    this.concurrentRate = const Value.absent(),
    this.header = const Value.absent(),
    this.loginUrl = const Value.absent(),
    this.loginUi = const Value.absent(),
    this.loginCheckJs = const Value.absent(),
    this.coverDecodeJs = const Value.absent(),
    this.sortUrl = const Value.absent(),
    this.ruleArticles = const Value.absent(),
    this.ruleNextPage = const Value.absent(),
    this.ruleTitle = const Value.absent(),
    this.rulePubDate = const Value.absent(),
    this.ruleDescription = const Value.absent(),
    this.ruleImage = const Value.absent(),
    this.ruleLink = const Value.absent(),
    this.ruleContent = const Value.absent(),
    this.contentWhitelist = const Value.absent(),
    this.contentBlacklist = const Value.absent(),
    this.style = const Value.absent(),
    this.injectJs = const Value.absent(),
    this.preloadJs = const Value.absent(),
    this.startHtml = const Value.absent(),
    this.startStyle = const Value.absent(),
    this.startJs = const Value.absent(),
    this.searchUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceUrl = Value(sourceUrl);
  static Insertable<RssSource> custom({
    Expression<String>? sourceUrl,
    Expression<String>? sourceName,
    Expression<String>? sourceIcon,
    Expression<String>? sourceGroup,
    Expression<String>? sourceComment,
    Expression<String>? variableComment,
    Expression<bool>? enabled,
    Expression<bool>? enabledCookieJar,
    Expression<bool>? enableJs,
    Expression<bool>? singleUrl,
    Expression<bool>? loadWithBaseUrl,
    Expression<bool>? shouldOverrideUrlLoading,
    Expression<int>? articleStyle,
    Expression<int>? customOrder,
    Expression<int>? lastUpdateTime,
    Expression<int>? type,
    Expression<int>? showWebLog,
    Expression<int>? preload,
    Expression<int>? cacheFirst,
    Expression<String>? jsLib,
    Expression<String>? concurrentRate,
    Expression<String>? header,
    Expression<String>? loginUrl,
    Expression<String>? loginUi,
    Expression<String>? loginCheckJs,
    Expression<String>? coverDecodeJs,
    Expression<String>? sortUrl,
    Expression<String>? ruleArticles,
    Expression<String>? ruleNextPage,
    Expression<String>? ruleTitle,
    Expression<String>? rulePubDate,
    Expression<String>? ruleDescription,
    Expression<String>? ruleImage,
    Expression<String>? ruleLink,
    Expression<String>? ruleContent,
    Expression<String>? contentWhitelist,
    Expression<String>? contentBlacklist,
    Expression<String>? style,
    Expression<String>? injectJs,
    Expression<String>? preloadJs,
    Expression<String>? startHtml,
    Expression<String>? startStyle,
    Expression<String>? startJs,
    Expression<String>? searchUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (sourceName != null) 'source_name': sourceName,
      if (sourceIcon != null) 'source_icon': sourceIcon,
      if (sourceGroup != null) 'source_group': sourceGroup,
      if (sourceComment != null) 'source_comment': sourceComment,
      if (variableComment != null) 'variable_comment': variableComment,
      if (enabled != null) 'enabled': enabled,
      if (enabledCookieJar != null) 'enabled_cookie_jar': enabledCookieJar,
      if (enableJs != null) 'enable_js': enableJs,
      if (singleUrl != null) 'single_url': singleUrl,
      if (loadWithBaseUrl != null) 'load_with_base_url': loadWithBaseUrl,
      if (shouldOverrideUrlLoading != null)
        'should_override_url_loading': shouldOverrideUrlLoading,
      if (articleStyle != null) 'article_style': articleStyle,
      if (customOrder != null) 'custom_order': customOrder,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
      if (type != null) 'type': type,
      if (showWebLog != null) 'show_web_log': showWebLog,
      if (preload != null) 'preload': preload,
      if (cacheFirst != null) 'cache_first': cacheFirst,
      if (jsLib != null) 'js_lib': jsLib,
      if (concurrentRate != null) 'concurrent_rate': concurrentRate,
      if (header != null) 'header': header,
      if (loginUrl != null) 'login_url': loginUrl,
      if (loginUi != null) 'login_ui': loginUi,
      if (loginCheckJs != null) 'login_check_js': loginCheckJs,
      if (coverDecodeJs != null) 'cover_decode_js': coverDecodeJs,
      if (sortUrl != null) 'sort_url': sortUrl,
      if (ruleArticles != null) 'rule_articles': ruleArticles,
      if (ruleNextPage != null) 'rule_next_page': ruleNextPage,
      if (ruleTitle != null) 'rule_title': ruleTitle,
      if (rulePubDate != null) 'rule_pub_date': rulePubDate,
      if (ruleDescription != null) 'rule_description': ruleDescription,
      if (ruleImage != null) 'rule_image': ruleImage,
      if (ruleLink != null) 'rule_link': ruleLink,
      if (ruleContent != null) 'rule_content': ruleContent,
      if (contentWhitelist != null) 'content_whitelist': contentWhitelist,
      if (contentBlacklist != null) 'content_blacklist': contentBlacklist,
      if (style != null) 'style': style,
      if (injectJs != null) 'inject_js': injectJs,
      if (preloadJs != null) 'preload_js': preloadJs,
      if (startHtml != null) 'start_html': startHtml,
      if (startStyle != null) 'start_style': startStyle,
      if (startJs != null) 'start_js': startJs,
      if (searchUrl != null) 'search_url': searchUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RssSourcesCompanion copyWith({
    Value<String>? sourceUrl,
    Value<String>? sourceName,
    Value<String>? sourceIcon,
    Value<String?>? sourceGroup,
    Value<String?>? sourceComment,
    Value<String?>? variableComment,
    Value<bool>? enabled,
    Value<bool>? enabledCookieJar,
    Value<bool>? enableJs,
    Value<bool>? singleUrl,
    Value<bool>? loadWithBaseUrl,
    Value<bool?>? shouldOverrideUrlLoading,
    Value<int>? articleStyle,
    Value<int>? customOrder,
    Value<int>? lastUpdateTime,
    Value<int>? type,
    Value<int>? showWebLog,
    Value<int>? preload,
    Value<int>? cacheFirst,
    Value<String?>? jsLib,
    Value<String?>? concurrentRate,
    Value<String?>? header,
    Value<String?>? loginUrl,
    Value<String?>? loginUi,
    Value<String?>? loginCheckJs,
    Value<String?>? coverDecodeJs,
    Value<String?>? sortUrl,
    Value<String?>? ruleArticles,
    Value<String?>? ruleNextPage,
    Value<String?>? ruleTitle,
    Value<String?>? rulePubDate,
    Value<String?>? ruleDescription,
    Value<String?>? ruleImage,
    Value<String?>? ruleLink,
    Value<String?>? ruleContent,
    Value<String?>? contentWhitelist,
    Value<String?>? contentBlacklist,
    Value<String?>? style,
    Value<String?>? injectJs,
    Value<String?>? preloadJs,
    Value<String?>? startHtml,
    Value<String?>? startStyle,
    Value<String?>? startJs,
    Value<String?>? searchUrl,
    Value<int>? rowid,
  }) {
    return RssSourcesCompanion(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceName: sourceName ?? this.sourceName,
      sourceIcon: sourceIcon ?? this.sourceIcon,
      sourceGroup: sourceGroup ?? this.sourceGroup,
      sourceComment: sourceComment ?? this.sourceComment,
      variableComment: variableComment ?? this.variableComment,
      enabled: enabled ?? this.enabled,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      enableJs: enableJs ?? this.enableJs,
      singleUrl: singleUrl ?? this.singleUrl,
      loadWithBaseUrl: loadWithBaseUrl ?? this.loadWithBaseUrl,
      shouldOverrideUrlLoading:
          shouldOverrideUrlLoading ?? this.shouldOverrideUrlLoading,
      articleStyle: articleStyle ?? this.articleStyle,
      customOrder: customOrder ?? this.customOrder,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      type: type ?? this.type,
      showWebLog: showWebLog ?? this.showWebLog,
      preload: preload ?? this.preload,
      cacheFirst: cacheFirst ?? this.cacheFirst,
      jsLib: jsLib ?? this.jsLib,
      concurrentRate: concurrentRate ?? this.concurrentRate,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      loginCheckJs: loginCheckJs ?? this.loginCheckJs,
      coverDecodeJs: coverDecodeJs ?? this.coverDecodeJs,
      sortUrl: sortUrl ?? this.sortUrl,
      ruleArticles: ruleArticles ?? this.ruleArticles,
      ruleNextPage: ruleNextPage ?? this.ruleNextPage,
      ruleTitle: ruleTitle ?? this.ruleTitle,
      rulePubDate: rulePubDate ?? this.rulePubDate,
      ruleDescription: ruleDescription ?? this.ruleDescription,
      ruleImage: ruleImage ?? this.ruleImage,
      ruleLink: ruleLink ?? this.ruleLink,
      ruleContent: ruleContent ?? this.ruleContent,
      contentWhitelist: contentWhitelist ?? this.contentWhitelist,
      contentBlacklist: contentBlacklist ?? this.contentBlacklist,
      style: style ?? this.style,
      injectJs: injectJs ?? this.injectJs,
      preloadJs: preloadJs ?? this.preloadJs,
      startHtml: startHtml ?? this.startHtml,
      startStyle: startStyle ?? this.startStyle,
      startJs: startJs ?? this.startJs,
      searchUrl: searchUrl ?? this.searchUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (sourceIcon.present) {
      map['source_icon'] = Variable<String>(sourceIcon.value);
    }
    if (sourceGroup.present) {
      map['source_group'] = Variable<String>(sourceGroup.value);
    }
    if (sourceComment.present) {
      map['source_comment'] = Variable<String>(sourceComment.value);
    }
    if (variableComment.present) {
      map['variable_comment'] = Variable<String>(variableComment.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (enabledCookieJar.present) {
      map['enabled_cookie_jar'] = Variable<bool>(enabledCookieJar.value);
    }
    if (enableJs.present) {
      map['enable_js'] = Variable<bool>(enableJs.value);
    }
    if (singleUrl.present) {
      map['single_url'] = Variable<bool>(singleUrl.value);
    }
    if (loadWithBaseUrl.present) {
      map['load_with_base_url'] = Variable<bool>(loadWithBaseUrl.value);
    }
    if (shouldOverrideUrlLoading.present) {
      map['should_override_url_loading'] = Variable<bool>(
        shouldOverrideUrlLoading.value,
      );
    }
    if (articleStyle.present) {
      map['article_style'] = Variable<int>(articleStyle.value);
    }
    if (customOrder.present) {
      map['custom_order'] = Variable<int>(customOrder.value);
    }
    if (lastUpdateTime.present) {
      map['last_update_time'] = Variable<int>(lastUpdateTime.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (showWebLog.present) {
      map['show_web_log'] = Variable<int>(showWebLog.value);
    }
    if (preload.present) {
      map['preload'] = Variable<int>(preload.value);
    }
    if (cacheFirst.present) {
      map['cache_first'] = Variable<int>(cacheFirst.value);
    }
    if (jsLib.present) {
      map['js_lib'] = Variable<String>(jsLib.value);
    }
    if (concurrentRate.present) {
      map['concurrent_rate'] = Variable<String>(concurrentRate.value);
    }
    if (header.present) {
      map['header'] = Variable<String>(header.value);
    }
    if (loginUrl.present) {
      map['login_url'] = Variable<String>(loginUrl.value);
    }
    if (loginUi.present) {
      map['login_ui'] = Variable<String>(loginUi.value);
    }
    if (loginCheckJs.present) {
      map['login_check_js'] = Variable<String>(loginCheckJs.value);
    }
    if (coverDecodeJs.present) {
      map['cover_decode_js'] = Variable<String>(coverDecodeJs.value);
    }
    if (sortUrl.present) {
      map['sort_url'] = Variable<String>(sortUrl.value);
    }
    if (ruleArticles.present) {
      map['rule_articles'] = Variable<String>(ruleArticles.value);
    }
    if (ruleNextPage.present) {
      map['rule_next_page'] = Variable<String>(ruleNextPage.value);
    }
    if (ruleTitle.present) {
      map['rule_title'] = Variable<String>(ruleTitle.value);
    }
    if (rulePubDate.present) {
      map['rule_pub_date'] = Variable<String>(rulePubDate.value);
    }
    if (ruleDescription.present) {
      map['rule_description'] = Variable<String>(ruleDescription.value);
    }
    if (ruleImage.present) {
      map['rule_image'] = Variable<String>(ruleImage.value);
    }
    if (ruleLink.present) {
      map['rule_link'] = Variable<String>(ruleLink.value);
    }
    if (ruleContent.present) {
      map['rule_content'] = Variable<String>(ruleContent.value);
    }
    if (contentWhitelist.present) {
      map['content_whitelist'] = Variable<String>(contentWhitelist.value);
    }
    if (contentBlacklist.present) {
      map['content_blacklist'] = Variable<String>(contentBlacklist.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (injectJs.present) {
      map['inject_js'] = Variable<String>(injectJs.value);
    }
    if (preloadJs.present) {
      map['preload_js'] = Variable<String>(preloadJs.value);
    }
    if (startHtml.present) {
      map['start_html'] = Variable<String>(startHtml.value);
    }
    if (startStyle.present) {
      map['start_style'] = Variable<String>(startStyle.value);
    }
    if (startJs.present) {
      map['start_js'] = Variable<String>(startJs.value);
    }
    if (searchUrl.present) {
      map['search_url'] = Variable<String>(searchUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RssSourcesCompanion(')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceIcon: $sourceIcon, ')
          ..write('sourceGroup: $sourceGroup, ')
          ..write('sourceComment: $sourceComment, ')
          ..write('variableComment: $variableComment, ')
          ..write('enabled: $enabled, ')
          ..write('enabledCookieJar: $enabledCookieJar, ')
          ..write('enableJs: $enableJs, ')
          ..write('singleUrl: $singleUrl, ')
          ..write('loadWithBaseUrl: $loadWithBaseUrl, ')
          ..write('shouldOverrideUrlLoading: $shouldOverrideUrlLoading, ')
          ..write('articleStyle: $articleStyle, ')
          ..write('customOrder: $customOrder, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('type: $type, ')
          ..write('showWebLog: $showWebLog, ')
          ..write('preload: $preload, ')
          ..write('cacheFirst: $cacheFirst, ')
          ..write('jsLib: $jsLib, ')
          ..write('concurrentRate: $concurrentRate, ')
          ..write('header: $header, ')
          ..write('loginUrl: $loginUrl, ')
          ..write('loginUi: $loginUi, ')
          ..write('loginCheckJs: $loginCheckJs, ')
          ..write('coverDecodeJs: $coverDecodeJs, ')
          ..write('sortUrl: $sortUrl, ')
          ..write('ruleArticles: $ruleArticles, ')
          ..write('ruleNextPage: $ruleNextPage, ')
          ..write('ruleTitle: $ruleTitle, ')
          ..write('rulePubDate: $rulePubDate, ')
          ..write('ruleDescription: $ruleDescription, ')
          ..write('ruleImage: $ruleImage, ')
          ..write('ruleLink: $ruleLink, ')
          ..write('ruleContent: $ruleContent, ')
          ..write('contentWhitelist: $contentWhitelist, ')
          ..write('contentBlacklist: $contentBlacklist, ')
          ..write('style: $style, ')
          ..write('injectJs: $injectJs, ')
          ..write('preloadJs: $preloadJs, ')
          ..write('startHtml: $startHtml, ')
          ..write('startStyle: $startStyle, ')
          ..write('startJs: $startJs, ')
          ..write('searchUrl: $searchUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RssArticlesTable extends RssArticles
    with TableInfo<$RssArticlesTable, RssArticle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RssArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<String> sort = GeneratedColumn<String>(
    'sort',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pubDateMeta = const VerificationMeta(
    'pubDate',
  );
  @override
  late final GeneratedColumn<String> pubDate = GeneratedColumn<String>(
    'pub_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
    'group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('默认分组'),
  );
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
    'read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _variableMeta = const VerificationMeta(
    'variable',
  );
  @override
  late final GeneratedColumn<String> variable = GeneratedColumn<String>(
    'variable',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durPosMeta = const VerificationMeta('durPos');
  @override
  late final GeneratedColumn<int> durPos = GeneratedColumn<int>(
    'dur_pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    origin,
    link,
    sort,
    title,
    order,
    pubDate,
    description,
    content,
    image,
    group,
    read,
    variable,
    type,
    durPos,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rss_articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<RssArticle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    } else if (isInserting) {
      context.missing(_linkMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    } else if (isInserting) {
      context.missing(_sortMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    }
    if (data.containsKey('pub_date')) {
      context.handle(
        _pubDateMeta,
        pubDate.isAcceptableOrUnknown(data['pub_date']!, _pubDateMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    }
    if (data.containsKey('group')) {
      context.handle(
        _groupMeta,
        group.isAcceptableOrUnknown(data['group']!, _groupMeta),
      );
    }
    if (data.containsKey('read')) {
      context.handle(
        _readMeta,
        read.isAcceptableOrUnknown(data['read']!, _readMeta),
      );
    }
    if (data.containsKey('variable')) {
      context.handle(
        _variableMeta,
        variable.isAcceptableOrUnknown(data['variable']!, _variableMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('dur_pos')) {
      context.handle(
        _durPosMeta,
        durPos.isAcceptableOrUnknown(data['dur_pos']!, _durPosMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {origin, link, sort};
  @override
  RssArticle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RssArticle(
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      )!,
      pubDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pub_date'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image'],
      ),
      group: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group'],
      )!,
      read: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read'],
      )!,
      variable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variable'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      durPos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dur_pos'],
      )!,
    );
  }

  @override
  $RssArticlesTable createAlias(String alias) {
    return $RssArticlesTable(attachedDatabase, alias);
  }
}

class RssArticle extends DataClass implements Insertable<RssArticle> {
  final String origin;
  final String link;
  final String sort;
  final String title;
  final int order;
  final String? pubDate;
  final String? description;
  final String? content;
  final String? image;
  final String group;
  final bool read;
  final String? variable;
  final int type;
  final int durPos;
  const RssArticle({
    required this.origin,
    required this.link,
    required this.sort,
    required this.title,
    required this.order,
    this.pubDate,
    this.description,
    this.content,
    this.image,
    required this.group,
    required this.read,
    this.variable,
    required this.type,
    required this.durPos,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['origin'] = Variable<String>(origin);
    map['link'] = Variable<String>(link);
    map['sort'] = Variable<String>(sort);
    map['title'] = Variable<String>(title);
    map['order'] = Variable<int>(order);
    if (!nullToAbsent || pubDate != null) {
      map['pub_date'] = Variable<String>(pubDate);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || image != null) {
      map['image'] = Variable<String>(image);
    }
    map['group'] = Variable<String>(group);
    map['read'] = Variable<bool>(read);
    if (!nullToAbsent || variable != null) {
      map['variable'] = Variable<String>(variable);
    }
    map['type'] = Variable<int>(type);
    map['dur_pos'] = Variable<int>(durPos);
    return map;
  }

  RssArticlesCompanion toCompanion(bool nullToAbsent) {
    return RssArticlesCompanion(
      origin: Value(origin),
      link: Value(link),
      sort: Value(sort),
      title: Value(title),
      order: Value(order),
      pubDate: pubDate == null && nullToAbsent
          ? const Value.absent()
          : Value(pubDate),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      image: image == null && nullToAbsent
          ? const Value.absent()
          : Value(image),
      group: Value(group),
      read: Value(read),
      variable: variable == null && nullToAbsent
          ? const Value.absent()
          : Value(variable),
      type: Value(type),
      durPos: Value(durPos),
    );
  }

  factory RssArticle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RssArticle(
      origin: serializer.fromJson<String>(json['origin']),
      link: serializer.fromJson<String>(json['link']),
      sort: serializer.fromJson<String>(json['sort']),
      title: serializer.fromJson<String>(json['title']),
      order: serializer.fromJson<int>(json['order']),
      pubDate: serializer.fromJson<String?>(json['pubDate']),
      description: serializer.fromJson<String?>(json['description']),
      content: serializer.fromJson<String?>(json['content']),
      image: serializer.fromJson<String?>(json['image']),
      group: serializer.fromJson<String>(json['group']),
      read: serializer.fromJson<bool>(json['read']),
      variable: serializer.fromJson<String?>(json['variable']),
      type: serializer.fromJson<int>(json['type']),
      durPos: serializer.fromJson<int>(json['durPos']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'origin': serializer.toJson<String>(origin),
      'link': serializer.toJson<String>(link),
      'sort': serializer.toJson<String>(sort),
      'title': serializer.toJson<String>(title),
      'order': serializer.toJson<int>(order),
      'pubDate': serializer.toJson<String?>(pubDate),
      'description': serializer.toJson<String?>(description),
      'content': serializer.toJson<String?>(content),
      'image': serializer.toJson<String?>(image),
      'group': serializer.toJson<String>(group),
      'read': serializer.toJson<bool>(read),
      'variable': serializer.toJson<String?>(variable),
      'type': serializer.toJson<int>(type),
      'durPos': serializer.toJson<int>(durPos),
    };
  }

  RssArticle copyWith({
    String? origin,
    String? link,
    String? sort,
    String? title,
    int? order,
    Value<String?> pubDate = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> image = const Value.absent(),
    String? group,
    bool? read,
    Value<String?> variable = const Value.absent(),
    int? type,
    int? durPos,
  }) => RssArticle(
    origin: origin ?? this.origin,
    link: link ?? this.link,
    sort: sort ?? this.sort,
    title: title ?? this.title,
    order: order ?? this.order,
    pubDate: pubDate.present ? pubDate.value : this.pubDate,
    description: description.present ? description.value : this.description,
    content: content.present ? content.value : this.content,
    image: image.present ? image.value : this.image,
    group: group ?? this.group,
    read: read ?? this.read,
    variable: variable.present ? variable.value : this.variable,
    type: type ?? this.type,
    durPos: durPos ?? this.durPos,
  );
  RssArticle copyWithCompanion(RssArticlesCompanion data) {
    return RssArticle(
      origin: data.origin.present ? data.origin.value : this.origin,
      link: data.link.present ? data.link.value : this.link,
      sort: data.sort.present ? data.sort.value : this.sort,
      title: data.title.present ? data.title.value : this.title,
      order: data.order.present ? data.order.value : this.order,
      pubDate: data.pubDate.present ? data.pubDate.value : this.pubDate,
      description: data.description.present
          ? data.description.value
          : this.description,
      content: data.content.present ? data.content.value : this.content,
      image: data.image.present ? data.image.value : this.image,
      group: data.group.present ? data.group.value : this.group,
      read: data.read.present ? data.read.value : this.read,
      variable: data.variable.present ? data.variable.value : this.variable,
      type: data.type.present ? data.type.value : this.type,
      durPos: data.durPos.present ? data.durPos.value : this.durPos,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RssArticle(')
          ..write('origin: $origin, ')
          ..write('link: $link, ')
          ..write('sort: $sort, ')
          ..write('title: $title, ')
          ..write('order: $order, ')
          ..write('pubDate: $pubDate, ')
          ..write('description: $description, ')
          ..write('content: $content, ')
          ..write('image: $image, ')
          ..write('group: $group, ')
          ..write('read: $read, ')
          ..write('variable: $variable, ')
          ..write('type: $type, ')
          ..write('durPos: $durPos')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    origin,
    link,
    sort,
    title,
    order,
    pubDate,
    description,
    content,
    image,
    group,
    read,
    variable,
    type,
    durPos,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RssArticle &&
          other.origin == this.origin &&
          other.link == this.link &&
          other.sort == this.sort &&
          other.title == this.title &&
          other.order == this.order &&
          other.pubDate == this.pubDate &&
          other.description == this.description &&
          other.content == this.content &&
          other.image == this.image &&
          other.group == this.group &&
          other.read == this.read &&
          other.variable == this.variable &&
          other.type == this.type &&
          other.durPos == this.durPos);
}

class RssArticlesCompanion extends UpdateCompanion<RssArticle> {
  final Value<String> origin;
  final Value<String> link;
  final Value<String> sort;
  final Value<String> title;
  final Value<int> order;
  final Value<String?> pubDate;
  final Value<String?> description;
  final Value<String?> content;
  final Value<String?> image;
  final Value<String> group;
  final Value<bool> read;
  final Value<String?> variable;
  final Value<int> type;
  final Value<int> durPos;
  final Value<int> rowid;
  const RssArticlesCompanion({
    this.origin = const Value.absent(),
    this.link = const Value.absent(),
    this.sort = const Value.absent(),
    this.title = const Value.absent(),
    this.order = const Value.absent(),
    this.pubDate = const Value.absent(),
    this.description = const Value.absent(),
    this.content = const Value.absent(),
    this.image = const Value.absent(),
    this.group = const Value.absent(),
    this.read = const Value.absent(),
    this.variable = const Value.absent(),
    this.type = const Value.absent(),
    this.durPos = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RssArticlesCompanion.insert({
    required String origin,
    required String link,
    required String sort,
    this.title = const Value.absent(),
    this.order = const Value.absent(),
    this.pubDate = const Value.absent(),
    this.description = const Value.absent(),
    this.content = const Value.absent(),
    this.image = const Value.absent(),
    this.group = const Value.absent(),
    this.read = const Value.absent(),
    this.variable = const Value.absent(),
    this.type = const Value.absent(),
    this.durPos = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : origin = Value(origin),
       link = Value(link),
       sort = Value(sort);
  static Insertable<RssArticle> custom({
    Expression<String>? origin,
    Expression<String>? link,
    Expression<String>? sort,
    Expression<String>? title,
    Expression<int>? order,
    Expression<String>? pubDate,
    Expression<String>? description,
    Expression<String>? content,
    Expression<String>? image,
    Expression<String>? group,
    Expression<bool>? read,
    Expression<String>? variable,
    Expression<int>? type,
    Expression<int>? durPos,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (origin != null) 'origin': origin,
      if (link != null) 'link': link,
      if (sort != null) 'sort': sort,
      if (title != null) 'title': title,
      if (order != null) 'order': order,
      if (pubDate != null) 'pub_date': pubDate,
      if (description != null) 'description': description,
      if (content != null) 'content': content,
      if (image != null) 'image': image,
      if (group != null) 'group': group,
      if (read != null) 'read': read,
      if (variable != null) 'variable': variable,
      if (type != null) 'type': type,
      if (durPos != null) 'dur_pos': durPos,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RssArticlesCompanion copyWith({
    Value<String>? origin,
    Value<String>? link,
    Value<String>? sort,
    Value<String>? title,
    Value<int>? order,
    Value<String?>? pubDate,
    Value<String?>? description,
    Value<String?>? content,
    Value<String?>? image,
    Value<String>? group,
    Value<bool>? read,
    Value<String?>? variable,
    Value<int>? type,
    Value<int>? durPos,
    Value<int>? rowid,
  }) {
    return RssArticlesCompanion(
      origin: origin ?? this.origin,
      link: link ?? this.link,
      sort: sort ?? this.sort,
      title: title ?? this.title,
      order: order ?? this.order,
      pubDate: pubDate ?? this.pubDate,
      description: description ?? this.description,
      content: content ?? this.content,
      image: image ?? this.image,
      group: group ?? this.group,
      read: read ?? this.read,
      variable: variable ?? this.variable,
      type: type ?? this.type,
      durPos: durPos ?? this.durPos,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (sort.present) {
      map['sort'] = Variable<String>(sort.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (pubDate.present) {
      map['pub_date'] = Variable<String>(pubDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    if (variable.present) {
      map['variable'] = Variable<String>(variable.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (durPos.present) {
      map['dur_pos'] = Variable<int>(durPos.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RssArticlesCompanion(')
          ..write('origin: $origin, ')
          ..write('link: $link, ')
          ..write('sort: $sort, ')
          ..write('title: $title, ')
          ..write('order: $order, ')
          ..write('pubDate: $pubDate, ')
          ..write('description: $description, ')
          ..write('content: $content, ')
          ..write('image: $image, ')
          ..write('group: $group, ')
          ..write('read: $read, ')
          ..write('variable: $variable, ')
          ..write('type: $type, ')
          ..write('durPos: $durPos, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RssStarsTable extends RssStars with TableInfo<$RssStarsTable, RssStar> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RssStarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<String> sort = GeneratedColumn<String>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _starTimeMeta = const VerificationMeta(
    'starTime',
  );
  @override
  late final GeneratedColumn<int> starTime = GeneratedColumn<int>(
    'star_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pubDateMeta = const VerificationMeta(
    'pubDate',
  );
  @override
  late final GeneratedColumn<String> pubDate = GeneratedColumn<String>(
    'pub_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
    'group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('默认分组'),
  );
  static const VerificationMeta _variableMeta = const VerificationMeta(
    'variable',
  );
  @override
  late final GeneratedColumn<String> variable = GeneratedColumn<String>(
    'variable',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durPosMeta = const VerificationMeta('durPos');
  @override
  late final GeneratedColumn<int> durPos = GeneratedColumn<int>(
    'dur_pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    origin,
    link,
    sort,
    title,
    starTime,
    pubDate,
    description,
    content,
    image,
    group,
    variable,
    type,
    durPos,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rss_stars';
  @override
  VerificationContext validateIntegrity(
    Insertable<RssStar> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    } else if (isInserting) {
      context.missing(_linkMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('star_time')) {
      context.handle(
        _starTimeMeta,
        starTime.isAcceptableOrUnknown(data['star_time']!, _starTimeMeta),
      );
    }
    if (data.containsKey('pub_date')) {
      context.handle(
        _pubDateMeta,
        pubDate.isAcceptableOrUnknown(data['pub_date']!, _pubDateMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    }
    if (data.containsKey('group')) {
      context.handle(
        _groupMeta,
        group.isAcceptableOrUnknown(data['group']!, _groupMeta),
      );
    }
    if (data.containsKey('variable')) {
      context.handle(
        _variableMeta,
        variable.isAcceptableOrUnknown(data['variable']!, _variableMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('dur_pos')) {
      context.handle(
        _durPosMeta,
        durPos.isAcceptableOrUnknown(data['dur_pos']!, _durPosMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {origin, link};
  @override
  RssStar map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RssStar(
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      starTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}star_time'],
      )!,
      pubDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pub_date'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image'],
      ),
      group: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group'],
      )!,
      variable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variable'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      durPos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dur_pos'],
      )!,
    );
  }

  @override
  $RssStarsTable createAlias(String alias) {
    return $RssStarsTable(attachedDatabase, alias);
  }
}

class RssStar extends DataClass implements Insertable<RssStar> {
  final String origin;
  final String link;
  final String sort;
  final String title;
  final int starTime;
  final String? pubDate;
  final String? description;
  final String? content;
  final String? image;
  final String group;
  final String? variable;
  final int type;
  final int durPos;
  const RssStar({
    required this.origin,
    required this.link,
    required this.sort,
    required this.title,
    required this.starTime,
    this.pubDate,
    this.description,
    this.content,
    this.image,
    required this.group,
    this.variable,
    required this.type,
    required this.durPos,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['origin'] = Variable<String>(origin);
    map['link'] = Variable<String>(link);
    map['sort'] = Variable<String>(sort);
    map['title'] = Variable<String>(title);
    map['star_time'] = Variable<int>(starTime);
    if (!nullToAbsent || pubDate != null) {
      map['pub_date'] = Variable<String>(pubDate);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || image != null) {
      map['image'] = Variable<String>(image);
    }
    map['group'] = Variable<String>(group);
    if (!nullToAbsent || variable != null) {
      map['variable'] = Variable<String>(variable);
    }
    map['type'] = Variable<int>(type);
    map['dur_pos'] = Variable<int>(durPos);
    return map;
  }

  RssStarsCompanion toCompanion(bool nullToAbsent) {
    return RssStarsCompanion(
      origin: Value(origin),
      link: Value(link),
      sort: Value(sort),
      title: Value(title),
      starTime: Value(starTime),
      pubDate: pubDate == null && nullToAbsent
          ? const Value.absent()
          : Value(pubDate),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      image: image == null && nullToAbsent
          ? const Value.absent()
          : Value(image),
      group: Value(group),
      variable: variable == null && nullToAbsent
          ? const Value.absent()
          : Value(variable),
      type: Value(type),
      durPos: Value(durPos),
    );
  }

  factory RssStar.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RssStar(
      origin: serializer.fromJson<String>(json['origin']),
      link: serializer.fromJson<String>(json['link']),
      sort: serializer.fromJson<String>(json['sort']),
      title: serializer.fromJson<String>(json['title']),
      starTime: serializer.fromJson<int>(json['starTime']),
      pubDate: serializer.fromJson<String?>(json['pubDate']),
      description: serializer.fromJson<String?>(json['description']),
      content: serializer.fromJson<String?>(json['content']),
      image: serializer.fromJson<String?>(json['image']),
      group: serializer.fromJson<String>(json['group']),
      variable: serializer.fromJson<String?>(json['variable']),
      type: serializer.fromJson<int>(json['type']),
      durPos: serializer.fromJson<int>(json['durPos']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'origin': serializer.toJson<String>(origin),
      'link': serializer.toJson<String>(link),
      'sort': serializer.toJson<String>(sort),
      'title': serializer.toJson<String>(title),
      'starTime': serializer.toJson<int>(starTime),
      'pubDate': serializer.toJson<String?>(pubDate),
      'description': serializer.toJson<String?>(description),
      'content': serializer.toJson<String?>(content),
      'image': serializer.toJson<String?>(image),
      'group': serializer.toJson<String>(group),
      'variable': serializer.toJson<String?>(variable),
      'type': serializer.toJson<int>(type),
      'durPos': serializer.toJson<int>(durPos),
    };
  }

  RssStar copyWith({
    String? origin,
    String? link,
    String? sort,
    String? title,
    int? starTime,
    Value<String?> pubDate = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> image = const Value.absent(),
    String? group,
    Value<String?> variable = const Value.absent(),
    int? type,
    int? durPos,
  }) => RssStar(
    origin: origin ?? this.origin,
    link: link ?? this.link,
    sort: sort ?? this.sort,
    title: title ?? this.title,
    starTime: starTime ?? this.starTime,
    pubDate: pubDate.present ? pubDate.value : this.pubDate,
    description: description.present ? description.value : this.description,
    content: content.present ? content.value : this.content,
    image: image.present ? image.value : this.image,
    group: group ?? this.group,
    variable: variable.present ? variable.value : this.variable,
    type: type ?? this.type,
    durPos: durPos ?? this.durPos,
  );
  RssStar copyWithCompanion(RssStarsCompanion data) {
    return RssStar(
      origin: data.origin.present ? data.origin.value : this.origin,
      link: data.link.present ? data.link.value : this.link,
      sort: data.sort.present ? data.sort.value : this.sort,
      title: data.title.present ? data.title.value : this.title,
      starTime: data.starTime.present ? data.starTime.value : this.starTime,
      pubDate: data.pubDate.present ? data.pubDate.value : this.pubDate,
      description: data.description.present
          ? data.description.value
          : this.description,
      content: data.content.present ? data.content.value : this.content,
      image: data.image.present ? data.image.value : this.image,
      group: data.group.present ? data.group.value : this.group,
      variable: data.variable.present ? data.variable.value : this.variable,
      type: data.type.present ? data.type.value : this.type,
      durPos: data.durPos.present ? data.durPos.value : this.durPos,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RssStar(')
          ..write('origin: $origin, ')
          ..write('link: $link, ')
          ..write('sort: $sort, ')
          ..write('title: $title, ')
          ..write('starTime: $starTime, ')
          ..write('pubDate: $pubDate, ')
          ..write('description: $description, ')
          ..write('content: $content, ')
          ..write('image: $image, ')
          ..write('group: $group, ')
          ..write('variable: $variable, ')
          ..write('type: $type, ')
          ..write('durPos: $durPos')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    origin,
    link,
    sort,
    title,
    starTime,
    pubDate,
    description,
    content,
    image,
    group,
    variable,
    type,
    durPos,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RssStar &&
          other.origin == this.origin &&
          other.link == this.link &&
          other.sort == this.sort &&
          other.title == this.title &&
          other.starTime == this.starTime &&
          other.pubDate == this.pubDate &&
          other.description == this.description &&
          other.content == this.content &&
          other.image == this.image &&
          other.group == this.group &&
          other.variable == this.variable &&
          other.type == this.type &&
          other.durPos == this.durPos);
}

class RssStarsCompanion extends UpdateCompanion<RssStar> {
  final Value<String> origin;
  final Value<String> link;
  final Value<String> sort;
  final Value<String> title;
  final Value<int> starTime;
  final Value<String?> pubDate;
  final Value<String?> description;
  final Value<String?> content;
  final Value<String?> image;
  final Value<String> group;
  final Value<String?> variable;
  final Value<int> type;
  final Value<int> durPos;
  final Value<int> rowid;
  const RssStarsCompanion({
    this.origin = const Value.absent(),
    this.link = const Value.absent(),
    this.sort = const Value.absent(),
    this.title = const Value.absent(),
    this.starTime = const Value.absent(),
    this.pubDate = const Value.absent(),
    this.description = const Value.absent(),
    this.content = const Value.absent(),
    this.image = const Value.absent(),
    this.group = const Value.absent(),
    this.variable = const Value.absent(),
    this.type = const Value.absent(),
    this.durPos = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RssStarsCompanion.insert({
    required String origin,
    required String link,
    this.sort = const Value.absent(),
    this.title = const Value.absent(),
    this.starTime = const Value.absent(),
    this.pubDate = const Value.absent(),
    this.description = const Value.absent(),
    this.content = const Value.absent(),
    this.image = const Value.absent(),
    this.group = const Value.absent(),
    this.variable = const Value.absent(),
    this.type = const Value.absent(),
    this.durPos = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : origin = Value(origin),
       link = Value(link);
  static Insertable<RssStar> custom({
    Expression<String>? origin,
    Expression<String>? link,
    Expression<String>? sort,
    Expression<String>? title,
    Expression<int>? starTime,
    Expression<String>? pubDate,
    Expression<String>? description,
    Expression<String>? content,
    Expression<String>? image,
    Expression<String>? group,
    Expression<String>? variable,
    Expression<int>? type,
    Expression<int>? durPos,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (origin != null) 'origin': origin,
      if (link != null) 'link': link,
      if (sort != null) 'sort': sort,
      if (title != null) 'title': title,
      if (starTime != null) 'star_time': starTime,
      if (pubDate != null) 'pub_date': pubDate,
      if (description != null) 'description': description,
      if (content != null) 'content': content,
      if (image != null) 'image': image,
      if (group != null) 'group': group,
      if (variable != null) 'variable': variable,
      if (type != null) 'type': type,
      if (durPos != null) 'dur_pos': durPos,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RssStarsCompanion copyWith({
    Value<String>? origin,
    Value<String>? link,
    Value<String>? sort,
    Value<String>? title,
    Value<int>? starTime,
    Value<String?>? pubDate,
    Value<String?>? description,
    Value<String?>? content,
    Value<String?>? image,
    Value<String>? group,
    Value<String?>? variable,
    Value<int>? type,
    Value<int>? durPos,
    Value<int>? rowid,
  }) {
    return RssStarsCompanion(
      origin: origin ?? this.origin,
      link: link ?? this.link,
      sort: sort ?? this.sort,
      title: title ?? this.title,
      starTime: starTime ?? this.starTime,
      pubDate: pubDate ?? this.pubDate,
      description: description ?? this.description,
      content: content ?? this.content,
      image: image ?? this.image,
      group: group ?? this.group,
      variable: variable ?? this.variable,
      type: type ?? this.type,
      durPos: durPos ?? this.durPos,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (sort.present) {
      map['sort'] = Variable<String>(sort.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (starTime.present) {
      map['star_time'] = Variable<int>(starTime.value);
    }
    if (pubDate.present) {
      map['pub_date'] = Variable<String>(pubDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (variable.present) {
      map['variable'] = Variable<String>(variable.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (durPos.present) {
      map['dur_pos'] = Variable<int>(durPos.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RssStarsCompanion(')
          ..write('origin: $origin, ')
          ..write('link: $link, ')
          ..write('sort: $sort, ')
          ..write('title: $title, ')
          ..write('starTime: $starTime, ')
          ..write('pubDate: $pubDate, ')
          ..write('description: $description, ')
          ..write('content: $content, ')
          ..write('image: $image, ')
          ..write('group: $group, ')
          ..write('variable: $variable, ')
          ..write('type: $type, ')
          ..write('durPos: $durPos, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RssReadRecordsTable extends RssReadRecords
    with TableInfo<$RssReadRecordsTable, RssReadRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RssReadRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<String> record = GeneratedColumn<String>(
    'record',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<String> sort = GeneratedColumn<String>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _readTimeMeta = const VerificationMeta(
    'readTime',
  );
  @override
  late final GeneratedColumn<int> readTime = GeneratedColumn<int>(
    'read_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
    'read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durPosMeta = const VerificationMeta('durPos');
  @override
  late final GeneratedColumn<int> durPos = GeneratedColumn<int>(
    'dur_pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pubDateMeta = const VerificationMeta(
    'pubDate',
  );
  @override
  late final GeneratedColumn<String> pubDate = GeneratedColumn<String>(
    'pub_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    record,
    origin,
    sort,
    title,
    readTime,
    read,
    image,
    type,
    durPos,
    pubDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rss_read_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RssReadRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('read_time')) {
      context.handle(
        _readTimeMeta,
        readTime.isAcceptableOrUnknown(data['read_time']!, _readTimeMeta),
      );
    }
    if (data.containsKey('read')) {
      context.handle(
        _readMeta,
        read.isAcceptableOrUnknown(data['read']!, _readMeta),
      );
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('dur_pos')) {
      context.handle(
        _durPosMeta,
        durPos.isAcceptableOrUnknown(data['dur_pos']!, _durPosMeta),
      );
    }
    if (data.containsKey('pub_date')) {
      context.handle(
        _pubDateMeta,
        pubDate.isAcceptableOrUnknown(data['pub_date']!, _pubDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {record};
  @override
  RssReadRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RssReadRecord(
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      readTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_time'],
      ),
      read: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read'],
      )!,
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      durPos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dur_pos'],
      )!,
      pubDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pub_date'],
      ),
    );
  }

  @override
  $RssReadRecordsTable createAlias(String alias) {
    return $RssReadRecordsTable(attachedDatabase, alias);
  }
}

class RssReadRecord extends DataClass implements Insertable<RssReadRecord> {
  final String record;
  final String origin;
  final String sort;
  final String? title;
  final int? readTime;
  final bool read;
  final String? image;
  final int type;
  final int durPos;
  final String? pubDate;
  const RssReadRecord({
    required this.record,
    required this.origin,
    required this.sort,
    this.title,
    this.readTime,
    required this.read,
    this.image,
    required this.type,
    required this.durPos,
    this.pubDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record'] = Variable<String>(record);
    map['origin'] = Variable<String>(origin);
    map['sort'] = Variable<String>(sort);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || readTime != null) {
      map['read_time'] = Variable<int>(readTime);
    }
    map['read'] = Variable<bool>(read);
    if (!nullToAbsent || image != null) {
      map['image'] = Variable<String>(image);
    }
    map['type'] = Variable<int>(type);
    map['dur_pos'] = Variable<int>(durPos);
    if (!nullToAbsent || pubDate != null) {
      map['pub_date'] = Variable<String>(pubDate);
    }
    return map;
  }

  RssReadRecordsCompanion toCompanion(bool nullToAbsent) {
    return RssReadRecordsCompanion(
      record: Value(record),
      origin: Value(origin),
      sort: Value(sort),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      readTime: readTime == null && nullToAbsent
          ? const Value.absent()
          : Value(readTime),
      read: Value(read),
      image: image == null && nullToAbsent
          ? const Value.absent()
          : Value(image),
      type: Value(type),
      durPos: Value(durPos),
      pubDate: pubDate == null && nullToAbsent
          ? const Value.absent()
          : Value(pubDate),
    );
  }

  factory RssReadRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RssReadRecord(
      record: serializer.fromJson<String>(json['record']),
      origin: serializer.fromJson<String>(json['origin']),
      sort: serializer.fromJson<String>(json['sort']),
      title: serializer.fromJson<String?>(json['title']),
      readTime: serializer.fromJson<int?>(json['readTime']),
      read: serializer.fromJson<bool>(json['read']),
      image: serializer.fromJson<String?>(json['image']),
      type: serializer.fromJson<int>(json['type']),
      durPos: serializer.fromJson<int>(json['durPos']),
      pubDate: serializer.fromJson<String?>(json['pubDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'record': serializer.toJson<String>(record),
      'origin': serializer.toJson<String>(origin),
      'sort': serializer.toJson<String>(sort),
      'title': serializer.toJson<String?>(title),
      'readTime': serializer.toJson<int?>(readTime),
      'read': serializer.toJson<bool>(read),
      'image': serializer.toJson<String?>(image),
      'type': serializer.toJson<int>(type),
      'durPos': serializer.toJson<int>(durPos),
      'pubDate': serializer.toJson<String?>(pubDate),
    };
  }

  RssReadRecord copyWith({
    String? record,
    String? origin,
    String? sort,
    Value<String?> title = const Value.absent(),
    Value<int?> readTime = const Value.absent(),
    bool? read,
    Value<String?> image = const Value.absent(),
    int? type,
    int? durPos,
    Value<String?> pubDate = const Value.absent(),
  }) => RssReadRecord(
    record: record ?? this.record,
    origin: origin ?? this.origin,
    sort: sort ?? this.sort,
    title: title.present ? title.value : this.title,
    readTime: readTime.present ? readTime.value : this.readTime,
    read: read ?? this.read,
    image: image.present ? image.value : this.image,
    type: type ?? this.type,
    durPos: durPos ?? this.durPos,
    pubDate: pubDate.present ? pubDate.value : this.pubDate,
  );
  RssReadRecord copyWithCompanion(RssReadRecordsCompanion data) {
    return RssReadRecord(
      record: data.record.present ? data.record.value : this.record,
      origin: data.origin.present ? data.origin.value : this.origin,
      sort: data.sort.present ? data.sort.value : this.sort,
      title: data.title.present ? data.title.value : this.title,
      readTime: data.readTime.present ? data.readTime.value : this.readTime,
      read: data.read.present ? data.read.value : this.read,
      image: data.image.present ? data.image.value : this.image,
      type: data.type.present ? data.type.value : this.type,
      durPos: data.durPos.present ? data.durPos.value : this.durPos,
      pubDate: data.pubDate.present ? data.pubDate.value : this.pubDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RssReadRecord(')
          ..write('record: $record, ')
          ..write('origin: $origin, ')
          ..write('sort: $sort, ')
          ..write('title: $title, ')
          ..write('readTime: $readTime, ')
          ..write('read: $read, ')
          ..write('image: $image, ')
          ..write('type: $type, ')
          ..write('durPos: $durPos, ')
          ..write('pubDate: $pubDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    record,
    origin,
    sort,
    title,
    readTime,
    read,
    image,
    type,
    durPos,
    pubDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RssReadRecord &&
          other.record == this.record &&
          other.origin == this.origin &&
          other.sort == this.sort &&
          other.title == this.title &&
          other.readTime == this.readTime &&
          other.read == this.read &&
          other.image == this.image &&
          other.type == this.type &&
          other.durPos == this.durPos &&
          other.pubDate == this.pubDate);
}

class RssReadRecordsCompanion extends UpdateCompanion<RssReadRecord> {
  final Value<String> record;
  final Value<String> origin;
  final Value<String> sort;
  final Value<String?> title;
  final Value<int?> readTime;
  final Value<bool> read;
  final Value<String?> image;
  final Value<int> type;
  final Value<int> durPos;
  final Value<String?> pubDate;
  final Value<int> rowid;
  const RssReadRecordsCompanion({
    this.record = const Value.absent(),
    this.origin = const Value.absent(),
    this.sort = const Value.absent(),
    this.title = const Value.absent(),
    this.readTime = const Value.absent(),
    this.read = const Value.absent(),
    this.image = const Value.absent(),
    this.type = const Value.absent(),
    this.durPos = const Value.absent(),
    this.pubDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RssReadRecordsCompanion.insert({
    required String record,
    this.origin = const Value.absent(),
    this.sort = const Value.absent(),
    this.title = const Value.absent(),
    this.readTime = const Value.absent(),
    this.read = const Value.absent(),
    this.image = const Value.absent(),
    this.type = const Value.absent(),
    this.durPos = const Value.absent(),
    this.pubDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : record = Value(record);
  static Insertable<RssReadRecord> custom({
    Expression<String>? record,
    Expression<String>? origin,
    Expression<String>? sort,
    Expression<String>? title,
    Expression<int>? readTime,
    Expression<bool>? read,
    Expression<String>? image,
    Expression<int>? type,
    Expression<int>? durPos,
    Expression<String>? pubDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (record != null) 'record': record,
      if (origin != null) 'origin': origin,
      if (sort != null) 'sort': sort,
      if (title != null) 'title': title,
      if (readTime != null) 'read_time': readTime,
      if (read != null) 'read': read,
      if (image != null) 'image': image,
      if (type != null) 'type': type,
      if (durPos != null) 'dur_pos': durPos,
      if (pubDate != null) 'pub_date': pubDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RssReadRecordsCompanion copyWith({
    Value<String>? record,
    Value<String>? origin,
    Value<String>? sort,
    Value<String?>? title,
    Value<int?>? readTime,
    Value<bool>? read,
    Value<String?>? image,
    Value<int>? type,
    Value<int>? durPos,
    Value<String?>? pubDate,
    Value<int>? rowid,
  }) {
    return RssReadRecordsCompanion(
      record: record ?? this.record,
      origin: origin ?? this.origin,
      sort: sort ?? this.sort,
      title: title ?? this.title,
      readTime: readTime ?? this.readTime,
      read: read ?? this.read,
      image: image ?? this.image,
      type: type ?? this.type,
      durPos: durPos ?? this.durPos,
      pubDate: pubDate ?? this.pubDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (record.present) {
      map['record'] = Variable<String>(record.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (sort.present) {
      map['sort'] = Variable<String>(sort.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (readTime.present) {
      map['read_time'] = Variable<int>(readTime.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (durPos.present) {
      map['dur_pos'] = Variable<int>(durPos.value);
    }
    if (pubDate.present) {
      map['pub_date'] = Variable<String>(pubDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RssReadRecordsCompanion(')
          ..write('record: $record, ')
          ..write('origin: $origin, ')
          ..write('sort: $sort, ')
          ..write('title: $title, ')
          ..write('readTime: $readTime, ')
          ..write('read: $read, ')
          ..write('image: $image, ')
          ..write('type: $type, ')
          ..write('durPos: $durPos, ')
          ..write('pubDate: $pubDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $BookSourcesTable bookSources = $BookSourcesTable(this);
  late final $SearchBooksTable searchBooks = $SearchBooksTable(this);
  late final $ReplaceRulesTable replaceRules = $ReplaceRulesTable(this);
  late final $BookChaptersTable bookChapters = $BookChaptersTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ReadRecordsTable readRecords = $ReadRecordsTable(this);
  late final $BookGroupsTable bookGroups = $BookGroupsTable(this);
  late final $CookiesTable cookies = $CookiesTable(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  late final $RssSourcesTable rssSources = $RssSourcesTable(this);
  late final $RssArticlesTable rssArticles = $RssArticlesTable(this);
  late final $RssStarsTable rssStars = $RssStarsTable(this);
  late final $RssReadRecordsTable rssReadRecords = $RssReadRecordsTable(this);
  late final Index booksLastRead = Index(
    'books_last_read',
    'CREATE INDEX books_last_read ON books (last_read_time)',
  );
  late final Index booksGroup = Index(
    'books_group',
    'CREATE INDEX books_group ON books ("group")',
  );
  late final Index searchBooksOrigin = Index(
    'search_books_origin',
    'CREATE INDEX search_books_origin ON search_books (origin)',
  );
  late final Index searchBooksBookUrl = Index(
    'search_books_book_url',
    'CREATE INDEX search_books_book_url ON search_books (book_url)',
  );
  late final Index bookChaptersBookIndex = Index(
    'book_chapters_book_index',
    'CREATE UNIQUE INDEX book_chapters_book_index ON book_chapters (book_url, "index")',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    bookSources,
    searchBooks,
    replaceRules,
    bookChapters,
    bookmarks,
    readRecords,
    bookGroups,
    cookies,
    cacheEntries,
    rssSources,
    rssArticles,
    rssStars,
    rssReadRecords,
    booksLastRead,
    booksGroup,
    searchBooksOrigin,
    searchBooksBookUrl,
    bookChaptersBookIndex,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'book_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('search_books', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_chapters', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      required String bookUrl,
      required String name,
      Value<String> author,
      Value<String?> intro,
      Value<String?> coverUrl,
      Value<String?> origin,
      Value<String?> originName,
      Value<String?> kind,
      Value<int> durChapterIndex,
      Value<String?> durChapterTitle,
      Value<int> durChapterPos,
      Value<int> durChapterPosEnd,
      Value<String?> latestChapterTitle,
      Value<int> totalChapterNum,
      Value<int> type,
      Value<int> group,
      Value<int> customOrder,
      Value<int> lastReadTime,
      Value<int> lastUpdateTime,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      Value<String> bookUrl,
      Value<String> name,
      Value<String> author,
      Value<String?> intro,
      Value<String?> coverUrl,
      Value<String?> origin,
      Value<String?> originName,
      Value<String?> kind,
      Value<int> durChapterIndex,
      Value<String?> durChapterTitle,
      Value<int> durChapterPos,
      Value<int> durChapterPosEnd,
      Value<String?> latestChapterTitle,
      Value<int> totalChapterNum,
      Value<int> type,
      Value<int> group,
      Value<int> customOrder,
      Value<int> lastReadTime,
      Value<int> lastUpdateTime,
    });

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, Book> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookChaptersTable, List<BookChapter>>
  _bookChaptersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookChapters,
    aliasName: $_aliasNameGenerator(db.books.bookUrl, db.bookChapters.bookUrl),
  );

  $$BookChaptersTableProcessedTableManager get bookChaptersRefs {
    final manager = $$BookChaptersTableTableManager($_db, $_db.bookChapters)
        .filter(
          (f) => f.bookUrl.bookUrl.sqlEquals($_itemColumn<String>('book_url')!),
        );

    final cache = $_typedResult.readTableOrNull(_bookChaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
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

  ColumnFilters<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durChapterIndex => $composableBuilder(
    column: $table.durChapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get durChapterTitle => $composableBuilder(
    column: $table.durChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durChapterPos => $composableBuilder(
    column: $table.durChapterPos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durChapterPosEnd => $composableBuilder(
    column: $table.durChapterPosEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapterNum => $composableBuilder(
    column: $table.totalChapterNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadTime => $composableBuilder(
    column: $table.lastReadTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bookChaptersRefs(
    Expression<bool> Function($$BookChaptersTableFilterComposer f) f,
  ) {
    final $$BookChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookUrl,
      referencedTable: $db.bookChapters,
      getReferencedColumn: (t) => t.bookUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookChaptersTableFilterComposer(
            $db: $db,
            $table: $db.bookChapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
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

  ColumnOrderings<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durChapterIndex => $composableBuilder(
    column: $table.durChapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get durChapterTitle => $composableBuilder(
    column: $table.durChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durChapterPos => $composableBuilder(
    column: $table.durChapterPos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durChapterPosEnd => $composableBuilder(
    column: $table.durChapterPosEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapterNum => $composableBuilder(
    column: $table.totalChapterNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadTime => $composableBuilder(
    column: $table.lastReadTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookUrl =>
      $composableBuilder(column: $table.bookUrl, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get durChapterIndex => $composableBuilder(
    column: $table.durChapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get durChapterTitle => $composableBuilder(
    column: $table.durChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durChapterPos => $composableBuilder(
    column: $table.durChapterPos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durChapterPosEnd => $composableBuilder(
    column: $table.durChapterPosEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChapterNum => $composableBuilder(
    column: $table.totalChapterNum,
    builder: (column) => column,
  );

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  GeneratedColumn<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReadTime => $composableBuilder(
    column: $table.lastReadTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => column,
  );

  Expression<T> bookChaptersRefs<T extends Object>(
    Expression<T> Function($$BookChaptersTableAnnotationComposer a) f,
  ) {
    final $$BookChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookUrl,
      referencedTable: $db.bookChapters,
      getReferencedColumn: (t) => t.bookUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.bookChapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, $$BooksTableReferences),
          Book,
          PrefetchHooks Function({bool bookChaptersRefs})
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookUrl = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> originName = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<int> durChapterIndex = const Value.absent(),
                Value<String?> durChapterTitle = const Value.absent(),
                Value<int> durChapterPos = const Value.absent(),
                Value<int> durChapterPosEnd = const Value.absent(),
                Value<String?> latestChapterTitle = const Value.absent(),
                Value<int> totalChapterNum = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> group = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> lastReadTime = const Value.absent(),
                Value<int> lastUpdateTime = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                bookUrl: bookUrl,
                name: name,
                author: author,
                intro: intro,
                coverUrl: coverUrl,
                origin: origin,
                originName: originName,
                kind: kind,
                durChapterIndex: durChapterIndex,
                durChapterTitle: durChapterTitle,
                durChapterPos: durChapterPos,
                durChapterPosEnd: durChapterPosEnd,
                latestChapterTitle: latestChapterTitle,
                totalChapterNum: totalChapterNum,
                type: type,
                group: group,
                customOrder: customOrder,
                lastReadTime: lastReadTime,
                lastUpdateTime: lastUpdateTime,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookUrl,
                required String name,
                Value<String> author = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> originName = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<int> durChapterIndex = const Value.absent(),
                Value<String?> durChapterTitle = const Value.absent(),
                Value<int> durChapterPos = const Value.absent(),
                Value<int> durChapterPosEnd = const Value.absent(),
                Value<String?> latestChapterTitle = const Value.absent(),
                Value<int> totalChapterNum = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> group = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> lastReadTime = const Value.absent(),
                Value<int> lastUpdateTime = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                bookUrl: bookUrl,
                name: name,
                author: author,
                intro: intro,
                coverUrl: coverUrl,
                origin: origin,
                originName: originName,
                kind: kind,
                durChapterIndex: durChapterIndex,
                durChapterTitle: durChapterTitle,
                durChapterPos: durChapterPos,
                durChapterPosEnd: durChapterPosEnd,
                latestChapterTitle: latestChapterTitle,
                totalChapterNum: totalChapterNum,
                type: type,
                group: group,
                customOrder: customOrder,
                lastReadTime: lastReadTime,
                lastUpdateTime: lastUpdateTime,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BooksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({bookChaptersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (bookChaptersRefs) db.bookChapters],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (bookChaptersRefs)
                    await $_getPrefetchedData<Book, $BooksTable, BookChapter>(
                      currentTable: table,
                      referencedTable: $$BooksTableReferences
                          ._bookChaptersRefsTable(db),
                      managerFromTypedResult: (p0) => $$BooksTableReferences(
                        db,
                        table,
                        p0,
                      ).bookChaptersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.bookUrl == item.bookUrl,
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

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, $$BooksTableReferences),
      Book,
      PrefetchHooks Function({bool bookChaptersRefs})
    >;
typedef $$BookSourcesTableCreateCompanionBuilder =
    BookSourcesCompanion Function({
      Value<int> id,
      required String bookSourceUrl,
      required String bookSourceName,
      Value<String?> bookSourceGroup,
      Value<int> bookSourceType,
      Value<bool> enabled,
      Value<bool> enabledExplore,
      Value<int> customOrder,
      Value<int> lastUpdateTime,
      Value<int> respondTime,
      Value<int> weight,
      Value<String?> raw,
    });
typedef $$BookSourcesTableUpdateCompanionBuilder =
    BookSourcesCompanion Function({
      Value<int> id,
      Value<String> bookSourceUrl,
      Value<String> bookSourceName,
      Value<String?> bookSourceGroup,
      Value<int> bookSourceType,
      Value<bool> enabled,
      Value<bool> enabledExplore,
      Value<int> customOrder,
      Value<int> lastUpdateTime,
      Value<int> respondTime,
      Value<int> weight,
      Value<String?> raw,
    });

final class $$BookSourcesTableReferences
    extends BaseReferences<_$AppDatabase, $BookSourcesTable, BookSource> {
  $$BookSourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SearchBooksTable, List<SearchBook>>
  _searchBooksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.searchBooks,
    aliasName: $_aliasNameGenerator(
      db.bookSources.bookSourceUrl,
      db.searchBooks.origin,
    ),
  );

  $$SearchBooksTableProcessedTableManager get searchBooksRefs {
    final manager = $$SearchBooksTableTableManager($_db, $_db.searchBooks)
        .filter(
          (f) => f.origin.bookSourceUrl.sqlEquals(
            $_itemColumn<String>('book_source_url')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_searchBooksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BookSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $BookSourcesTable> {
  $$BookSourcesTableFilterComposer({
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

  ColumnFilters<String> get bookSourceUrl => $composableBuilder(
    column: $table.bookSourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookSourceName => $composableBuilder(
    column: $table.bookSourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookSourceGroup => $composableBuilder(
    column: $table.bookSourceGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bookSourceType => $composableBuilder(
    column: $table.bookSourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabledExplore => $composableBuilder(
    column: $table.enabledExplore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> searchBooksRefs(
    Expression<bool> Function($$SearchBooksTableFilterComposer f) f,
  ) {
    final $$SearchBooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookSourceUrl,
      referencedTable: $db.searchBooks,
      getReferencedColumn: (t) => t.origin,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchBooksTableFilterComposer(
            $db: $db,
            $table: $db.searchBooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BookSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookSourcesTable> {
  $$BookSourcesTableOrderingComposer({
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

  ColumnOrderings<String> get bookSourceUrl => $composableBuilder(
    column: $table.bookSourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookSourceName => $composableBuilder(
    column: $table.bookSourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookSourceGroup => $composableBuilder(
    column: $table.bookSourceGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bookSourceType => $composableBuilder(
    column: $table.bookSourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabledExplore => $composableBuilder(
    column: $table.enabledExplore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookSourcesTable> {
  $$BookSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookSourceUrl => $composableBuilder(
    column: $table.bookSourceUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookSourceName => $composableBuilder(
    column: $table.bookSourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookSourceGroup => $composableBuilder(
    column: $table.bookSourceGroup,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bookSourceType => $composableBuilder(
    column: $table.bookSourceType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get enabledExplore => $composableBuilder(
    column: $table.enabledExplore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);

  Expression<T> searchBooksRefs<T extends Object>(
    Expression<T> Function($$SearchBooksTableAnnotationComposer a) f,
  ) {
    final $$SearchBooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookSourceUrl,
      referencedTable: $db.searchBooks,
      getReferencedColumn: (t) => t.origin,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchBooksTableAnnotationComposer(
            $db: $db,
            $table: $db.searchBooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BookSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookSourcesTable,
          BookSource,
          $$BookSourcesTableFilterComposer,
          $$BookSourcesTableOrderingComposer,
          $$BookSourcesTableAnnotationComposer,
          $$BookSourcesTableCreateCompanionBuilder,
          $$BookSourcesTableUpdateCompanionBuilder,
          (BookSource, $$BookSourcesTableReferences),
          BookSource,
          PrefetchHooks Function({bool searchBooksRefs})
        > {
  $$BookSourcesTableTableManager(_$AppDatabase db, $BookSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookSourceUrl = const Value.absent(),
                Value<String> bookSourceName = const Value.absent(),
                Value<String?> bookSourceGroup = const Value.absent(),
                Value<int> bookSourceType = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> enabledExplore = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> lastUpdateTime = const Value.absent(),
                Value<int> respondTime = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<String?> raw = const Value.absent(),
              }) => BookSourcesCompanion(
                id: id,
                bookSourceUrl: bookSourceUrl,
                bookSourceName: bookSourceName,
                bookSourceGroup: bookSourceGroup,
                bookSourceType: bookSourceType,
                enabled: enabled,
                enabledExplore: enabledExplore,
                customOrder: customOrder,
                lastUpdateTime: lastUpdateTime,
                respondTime: respondTime,
                weight: weight,
                raw: raw,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookSourceUrl,
                required String bookSourceName,
                Value<String?> bookSourceGroup = const Value.absent(),
                Value<int> bookSourceType = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> enabledExplore = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> lastUpdateTime = const Value.absent(),
                Value<int> respondTime = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<String?> raw = const Value.absent(),
              }) => BookSourcesCompanion.insert(
                id: id,
                bookSourceUrl: bookSourceUrl,
                bookSourceName: bookSourceName,
                bookSourceGroup: bookSourceGroup,
                bookSourceType: bookSourceType,
                enabled: enabled,
                enabledExplore: enabledExplore,
                customOrder: customOrder,
                lastUpdateTime: lastUpdateTime,
                respondTime: respondTime,
                weight: weight,
                raw: raw,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({searchBooksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (searchBooksRefs) db.searchBooks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (searchBooksRefs)
                    await $_getPrefetchedData<
                      BookSource,
                      $BookSourcesTable,
                      SearchBook
                    >(
                      currentTable: table,
                      referencedTable: $$BookSourcesTableReferences
                          ._searchBooksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BookSourcesTableReferences(
                            db,
                            table,
                            p0,
                          ).searchBooksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.origin == item.bookSourceUrl,
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

typedef $$BookSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookSourcesTable,
      BookSource,
      $$BookSourcesTableFilterComposer,
      $$BookSourcesTableOrderingComposer,
      $$BookSourcesTableAnnotationComposer,
      $$BookSourcesTableCreateCompanionBuilder,
      $$BookSourcesTableUpdateCompanionBuilder,
      (BookSource, $$BookSourcesTableReferences),
      BookSource,
      PrefetchHooks Function({bool searchBooksRefs})
    >;
typedef $$SearchBooksTableCreateCompanionBuilder =
    SearchBooksCompanion Function({
      required String bookUrl,
      required String origin,
      Value<String> originName,
      Value<String> name,
      Value<String> author,
      Value<int> type,
      Value<String?> kind,
      Value<String?> coverUrl,
      Value<String?> intro,
      Value<String?> wordCount,
      Value<String?> latestChapterTitle,
      Value<String> tocUrl,
      Value<int> time,
      Value<String?> variable,
      Value<int> originOrder,
      Value<String?> chapterWordCountText,
      Value<int> chapterWordCount,
      Value<int> respondTime,
      Value<int> rowid,
    });
typedef $$SearchBooksTableUpdateCompanionBuilder =
    SearchBooksCompanion Function({
      Value<String> bookUrl,
      Value<String> origin,
      Value<String> originName,
      Value<String> name,
      Value<String> author,
      Value<int> type,
      Value<String?> kind,
      Value<String?> coverUrl,
      Value<String?> intro,
      Value<String?> wordCount,
      Value<String?> latestChapterTitle,
      Value<String> tocUrl,
      Value<int> time,
      Value<String?> variable,
      Value<int> originOrder,
      Value<String?> chapterWordCountText,
      Value<int> chapterWordCount,
      Value<int> respondTime,
      Value<int> rowid,
    });

final class $$SearchBooksTableReferences
    extends BaseReferences<_$AppDatabase, $SearchBooksTable, SearchBook> {
  $$SearchBooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BookSourcesTable _originTable(_$AppDatabase db) =>
      db.bookSources.createAlias(
        $_aliasNameGenerator(
          db.searchBooks.origin,
          db.bookSources.bookSourceUrl,
        ),
      );

  $$BookSourcesTableProcessedTableManager get origin {
    final $_column = $_itemColumn<String>('origin')!;

    final manager = $$BookSourcesTableTableManager(
      $_db,
      $_db.bookSources,
    ).filter((f) => f.bookSourceUrl.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_originTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SearchBooksTableFilterComposer
    extends Composer<_$AppDatabase, $SearchBooksTable> {
  $$SearchBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originOrder => $composableBuilder(
    column: $table.originOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterWordCountText => $composableBuilder(
    column: $table.chapterWordCountText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterWordCount => $composableBuilder(
    column: $table.chapterWordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => ColumnFilters(column),
  );

  $$BookSourcesTableFilterComposer get origin {
    final $$BookSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.origin,
      referencedTable: $db.bookSources,
      getReferencedColumn: (t) => t.bookSourceUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookSourcesTableFilterComposer(
            $db: $db,
            $table: $db.bookSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchBooksTable> {
  $$SearchBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originOrder => $composableBuilder(
    column: $table.originOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterWordCountText => $composableBuilder(
    column: $table.chapterWordCountText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterWordCount => $composableBuilder(
    column: $table.chapterWordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => ColumnOrderings(column),
  );

  $$BookSourcesTableOrderingComposer get origin {
    final $$BookSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.origin,
      referencedTable: $db.bookSources,
      getReferencedColumn: (t) => t.bookSourceUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.bookSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchBooksTable> {
  $$SearchBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookUrl =>
      $composableBuilder(column: $table.bookUrl, builder: (column) => column);

  GeneratedColumn<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tocUrl =>
      $composableBuilder(column: $table.tocUrl, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get variable =>
      $composableBuilder(column: $table.variable, builder: (column) => column);

  GeneratedColumn<int> get originOrder => $composableBuilder(
    column: $table.originOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterWordCountText => $composableBuilder(
    column: $table.chapterWordCountText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterWordCount => $composableBuilder(
    column: $table.chapterWordCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => column,
  );

  $$BookSourcesTableAnnotationComposer get origin {
    final $$BookSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.origin,
      referencedTable: $db.bookSources,
      getReferencedColumn: (t) => t.bookSourceUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchBooksTable,
          SearchBook,
          $$SearchBooksTableFilterComposer,
          $$SearchBooksTableOrderingComposer,
          $$SearchBooksTableAnnotationComposer,
          $$SearchBooksTableCreateCompanionBuilder,
          $$SearchBooksTableUpdateCompanionBuilder,
          (SearchBook, $$SearchBooksTableReferences),
          SearchBook,
          PrefetchHooks Function({bool origin})
        > {
  $$SearchBooksTableTableManager(_$AppDatabase db, $SearchBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookUrl = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> originName = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> wordCount = const Value.absent(),
                Value<String?> latestChapterTitle = const Value.absent(),
                Value<String> tocUrl = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<int> originOrder = const Value.absent(),
                Value<String?> chapterWordCountText = const Value.absent(),
                Value<int> chapterWordCount = const Value.absent(),
                Value<int> respondTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchBooksCompanion(
                bookUrl: bookUrl,
                origin: origin,
                originName: originName,
                name: name,
                author: author,
                type: type,
                kind: kind,
                coverUrl: coverUrl,
                intro: intro,
                wordCount: wordCount,
                latestChapterTitle: latestChapterTitle,
                tocUrl: tocUrl,
                time: time,
                variable: variable,
                originOrder: originOrder,
                chapterWordCountText: chapterWordCountText,
                chapterWordCount: chapterWordCount,
                respondTime: respondTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookUrl,
                required String origin,
                Value<String> originName = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> wordCount = const Value.absent(),
                Value<String?> latestChapterTitle = const Value.absent(),
                Value<String> tocUrl = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<int> originOrder = const Value.absent(),
                Value<String?> chapterWordCountText = const Value.absent(),
                Value<int> chapterWordCount = const Value.absent(),
                Value<int> respondTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchBooksCompanion.insert(
                bookUrl: bookUrl,
                origin: origin,
                originName: originName,
                name: name,
                author: author,
                type: type,
                kind: kind,
                coverUrl: coverUrl,
                intro: intro,
                wordCount: wordCount,
                latestChapterTitle: latestChapterTitle,
                tocUrl: tocUrl,
                time: time,
                variable: variable,
                originOrder: originOrder,
                chapterWordCountText: chapterWordCountText,
                chapterWordCount: chapterWordCount,
                respondTime: respondTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SearchBooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({origin = false}) {
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
                    if (origin) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.origin,
                                referencedTable: $$SearchBooksTableReferences
                                    ._originTable(db),
                                referencedColumn: $$SearchBooksTableReferences
                                    ._originTable(db)
                                    .bookSourceUrl,
                              )
                              as T;
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

typedef $$SearchBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchBooksTable,
      SearchBook,
      $$SearchBooksTableFilterComposer,
      $$SearchBooksTableOrderingComposer,
      $$SearchBooksTableAnnotationComposer,
      $$SearchBooksTableCreateCompanionBuilder,
      $$SearchBooksTableUpdateCompanionBuilder,
      (SearchBook, $$SearchBooksTableReferences),
      SearchBook,
      PrefetchHooks Function({bool origin})
    >;
typedef $$ReplaceRulesTableCreateCompanionBuilder =
    ReplaceRulesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> groupName,
      required String pattern,
      required String replacement,
      Value<String?> scope,
      Value<bool> scopeTitle,
      Value<bool> scopeContent,
      Value<String?> excludeScope,
      Value<bool> enabled,
      Value<bool> isRegex,
      Value<int> timeoutMillisecond,
      Value<int> orderValue,
    });
typedef $$ReplaceRulesTableUpdateCompanionBuilder =
    ReplaceRulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> groupName,
      Value<String> pattern,
      Value<String> replacement,
      Value<String?> scope,
      Value<bool> scopeTitle,
      Value<bool> scopeContent,
      Value<String?> excludeScope,
      Value<bool> enabled,
      Value<bool> isRegex,
      Value<int> timeoutMillisecond,
      Value<int> orderValue,
    });

class $$ReplaceRulesTableFilterComposer
    extends Composer<_$AppDatabase, $ReplaceRulesTable> {
  $$ReplaceRulesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replacement => $composableBuilder(
    column: $table.replacement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get scopeTitle => $composableBuilder(
    column: $table.scopeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get scopeContent => $composableBuilder(
    column: $table.scopeContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get excludeScope => $composableBuilder(
    column: $table.excludeScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRegex => $composableBuilder(
    column: $table.isRegex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeoutMillisecond => $composableBuilder(
    column: $table.timeoutMillisecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderValue => $composableBuilder(
    column: $table.orderValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReplaceRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReplaceRulesTable> {
  $$ReplaceRulesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replacement => $composableBuilder(
    column: $table.replacement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get scopeTitle => $composableBuilder(
    column: $table.scopeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get scopeContent => $composableBuilder(
    column: $table.scopeContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get excludeScope => $composableBuilder(
    column: $table.excludeScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRegex => $composableBuilder(
    column: $table.isRegex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeoutMillisecond => $composableBuilder(
    column: $table.timeoutMillisecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderValue => $composableBuilder(
    column: $table.orderValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReplaceRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReplaceRulesTable> {
  $$ReplaceRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get replacement => $composableBuilder(
    column: $table.replacement,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<bool> get scopeTitle => $composableBuilder(
    column: $table.scopeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get scopeContent => $composableBuilder(
    column: $table.scopeContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get excludeScope => $composableBuilder(
    column: $table.excludeScope,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get isRegex =>
      $composableBuilder(column: $table.isRegex, builder: (column) => column);

  GeneratedColumn<int> get timeoutMillisecond => $composableBuilder(
    column: $table.timeoutMillisecond,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderValue => $composableBuilder(
    column: $table.orderValue,
    builder: (column) => column,
  );
}

class $$ReplaceRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReplaceRulesTable,
          ReplaceRule,
          $$ReplaceRulesTableFilterComposer,
          $$ReplaceRulesTableOrderingComposer,
          $$ReplaceRulesTableAnnotationComposer,
          $$ReplaceRulesTableCreateCompanionBuilder,
          $$ReplaceRulesTableUpdateCompanionBuilder,
          (
            ReplaceRule,
            BaseReferences<_$AppDatabase, $ReplaceRulesTable, ReplaceRule>,
          ),
          ReplaceRule,
          PrefetchHooks Function()
        > {
  $$ReplaceRulesTableTableManager(_$AppDatabase db, $ReplaceRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReplaceRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReplaceRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReplaceRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String> replacement = const Value.absent(),
                Value<String?> scope = const Value.absent(),
                Value<bool> scopeTitle = const Value.absent(),
                Value<bool> scopeContent = const Value.absent(),
                Value<String?> excludeScope = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> isRegex = const Value.absent(),
                Value<int> timeoutMillisecond = const Value.absent(),
                Value<int> orderValue = const Value.absent(),
              }) => ReplaceRulesCompanion(
                id: id,
                name: name,
                groupName: groupName,
                pattern: pattern,
                replacement: replacement,
                scope: scope,
                scopeTitle: scopeTitle,
                scopeContent: scopeContent,
                excludeScope: excludeScope,
                enabled: enabled,
                isRegex: isRegex,
                timeoutMillisecond: timeoutMillisecond,
                orderValue: orderValue,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> groupName = const Value.absent(),
                required String pattern,
                required String replacement,
                Value<String?> scope = const Value.absent(),
                Value<bool> scopeTitle = const Value.absent(),
                Value<bool> scopeContent = const Value.absent(),
                Value<String?> excludeScope = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> isRegex = const Value.absent(),
                Value<int> timeoutMillisecond = const Value.absent(),
                Value<int> orderValue = const Value.absent(),
              }) => ReplaceRulesCompanion.insert(
                id: id,
                name: name,
                groupName: groupName,
                pattern: pattern,
                replacement: replacement,
                scope: scope,
                scopeTitle: scopeTitle,
                scopeContent: scopeContent,
                excludeScope: excludeScope,
                enabled: enabled,
                isRegex: isRegex,
                timeoutMillisecond: timeoutMillisecond,
                orderValue: orderValue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReplaceRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReplaceRulesTable,
      ReplaceRule,
      $$ReplaceRulesTableFilterComposer,
      $$ReplaceRulesTableOrderingComposer,
      $$ReplaceRulesTableAnnotationComposer,
      $$ReplaceRulesTableCreateCompanionBuilder,
      $$ReplaceRulesTableUpdateCompanionBuilder,
      (
        ReplaceRule,
        BaseReferences<_$AppDatabase, $ReplaceRulesTable, ReplaceRule>,
      ),
      ReplaceRule,
      PrefetchHooks Function()
    >;
typedef $$BookChaptersTableCreateCompanionBuilder =
    BookChaptersCompanion Function({
      required String url,
      required String bookUrl,
      Value<String> title,
      required int index,
      Value<String> baseUrl,
      Value<bool> isVolume,
      Value<bool> isVip,
      Value<bool> isPay,
      Value<String?> tag,
      Value<String?> wordCount,
      Value<int?> start,
      Value<int?> end,
      Value<String?> startFragmentId,
      Value<String?> endFragmentId,
      Value<String?> variable,
      Value<String?> imgUrl,
      Value<String?> resourceUrl,
      Value<int> rowid,
    });
typedef $$BookChaptersTableUpdateCompanionBuilder =
    BookChaptersCompanion Function({
      Value<String> url,
      Value<String> bookUrl,
      Value<String> title,
      Value<int> index,
      Value<String> baseUrl,
      Value<bool> isVolume,
      Value<bool> isVip,
      Value<bool> isPay,
      Value<String?> tag,
      Value<String?> wordCount,
      Value<int?> start,
      Value<int?> end,
      Value<String?> startFragmentId,
      Value<String?> endFragmentId,
      Value<String?> variable,
      Value<String?> imgUrl,
      Value<String?> resourceUrl,
      Value<int> rowid,
    });

final class $$BookChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $BookChaptersTable, BookChapter> {
  $$BookChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookUrlTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.bookChapters.bookUrl, db.books.bookUrl),
  );

  $$BooksTableProcessedTableManager get bookUrl {
    final $_column = $_itemColumn<String>('book_url')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.bookUrl.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookUrlTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $BookChaptersTable> {
  $$BookChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVolume => $composableBuilder(
    column: $table.isVolume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVip => $composableBuilder(
    column: $table.isVip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPay => $composableBuilder(
    column: $table.isPay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startFragmentId => $composableBuilder(
    column: $table.startFragmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endFragmentId => $composableBuilder(
    column: $table.endFragmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imgUrl => $composableBuilder(
    column: $table.imgUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceUrl => $composableBuilder(
    column: $table.resourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookUrl {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookUrl,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.bookUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $BookChaptersTable> {
  $$BookChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVolume => $composableBuilder(
    column: $table.isVolume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVip => $composableBuilder(
    column: $table.isVip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPay => $composableBuilder(
    column: $table.isPay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startFragmentId => $composableBuilder(
    column: $table.startFragmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endFragmentId => $composableBuilder(
    column: $table.endFragmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imgUrl => $composableBuilder(
    column: $table.imgUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceUrl => $composableBuilder(
    column: $table.resourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookUrl {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookUrl,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.bookUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookChaptersTable> {
  $$BookChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get index =>
      $composableBuilder(column: $table.index, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<bool> get isVolume =>
      $composableBuilder(column: $table.isVolume, builder: (column) => column);

  GeneratedColumn<bool> get isVip =>
      $composableBuilder(column: $table.isVip, builder: (column) => column);

  GeneratedColumn<bool> get isPay =>
      $composableBuilder(column: $table.isPay, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<int> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<String> get startFragmentId => $composableBuilder(
    column: $table.startFragmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endFragmentId => $composableBuilder(
    column: $table.endFragmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variable =>
      $composableBuilder(column: $table.variable, builder: (column) => column);

  GeneratedColumn<String> get imgUrl =>
      $composableBuilder(column: $table.imgUrl, builder: (column) => column);

  GeneratedColumn<String> get resourceUrl => $composableBuilder(
    column: $table.resourceUrl,
    builder: (column) => column,
  );

  $$BooksTableAnnotationComposer get bookUrl {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookUrl,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.bookUrl,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookChaptersTable,
          BookChapter,
          $$BookChaptersTableFilterComposer,
          $$BookChaptersTableOrderingComposer,
          $$BookChaptersTableAnnotationComposer,
          $$BookChaptersTableCreateCompanionBuilder,
          $$BookChaptersTableUpdateCompanionBuilder,
          (BookChapter, $$BookChaptersTableReferences),
          BookChapter,
          PrefetchHooks Function({bool bookUrl})
        > {
  $$BookChaptersTableTableManager(_$AppDatabase db, $BookChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> url = const Value.absent(),
                Value<String> bookUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> index = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<bool> isVolume = const Value.absent(),
                Value<bool> isVip = const Value.absent(),
                Value<bool> isPay = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> wordCount = const Value.absent(),
                Value<int?> start = const Value.absent(),
                Value<int?> end = const Value.absent(),
                Value<String?> startFragmentId = const Value.absent(),
                Value<String?> endFragmentId = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<String?> imgUrl = const Value.absent(),
                Value<String?> resourceUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookChaptersCompanion(
                url: url,
                bookUrl: bookUrl,
                title: title,
                index: index,
                baseUrl: baseUrl,
                isVolume: isVolume,
                isVip: isVip,
                isPay: isPay,
                tag: tag,
                wordCount: wordCount,
                start: start,
                end: end,
                startFragmentId: startFragmentId,
                endFragmentId: endFragmentId,
                variable: variable,
                imgUrl: imgUrl,
                resourceUrl: resourceUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String url,
                required String bookUrl,
                Value<String> title = const Value.absent(),
                required int index,
                Value<String> baseUrl = const Value.absent(),
                Value<bool> isVolume = const Value.absent(),
                Value<bool> isVip = const Value.absent(),
                Value<bool> isPay = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> wordCount = const Value.absent(),
                Value<int?> start = const Value.absent(),
                Value<int?> end = const Value.absent(),
                Value<String?> startFragmentId = const Value.absent(),
                Value<String?> endFragmentId = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<String?> imgUrl = const Value.absent(),
                Value<String?> resourceUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookChaptersCompanion.insert(
                url: url,
                bookUrl: bookUrl,
                title: title,
                index: index,
                baseUrl: baseUrl,
                isVolume: isVolume,
                isVip: isVip,
                isPay: isPay,
                tag: tag,
                wordCount: wordCount,
                start: start,
                end: end,
                startFragmentId: startFragmentId,
                endFragmentId: endFragmentId,
                variable: variable,
                imgUrl: imgUrl,
                resourceUrl: resourceUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookUrl = false}) {
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
                    if (bookUrl) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookUrl,
                                referencedTable: $$BookChaptersTableReferences
                                    ._bookUrlTable(db),
                                referencedColumn: $$BookChaptersTableReferences
                                    ._bookUrlTable(db)
                                    .bookUrl,
                              )
                              as T;
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

typedef $$BookChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookChaptersTable,
      BookChapter,
      $$BookChaptersTableFilterComposer,
      $$BookChaptersTableOrderingComposer,
      $$BookChaptersTableAnnotationComposer,
      $$BookChaptersTableCreateCompanionBuilder,
      $$BookChaptersTableUpdateCompanionBuilder,
      (BookChapter, $$BookChaptersTableReferences),
      BookChapter,
      PrefetchHooks Function({bool bookUrl})
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> time,
      required String bookName,
      required String bookAuthor,
      required int chapterIndex,
      required int chapterPos,
      required String chapterName,
      required String bookText,
      required String content,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> time,
      Value<String> bookName,
      Value<String> bookAuthor,
      Value<int> chapterIndex,
      Value<int> chapterPos,
      Value<String> chapterName,
      Value<String> bookText,
      Value<String> content,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterPos => $composableBuilder(
    column: $table.chapterPos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookText => $composableBuilder(
    column: $table.bookText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterPos => $composableBuilder(
    column: $table.chapterPos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookText => $composableBuilder(
    column: $table.bookText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterPos => $composableBuilder(
    column: $table.chapterPos,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookText =>
      $composableBuilder(column: $table.bookText, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> time = const Value.absent(),
                Value<String> bookName = const Value.absent(),
                Value<String> bookAuthor = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> chapterPos = const Value.absent(),
                Value<String> chapterName = const Value.absent(),
                Value<String> bookText = const Value.absent(),
                Value<String> content = const Value.absent(),
              }) => BookmarksCompanion(
                time: time,
                bookName: bookName,
                bookAuthor: bookAuthor,
                chapterIndex: chapterIndex,
                chapterPos: chapterPos,
                chapterName: chapterName,
                bookText: bookText,
                content: content,
              ),
          createCompanionCallback:
              ({
                Value<int> time = const Value.absent(),
                required String bookName,
                required String bookAuthor,
                required int chapterIndex,
                required int chapterPos,
                required String chapterName,
                required String bookText,
                required String content,
              }) => BookmarksCompanion.insert(
                time: time,
                bookName: bookName,
                bookAuthor: bookAuthor,
                chapterIndex: chapterIndex,
                chapterPos: chapterPos,
                chapterName: chapterName,
                bookText: bookText,
                content: content,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$ReadRecordsTableCreateCompanionBuilder =
    ReadRecordsCompanion Function({
      required String deviceId,
      required String bookName,
      Value<int> readTime,
      Value<int> lastRead,
      Value<int> rowid,
    });
typedef $$ReadRecordsTableUpdateCompanionBuilder =
    ReadRecordsCompanion Function({
      Value<String> deviceId,
      Value<String> bookName,
      Value<int> readTime,
      Value<int> lastRead,
      Value<int> rowid,
    });

class $$ReadRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadRecordsTable> {
  $$ReadRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readTime => $composableBuilder(
    column: $table.readTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRead => $composableBuilder(
    column: $table.lastRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadRecordsTable> {
  $$ReadRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readTime => $composableBuilder(
    column: $table.readTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRead => $composableBuilder(
    column: $table.lastRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadRecordsTable> {
  $$ReadRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<int> get readTime =>
      $composableBuilder(column: $table.readTime, builder: (column) => column);

  GeneratedColumn<int> get lastRead =>
      $composableBuilder(column: $table.lastRead, builder: (column) => column);
}

class $$ReadRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadRecordsTable,
          ReadRecord,
          $$ReadRecordsTableFilterComposer,
          $$ReadRecordsTableOrderingComposer,
          $$ReadRecordsTableAnnotationComposer,
          $$ReadRecordsTableCreateCompanionBuilder,
          $$ReadRecordsTableUpdateCompanionBuilder,
          (
            ReadRecord,
            BaseReferences<_$AppDatabase, $ReadRecordsTable, ReadRecord>,
          ),
          ReadRecord,
          PrefetchHooks Function()
        > {
  $$ReadRecordsTableTableManager(_$AppDatabase db, $ReadRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> bookName = const Value.absent(),
                Value<int> readTime = const Value.absent(),
                Value<int> lastRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadRecordsCompanion(
                deviceId: deviceId,
                bookName: bookName,
                readTime: readTime,
                lastRead: lastRead,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String bookName,
                Value<int> readTime = const Value.absent(),
                Value<int> lastRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadRecordsCompanion.insert(
                deviceId: deviceId,
                bookName: bookName,
                readTime: readTime,
                lastRead: lastRead,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadRecordsTable,
      ReadRecord,
      $$ReadRecordsTableFilterComposer,
      $$ReadRecordsTableOrderingComposer,
      $$ReadRecordsTableAnnotationComposer,
      $$ReadRecordsTableCreateCompanionBuilder,
      $$ReadRecordsTableUpdateCompanionBuilder,
      (
        ReadRecord,
        BaseReferences<_$AppDatabase, $ReadRecordsTable, ReadRecord>,
      ),
      ReadRecord,
      PrefetchHooks Function()
    >;
typedef $$BookGroupsTableCreateCompanionBuilder =
    BookGroupsCompanion Function({
      Value<int> groupId,
      required String groupName,
      Value<String?> cover,
      Value<int> order,
      Value<bool> enableRefresh,
      Value<bool> show,
      Value<int> bookSort,
      Value<bool> onlyUpdateRead,
    });
typedef $$BookGroupsTableUpdateCompanionBuilder =
    BookGroupsCompanion Function({
      Value<int> groupId,
      Value<String> groupName,
      Value<String?> cover,
      Value<int> order,
      Value<bool> enableRefresh,
      Value<bool> show,
      Value<int> bookSort,
      Value<bool> onlyUpdateRead,
    });

class $$BookGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $BookGroupsTable> {
  $$BookGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enableRefresh => $composableBuilder(
    column: $table.enableRefresh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bookSort => $composableBuilder(
    column: $table.bookSort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlyUpdateRead => $composableBuilder(
    column: $table.onlyUpdateRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookGroupsTable> {
  $$BookGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enableRefresh => $composableBuilder(
    column: $table.enableRefresh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bookSort => $composableBuilder(
    column: $table.bookSort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlyUpdateRead => $composableBuilder(
    column: $table.onlyUpdateRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookGroupsTable> {
  $$BookGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<bool> get enableRefresh => $composableBuilder(
    column: $table.enableRefresh,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get show =>
      $composableBuilder(column: $table.show, builder: (column) => column);

  GeneratedColumn<int> get bookSort =>
      $composableBuilder(column: $table.bookSort, builder: (column) => column);

  GeneratedColumn<bool> get onlyUpdateRead => $composableBuilder(
    column: $table.onlyUpdateRead,
    builder: (column) => column,
  );
}

class $$BookGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookGroupsTable,
          BookGroup,
          $$BookGroupsTableFilterComposer,
          $$BookGroupsTableOrderingComposer,
          $$BookGroupsTableAnnotationComposer,
          $$BookGroupsTableCreateCompanionBuilder,
          $$BookGroupsTableUpdateCompanionBuilder,
          (
            BookGroup,
            BaseReferences<_$AppDatabase, $BookGroupsTable, BookGroup>,
          ),
          BookGroup,
          PrefetchHooks Function()
        > {
  $$BookGroupsTableTableManager(_$AppDatabase db, $BookGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> groupId = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<int> order = const Value.absent(),
                Value<bool> enableRefresh = const Value.absent(),
                Value<bool> show = const Value.absent(),
                Value<int> bookSort = const Value.absent(),
                Value<bool> onlyUpdateRead = const Value.absent(),
              }) => BookGroupsCompanion(
                groupId: groupId,
                groupName: groupName,
                cover: cover,
                order: order,
                enableRefresh: enableRefresh,
                show: show,
                bookSort: bookSort,
                onlyUpdateRead: onlyUpdateRead,
              ),
          createCompanionCallback:
              ({
                Value<int> groupId = const Value.absent(),
                required String groupName,
                Value<String?> cover = const Value.absent(),
                Value<int> order = const Value.absent(),
                Value<bool> enableRefresh = const Value.absent(),
                Value<bool> show = const Value.absent(),
                Value<int> bookSort = const Value.absent(),
                Value<bool> onlyUpdateRead = const Value.absent(),
              }) => BookGroupsCompanion.insert(
                groupId: groupId,
                groupName: groupName,
                cover: cover,
                order: order,
                enableRefresh: enableRefresh,
                show: show,
                bookSort: bookSort,
                onlyUpdateRead: onlyUpdateRead,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookGroupsTable,
      BookGroup,
      $$BookGroupsTableFilterComposer,
      $$BookGroupsTableOrderingComposer,
      $$BookGroupsTableAnnotationComposer,
      $$BookGroupsTableCreateCompanionBuilder,
      $$BookGroupsTableUpdateCompanionBuilder,
      (BookGroup, BaseReferences<_$AppDatabase, $BookGroupsTable, BookGroup>),
      BookGroup,
      PrefetchHooks Function()
    >;
typedef $$CookiesTableCreateCompanionBuilder =
    CookiesCompanion Function({
      required String url,
      required String cookie,
      Value<int> rowid,
    });
typedef $$CookiesTableUpdateCompanionBuilder =
    CookiesCompanion Function({
      Value<String> url,
      Value<String> cookie,
      Value<int> rowid,
    });

class $$CookiesTableFilterComposer
    extends Composer<_$AppDatabase, $CookiesTable> {
  $$CookiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cookie => $composableBuilder(
    column: $table.cookie,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CookiesTableOrderingComposer
    extends Composer<_$AppDatabase, $CookiesTable> {
  $$CookiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cookie => $composableBuilder(
    column: $table.cookie,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CookiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CookiesTable> {
  $$CookiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get cookie =>
      $composableBuilder(column: $table.cookie, builder: (column) => column);
}

class $$CookiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CookiesTable,
          Cooky,
          $$CookiesTableFilterComposer,
          $$CookiesTableOrderingComposer,
          $$CookiesTableAnnotationComposer,
          $$CookiesTableCreateCompanionBuilder,
          $$CookiesTableUpdateCompanionBuilder,
          (Cooky, BaseReferences<_$AppDatabase, $CookiesTable, Cooky>),
          Cooky,
          PrefetchHooks Function()
        > {
  $$CookiesTableTableManager(_$AppDatabase db, $CookiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CookiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CookiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CookiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> url = const Value.absent(),
                Value<String> cookie = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CookiesCompanion(url: url, cookie: cookie, rowid: rowid),
          createCompanionCallback:
              ({
                required String url,
                required String cookie,
                Value<int> rowid = const Value.absent(),
              }) => CookiesCompanion.insert(
                url: url,
                cookie: cookie,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CookiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CookiesTable,
      Cooky,
      $$CookiesTableFilterComposer,
      $$CookiesTableOrderingComposer,
      $$CookiesTableAnnotationComposer,
      $$CookiesTableCreateCompanionBuilder,
      $$CookiesTableUpdateCompanionBuilder,
      (Cooky, BaseReferences<_$AppDatabase, $CookiesTable, Cooky>),
      Cooky,
      PrefetchHooks Function()
    >;
typedef $$CacheEntriesTableCreateCompanionBuilder =
    CacheEntriesCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> deadline,
      Value<int> rowid,
    });
typedef $$CacheEntriesTableUpdateCompanionBuilder =
    CacheEntriesCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> deadline,
      Value<int> rowid,
    });

class $$CacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);
}

class $$CacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheEntriesTable,
          CacheEntry,
          $$CacheEntriesTableFilterComposer,
          $$CacheEntriesTableOrderingComposer,
          $$CacheEntriesTableAnnotationComposer,
          $$CacheEntriesTableCreateCompanionBuilder,
          $$CacheEntriesTableUpdateCompanionBuilder,
          (
            CacheEntry,
            BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>,
          ),
          CacheEntry,
          PrefetchHooks Function()
        > {
  $$CacheEntriesTableTableManager(_$AppDatabase db, $CacheEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> deadline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion(
                key: key,
                value: value,
                deadline: deadline,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> deadline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion.insert(
                key: key,
                value: value,
                deadline: deadline,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheEntriesTable,
      CacheEntry,
      $$CacheEntriesTableFilterComposer,
      $$CacheEntriesTableOrderingComposer,
      $$CacheEntriesTableAnnotationComposer,
      $$CacheEntriesTableCreateCompanionBuilder,
      $$CacheEntriesTableUpdateCompanionBuilder,
      (
        CacheEntry,
        BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>,
      ),
      CacheEntry,
      PrefetchHooks Function()
    >;
typedef $$RssSourcesTableCreateCompanionBuilder =
    RssSourcesCompanion Function({
      required String sourceUrl,
      Value<String> sourceName,
      Value<String> sourceIcon,
      Value<String?> sourceGroup,
      Value<String?> sourceComment,
      Value<String?> variableComment,
      Value<bool> enabled,
      Value<bool> enabledCookieJar,
      Value<bool> enableJs,
      Value<bool> singleUrl,
      Value<bool> loadWithBaseUrl,
      Value<bool?> shouldOverrideUrlLoading,
      Value<int> articleStyle,
      Value<int> customOrder,
      Value<int> lastUpdateTime,
      Value<int> type,
      Value<int> showWebLog,
      Value<int> preload,
      Value<int> cacheFirst,
      Value<String?> jsLib,
      Value<String?> concurrentRate,
      Value<String?> header,
      Value<String?> loginUrl,
      Value<String?> loginUi,
      Value<String?> loginCheckJs,
      Value<String?> coverDecodeJs,
      Value<String?> sortUrl,
      Value<String?> ruleArticles,
      Value<String?> ruleNextPage,
      Value<String?> ruleTitle,
      Value<String?> rulePubDate,
      Value<String?> ruleDescription,
      Value<String?> ruleImage,
      Value<String?> ruleLink,
      Value<String?> ruleContent,
      Value<String?> contentWhitelist,
      Value<String?> contentBlacklist,
      Value<String?> style,
      Value<String?> injectJs,
      Value<String?> preloadJs,
      Value<String?> startHtml,
      Value<String?> startStyle,
      Value<String?> startJs,
      Value<String?> searchUrl,
      Value<int> rowid,
    });
typedef $$RssSourcesTableUpdateCompanionBuilder =
    RssSourcesCompanion Function({
      Value<String> sourceUrl,
      Value<String> sourceName,
      Value<String> sourceIcon,
      Value<String?> sourceGroup,
      Value<String?> sourceComment,
      Value<String?> variableComment,
      Value<bool> enabled,
      Value<bool> enabledCookieJar,
      Value<bool> enableJs,
      Value<bool> singleUrl,
      Value<bool> loadWithBaseUrl,
      Value<bool?> shouldOverrideUrlLoading,
      Value<int> articleStyle,
      Value<int> customOrder,
      Value<int> lastUpdateTime,
      Value<int> type,
      Value<int> showWebLog,
      Value<int> preload,
      Value<int> cacheFirst,
      Value<String?> jsLib,
      Value<String?> concurrentRate,
      Value<String?> header,
      Value<String?> loginUrl,
      Value<String?> loginUi,
      Value<String?> loginCheckJs,
      Value<String?> coverDecodeJs,
      Value<String?> sortUrl,
      Value<String?> ruleArticles,
      Value<String?> ruleNextPage,
      Value<String?> ruleTitle,
      Value<String?> rulePubDate,
      Value<String?> ruleDescription,
      Value<String?> ruleImage,
      Value<String?> ruleLink,
      Value<String?> ruleContent,
      Value<String?> contentWhitelist,
      Value<String?> contentBlacklist,
      Value<String?> style,
      Value<String?> injectJs,
      Value<String?> preloadJs,
      Value<String?> startHtml,
      Value<String?> startStyle,
      Value<String?> startJs,
      Value<String?> searchUrl,
      Value<int> rowid,
    });

class $$RssSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $RssSourcesTable> {
  $$RssSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceIcon => $composableBuilder(
    column: $table.sourceIcon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceGroup => $composableBuilder(
    column: $table.sourceGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceComment => $composableBuilder(
    column: $table.sourceComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variableComment => $composableBuilder(
    column: $table.variableComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabledCookieJar => $composableBuilder(
    column: $table.enabledCookieJar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enableJs => $composableBuilder(
    column: $table.enableJs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get singleUrl => $composableBuilder(
    column: $table.singleUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get loadWithBaseUrl => $composableBuilder(
    column: $table.loadWithBaseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shouldOverrideUrlLoading => $composableBuilder(
    column: $table.shouldOverrideUrlLoading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get articleStyle => $composableBuilder(
    column: $table.articleStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get showWebLog => $composableBuilder(
    column: $table.showWebLog,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get preload => $composableBuilder(
    column: $table.preload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheFirst => $composableBuilder(
    column: $table.cacheFirst,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsLib => $composableBuilder(
    column: $table.jsLib,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get concurrentRate => $composableBuilder(
    column: $table.concurrentRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get header => $composableBuilder(
    column: $table.header,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loginUrl => $composableBuilder(
    column: $table.loginUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loginUi => $composableBuilder(
    column: $table.loginUi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loginCheckJs => $composableBuilder(
    column: $table.loginCheckJs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverDecodeJs => $composableBuilder(
    column: $table.coverDecodeJs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortUrl => $composableBuilder(
    column: $table.sortUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleArticles => $composableBuilder(
    column: $table.ruleArticles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleNextPage => $composableBuilder(
    column: $table.ruleNextPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleTitle => $composableBuilder(
    column: $table.ruleTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulePubDate => $composableBuilder(
    column: $table.rulePubDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleDescription => $composableBuilder(
    column: $table.ruleDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleImage => $composableBuilder(
    column: $table.ruleImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleLink => $composableBuilder(
    column: $table.ruleLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleContent => $composableBuilder(
    column: $table.ruleContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentWhitelist => $composableBuilder(
    column: $table.contentWhitelist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentBlacklist => $composableBuilder(
    column: $table.contentBlacklist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get injectJs => $composableBuilder(
    column: $table.injectJs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preloadJs => $composableBuilder(
    column: $table.preloadJs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startHtml => $composableBuilder(
    column: $table.startHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startStyle => $composableBuilder(
    column: $table.startStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startJs => $composableBuilder(
    column: $table.startJs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchUrl => $composableBuilder(
    column: $table.searchUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RssSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $RssSourcesTable> {
  $$RssSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceIcon => $composableBuilder(
    column: $table.sourceIcon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceGroup => $composableBuilder(
    column: $table.sourceGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceComment => $composableBuilder(
    column: $table.sourceComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variableComment => $composableBuilder(
    column: $table.variableComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabledCookieJar => $composableBuilder(
    column: $table.enabledCookieJar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enableJs => $composableBuilder(
    column: $table.enableJs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get singleUrl => $composableBuilder(
    column: $table.singleUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get loadWithBaseUrl => $composableBuilder(
    column: $table.loadWithBaseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shouldOverrideUrlLoading => $composableBuilder(
    column: $table.shouldOverrideUrlLoading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get articleStyle => $composableBuilder(
    column: $table.articleStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get showWebLog => $composableBuilder(
    column: $table.showWebLog,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get preload => $composableBuilder(
    column: $table.preload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheFirst => $composableBuilder(
    column: $table.cacheFirst,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsLib => $composableBuilder(
    column: $table.jsLib,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get concurrentRate => $composableBuilder(
    column: $table.concurrentRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get header => $composableBuilder(
    column: $table.header,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginUrl => $composableBuilder(
    column: $table.loginUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginUi => $composableBuilder(
    column: $table.loginUi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginCheckJs => $composableBuilder(
    column: $table.loginCheckJs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverDecodeJs => $composableBuilder(
    column: $table.coverDecodeJs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortUrl => $composableBuilder(
    column: $table.sortUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleArticles => $composableBuilder(
    column: $table.ruleArticles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleNextPage => $composableBuilder(
    column: $table.ruleNextPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleTitle => $composableBuilder(
    column: $table.ruleTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulePubDate => $composableBuilder(
    column: $table.rulePubDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleDescription => $composableBuilder(
    column: $table.ruleDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleImage => $composableBuilder(
    column: $table.ruleImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleLink => $composableBuilder(
    column: $table.ruleLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleContent => $composableBuilder(
    column: $table.ruleContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentWhitelist => $composableBuilder(
    column: $table.contentWhitelist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentBlacklist => $composableBuilder(
    column: $table.contentBlacklist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get injectJs => $composableBuilder(
    column: $table.injectJs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preloadJs => $composableBuilder(
    column: $table.preloadJs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startHtml => $composableBuilder(
    column: $table.startHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startStyle => $composableBuilder(
    column: $table.startStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startJs => $composableBuilder(
    column: $table.startJs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchUrl => $composableBuilder(
    column: $table.searchUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RssSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RssSourcesTable> {
  $$RssSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceIcon => $composableBuilder(
    column: $table.sourceIcon,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceGroup => $composableBuilder(
    column: $table.sourceGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceComment => $composableBuilder(
    column: $table.sourceComment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variableComment => $composableBuilder(
    column: $table.variableComment,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get enabledCookieJar => $composableBuilder(
    column: $table.enabledCookieJar,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enableJs =>
      $composableBuilder(column: $table.enableJs, builder: (column) => column);

  GeneratedColumn<bool> get singleUrl =>
      $composableBuilder(column: $table.singleUrl, builder: (column) => column);

  GeneratedColumn<bool> get loadWithBaseUrl => $composableBuilder(
    column: $table.loadWithBaseUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get shouldOverrideUrlLoading => $composableBuilder(
    column: $table.shouldOverrideUrlLoading,
    builder: (column) => column,
  );

  GeneratedColumn<int> get articleStyle => $composableBuilder(
    column: $table.articleStyle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get showWebLog => $composableBuilder(
    column: $table.showWebLog,
    builder: (column) => column,
  );

  GeneratedColumn<int> get preload =>
      $composableBuilder(column: $table.preload, builder: (column) => column);

  GeneratedColumn<int> get cacheFirst => $composableBuilder(
    column: $table.cacheFirst,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jsLib =>
      $composableBuilder(column: $table.jsLib, builder: (column) => column);

  GeneratedColumn<String> get concurrentRate => $composableBuilder(
    column: $table.concurrentRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get header =>
      $composableBuilder(column: $table.header, builder: (column) => column);

  GeneratedColumn<String> get loginUrl =>
      $composableBuilder(column: $table.loginUrl, builder: (column) => column);

  GeneratedColumn<String> get loginUi =>
      $composableBuilder(column: $table.loginUi, builder: (column) => column);

  GeneratedColumn<String> get loginCheckJs => $composableBuilder(
    column: $table.loginCheckJs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverDecodeJs => $composableBuilder(
    column: $table.coverDecodeJs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortUrl =>
      $composableBuilder(column: $table.sortUrl, builder: (column) => column);

  GeneratedColumn<String> get ruleArticles => $composableBuilder(
    column: $table.ruleArticles,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleNextPage => $composableBuilder(
    column: $table.ruleNextPage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleTitle =>
      $composableBuilder(column: $table.ruleTitle, builder: (column) => column);

  GeneratedColumn<String> get rulePubDate => $composableBuilder(
    column: $table.rulePubDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleDescription => $composableBuilder(
    column: $table.ruleDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleImage =>
      $composableBuilder(column: $table.ruleImage, builder: (column) => column);

  GeneratedColumn<String> get ruleLink =>
      $composableBuilder(column: $table.ruleLink, builder: (column) => column);

  GeneratedColumn<String> get ruleContent => $composableBuilder(
    column: $table.ruleContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentWhitelist => $composableBuilder(
    column: $table.contentWhitelist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentBlacklist => $composableBuilder(
    column: $table.contentBlacklist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get injectJs =>
      $composableBuilder(column: $table.injectJs, builder: (column) => column);

  GeneratedColumn<String> get preloadJs =>
      $composableBuilder(column: $table.preloadJs, builder: (column) => column);

  GeneratedColumn<String> get startHtml =>
      $composableBuilder(column: $table.startHtml, builder: (column) => column);

  GeneratedColumn<String> get startStyle => $composableBuilder(
    column: $table.startStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startJs =>
      $composableBuilder(column: $table.startJs, builder: (column) => column);

  GeneratedColumn<String> get searchUrl =>
      $composableBuilder(column: $table.searchUrl, builder: (column) => column);
}

class $$RssSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RssSourcesTable,
          RssSource,
          $$RssSourcesTableFilterComposer,
          $$RssSourcesTableOrderingComposer,
          $$RssSourcesTableAnnotationComposer,
          $$RssSourcesTableCreateCompanionBuilder,
          $$RssSourcesTableUpdateCompanionBuilder,
          (
            RssSource,
            BaseReferences<_$AppDatabase, $RssSourcesTable, RssSource>,
          ),
          RssSource,
          PrefetchHooks Function()
        > {
  $$RssSourcesTableTableManager(_$AppDatabase db, $RssSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RssSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RssSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RssSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceUrl = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<String> sourceIcon = const Value.absent(),
                Value<String?> sourceGroup = const Value.absent(),
                Value<String?> sourceComment = const Value.absent(),
                Value<String?> variableComment = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> enabledCookieJar = const Value.absent(),
                Value<bool> enableJs = const Value.absent(),
                Value<bool> singleUrl = const Value.absent(),
                Value<bool> loadWithBaseUrl = const Value.absent(),
                Value<bool?> shouldOverrideUrlLoading = const Value.absent(),
                Value<int> articleStyle = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> lastUpdateTime = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> showWebLog = const Value.absent(),
                Value<int> preload = const Value.absent(),
                Value<int> cacheFirst = const Value.absent(),
                Value<String?> jsLib = const Value.absent(),
                Value<String?> concurrentRate = const Value.absent(),
                Value<String?> header = const Value.absent(),
                Value<String?> loginUrl = const Value.absent(),
                Value<String?> loginUi = const Value.absent(),
                Value<String?> loginCheckJs = const Value.absent(),
                Value<String?> coverDecodeJs = const Value.absent(),
                Value<String?> sortUrl = const Value.absent(),
                Value<String?> ruleArticles = const Value.absent(),
                Value<String?> ruleNextPage = const Value.absent(),
                Value<String?> ruleTitle = const Value.absent(),
                Value<String?> rulePubDate = const Value.absent(),
                Value<String?> ruleDescription = const Value.absent(),
                Value<String?> ruleImage = const Value.absent(),
                Value<String?> ruleLink = const Value.absent(),
                Value<String?> ruleContent = const Value.absent(),
                Value<String?> contentWhitelist = const Value.absent(),
                Value<String?> contentBlacklist = const Value.absent(),
                Value<String?> style = const Value.absent(),
                Value<String?> injectJs = const Value.absent(),
                Value<String?> preloadJs = const Value.absent(),
                Value<String?> startHtml = const Value.absent(),
                Value<String?> startStyle = const Value.absent(),
                Value<String?> startJs = const Value.absent(),
                Value<String?> searchUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssSourcesCompanion(
                sourceUrl: sourceUrl,
                sourceName: sourceName,
                sourceIcon: sourceIcon,
                sourceGroup: sourceGroup,
                sourceComment: sourceComment,
                variableComment: variableComment,
                enabled: enabled,
                enabledCookieJar: enabledCookieJar,
                enableJs: enableJs,
                singleUrl: singleUrl,
                loadWithBaseUrl: loadWithBaseUrl,
                shouldOverrideUrlLoading: shouldOverrideUrlLoading,
                articleStyle: articleStyle,
                customOrder: customOrder,
                lastUpdateTime: lastUpdateTime,
                type: type,
                showWebLog: showWebLog,
                preload: preload,
                cacheFirst: cacheFirst,
                jsLib: jsLib,
                concurrentRate: concurrentRate,
                header: header,
                loginUrl: loginUrl,
                loginUi: loginUi,
                loginCheckJs: loginCheckJs,
                coverDecodeJs: coverDecodeJs,
                sortUrl: sortUrl,
                ruleArticles: ruleArticles,
                ruleNextPage: ruleNextPage,
                ruleTitle: ruleTitle,
                rulePubDate: rulePubDate,
                ruleDescription: ruleDescription,
                ruleImage: ruleImage,
                ruleLink: ruleLink,
                ruleContent: ruleContent,
                contentWhitelist: contentWhitelist,
                contentBlacklist: contentBlacklist,
                style: style,
                injectJs: injectJs,
                preloadJs: preloadJs,
                startHtml: startHtml,
                startStyle: startStyle,
                startJs: startJs,
                searchUrl: searchUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceUrl,
                Value<String> sourceName = const Value.absent(),
                Value<String> sourceIcon = const Value.absent(),
                Value<String?> sourceGroup = const Value.absent(),
                Value<String?> sourceComment = const Value.absent(),
                Value<String?> variableComment = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> enabledCookieJar = const Value.absent(),
                Value<bool> enableJs = const Value.absent(),
                Value<bool> singleUrl = const Value.absent(),
                Value<bool> loadWithBaseUrl = const Value.absent(),
                Value<bool?> shouldOverrideUrlLoading = const Value.absent(),
                Value<int> articleStyle = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> lastUpdateTime = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> showWebLog = const Value.absent(),
                Value<int> preload = const Value.absent(),
                Value<int> cacheFirst = const Value.absent(),
                Value<String?> jsLib = const Value.absent(),
                Value<String?> concurrentRate = const Value.absent(),
                Value<String?> header = const Value.absent(),
                Value<String?> loginUrl = const Value.absent(),
                Value<String?> loginUi = const Value.absent(),
                Value<String?> loginCheckJs = const Value.absent(),
                Value<String?> coverDecodeJs = const Value.absent(),
                Value<String?> sortUrl = const Value.absent(),
                Value<String?> ruleArticles = const Value.absent(),
                Value<String?> ruleNextPage = const Value.absent(),
                Value<String?> ruleTitle = const Value.absent(),
                Value<String?> rulePubDate = const Value.absent(),
                Value<String?> ruleDescription = const Value.absent(),
                Value<String?> ruleImage = const Value.absent(),
                Value<String?> ruleLink = const Value.absent(),
                Value<String?> ruleContent = const Value.absent(),
                Value<String?> contentWhitelist = const Value.absent(),
                Value<String?> contentBlacklist = const Value.absent(),
                Value<String?> style = const Value.absent(),
                Value<String?> injectJs = const Value.absent(),
                Value<String?> preloadJs = const Value.absent(),
                Value<String?> startHtml = const Value.absent(),
                Value<String?> startStyle = const Value.absent(),
                Value<String?> startJs = const Value.absent(),
                Value<String?> searchUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssSourcesCompanion.insert(
                sourceUrl: sourceUrl,
                sourceName: sourceName,
                sourceIcon: sourceIcon,
                sourceGroup: sourceGroup,
                sourceComment: sourceComment,
                variableComment: variableComment,
                enabled: enabled,
                enabledCookieJar: enabledCookieJar,
                enableJs: enableJs,
                singleUrl: singleUrl,
                loadWithBaseUrl: loadWithBaseUrl,
                shouldOverrideUrlLoading: shouldOverrideUrlLoading,
                articleStyle: articleStyle,
                customOrder: customOrder,
                lastUpdateTime: lastUpdateTime,
                type: type,
                showWebLog: showWebLog,
                preload: preload,
                cacheFirst: cacheFirst,
                jsLib: jsLib,
                concurrentRate: concurrentRate,
                header: header,
                loginUrl: loginUrl,
                loginUi: loginUi,
                loginCheckJs: loginCheckJs,
                coverDecodeJs: coverDecodeJs,
                sortUrl: sortUrl,
                ruleArticles: ruleArticles,
                ruleNextPage: ruleNextPage,
                ruleTitle: ruleTitle,
                rulePubDate: rulePubDate,
                ruleDescription: ruleDescription,
                ruleImage: ruleImage,
                ruleLink: ruleLink,
                ruleContent: ruleContent,
                contentWhitelist: contentWhitelist,
                contentBlacklist: contentBlacklist,
                style: style,
                injectJs: injectJs,
                preloadJs: preloadJs,
                startHtml: startHtml,
                startStyle: startStyle,
                startJs: startJs,
                searchUrl: searchUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RssSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RssSourcesTable,
      RssSource,
      $$RssSourcesTableFilterComposer,
      $$RssSourcesTableOrderingComposer,
      $$RssSourcesTableAnnotationComposer,
      $$RssSourcesTableCreateCompanionBuilder,
      $$RssSourcesTableUpdateCompanionBuilder,
      (RssSource, BaseReferences<_$AppDatabase, $RssSourcesTable, RssSource>),
      RssSource,
      PrefetchHooks Function()
    >;
typedef $$RssArticlesTableCreateCompanionBuilder =
    RssArticlesCompanion Function({
      required String origin,
      required String link,
      required String sort,
      Value<String> title,
      Value<int> order,
      Value<String?> pubDate,
      Value<String?> description,
      Value<String?> content,
      Value<String?> image,
      Value<String> group,
      Value<bool> read,
      Value<String?> variable,
      Value<int> type,
      Value<int> durPos,
      Value<int> rowid,
    });
typedef $$RssArticlesTableUpdateCompanionBuilder =
    RssArticlesCompanion Function({
      Value<String> origin,
      Value<String> link,
      Value<String> sort,
      Value<String> title,
      Value<int> order,
      Value<String?> pubDate,
      Value<String?> description,
      Value<String?> content,
      Value<String?> image,
      Value<String> group,
      Value<bool> read,
      Value<String?> variable,
      Value<int> type,
      Value<int> durPos,
      Value<int> rowid,
    });

class $$RssArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $RssArticlesTable> {
  $$RssArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pubDate => $composableBuilder(
    column: $table.pubDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durPos => $composableBuilder(
    column: $table.durPos,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RssArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $RssArticlesTable> {
  $$RssArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pubDate => $composableBuilder(
    column: $table.pubDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durPos => $composableBuilder(
    column: $table.durPos,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RssArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RssArticlesTable> {
  $$RssArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<String> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<String> get pubDate =>
      $composableBuilder(column: $table.pubDate, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<String> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);

  GeneratedColumn<String> get variable =>
      $composableBuilder(column: $table.variable, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get durPos =>
      $composableBuilder(column: $table.durPos, builder: (column) => column);
}

class $$RssArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RssArticlesTable,
          RssArticle,
          $$RssArticlesTableFilterComposer,
          $$RssArticlesTableOrderingComposer,
          $$RssArticlesTableAnnotationComposer,
          $$RssArticlesTableCreateCompanionBuilder,
          $$RssArticlesTableUpdateCompanionBuilder,
          (
            RssArticle,
            BaseReferences<_$AppDatabase, $RssArticlesTable, RssArticle>,
          ),
          RssArticle,
          PrefetchHooks Function()
        > {
  $$RssArticlesTableTableManager(_$AppDatabase db, $RssArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RssArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RssArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RssArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> origin = const Value.absent(),
                Value<String> link = const Value.absent(),
                Value<String> sort = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> order = const Value.absent(),
                Value<String?> pubDate = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<String> group = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> durPos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssArticlesCompanion(
                origin: origin,
                link: link,
                sort: sort,
                title: title,
                order: order,
                pubDate: pubDate,
                description: description,
                content: content,
                image: image,
                group: group,
                read: read,
                variable: variable,
                type: type,
                durPos: durPos,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String origin,
                required String link,
                required String sort,
                Value<String> title = const Value.absent(),
                Value<int> order = const Value.absent(),
                Value<String?> pubDate = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<String> group = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> durPos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssArticlesCompanion.insert(
                origin: origin,
                link: link,
                sort: sort,
                title: title,
                order: order,
                pubDate: pubDate,
                description: description,
                content: content,
                image: image,
                group: group,
                read: read,
                variable: variable,
                type: type,
                durPos: durPos,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RssArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RssArticlesTable,
      RssArticle,
      $$RssArticlesTableFilterComposer,
      $$RssArticlesTableOrderingComposer,
      $$RssArticlesTableAnnotationComposer,
      $$RssArticlesTableCreateCompanionBuilder,
      $$RssArticlesTableUpdateCompanionBuilder,
      (
        RssArticle,
        BaseReferences<_$AppDatabase, $RssArticlesTable, RssArticle>,
      ),
      RssArticle,
      PrefetchHooks Function()
    >;
typedef $$RssStarsTableCreateCompanionBuilder =
    RssStarsCompanion Function({
      required String origin,
      required String link,
      Value<String> sort,
      Value<String> title,
      Value<int> starTime,
      Value<String?> pubDate,
      Value<String?> description,
      Value<String?> content,
      Value<String?> image,
      Value<String> group,
      Value<String?> variable,
      Value<int> type,
      Value<int> durPos,
      Value<int> rowid,
    });
typedef $$RssStarsTableUpdateCompanionBuilder =
    RssStarsCompanion Function({
      Value<String> origin,
      Value<String> link,
      Value<String> sort,
      Value<String> title,
      Value<int> starTime,
      Value<String?> pubDate,
      Value<String?> description,
      Value<String?> content,
      Value<String?> image,
      Value<String> group,
      Value<String?> variable,
      Value<int> type,
      Value<int> durPos,
      Value<int> rowid,
    });

class $$RssStarsTableFilterComposer
    extends Composer<_$AppDatabase, $RssStarsTable> {
  $$RssStarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get starTime => $composableBuilder(
    column: $table.starTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pubDate => $composableBuilder(
    column: $table.pubDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durPos => $composableBuilder(
    column: $table.durPos,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RssStarsTableOrderingComposer
    extends Composer<_$AppDatabase, $RssStarsTable> {
  $$RssStarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get starTime => $composableBuilder(
    column: $table.starTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pubDate => $composableBuilder(
    column: $table.pubDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durPos => $composableBuilder(
    column: $table.durPos,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RssStarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RssStarsTable> {
  $$RssStarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<String> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get starTime =>
      $composableBuilder(column: $table.starTime, builder: (column) => column);

  GeneratedColumn<String> get pubDate =>
      $composableBuilder(column: $table.pubDate, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<String> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  GeneratedColumn<String> get variable =>
      $composableBuilder(column: $table.variable, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get durPos =>
      $composableBuilder(column: $table.durPos, builder: (column) => column);
}

class $$RssStarsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RssStarsTable,
          RssStar,
          $$RssStarsTableFilterComposer,
          $$RssStarsTableOrderingComposer,
          $$RssStarsTableAnnotationComposer,
          $$RssStarsTableCreateCompanionBuilder,
          $$RssStarsTableUpdateCompanionBuilder,
          (RssStar, BaseReferences<_$AppDatabase, $RssStarsTable, RssStar>),
          RssStar,
          PrefetchHooks Function()
        > {
  $$RssStarsTableTableManager(_$AppDatabase db, $RssStarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RssStarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RssStarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RssStarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> origin = const Value.absent(),
                Value<String> link = const Value.absent(),
                Value<String> sort = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> starTime = const Value.absent(),
                Value<String?> pubDate = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<String> group = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> durPos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssStarsCompanion(
                origin: origin,
                link: link,
                sort: sort,
                title: title,
                starTime: starTime,
                pubDate: pubDate,
                description: description,
                content: content,
                image: image,
                group: group,
                variable: variable,
                type: type,
                durPos: durPos,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String origin,
                required String link,
                Value<String> sort = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> starTime = const Value.absent(),
                Value<String?> pubDate = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<String> group = const Value.absent(),
                Value<String?> variable = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> durPos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssStarsCompanion.insert(
                origin: origin,
                link: link,
                sort: sort,
                title: title,
                starTime: starTime,
                pubDate: pubDate,
                description: description,
                content: content,
                image: image,
                group: group,
                variable: variable,
                type: type,
                durPos: durPos,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RssStarsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RssStarsTable,
      RssStar,
      $$RssStarsTableFilterComposer,
      $$RssStarsTableOrderingComposer,
      $$RssStarsTableAnnotationComposer,
      $$RssStarsTableCreateCompanionBuilder,
      $$RssStarsTableUpdateCompanionBuilder,
      (RssStar, BaseReferences<_$AppDatabase, $RssStarsTable, RssStar>),
      RssStar,
      PrefetchHooks Function()
    >;
typedef $$RssReadRecordsTableCreateCompanionBuilder =
    RssReadRecordsCompanion Function({
      required String record,
      Value<String> origin,
      Value<String> sort,
      Value<String?> title,
      Value<int?> readTime,
      Value<bool> read,
      Value<String?> image,
      Value<int> type,
      Value<int> durPos,
      Value<String?> pubDate,
      Value<int> rowid,
    });
typedef $$RssReadRecordsTableUpdateCompanionBuilder =
    RssReadRecordsCompanion Function({
      Value<String> record,
      Value<String> origin,
      Value<String> sort,
      Value<String?> title,
      Value<int?> readTime,
      Value<bool> read,
      Value<String?> image,
      Value<int> type,
      Value<int> durPos,
      Value<String?> pubDate,
      Value<int> rowid,
    });

class $$RssReadRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RssReadRecordsTable> {
  $$RssReadRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readTime => $composableBuilder(
    column: $table.readTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durPos => $composableBuilder(
    column: $table.durPos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pubDate => $composableBuilder(
    column: $table.pubDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RssReadRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RssReadRecordsTable> {
  $$RssReadRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readTime => $composableBuilder(
    column: $table.readTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durPos => $composableBuilder(
    column: $table.durPos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pubDate => $composableBuilder(
    column: $table.pubDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RssReadRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RssReadRecordsTable> {
  $$RssReadRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get readTime =>
      $composableBuilder(column: $table.readTime, builder: (column) => column);

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);

  GeneratedColumn<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get durPos =>
      $composableBuilder(column: $table.durPos, builder: (column) => column);

  GeneratedColumn<String> get pubDate =>
      $composableBuilder(column: $table.pubDate, builder: (column) => column);
}

class $$RssReadRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RssReadRecordsTable,
          RssReadRecord,
          $$RssReadRecordsTableFilterComposer,
          $$RssReadRecordsTableOrderingComposer,
          $$RssReadRecordsTableAnnotationComposer,
          $$RssReadRecordsTableCreateCompanionBuilder,
          $$RssReadRecordsTableUpdateCompanionBuilder,
          (
            RssReadRecord,
            BaseReferences<_$AppDatabase, $RssReadRecordsTable, RssReadRecord>,
          ),
          RssReadRecord,
          PrefetchHooks Function()
        > {
  $$RssReadRecordsTableTableManager(
    _$AppDatabase db,
    $RssReadRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RssReadRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RssReadRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RssReadRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> record = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> sort = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> readTime = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> durPos = const Value.absent(),
                Value<String?> pubDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssReadRecordsCompanion(
                record: record,
                origin: origin,
                sort: sort,
                title: title,
                readTime: readTime,
                read: read,
                image: image,
                type: type,
                durPos: durPos,
                pubDate: pubDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String record,
                Value<String> origin = const Value.absent(),
                Value<String> sort = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> readTime = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> durPos = const Value.absent(),
                Value<String?> pubDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RssReadRecordsCompanion.insert(
                record: record,
                origin: origin,
                sort: sort,
                title: title,
                readTime: readTime,
                read: read,
                image: image,
                type: type,
                durPos: durPos,
                pubDate: pubDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RssReadRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RssReadRecordsTable,
      RssReadRecord,
      $$RssReadRecordsTableFilterComposer,
      $$RssReadRecordsTableOrderingComposer,
      $$RssReadRecordsTableAnnotationComposer,
      $$RssReadRecordsTableCreateCompanionBuilder,
      $$RssReadRecordsTableUpdateCompanionBuilder,
      (
        RssReadRecord,
        BaseReferences<_$AppDatabase, $RssReadRecordsTable, RssReadRecord>,
      ),
      RssReadRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$BookSourcesTableTableManager get bookSources =>
      $$BookSourcesTableTableManager(_db, _db.bookSources);
  $$SearchBooksTableTableManager get searchBooks =>
      $$SearchBooksTableTableManager(_db, _db.searchBooks);
  $$ReplaceRulesTableTableManager get replaceRules =>
      $$ReplaceRulesTableTableManager(_db, _db.replaceRules);
  $$BookChaptersTableTableManager get bookChapters =>
      $$BookChaptersTableTableManager(_db, _db.bookChapters);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ReadRecordsTableTableManager get readRecords =>
      $$ReadRecordsTableTableManager(_db, _db.readRecords);
  $$BookGroupsTableTableManager get bookGroups =>
      $$BookGroupsTableTableManager(_db, _db.bookGroups);
  $$CookiesTableTableManager get cookies =>
      $$CookiesTableTableManager(_db, _db.cookies);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
  $$RssSourcesTableTableManager get rssSources =>
      $$RssSourcesTableTableManager(_db, _db.rssSources);
  $$RssArticlesTableTableManager get rssArticles =>
      $$RssArticlesTableTableManager(_db, _db.rssArticles);
  $$RssStarsTableTableManager get rssStars =>
      $$RssStarsTableTableManager(_db, _db.rssStars);
  $$RssReadRecordsTableTableManager get rssReadRecords =>
      $$RssReadRecordsTableTableManager(_db, _db.rssReadRecords);
}
