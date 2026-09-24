"""Rebuild Chloris vector artwork. Requires fonttools and cairosvg for previews.

Run from anywhere: python brand/build_vectors.py
All deliverable SVGs contain editable vector paths, including outlined lettering.
"""
from pathlib import Path
from html import escape
import base64
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'brand'
CREAM = '#FBF3E9'
INK = '#525B43'

def svg(body, width, height, title, desc='', color=None):
    c = f' color="{color}"' if color else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc"{c}>\n'
            f'  <title id="title">{escape(title)}</title>\n'
            f'  <desc id="desc">{escape(desc)}</desc>\n{body}\n</svg>\n')

def png_wrapped(path, width, height, title, desc=''):
    data = base64.b64encode(Path(path).read_bytes()).decode('ascii')
    body = (f'<image x="0" y="0" width="{width}" height="{height}" '
            f'preserveAspectRatio="none" href="data:image/png;base64,{data}"/>')
    return svg(body, width, height, title, desc)

DEFS = '''<defs>
  <linearGradient id="coral" x1="0%" y1="0%" x2="100%" y2="100%" gradientUnits="objectBoundingBox">
    <stop stop-color="#F9B49E"/><stop offset="1" stop-color="#F7A88F"/>
  </linearGradient>
  <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%" gradientUnits="objectBoundingBox">
    <stop stop-color="#F7C46F"/><stop offset="1" stop-color="#F1B357"/>
  </linearGradient>
  <linearGradient id="paper" x1="0%" y1="0%" x2="0%" y2="100%" gradientUnits="objectBoundingBox">
    <stop stop-color="#FFF9EF"/><stop offset="1" stop-color="#F2E1CD"/>
  </linearGradient>
  <linearGradient id="cover" x1="0%" y1="0%" x2="100%" y2="100%" gradientUnits="objectBoundingBox">
    <stop stop-color="#B69B85"/><stop offset="1" stop-color="#A68A74"/>
  </linearGradient>
</defs>'''

