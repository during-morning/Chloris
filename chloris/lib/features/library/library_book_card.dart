part of 'library_screen.dart';

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    this.source,
    this.progress,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onSelect,
    required this.onLongPress,
  });

  final Book book;
  final BookSource? source;
  final String? progress;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: selectMode ? onSelect : onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MeowCover(
                title: book.name,
                imageUrl: book.coverUrl,
                height: 180,
                source: source,
                book: book,
              ),
              if (selectMode)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? c.accentPale : c.panel,
                      border: Border.all(
                        color: selected ? c.accent : c.lineStrong,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            book.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: c.ink,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            progress ?? book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
        ],
      ),
    );
  }
}
