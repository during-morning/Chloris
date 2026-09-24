import 'dart:html' as html;

String? htmlCookieGet() => html.document.cookie;

void htmlCookieSet(String v) {
  html.document.cookie = v;
}
