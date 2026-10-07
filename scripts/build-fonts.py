"""앱에 넣을 한글 글꼴(Noto Sans KR)을 만든다.

웹에서는 한글 글꼴이 늦게 내려오면 글자 폭이 잘못 계산돼 칩·배지 글자가 잘리므로,
글꼴을 앱에 직접 포함한다. 가변 글꼴에서 굵기 4개를 뽑고, 자주 쓰는 글자(KS X 1001 한글 2350자
+ 영문·숫자·기호)만 남겨 용량을 줄인다. (OFL 라이선스: https://openfontlicense.org)

사용법:
  1) 원본 받기: https://github.com/google/fonts/raw/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf
  2) pip install fonttools
  3) python scripts/build-fonts.py <원본.ttf> app/assets/fonts
"""
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

WEIGHTS = {"Regular": 400, "Medium": 500, "Bold": 700, "Black": 900}


def ksx1001_hangul() -> str:
    chars = []
    for lead in range(0xB0, 0xC9):  # KS X 1001 한글 영역
        for trail in range(0xA1, 0xFF):
            try:
                chars.append(bytes([lead, trail]).decode("euc-kr"))
            except UnicodeDecodeError:
                pass
    return "".join(chars)


def keep_text() -> str:
    ascii_printable = "".join(chr(c) for c in range(0x20, 0x7F))
    extra = "·•…—–‘’“”←→↑↓★☆○●×÷±≈≠≤≥℃₩①②③④⑤⑥⑦⑧⑨⑩"
    jamo = "".join(chr(c) for c in range(0x3131, 0x3164))  # ㄱ~ㅣ (ㅎㅎ, ㅋㅋ 같은 자모)
    return ascii_printable + extra + jamo + ksx1001_hangul()


def main(src: str, out_dir: str) -> None:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    text = keep_text()
    for name, wght in WEIGHTS.items():
        font = TTFont(src)
        inst = instancer.instantiateVariableFont(font, {"wght": wght})
        opts = subset.Options()
        opts.layout_features = ["kern", "liga", "ccmp", "locl", "mark", "mkmk"]
        opts.name_IDs = [1, 2, 3, 4, 6]
        opts.notdef_outline = True
        sub = subset.Subsetter(opts)
        sub.populate(text=text)
        sub.subset(inst)
        dest = out / f"NotoSansKR-{name}.ttf"
        inst.save(dest)
        print(f"{dest} {dest.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
