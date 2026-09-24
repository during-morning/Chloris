import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_use_cases.dart';

final settingsWritePortProvider = Provider<SettingsWritePort>(
  (ref) => const KvSettingsWriteAdapter(),
);

final settingsWriteUseCaseProvider = Provider<SettingsWriteUseCase>(
  (ref) => SettingsWriteUseCase(ref.watch(settingsWritePortProvider)),
);

final backupPortProvider = Provider<BackupPort>(
  (ref) => const BackupServiceAdapter(),
);

final createBackupUseCaseProvider = Provider<CreateBackupUseCase>(
  (ref) => CreateBackupUseCase(ref.watch(backupPortProvider)),
);

final restoreBackupUseCaseProvider = Provider<RestoreBackupUseCase>(
  (ref) => RestoreBackupUseCase(ref.watch(backupPortProvider)),
);

final webDavUseCasesProvider = Provider<WebDavUseCases>(
  (ref) => const WebDavUseCases(),
);
