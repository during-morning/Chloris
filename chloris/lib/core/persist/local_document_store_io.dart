import 'dart:typed_data';

import 'blob_file_io.dart';

Future<bool> write(String key, Uint8List bytes) =>
    BlobFileBackend.instance.write('local-documents/$key.bin', bytes);

Future<Uint8List?> read(String key) =>
    BlobFileBackend.instance.read('local-documents/$key.bin');

Future<void> delete(String key) =>
    BlobFileBackend.instance.delete('local-documents/$key.bin');
