# Bundled fonts

All families in this directory are licensed under the **SIL Open Font
License 1.1** (OFL), which permits bundling and redistribution inside an
application. They are committed here — rather than resolved from the host —
because Flutter Web (CanvasKit) keeps its own font collection: it cannot see
platform-installed fonts, and it downloads its CJK fallback from
`fonts.gstatic.com`. On a machine that cannot reach that host the whole UI
fell back to tofu boxes, and the Claude serif / terminal monospace styles had
nothing to resolve to.

| Family | Files | Used by | Upstream |
| --- | --- | --- | --- |
| `PTSerif` | `PTSerif-Regular.ttf`, `PTSerif-Bold.ttf` | Claude display/headings, reader default paper | [PT Serif](https://fonts.google.com/specimen/PT+Serif) (ParaType) |
| `SourceSansPro` | `SourceSansPro-Regular.ttf`, `SourceSansPro-SemiBold.ttf` | Claude UI chrome, labels, buttons | [Source Sans Pro](https://fonts.google.com/specimen/Source+Sans+Pro) (Adobe) |
| `IBMPlexMono` | `IBMPlexMono-Regular/Medium/SemiBold.ttf` | Terminal style, end to end | [IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono) (IBM) |
| `NotoSansSC` | `NotoSansSC-Regular.otf` | Pan-CJK fallback for UI text and the terminal | [Noto Sans CJK SC](https://github.com/notofonts/noto-cjk) (Adobe/Google) |
| `NotoSerifSC` | `NotoSerifSC-Regular.otf` | Pan-CJK fallback for serif headings and the reader | [Noto Serif CJK SC](https://github.com/notofonts/noto-cjk) (Adobe/Google) |

Both CJK faces are registered as the **last** entries of each font stack, so
they only supply glyphs the primary face lacks.

## CJK fallback coverage

`NotoSansSC-Regular.otf` is the full Simplified Chinese face from
`notofonts/noto-cjk` (16 MB). It includes uncommon Han characters and removes
the network dependency that previously left them as tofu. `NotoSerifSC` is
still subset to the **GB2312** set plus Latin-1, Latin Extended-A, general
punctuation, kana, CJK symbols, fullwidth forms and CJK punctuation (~8,000
codepoints, 2.2 MB); the reader fallback stack continues to Noto Sans SC for
characters missing from the serif subset.

Note: **Noto Sans JP is not a substitute.** It looks similar but omits
Simplified-only forms such as 书 / 寻 / 还 / 导, which are common in Chloris's
own UI. Always verify a CJK fallback against real Simplified text.

To reduce the bundled serif face while retaining wide glyph coverage, the
current Noto Serif subset can be rebuilt from the full CJK source with:

```bash
# from a checkout of notofonts/noto-cjk (or the Debian fonts-noto-cjk package)
pip install fonttools brotli
python - <<'PY'
gbk = set()
for hi in range(0x81, 0xFF):
    for lo in range(0x40, 0xFF):
        if lo == 0x7F: continue
        try:
            ch = bytes([hi, lo]).decode('gbk')
            if len(ch) == 1: gbk.add(ch)
        except Exception: pass
ranges, cps = [], sorted(ord(c) for c in gbk)
start = prev = cps[0]
for c in cps[1:]:
    if c == prev + 1: prev = c; continue
    ranges.append((start, prev)); start = prev = c
ranges.append((start, prev))
open('u.txt','w').write(','.join(f'U+{a:04X}' if a == b else f'U+{a:04X}-{b:04X}' for a, b in ranges))
PY
pyftsubset NotoSerifCJK-Regular.ttc --font-number=2 --unicodes-file=u.txt \
  --output-file=NotoSerifSC-Regular.otf --no-hinting --desubroutinize --layout-features=''
```

That yields a ~5.1 MB serif face (~21,800 codepoints).

## Removing a font

Drop its `fonts:` entry from `pubspec.yaml` and delete the files here. If the
CJK faces are removed, the Web build will show tofu for Chinese text unless
the host can reach `fonts.gstatic.com`.

## License

Full OFL 1.1 text: <https://openfontlicense.org/open-font-license-official-text/>.
Upstream copyright:

- PT Serif — Copyright © 2010 ParaType Ltd.
- Source Sans Pro — Copyright © 2010–2019 Adobe.
- IBM Plex Mono — Copyright © 2017 IBM Corp.
- Noto Sans CJK SC / Noto Serif CJK SC — Copyright © 2014–2021 Adobe
  (Source Han Sans / Source Han Serif), reserved font name "Noto".
