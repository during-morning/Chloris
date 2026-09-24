import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/online/online_reading_use_cases.dart';
import '../../app/providers.dart';

Future<List<SearchBook>> exploreBooks(
  WidgetRef ref, {
  required BookSource source,
  required String url,
  int page = 1,
}) {
  return ref.read(exploreOnlineBooksUseCaseProvider)(source, url, page: page);
}
