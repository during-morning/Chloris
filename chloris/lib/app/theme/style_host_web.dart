import 'dart:js_interop';

@JS('setChlorisUiStyle')
external void _setChlorisUiStyle(JSString id);

void applyHostUiStyle(String id) => _setChlorisUiStyle(id.toJS);
