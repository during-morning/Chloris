class AppStrings {
  const AppStrings(this.language);

  final String language;

  static AppStrings of(String lang) =>
      lang == 'en' ? const AppStrings('en') : const AppStrings('zh');

  String get library => language == 'en' ? 'Library' : '书库';
  String get search => language == 'en' ? 'Search' : '寻找';
  String get explore => language == 'en' ? 'Explore' : '探索';
  String get sources => language == 'en' ? 'Sources' : '书源';
  String get rss => 'RSS';
  String get settings => language == 'en' ? 'Mine' : '我的';
  String get readingSpace => language == 'en' ? 'Your reading space' : '你的阅读空间';
  String get emptyLibrary => language == 'en' ? 'No books yet' : '书库还没有书';
}
