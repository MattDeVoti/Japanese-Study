#!/usr/bin/env python3
"""Content lint for the lesson/dictionary JSON.

Catches the furigana defect classes that a bulk content edit tends to reintroduce.
Run from the repo root:

    python3 Scripts/lint_content.py            # report, exit 1 on findings
    python3 Scripts/lint_content.py --quiet    # summary only

Checks
  1. structure     `kanji[...]` whose content is not pure kana would render with
                   literal visible brackets (FuriganaAnnotator.isAllKana rejects it).
  2. romaji        Sentences carrying both `japanese` and `romaji` are cross-checked:
                   the kana implied by the annotations must be able to spell the
                   romaji. This is the only check that sees *contextual* errors.
  3. truncation    A reading that is a strict prefix of the same string's dominant
                   reading (有名[ゆうめ] vs 有名[ゆうめい]) is a dropped-mora typo.
  4. counters      A numeral followed by a counter annotated with its standalone kun
                   reading (二[に]時[とき] -> "にとき") — the split-compound bug.
  5. choices       A question whose options contain a duplicate. When the repeated
                   option is the correct one, picking the "other" identical answer
                   is marked wrong.

Deliberate quiz distractors are wrong on purpose, so checks 3 and 4 skip any
string that sits in a `choices` array at an index other than `correctIndex`.
"""
from __future__ import annotations

import collections
import glob
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "Sources", "Omedetou", "Resources")

ANN = re.compile(r'([一-鿿々〇]+)\[([぀-ゟ゠-ヿー]+)\]')
KANJI = re.compile(r'[一-鿿々〇]')
LOOSE_BRACKET = re.compile(r'([一-鿿々〇])\[([^\]]*)\]')
UNVERIFIABLE = re.compile(r'[A-Za-z0-9０-９]')

# ---------------------------------------------------------------- kana -> romaji

VOWEL_OF = {'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o'}
BASE = {
    'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
    'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
    'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
    'さ': 'sa', 'し': 'shi|si', 'す': 'su', 'せ': 'se', 'そ': 'so',
    'ざ': 'za', 'じ': 'ji|zi', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
    'た': 'ta', 'ち': 'chi|ti', 'つ': 'tsu|tu', 'て': 'te', 'と': 'to',
    'だ': 'da', 'ぢ': 'ji|di', 'づ': 'zu|du', 'で': 'de', 'ど': 'do',
    'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
    'は': 'ha|wa', 'ひ': 'hi', 'ふ': 'fu|hu', 'へ': 'he|e', 'ほ': 'ho',
    'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
    'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
    'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
    'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
    'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
    'わ': 'wa', 'ゐ': 'i', 'ゑ': 'e', 'を': 'o|wo', 'ん': 'n|m',
    'ゔ': 'vu', 'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o',
}
YOON = {
    'き': 'ky', 'ぎ': 'gy', 'し': 'sh|sy', 'じ': 'j|jy|zy', 'ち': 'ch|ty',
    'ぢ': 'j', 'に': 'ny', 'ひ': 'hy', 'び': 'by', 'ぴ': 'py', 'み': 'my',
    'り': 'ry', 'ふ': 'f',
}
SMALL = {'ゃ': 'a', 'ゅ': 'u', 'ょ': 'o', 'ぇ': 'e', 'ぃ': 'i', 'ぁ': 'a', 'ぉ': 'o', 'ぅ': 'u'}
FOREIGN = {
    'てぃ': 'ti|tei', 'でぃ': 'di|dei', 'とぅ': 'tu', 'どぅ': 'du',
    'ふぁ': 'fa', 'ふぃ': 'fi', 'ふぇ': 'fe', 'ふぉ': 'fo', 'ふゅ': 'fyu',
    'じぇ': 'je', 'ちぇ': 'che', 'しぇ': 'she', 'つぁ': 'tsa', 'つぉ': 'tso',
    'うぃ': 'wi', 'うぇ': 'we', 'うぉ': 'wo', 'ゔぁ': 'va', 'ゔぃ': 'vi',
    'ゔぇ': 've', 'ゔぉ': 'vo', 'くぁ': 'kwa', 'ぐぁ': 'gwa', 'ぴぇ': 'pye',
}
LONG_MARKS = 'ー〜～'


def kata2hira(s: str) -> str:
    return ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in s)


