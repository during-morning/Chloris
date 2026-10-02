import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_theme.dart';

/// Cross-platform rounded icon vocabulary. Keep page code semantic and avoid
/// coupling it to a particular icon font.
///
/// Every icon in the Absolutely and terminal styles is **monochrome**. Emphasis
/// comes from two levels, never from hue:
///
/// * primary — the filled glyph painted in [ColorScheme.onSurface]
///   (black on Absolutely paper, white on the terminal canvas);
/// * secondary — the outline glyph painted in
///   [ColorScheme.onSurfaceVariant].
///
/// Use [AppIconPair.resolve] for anything with a selected state so the two
/// levels stay consistent across the app.
abstract final class AppIcons {
  static const library = CupertinoIcons.book;
  static const libraryFilled = CupertinoIcons.book_fill;
  static const search = CupertinoIcons.search;
  static const explore = CupertinoIcons.compass;
  static const exploreFilled = CupertinoIcons.compass_fill;
  static const person = CupertinoIcons.person;
  static const personFilled = CupertinoIcons.person_fill;
  static const settings = CupertinoIcons.gear;
  static const settingsFilled = CupertinoIcons.gear_alt_fill;
  static const back = CupertinoIcons.back;
  static const forward = CupertinoIcons.forward;
  static const close = CupertinoIcons.xmark;
  static const add = CupertinoIcons.plus;
  static const remove = CupertinoIcons.minus;
  static const menu = CupertinoIcons.line_horizontal_3;
  static const more = CupertinoIcons.ellipsis;
  static const refresh = CupertinoIcons.refresh;
  static const check = CupertinoIcons.check_mark;
  static const checkCircle = CupertinoIcons.check_mark_circled;
  static const checkCircleFilled = CupertinoIcons.check_mark_circled_solid;
  static const warning = CupertinoIcons.exclamationmark_triangle;
  static const warningFilled = CupertinoIcons.exclamationmark_triangle_fill;
  static const error = CupertinoIcons.exclamationmark_circle;
  static const errorFilled = CupertinoIcons.exclamationmark_circle_fill;
  static const info = CupertinoIcons.info_circle;
  static const infoFilled = CupertinoIcons.info_circle_fill;
  static const notification = CupertinoIcons.bell;
  static const notificationFilled = CupertinoIcons.bell_fill;
  static const palette = CupertinoIcons.paintbrush;
  static const paletteFilled = CupertinoIcons.paintbrush_fill;
  static const tune = CupertinoIcons.slider_horizontal_3;
  static const filter = CupertinoIcons.line_horizontal_3_decrease;
  static const copy = CupertinoIcons.doc_on_doc;
  static const paste = CupertinoIcons.doc_on_clipboard;
  static const edit = CupertinoIcons.pencil;
  static const delete = CupertinoIcons.delete;
  static const download = CupertinoIcons.cloud_download;
  static const downloadFilled = CupertinoIcons.cloud_download_fill;
  static const upload = CupertinoIcons.cloud_upload;
  static const uploadFilled = CupertinoIcons.cloud_upload_fill;
  static const folder = CupertinoIcons.folder;
  static const folderFilled = CupertinoIcons.folder_fill;
  static const file = CupertinoIcons.doc;
  static const fileFilled = CupertinoIcons.doc_fill;
  static const open = CupertinoIcons.arrow_up_right_square;
  static const openFilled = CupertinoIcons.arrow_up_right_square_fill;
  static const link = CupertinoIcons.link;
  static const bookmark = CupertinoIcons.bookmark;
  static const bookmarkFilled = CupertinoIcons.bookmark_fill;
  static const favorite = CupertinoIcons.heart;
  static const favoriteFilled = CupertinoIcons.heart_fill;
  static const star = CupertinoIcons.star;
  static const starFilled = CupertinoIcons.star_fill;
  static const eye = CupertinoIcons.eye;
  static const eyeFilled = CupertinoIcons.eye_fill;
  static const eyeOff = CupertinoIcons.eye_slash;
  static const eyeOffFilled = CupertinoIcons.eye_slash_fill;
  static const lock = CupertinoIcons.lock;
  static const lockFilled = CupertinoIcons.lock_fill;
  static const web = CupertinoIcons.globe;
  static const rss = CupertinoIcons.dot_radiowaves_left_right;
  static const translate = CupertinoIcons.globe;
  static const bold = CupertinoIcons.bold;
  static const contrast = CupertinoIcons.circle_lefthalf_fill;
  static const restart = CupertinoIcons.restart;
  static const history = CupertinoIcons.time;
  static const timer = CupertinoIcons.timer;
  static const bug = CupertinoIcons.ant;
  static const bugFilled = CupertinoIcons.ant_fill;
  static const flash = CupertinoIcons.bolt;
  static const flashFilled = CupertinoIcons.bolt_fill;
  static const archive = CupertinoIcons.archivebox;
  static const archiveFilled = CupertinoIcons.archivebox_fill;
  static const menuBook = CupertinoIcons.book;
  static const list = CupertinoIcons.list_bullet;
  static const grid = CupertinoIcons.square_grid_2x2;
  static const gridFilled = CupertinoIcons.square_grid_2x2_fill;
  static const viewList = CupertinoIcons.list_bullet;
  static const selectAll = CupertinoIcons.checkmark_square;
  static const selectAllFilled = CupertinoIcons.checkmark_square_fill;
  static const deselect = CupertinoIcons.square;
  static const arrowUp = CupertinoIcons.arrow_up;
  static const arrowDown = CupertinoIcons.arrow_down;
  static const arrowLeft = CupertinoIcons.arrow_left;
  static const arrowRight = CupertinoIcons.arrow_right;
  static const swap = CupertinoIcons.arrow_left_right;
  static const skipPrevious = CupertinoIcons.backward_end;
  static const skipPreviousFilled = CupertinoIcons.backward_end_fill;
  static const skipNext = CupertinoIcons.forward_end;
  static const skipNextFilled = CupertinoIcons.forward_end_fill;
  static const replay = CupertinoIcons.gobackward_10;
  static const forward10 = CupertinoIcons.goforward_10;
  static const play = CupertinoIcons.play;
  static const playFilled = CupertinoIcons.play_fill;
  static const pause = CupertinoIcons.pause;
  static const pauseFilled = CupertinoIcons.pause_fill;
  static const music = CupertinoIcons.music_note;
  static const headphones = CupertinoIcons.headphones;
  static const queue = CupertinoIcons.music_note_list;
  static const shuffle = CupertinoIcons.shuffle;
  static const equalizer = CupertinoIcons.waveform;
  static const volume = CupertinoIcons.volume_up;
  static const volumeOff = CupertinoIcons.volume_off;
  static const album = CupertinoIcons.music_albums;
  static const albumFilled = CupertinoIcons.music_albums_fill;
  static const zoomIn = CupertinoIcons.zoom_in;
  static const zoomOut = CupertinoIcons.zoom_out;
  static const pdf = CupertinoIcons.doc_text;
  static const pdfFilled = CupertinoIcons.doc_text_fill;

