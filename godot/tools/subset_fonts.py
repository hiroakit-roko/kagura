#!/usr/bin/env python3
"""見出し用の明朝フォントを、スクリプト内で実際に使う文字だけにサブセット化する。

Web 版のダウンロードサイズを抑えるため。本文用ゴシック（Zen Kaku Gothic New）は
動的な文字列も表示するので全グリフを同梱し、明朝はスクリプト中の固定文字列に限る。

使い方:
    python3 tools/subset_fonts.py path/to/ShipporiMinchoB1-Bold.ttf
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "fonts", "ShipporiMinchoB1-Bold.subset.ttf")


def collect_chars() -> set:
    chars = set()
    for path in glob.glob(os.path.join(ROOT, "scripts", "*.gd")):
        with open(path, encoding="utf-8") as f:
            chars.update(f.read())
    # 数字・英字・記号は常に入れておく
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update("。、・「」『』（）！？〜ー々〆〇◆◇○●□■△▽☆★※→←↑↓∞≪≫〈〉【】"
                 "０１２３４５６７８９ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ")
    # ひらがな・カタカナは全部
    chars.update(chr(c) for c in range(0x3041, 0x3097))
    chars.update(chr(c) for c in range(0x30A1, 0x30FB))
    return {c for c in chars if not c.isspace() or c == " "}


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    chars = collect_chars()
    text = "".join(sorted(chars))
    tmp = os.path.join(ROOT, "tools", ".subset_chars.txt")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    subprocess.check_call([
        "pyftsubset", src,
        f"--text-file={tmp}",
        f"--output-file={OUT}",
        "--layout-features=*",
        "--no-hinting",
        "--desubroutinize",
    ])
    os.remove(tmp)
    print(f"{len(chars)} chars -> {OUT} ({os.path.getsize(OUT) // 1024} KB)")


if __name__ == "__main__":
    main()
