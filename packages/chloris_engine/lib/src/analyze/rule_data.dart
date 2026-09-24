class RuleData {
  RuleData({this.variable});

  String? variable;
  final Map<String, String> values = {};

  String get(String key) => values[key] ?? '';

  void put(String key, String value) {
    values[key] = value;
  }
}