  // ---- Two-level pairs ---------------------------------------------------

  static const libraryPair = AppIconPair(library, libraryFilled);
  static const searchPair = AppIconPair(search, search);
  static const explorePair = AppIconPair(explore, exploreFilled);
  static const personPair = AppIconPair(person, personFilled);
  static const settingsPair = AppIconPair(settings, settingsFilled);
  static const bookmarkPair = AppIconPair(bookmark, bookmarkFilled);
  static const favoritePair = AppIconPair(favorite, favoriteFilled);
  static const starPair = AppIconPair(star, starFilled);
  static const notificationPair = AppIconPair(notification, notificationFilled);
  static const folderPair = AppIconPair(folder, folderFilled);
  static const gridPair = AppIconPair(grid, gridFilled);
  static const eyePair = AppIconPair(eye, eyeFilled);
  static const infoPair = AppIconPair(info, infoFilled);
  static const warningPair = AppIconPair(warning, warningFilled);
  static const errorPair = AppIconPair(error, errorFilled);
  static const checkPair = AppIconPair(checkCircle, checkCircleFilled);

  /// Destinations of the home shell, in tab order.
  static const navPairs = <AppIconPair>[
    libraryPair,
    searchPair,
    explorePair,
    personPair,
  ];

  static const all = <IconData>[
    library,
    search,
    explore,
    person,
    settings,
    back,
    close,
    add,
    refresh,
    check,
    warning,
    error,
    info,
    notification,
    palette,
    tune,
    filter,
    copy,
    edit,
    delete,
    download,
    upload,
    folder,
    bookmark,
    favorite,
    star,
    web,
  ];

