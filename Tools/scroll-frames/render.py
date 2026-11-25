#!/usr/bin/env python3
"""Render the website's scroll scenes as WebP frame sequences.

The preview draws each scene offscreen (XEERPE_FRAMES), one PNG per step of
its progress, and cwebp encodes them. No window opens and the pointer is
never touched. Writes <out>/<scene>/0001.webp... and <out>/scenes.json.

usage: render.py [--out DIR] [--quality Q] [scene ...]
"""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENES = ["card", "aurora", "pond", "reveal"]


def parse_summary(line):
    """'frames N W H' printed by the preview -> {'frames', 'width', 'height'}."""
    kind, *values = line.split()
    if kind != "frames" or len(values) != 3:
        raise ValueError(f"unexpected preview output: {line!r}")
    frames, width, height = (int(v) for v in values)
    return {"frames": frames, "width": width, "height": height}


def render(binary, scene, out, quality, work):
    pngs = work / scene
    done = subprocess.run([binary, str(pngs)], env={"XEERPE_FRAMES": scene, "PATH": "/usr/bin:/bin"},
                          check=True, capture_output=True, text=True)
    info = parse_summary(done.stdout.strip().splitlines()[-1])
    target = out / scene
    shutil.rmtree(target, ignore_errors=True)
    target.mkdir(parents=True)
    encode = lambda png: subprocess.run(["cwebp", "-quiet", "-q", str(quality), "-m", "6", png,
                                         "-o", target / (png.stem + ".webp")], check=True)
    with ThreadPoolExecutor() as pool:
        list(pool.map(encode, sorted(pngs.glob("*.png"))))
    return info


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--out", type=Path, default=ROOT / "Site/public/frames")
    p.add_argument("--quality", type=int, default=84)
    p.add_argument("scenes", nargs="*")
    args = p.parse_args()
    for tool in ("cwebp", "swift"):
        if not shutil.which(tool):
            sys.exit(f"missing {tool}")
    names = args.scenes or SCENES

    subprocess.run(["swift", "build", "-c", "release", "--product", "xeerpe-preview"], cwd=ROOT, check=True)
    binary = subprocess.run(["swift", "build", "-c", "release", "--show-bin-path"], cwd=ROOT, check=True,
                            capture_output=True, text=True).stdout.strip() + "/xeerpe-preview"
    args.out.mkdir(parents=True, exist_ok=True)
    index_path = args.out / "scenes.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}
    with tempfile.TemporaryDirectory() as tmp:
        for name in names:
            print(f"rendering {name}", flush=True)
            index[name] = render(binary, name, args.out, args.quality, Path(tmp))
    index_path.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
