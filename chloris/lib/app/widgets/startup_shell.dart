import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StartupShell extends StatelessWidget {
  const StartupShell({super.key});

  @override
  Widget build(BuildContext context) {
    // A temporary Navigator would report '/' to the browser and discard the
    // incoming deep link before GoRouter is mounted.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery.fromView(
        view: View.of(context),
        child: Theme(
          data: AppTheme.light(
            AppThemeFamily.green,
            style: AppUiStyle.absolutely,
          ),
          child: const Material(
            color: Color(0xFFF0EEE6),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载 Chloris…'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