def kana_to_pattern(kana: str) -> str:
    """A regex matching any reasonable Hepburn/Kunrei romanisation of `kana`."""
    kana = kata2hira(kana)
    out: list[str] = []
    i, n = 0, len(kana)
    while i < n:
        c = kana[i]
        nxt = kana[i + 1] if i + 1 < n else ''
        if c == 'っ':
            out.append('[a-z]?')                      # the doubled consonant
            i += 1
            continue
        if c in LONG_MARKS:
            out.append('[aiueo]?')
            i += 1
            continue
        if c + nxt in FOREIGN:
            out.append('(?:%s)' % FOREIGN[c + nxt])
            i += 2
            continue
        if nxt in SMALL and c in YOON:
            v = SMALL[nxt]
            out.append('(?:%s)' % '|'.join(p + v for p in YOON[c].split('|')))
            i += 2
            if i < n and kana[i] in ('う', v):         # きょう = kyo / kyou
                out.append('[aiueo]?')
                i += 1
            continue
        if c in BASE:
            alts = BASE[c].split('|')
            out.append('(?:%s)' % '|'.join(alts))
            i += 1
            if i < n:
                nv = kana[i]
                last = alts[0][-1] if alts[0] and alts[0][-1] in 'aiueo' else ''
                if (nv == 'う' and last in 'ou') or VOWEL_OF.get(nv) == last:
                    out.append('[aiueo]?')
                    i += 1
                elif nv == 'い' and last == 'e':
                    out.append('i?')
                    i += 1
            continue
        i += 1                                        # punctuation etc.
    return ''.join(out)


def norm_romaji(r: str) -> str:
    r = unicodedata.normalize('NFD', r.lower())
    r = ''.join(ch for ch in r if unicodedata.category(ch) != 'Mn')   # drop macrons
    return re.sub(r'[^a-z]', '', r)


def only_kana(s: str) -> str:
    return ''.join(ch for ch in s
                   if ('぀' <= ch <= 'ゟ') or ('゠' <= ch <= 'ヿ') or ch in LONG_MARKS)


def tokens(jp: str):
    """Ordered [('ann', kanji, reading) | ('plain', text, None)]."""
    out, pos = [], 0
    for m in ANN.finditer(jp):
        if m.start() > pos:
            out.append(('plain', jp[pos:m.start()], None))
        out.append(('ann', m.group(1), m.group(2)))
        pos = m.end()
    if pos < len(jp):
        out.append(('plain', jp[pos:], None))
    return out


def pattern_for(toks, wildcard=None) -> str:
    parts = []
    for i, (kind, a, b) in enumerate(toks):
        if kind == 'ann':
            parts.append('[a-z]{0,10}' if i == wildcard else kana_to_pattern(b))
        else:
            parts.append(kana_to_pattern(only_kana(a)))
    return ''.join(parts)


# ------------------------------------------------------------------- traversal

def walk_strings(node, path="", in_wrong_choice=False):
    """Yield (path, string, is_distractor). A string inside `choices` at an index
    other than `correctIndex` is a deliberate wrong answer."""
    if isinstance(node, dict):
        correct = node.get("correctIndex")
        for k, v in node.items():
            if k == "choices" and isinstance(v, list):
                for i, c in enumerate(v):
                    yield from walk_strings(c, f"{path}.choices[{i}]",
                                            in_wrong_choice or i != correct)
            else:
                yield from walk_strings(v, f"{path}.{k}", in_wrong_choice)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_strings(v, f"{path}[{i}]", in_wrong_choice)
    elif isinstance(node, str):
        yield path, node, in_wrong_choice


def load_all():
    files = sorted(glob.glob(os.path.join(RESOURCES, "**", "*.json"), recursive=True))
    for f in files:
        try:
            yield f, json.load(open(f, encoding="utf-8"))
        except Exception as e:                                    # noqa: BLE001
            print(f"  PARSE FAIL {os.path.relpath(f, ROOT)}: {e}")


# ---------------------------------------------------------------------- checks

# Readings that look like truncations but are correct: rare-but-real alternatives.
TRUNCATION_ALLOW = {("三", "み"), ("何", "な"), ("高", "た"), ("明", "あ"),
                    ("欲", "ほ"), ("寂", "さ"), ("苦", "く")}
# Counter kanji whose standalone kun reading is wrong directly after a numeral.
NUMERALS = set("一二三四五六七八九十百千万零")
BAD_AFTER_NUMERAL = {
    "時": {"とき", "どき"}, "日": {"ひ", "び"}, "月": {"つき", "づき"},
    "年": {"とし", "どし"}, "人": {"ひと", "びと"}, "分": {"わ", "ぶん"},
    "回": {"まわ"}, "本": {"もと"}, "度": {"たび"},
}
PAIR = re.compile(r'([一-鿿々〇]+)\[([぀-ゟ゠-ヿー]+)\]([一-鿿々〇]+)\[([぀-ゟ゠-ヿー]+)\]')