  /// Thin-line (≈1.5px stroke) Lucide counterparts used by the Absolutely style.
  /// Keyed by the Cupertino outline glyph; anything unmapped keeps the
  /// Cupertino outline so the vocabulary degrades gracefully.
  static final Map<IconData, IconData> _absolutelyLine = {
    library: LucideIcons.book300,
    search: LucideIcons.search300,
    explore: LucideIcons.compass300,
    person: LucideIcons.user300,
    settings: LucideIcons.settings300,
    back: LucideIcons.chevronLeft300,
    forward: LucideIcons.chevronRight300,
    close: LucideIcons.x300,
    add: LucideIcons.plus300,
    remove: LucideIcons.minus300,
    menu: LucideIcons.menu300,
    more: LucideIcons.ellipsis300,
    refresh: LucideIcons.refreshCw300,
    restart: LucideIcons.rotateCcw300,
    check: LucideIcons.check300,
    checkCircle: LucideIcons.circleCheck300,
    warning: LucideIcons.triangleAlert300,
    error: LucideIcons.circleAlert300,
    info: LucideIcons.info300,
    notification: LucideIcons.bell300,
    palette: LucideIcons.paintbrush300,
    tune: LucideIcons.slidersHorizontal300,
    filter: LucideIcons.listFilter300,
    copy: LucideIcons.copy300,
    paste: LucideIcons.clipboardPaste300,
    edit: LucideIcons.pencil300,
    delete: LucideIcons.trash2300,
    download: LucideIcons.cloudDownload300,
    upload: LucideIcons.cloudUpload300,
    folder: LucideIcons.folder300,
    file: LucideIcons.file300,
    open: LucideIcons.squareArrowOutUpRight300,
    link: LucideIcons.link300,
    bookmark: LucideIcons.bookmark300,
    favorite: LucideIcons.heart300,
    star: LucideIcons.star300,
    eye: LucideIcons.eye300,
    eyeOff: LucideIcons.eyeOff300,
    lock: LucideIcons.lock300,
    web: LucideIcons.globe300,
    history: LucideIcons.history300,
    timer: LucideIcons.timer300,
    bug: LucideIcons.bug300,
    flash: LucideIcons.zap300,
    archive: LucideIcons.archive300,

    list: LucideIcons.list300,
    grid: LucideIcons.layoutGrid300,
    selectAll: LucideIcons.squareCheckBig300,
    deselect: LucideIcons.square300,
    arrowUp: LucideIcons.arrowUp300,
    arrowDown: LucideIcons.arrowDown300,
    arrowLeft: LucideIcons.arrowLeft300,
    arrowRight: LucideIcons.arrowRight300,
    swap: LucideIcons.arrowLeftRight300,
    music: LucideIcons.music300,
    headphones: LucideIcons.headphones300,
    queue: LucideIcons.listMusic300,
    album: LucideIcons.disc3300,
    equalizer: LucideIcons.audioLines300,
    shuffle: LucideIcons.shuffle300,
    volume: LucideIcons.volume2300,
    volumeOff: LucideIcons.volumeX300,
    skipPrevious: LucideIcons.skipBack300,
    skipNext: LucideIcons.skipForward300,
    replay: LucideIcons.rotateCcw300,
    forward10: LucideIcons.rotateCw300,
    play: LucideIcons.play300,
    pause: LucideIcons.pause300,
    zoomIn: LucideIcons.zoomIn300,
    zoomOut: LucideIcons.zoomOut300,
    pdf: LucideIcons.fileText300,
  };
}

/// A monochrome icon at two weights.
///
/// [filled] is used when the control is selected/active; [outline] otherwise.
/// Colour is applied separately so the pair stays reusable at either ink
/// level.
///
/// Style aware: Absolutely's official icon language is **outline only** —
/// activation is expressed through ink depth (onSurface vs
/// onSurfaceVariant), never a fill switch. Pass the resolved
/// [AppStyleExtension] to [styled] and Absolutely gets a quiet glyph; classic
/// and terminal keep their filled/outline pair.
@immutable
class AppIconPair {
  const AppIconPair(this.outline, this.filled);

  final IconData outline;
  final IconData filled;

  IconData resolve({required bool active}) => active ? filled : outline;

  /// Style-aware resolution. [style] may be null (treated as classic).
  IconData styled(AppStyleExtension? style, {required bool active}) {
    if (style != null && !style.filledIcons) {
      return AppIcons._absolutelyLine[outline] ?? outline;
    }
    return resolve(active: active);
  }

  AppIcon at({required bool active, double? size, Color? color}) => AppIcon(
    resolve(active: active),
    size: size,
    color: color,
  );

  /// Style-aware [at]. Colour stays the caller's choice; the icon simply
  /// refuses to fill under styles with [AppStyleExtension.filledIcons] off.
  AppIcon styledAt(
    AppStyleExtension? style, {
    required bool active,
    double? size,
    Color? color,
  }) => AppIcon(
    styled(style, active: active),
    size: size,
    color: color,
  );
}

class AppIcon extends Icon {
  const AppIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
    super.textDirection,
  });
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<AppStyleExtension>();
    final line = style?.style == AppUiStyle.absolutely
        ? AppIcons._absolutelyLine[icon]
        : null;
    if (line == null) return super.build(context);
    return Icon(
      line,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
    );
  }
}
