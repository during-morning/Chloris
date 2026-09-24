import 'package:chloris_engine/chloris_engine.dart';

void main() {
  const five = '<ul><li>0</li><li>1</li><li>2</li><li>3</li><li>4</li></ul>';
  final css = AnalyzeByCss(five);
  print('a: ${css.getStringList('tag.li[10:2]')}');
  print('b: ${css.getStringList('tag.li[1:10]')}');
  print('c: ${css.getStringList('tag.li[1:4]')}');
  print('d: ${css.getStringList('tag.li[0:4:10]')}');
  print('e: ${css.getStringList('tag.li[4:0:-1]')}');
  print('f: ${css.getStringList('tag.li[4:0:-2]')}');
  print('g: ${css.getStringList('tag.li[10:20]')}');
  print('h: ${css.getStringList('tag.li[-10:-6]')}');
  print('done');
}