def main() -> int:
    quiet = "--quiet" in sys.argv
    findings: list[str] = []
    counts = collections.Counter()
    docs = list(load_all())

    # ---- 1. structure: brackets that would render literally
    for f, doc in docs:
        rel = os.path.relpath(f, ROOT)
        for path, s, _ in walk_strings(doc):
            for m in LOOSE_BRACKET.finditer(s):
                body = m.group(2)
                if body and all(('぀' <= c <= 'ゟ') or ('゠' <= c <= 'ヿ') or c in LONG_MARKS
                                for c in body):
                    continue
                # blank readings are used as deliberate fill-in-the-blank prompts
                if body.strip() == "":
                    counts["structure-blank"] += 1
                    continue
                counts["structure"] += 1
                findings.append(f"[structure] {rel}{path}: {m.group(0)} "
                                f"renders with literal brackets (reading is not pure kana)")

    # ---- 2. romaji cross-check
    for f, doc in docs:
        rel = os.path.relpath(f, ROOT)

        def visit(node, path=""):
            if isinstance(node, dict):
                jp, ro = node.get("japanese"), node.get("romaji")
                if isinstance(jp, str) and isinstance(ro, str) and ANN.search(jp):
                    if not UNVERIFIABLE.search(jp):
                        toks = tokens(jp)
                        stripped = ANN.sub(lambda m: m.group(2), jp)
                        if not KANJI.search(stripped):
                            target = norm_romaji(ro)
                            try:
                                ok = re.fullmatch(pattern_for(toks), target)
                            except re.error:
                                ok = True
                            if not ok:
                                culprits = []
                                for i, (kind, a, b) in enumerate(toks):
                                    if kind != 'ann':
                                        continue
                                    try:
                                        if re.fullmatch(pattern_for(toks, i), target):
                                            culprits.append(f"{a}[{b}]")
                                    except re.error:
                                        pass
                                counts["romaji"] += 1
                                who = f" suspect: {', '.join(culprits)}" if culprits else ""
                                findings.append(
                                    f"[romaji] {rel}{path}: {jp}\n"
                                    f"          romaji says: {ro}{who}")
                for k, v in node.items():
                    visit(v, f"{path}.{k}")
            elif isinstance(node, list):
                for i, v in enumerate(node):
                    visit(v, f"{path}[{i}]")

        visit(doc)

    # ---- 5. duplicate answer options
    for f, doc in docs:
        rel = os.path.relpath(f, ROOT)

        def visit_choices(node, path=""):
            if isinstance(node, dict):
                ch = node.get("choices")
                if isinstance(ch, list) and len(ch) != len(set(ch)):
                    dupes = {c for c in ch if ch.count(c) > 1}
                    correct = node.get("correctIndex")
                    hits_answer = (isinstance(correct, int) and 0 <= correct < len(ch)
                                   and ch[correct] in dupes)
                    counts["choices"] += 1
                    findings.append(
                        f"[choices] {rel}{path}: {node.get('id')} has duplicate options"
                        + (" — including the correct answer" if hits_answer else "")
                        + f": {sorted(dupes)}")
                for k, v in node.items():
                    visit_choices(v, f"{path}.{k}")
            elif isinstance(node, list):
                for i, v in enumerate(node):
                    visit_choices(v, f"{path}[{i}]")

        visit_choices(doc)

    # ---- 3 & 4 need corpus-wide reading frequencies, distractors excluded
    readings: dict[str, collections.Counter] = collections.defaultdict(collections.Counter)
    content_strings: list[tuple[str, str, str]] = []     # (rel, path, string)
    for f, doc in docs:
        rel = os.path.relpath(f, ROOT)
        for path, s, distractor in walk_strings(doc):
            if distractor:
                continue
            content_strings.append((rel, path, s))
            for m in ANN.finditer(s):
                readings[m.group(1)][m.group(2)] += 1

    for kanji, cnt in readings.items():
        if len(cnt) < 2:
            continue
        top, topn = cnt.most_common(1)[0]
        for rd, n in cnt.items():
            if rd == top or (kanji, rd) in TRUNCATION_ALLOW:
                continue
            if top.startswith(rd) and len(rd) < len(top) and topn > n:
                counts["truncation"] += 1
                findings.append(f"[truncation] {kanji}[{rd}] x{n} looks like a dropped "
                                f"mora — dominant reading is {kanji}[{top}] x{topn}")

    for rel, path, s in content_strings:
        for m in PAIR.finditer(s):
            k1, _r1, k2, r2 = m.groups()
            if k1[-1] in NUMERALS and k2[0] in BAD_AFTER_NUMERAL \
                    and r2 in BAD_AFTER_NUMERAL[k2[0]]:
                counts["counter"] += 1
                findings.append(f"[counter] {rel}{path}: {m.group(0)} — counter keeps its "
                                f"standalone reading after a numeral")

    if findings and not quiet:
        print("\n".join(findings))
        print()
    total = sum(v for k, v in counts.items() if k != "structure-blank")
    print(f"content lint: {len(docs)} files, "
          f"{sum(sum(c.values()) for c in readings.values())} non-distractor annotations")
    for name in ("structure", "romaji", "truncation", "counter", "choices"):
        print(f"  {name:<11} {counts[name]}")
    if counts["structure-blank"]:
        print(f"  (skipped {counts['structure-blank']} blank readings — "
              f"intentional fill-in-the-blank prompts)")
    print("OK" if total == 0 else f"FAILED — {total} finding(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
