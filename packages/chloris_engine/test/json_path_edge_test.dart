import 'dart:convert';

import 'package:test/test.dart';
import 'package:chloris_engine/chloris_engine.dart';

void main() {
  test('JSONPath supports wildcard, negative index and quoted union keys', () {
    final json =
        '{"items":[{"name":"A","title":"T"},{"name":"B"}],"meta":{"x":1}}';
    final a = AnalyzeByJsonPath(json);
    expect(a.getStringList(r'$.items[*].name'), ['A', 'B']);
    expect(a.getStringList(r'$.items[-1].name'), ['B']);
    expect(a.getStringList(r"$.items[0]['name','title']"), ['A', 'T']);
  });

  test('JSONPath filter expressions', () {
    final json = jsonEncode({
      'data': [
        {'id': 1, 'name': '仙逆'},
        {'id': 2, 'name': '求魔'},
        {'id': 3, 'name': '仙逆'},
      ],
    });
    final a = AnalyzeByJsonPath(json);
    expect(a.getStringList(r'$.data[?(@.id==1)].name'), ['仙逆']);
    expect(a.getStringList(r'$.data[?(@.id>1)].name'), ['求魔', '仙逆']);
    expect(a.getList(r'$.data[?(@.name=="求魔")]').length, 1);
  });

  test(
    'JSONPath supports slices, array unions, dot wildcards and nested filters',
    () {
      final json = jsonEncode({
        'items': [
          {
            'meta': {'score': 1},
            'name': 'A',
          },
          {
            'meta': {'score': 3},
            'name': 'B',
          },
          {
            'meta': {'score': 5},
            'name': 'C',
          },
          {
            'meta': {'score': 7},
            'name': 'D',
          },
        ],
        'groups': {
          'one': {'title': '一'},
          'two': {'title': '二'},
        },
      });
      final a = AnalyzeByJsonPath(json);
      expect(a.getStringList(r'$.items[1:4:2].name'), ['B', 'D']);
      expect(a.getStringList(r'$.items[::-1].name'), ['D', 'C', 'B', 'A']);
      expect(a.getStringList(r'$.items[0,2].name'), ['A', 'C']);
      expect(a.getStringList(r'$.groups.*.title'), ['一', '二']);
      expect(a.getStringList(r'$.items[?(contains(@.name,"C"))].name'), ['C']);
      expect(a.getStringList(r'$.items[?(@.meta.score>=5)].name'), ['C', 'D']);
    },
  );

  test('JSONPath filters support logical, length and regex predicates', () {
    final a = AnalyzeByJsonPath({
      'items': [
        {'name': 'Alpha', 'tags': ['a', 'b']},
        {'name': 'beta', 'tags': []},
        {'name': 'Gamma', 'tags': ['g']},
      ],
    });
    expect(
      a.getStringList(r'$.items[?(@.tags.length>0&&@.name=~/a/i)].name'),
      ['Alpha', 'Gamma'],
    );
    expect(
      a.getStringList(r'$.items[?(@.name contains "beta")].name'),
      ['beta'],
    );
  });

  test('JSONPath invalid regex predicate safely rejects the item', () {
    final a = AnalyzeByJsonPath({
      'items': [
        {'name': 'Alpha'},
      ],
    });

    expect(a.getStringList(r'$.items[?(@.name=~/[/)].name'), isEmpty);
  });
}