BOTANICAL = '''<g id="botanical-book">
  <g id="stems" fill="none" stroke="#777B57" stroke-width="10" stroke-linecap="round">
    <path d="M467 620 C470 520 452 442 421 377"/>
    <path d="M475 621 C488 544 523 472 567 400"/>
    <path d="M495 620 C546 530 606 432 665 325"/>
    <path d="M531 626 C615 535 698 459 773 414"/>
  </g>
  <g id="left-sprig" fill="#E7C6A1">
    <path fill="none" stroke="#E7C6A1" stroke-width="7" stroke-linecap="round" d="M357 565 C318 500 273 443 232 393"/>
    <path d="M245 412 C210 398 197 378 208 364 C223 350 244 380 245 412Z"/>
    <path d="M273 444 C251 420 251 387 264 381 C279 374 289 408 273 444Z"/>
    <path d="M271 444 C239 446 202 438 210 422 C220 404 253 421 271 444Z"/>
    <path d="M309 490 C287 469 289 420 303 415 C324 408 328 460 309 490Z"/>
    <path d="M312 490 C275 489 224 489 229 469 C234 443 285 459 312 490Z"/>
    <path d="M339 526 C300 532 257 526 260 510 C263 488 313 497 339 526Z"/>
  </g>
  <g id="leaves">
    <path fill="#65674E" d="M454 578 C434 518 365 511 331 413 Q328 405 345 408 C425 410 445 471 454 578Z"/>
    <path fill="#969C70" d="M414 571 C354 552 307 541 273 479 Q267 471 280 471 C344 468 388 507 414 571Z"/>
    <path fill="#A9AD7E" d="M273 476 C337 487 383 530 414 571 C354 552 307 541 273 476Z"/>
    <path fill="#737B4B" d="M487 618 C491 555 519 506 555 494 C541 544 526 582 487 618Z"/>
    <path fill="#8A925E" d="M487 618 C503 560 528 523 555 494 C519 506 491 555 487 618Z"/>
    <path fill="#899164" d="M471 566 C465 527 468 482 487 468 C504 454 495 507 471 566Z"/>
    <path fill="#63654B" d="M639 370 C654 320 610 255 605 216 Q602 203 594 221 C565 270 583 320 610 353Z"/>
    <path fill="#73784E" d="M665 332 C674 269 697 231 724 222 C755 210 728 277 665 332Z"/>
    <path fill="#656B48" d="M674 328 C718 270 763 255 786 272 C804 285 742 310 724 308Z"/>
    <path fill="#69714B" d="M649 397 C682 345 722 329 750 341 C776 353 695 391 649 397Z"/>
    <path fill="#A1A77A" d="M631 478 C644 429 672 408 704 403 Q713 401 708 415 C702 456 679 474 631 478Z"/>
    <path fill="#858D5D" d="M631 478 L686 428 C668 461 651 473 631 478Z"/>
    <path fill="#E2A048" d="M689 501 C727 461 769 460 797 480 Q802 484 794 490 C757 518 724 509 689 501Z"/>
    <path fill="#F3BD67" d="M689 501 Q744 485 797 484 C765 514 731 511 689 501Z"/>
    <path fill="#788059" d="M738 445 C735 425 749 410 765 408 L775 426Z"/>
    <path fill="#676B51" d="M397 384 Q416 417 441 409 Q453 399 446 369Z"/>
  </g>
  <g id="coral-flower">
    <path fill="url(#coral)" d="M309 372 C271 370 248 351 252 315 C255 291 275 282 295 293 C267 274 270 242 292 222 C317 203 342 218 362 246 C354 209 375 184 406 181 C439 178 459 199 453 230 C472 191 501 200 517 228 C535 260 525 290 497 307 C500 335 469 365 443 376 Q431 381 421 376 C404 398 366 395 342 391 C321 389 311 383 309 372Z"/>
    <g fill="#FFF7E9">
      <circle cx="372" cy="289" r="8.5"/><circle cx="398" cy="282" r="8"/>
      <circle cx="415" cy="302" r="8"/><circle cx="389" cy="305" r="9"/>
      <circle cx="362" cy="314" r="8.5"/><circle cx="384" cy="325" r="8.5"/>
      <circle cx="403" cy="319" r="5.5"/>
    </g>
  </g>
  <g id="gold-flower">
    <path fill="url(#gold)" d="M515 369 C491 348 516 318 539 316 C557 313 569 324 573 342 C584 307 615 314 628 334 C638 349 633 358 627 367 C660 359 668 392 648 415 C638 428 626 426 613 423 C639 444 631 471 606 477 C584 482 568 469 566 455 C552 480 522 473 511 457 C505 447 505 439 508 431 C480 433 468 407 479 382 C487 364 501 362 515 369Z"/>
    <path fill="#FFF5E5" d="M551 383 C562 374 579 381 586 391 C596 407 583 422 569 416 C551 411 541 395 551 383Z"/>
  </g>
  <g id="small-flower">
    <path fill="url(#coral)" d="M762 382 C756 360 777 352 788 366 Q794 372 792 379 C813 357 837 379 829 394 Q825 403 814 407 C845 408 841 437 820 440 Q810 441 802 435 C806 458 780 454 765 443 C751 434 739 411 742 392 C744 374 753 372 762 382Z"/>
    <path fill="#FFF4E1" d="M763 408 C773 396 789 403 792 414 Q794 423 786 426 L761 423Z"/>
  </g>
  <g id="ivory-flower">
    <path fill="#FFF9EE" d="M578 548 C548 536 542 506 559 484 C575 463 599 471 616 496 C609 459 632 439 655 444 C678 447 689 465 687 493 C711 480 738 494 739 516 C740 540 716 552 693 554 C712 577 702 600 679 605 C657 610 638 591 632 574 C619 603 601 613 579 607 C550 613 531 601 532 581 C532 562 551 548 578 548Z"/>
    <path fill="#E5A34F" d="M631 526 C644 516 659 523 665 535 C673 551 656 567 641 565 C621 564 615 541 631 526Z"/>
  </g>
  <g id="book-pages">
    <path fill="url(#paper)" d="M233 553 L245 532 Q248 524 257 526 C352 535 450 566 490 604 Q506 619 512 635 Q532 599 575 579 C642 548 710 534 770 526 Q780 524 783 536 L790 554 L526 667 L490 667Z"/>
  </g>
  <g id="book-cover">
    <path fill="url(#cover)" d="M232 548 C306 571 424 604 478 631 Q496 645 512 645 Q530 645 546 632 C613 603 722 571 791 548 Q815 542 812 566 L769 762 Q765 784 747 791 L546 846 Q511 867 478 846 L280 791 Q260 785 255 763 L212 568 Q207 544 232 548Z"/>
    <path fill="#977B64" opacity=".4" d="M478 631 Q511 658 546 632 L546 846 Q511 867 478 846Z"/>
  </g>
</g>'''

