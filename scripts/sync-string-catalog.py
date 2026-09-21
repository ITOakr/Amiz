#!/usr/bin/env python3
"""ビルドで抽出された画面の文字列（*.stringsdata）を Amiz/Localizable.xcstrings に集める。

Xcode の IDE でビルドすると自動で同期されるが、xcodebuild（コマンドライン）では同期されないので、
このスクリプトで同じことをする。使い方：
  xcodebuild build ... （先にビルドする）
  python3 scripts/sync-string-catalog.py
既にある項目（翻訳やコメント）は残し、抽出された文字列を追加する。ソース言語（日本語）の値はキーそのものなので、
項目の中身は空（Xcode と同じ形）。
"""
import glob
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "Amiz", "Localizable.xcstrings")


def objroot():
    out = subprocess.run(
        ["xcodebuild", "-project", "Amiz.xcodeproj", "-scheme", "Amiz",
         "-destination", "platform=iOS Simulator,name=iPhone 17", "-showBuildSettings"],
        cwd=ROOT, capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.strip().startswith("OBJROOT ="):
            return line.split("=", 1)[1].strip()
    sys.exit("OBJROOT が見つかりません。先にビルドしてください")


def main():
    files = glob.glob(os.path.join(objroot(), "Amiz.build", "**", "*.stringsdata"), recursive=True)
    if not files:
        sys.exit("*.stringsdata がありません。先に xcodebuild build を実行してください")
    keys = set()
    for path in files:
        with open(path) as f:
            data = json.load(f)
        for table, entries in data.get("tables", {}).items():
            if table != "Localizable":
                continue
            for entry in entries:
                keys.add(entry["key"])

    with open(CATALOG) as f:
        catalog = json.load(f)
    strings = catalog.setdefault("strings", {})
    added = 0
    for key in sorted(keys):
        if key not in strings:
            strings[key] = {}
            added += 1
    catalog["strings"] = dict(sorted(strings.items()))
    with open(CATALOG, "w") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"抽出 {len(keys)} 件、追加 {added} 件 → {os.path.relpath(CATALOG, ROOT)}")


if __name__ == "__main__":
    main()
