#!/usr/bin/env python3
"""Pack default_book_sources.json from all.json + curate_sources.log."""
import json
import re
from collections import defaultdict, Counter
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path('/Volumes/Software/ChlorisA/chloris')
ALL = ROOT / 'tool/archive/default_book_sources.all.json'
LOG = ROOT / 'tool/logs/curate_sources.log'
OUT = ROOT / 'assets/sources/default_book_sources.json'
VER = ROOT / 'assets/sources/verified_book_sources.json'
REPORT = ROOT / 'tool/logs/curate_report.md'

CAPS = {
    '小说': 500, '轻小说': 60, '漫画': 100, '听书': 40,
    '出版': 20, '正版': 40, '影视': 20, '其他': 40,
}
ORDER = list(CAPS)
PER_HOST = 6
MAX_ENABLED = 800


def canon(u: str) -> str:
    u = (u or '').strip()
    try:
        uri = urlparse(u)
    except Exception:
        return u.rstrip('/').lower()
    host = (uri.hostname or '').lower()
    if host.startswith('www.'):
        host = host[4:]
    path = uri.path or ''
    if path == '/':
        path = ''
    elif len(path) > 1 and path.endswith('/'):
        path = path[:-1]
    scheme = (uri.scheme or 'http').lower()
    return f'{scheme}://{host}{path}'


def host_of(u: str) -> str:
    try:
        h = (urlparse(u).hostname or u).lower()
    except Exception:
        h = u.lower()
    return h[4:] if h.startswith('www.') else h


def complete(s: dict) -> bool:
    search = (s.get('searchUrl') or '').strip()
    toc = ((s.get('ruleToc') or {}) or {}).get('chapterList') or ''
    content = ((s.get('ruleContent') or {}) or {}).get('content') or ''
    return bool(search and toc.strip() and content.strip())


def http_search(s: dict) -> bool:
    u = (s.get('searchUrl') or '').strip().lower()
    return u.startswith('http://') or u.startswith('https://')


def parse_log():
    s1, s2, s3 = {}, {}, {}
    s1_re = re.compile(r'^S1 OK (\d+)ms n=(\d+) q=\S+ \[([^\]]+)\] (.+)\s*$')
    s2_re = re.compile(r'^S2 OK (\d+)ms rel=(\d+) q=\S+ (.+)\s*$')
    s3_re = re.compile(r'^S3 OK ch=(\d+) body=(\d+) .*? ([^\s]+)\s*$')
    # S3 OK ch=$nCh body=$nContent $infoName ${source.bookSourceName}
    s3_re = re.compile(r'^S3 OK ch=\d+ body=\d+ .+ (.+)\s*$')
    for line in LOG.read_text(errors='replace').splitlines():
        m = s1_re.match(line)
        if m:
            name = m.group(4).strip()
            s1[name] = {'ms': int(m.group(1)), 'n': int(m.group(2)), 'g': m.group(3)}
            continue
        m = s2_re.match(line)
        if m:
            s2[m.group(3).strip()] = {'ms': int(m.group(1)), 'rel': int(m.group(2))}
            continue
        m = s3_re.match(line)
        if m:
            s3[m.group(1).strip()] = True
    return s1, s2, s3


def main():
    allj = json.loads(ALL.read_text())
    s1, s2, s3 = parse_log()
    print('log S1', len(s1), 'S2', len(s2), 'S3', len(s3), 'all', len(allj))

    scored = []
    for s in allj:
        name = (s.get('bookSourceName') or '').strip()
        g = s.get('bookSourceGroup') or '其他'
        weight = 0
        ms = s.get('respondTime') or 180000
        if name in s3:
            weight += 80
        if name in s2:
            weight += 40
            ms = min(ms, s2[name]['ms'] or ms)
        if name in s1:
            weight += 30
            ms = min(ms, s1[name]['ms'] or ms)
            n = s1[name]['n']
            weight += 20 if n > 20 else n
        if complete(s):
            weight += 15
        if http_search(s):
            weight += 10
        if not (s.get('searchUrl') or '').strip():
            continue
        s = dict(s)
        s['bookSourceUrl'] = canon(s.get('bookSourceUrl') or '')
        if not s['bookSourceUrl']:
            continue
        s['weight'] = weight
        s['respondTime'] = ms if ms > 0 else 180000
        s['bookSourceGroup'] = g if g in CAPS else '其他'
        s['enabled'] = False
        scored.append(s)

    # unique url
    best = {}
    for s in scored:
        k = s['bookSourceUrl']
        prev = best.get(k)
        if prev is None or s['weight'] > prev['weight'] or (
            s['weight'] == prev['weight'] and s['respondTime'] < prev['respondTime']
        ):
            best[k] = s

    by_host = defaultdict(list)
    for s in best.values():
        by_host[host_of(s['bookSourceUrl'])].append(s)
    host_pick = []
    for lst in by_host.values():
        lst.sort(key=lambda x: (-x['weight'], x['respondTime']))
        host_pick.extend(lst[:PER_HOST])

    buckets = defaultdict(list)
    for s in host_pick:
        buckets[s['bookSourceGroup']].append(s)
    picked = []
    for g in ORDER:
        lst = buckets.get(g, [])
        lst.sort(key=lambda x: (-x['weight'], x['respondTime']))
        picked.extend(lst[:CAPS[g]])
    picked.sort(key=lambda x: (ORDER.index(x['bookSourceGroup']), -x['weight'], x['respondTime']))
    if len(picked) > MAX_ENABLED:
        extra = len(picked) - MAX_ENABLED
        novels = [s for s in picked if s['bookSourceGroup'] == '小说']
        others = [s for s in picked if s['bookSourceGroup'] != '小说']
        keep_n = max(200, len(novels) - extra)
        picked = novels[:keep_n] + others
        picked.sort(key=lambda x: (ORDER.index(x['bookSourceGroup']), -x['weight'], x['respondTime']))
    for i, s in enumerate(picked):
        s['customOrder'] = i
        s['enabled'] = True

    OUT.write_text(json.dumps(picked, ensure_ascii=False, indent=2), encoding='utf-8')
    VER.write_text(json.dumps(picked, ensure_ascii=False, indent=2), encoding='utf-8')
    for s in allj:
        s['enabled'] = False
        k = canon(s.get('bookSourceUrl') or '')
        if k:
            s['bookSourceUrl'] = k
    ALL.write_text(json.dumps(allj, ensure_ascii=False, indent=2), encoding='utf-8')
    counts = Counter(x['bookSourceGroup'] for x in picked)
    print('picked', len(picked), dict(counts))
    REPORT.write_text(
        REPORT.read_text(errors='replace')
        + f'\n# pack_alive\nenabled={len(picked)}\ngroups {dict(counts)}\n',
        encoding='utf-8',
    )


if __name__ == '__main__':
    main()
