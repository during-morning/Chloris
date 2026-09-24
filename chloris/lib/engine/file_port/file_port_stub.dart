import 'package:chloris_engine/chloris_engine.dart';

/// Web has no file system for rule scripts, so the capability is reported as
/// absent and every file operation raises a clear error.
FilePort createFilePort() => const UnsupportedFilePort();
