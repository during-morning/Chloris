import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/reader/measured_paginator.dart';

void main() {
  testWidgets('MeasuredPaginator 按可视高度切出多页且偏移递增', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final content = List.generate(
      80,
      (i) => '第$i 段用于分页测量，内容足够长以换行。',
    ).join('\n\n');
    final pg = MeasuredPaginator.layout(
      content: content,
      width: 360,
      height: 240,
      style: const TextStyle(fontSize: 18, height: 1.6),
      paragraphSpacing: 8,
    );
    // Keep this assertion close to the layout fixture: every page must carry
    // actual text and page ranges must advance without a zero-length loop.
    expect(pg.pages.every((p) => p.text.isNotEmpty), isTrue);
    expect(pg.total, greaterThan(1));
    expect(pg.pages.first.startPos, 0);
    expect(pg.pages.last.endPos, greaterThan(pg.pages.first.endPos));
    for (var i = 1; i < pg.pages.length; i++) {
      expect(
        pg.pages[i].startPos,
        greaterThanOrEqualTo(pg.pages[i - 1].startPos),
      );
    }
  });

  testWidgets('first page can be shorter so later pages fill the column', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final content = List.generate(
      40,
      (i) => '第$i 段用于首页留标题、后续页铺满。',
    ).join('\n');
    final shortFirst = MeasuredPaginator.layout(
      content: content,
      width: 360,
      height: 400,
      firstPageHeight: 160,
      style: const TextStyle(fontSize: 18, height: 1.6),
    );
    final even = MeasuredPaginator.layout(
      content: content,
      width: 360,
      height: 400,
      style: const TextStyle(fontSize: 18, height: 1.6),
    );
    expect(shortFirst.pages.first.lines.length, lessThan(even.pages.first.lines.length));
    expect(shortFirst.total, greaterThanOrEqualTo(even.total));
  });

  test('CJK tidy keeps punctuation and lone glyphs off a new line', () {
    final tidied = tidyCjkLineStrings(const [
      '他终于明白了这件',
      '。事的真相',
      '法',
    ]);
    expect(tidied, ['他终于明白了这件。', '事的真', '相法']);
    expect(tidied.every((e) => !e.startsWith('。')), isTrue);
    expect(tidied.every((e) => e.length != 1), isTrue);
    expect(tidyCjkLineStrings(const ['寇洪拔刀相向', '！”']), ['寇洪拔刀相向！”']);
  });

  testWidgets('分页行测量不会把截图中的中文短尾拆成碎片行', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    const paragraph =
        '　　道玄子的语气忽地变为凶狠：“既如此，如今长生法门在前，我又怎么可能放过你，我又怎么可能不欺人太甚！”\n\n'
        '　　寇洪大笑：“不过做过一场罢了！可笑你我百年兄弟，如今却为了 一线生机拔刀相向！”\n\n'
        '　　寇洪却忽然说道：“我知道我不是你的对手，今日想必难逃一劫。但是此地凡人如此之多，却又不知道，你是否又能抵挡得住如此浓度的仙凡瘴呢！”';
    final page = MeasuredPaginator.layout(
      content: paragraph,
      width: 360,
      height: 800,
      style: const TextStyle(
        fontFamily: 'PTSerif',
        fontFamilyFallback: ['NotoSerifSC'],
        fontSize: 20,
        height: 1.6,
      ),
    );
    final lines = page.pages.expand((p) => p.lines).where((l) => l.isNotEmpty);
    expect(lines, isNotEmpty);
    expect(lines.where((line) => line.trim().runes.length < 3), isEmpty);
    expect(page.pages.expand((p) => p.lines).join(), contains('我又怎么可能不欺人太甚'));
  });

  test('collapseReaderBlankLines keeps one break between paragraphs', () {
    expect(
      collapseReaderBlankLines('第一段。\n\n\n　　\n第二段。'),
      '第一段。\n第二段。',
    );
  });

  testWidgets('blank paragraphs collapse to one small gap, not full lines', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final pg = MeasuredPaginator.layout(
      content: '第一段。\n\n\n　　\n第二段。',
      width: 360,
      height: 720,
      style: const TextStyle(fontSize: 18, height: 1.6),
      paragraphSpacing: 8,
    );
    final lines = pg.pages.expand((p) => p.lines).toList();
    expect(lines.where((l) => l.contains('第一段')), isNotEmpty);
    expect(lines.where((l) => l.contains('第二段')), isNotEmpty);
    expect(lines.where((l) => l.trim().isEmpty), hasLength(1));
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        expect(lines[i - 1].trim(), isNotEmpty);
      }
    }
  });

  testWidgets('measured CJK lines do not start with a full stop', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final pg = MeasuredPaginator.layout(
      content: '他终于明白了这件事。经营起了小本生意。李凡用这个办法与人报恩。',
      width: 168,
      height: 720,
      style: const TextStyle(fontSize: 18, height: 1.6),
    );
    final lines = pg.pages.expand((p) => p.lines).where((l) => l.isNotEmpty);
    expect(lines, isNotEmpty);
    expect(lines.every((l) => !l.startsWith('。')), isTrue);
    expect(lines.every((l) => l.length > 1), isTrue);
  });
}