def letters(text, font_path, size, x, y, color, tracking=0):
    font = TTFont(font_path)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = size / font['head'].unitsPerEm
    paths = []
    cursor = 0
    for char in text:
        name = cmap.get(ord(char))
        if name is None:
            raise ValueError(f'Missing glyph: {char}')
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(pen)
        data = pen.getCommands()
        if data:
            paths.append(f'<path transform="translate({cursor:.3f} 0)" d="{data}"/>')
        cursor += font['hmtx'][name][0] + tracking / scale
    return (f'<g aria-label="{escape(text)}" fill="{color}" '
            f'transform="translate({x} {y}) scale({scale:.8f} {-scale:.8f})">'
            + ''.join(paths) + '</g>')

serif = '/Library/Fonts/Lora-Regular.ttf'
sans = '/Library/Fonts/Arial Unicode.ttf'

icon_exact = png_wrapped(ROOT / 'icon.png', 1024, 1024, 'Chloris · 花与书',
                         '与原始 icon.png 像素级一致的 SVG 封装。')
(ROOT / 'icon.svg').write_text(icon_exact)

wordmark = letters('Chloris', serif, 150, 616, 304, INK, -3)
tagline = letters('让阅读，自然生长。', sans, 27, 625, 371, '#7F836D', 4)
banner = (DEFS + f'<rect width="1600" height="560" fill="{CREAM}"/>\n'
          '<g transform="translate(30 0) scale(.54)">' + BOTANICAL + '</g>\n'
          '<path d="M570 158 V402" stroke="#DEDCCB" stroke-width="1.5"/>\n'
          + wordmark + tagline
          + '<path d="M625 414 H684" stroke="#EAAA76" stroke-width="3" stroke-linecap="round"/>')
(ROOT / 'banner.svg').write_text(svg(banner, 1600, 560, 'Chloris · 品牌横幅', '花与书的彩色图标，Chloris 字标，以及“让阅读，自然生长。”；所有文字均已转为路径。'))

if __name__ == '__main__':
    import cairosvg
    for name in ('icon', 'banner'):
        width = 512 if name.startswith('icon') else 1600
        cairosvg.svg2png(url=str(ROOT / f'{name}.svg'), write_to=str(OUT / f'{name}.png'), output_width=width)
    # A single board to inspect all deliverables at their intended scale.
    def nested(name, x, y, width, height):
        import re
        content = (ROOT / f'{name}.svg').read_text()
        prefix = name.replace('-', '_') + '_'
        ids = re.findall(r'\bid="([^"]+)"', content)
        for i in ids:
            content = content.replace(f'id="{i}"', f'id="{prefix}{i}"').replace(f'url(#{i})', f'url(#{prefix}{i})')
        content = content.replace('aria-labelledby="title desc"', f'aria-labelledby="{prefix}title {prefix}desc"')
        content = re.sub(r'width="[^"]+" height="[^"]+"', f'x="{x}" y="{y}" width="{width}" height="{height}"', content, count=1)
        return content
    board = '<rect width="1600" height="1330" fill="#EEEDE6"/>'
    board += '<rect x="50" y="50" width="710" height="610" rx="24" fill="#FFFFFF"/>'
    board += '<rect x="790" y="50" width="760" height="610" rx="24" fill="#FFFFFF"/>'
    board += nested('icon', 190, 110, 440, 440)
    board += nested('banner', 50, 704, 1500, 525)
    board += letters('01  /  PRIMARY ICON', sans, 19, 84, 622, '#747B69', 1)
    board += letters('02  /  BRAND BANNER', sans, 19, 84, 1280, '#747B69', 1)
    preview = svg(board, 1600, 1330, 'Chloris 品牌资源总览')
    (OUT / 'preview.svg').write_text(preview)
    cairosvg.svg2png(bytestring=preview.encode(), write_to=str(OUT / 'preview.png'))
    print('Created two path-only SVGs and two PNG previews.')
