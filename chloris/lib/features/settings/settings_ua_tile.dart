part of 'settings_screen.dart';

class _UserAgentTile extends ConsumerStatefulWidget {
  const _UserAgentTile();

  @override
  ConsumerState<_UserAgentTile> createState() => _UserAgentTileState();
}

class _UserAgentTileState extends ConsumerState<_UserAgentTile> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: ref.read(userAgentProvider));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save(String v) {
    ref.read(userAgentProvider.notifier).state = v;
    EngineLimits.apply(userAgent: v);
    ref.read(settingsWriteUseCaseProvider).setString('userAgent', v);
  }

  @override
  Widget build(BuildContext context) {
    final ua = ref.watch(userAgentProvider);
    if (_c.text != ua && !imeComposing(_c.value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_c.text != ua && !imeComposing(_c.value)) _c.text = ua;
      });
    }
    return ListTile(
      leading: const Icon(Icons.web_asset),
      title: const Text('User-Agent'),
      subtitle: TextField(
        controller: _c,
        enableInteractiveSelection: true,
        enableSuggestions: false,
        autocorrect: false,
        scrollPhysics: const NeverScrollableScrollPhysics(),
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: '空则用默认移动 Chrome UA，回车保存',
          isDense: true,
        ),
        onSubmitted: _save,
      ),
    );
  }
}
