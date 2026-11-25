#!/usr/bin/env python3
"""Writes the chain forms of xeerpe's API from their single definitions, so
each effect and preset is declared once.

Usage: generate.py [--check] [<sources dir>] [<output file>]
With --check nothing is written: the exit status is 1 when the output is
out of date, for CI.
Defaults: Sources/xeerpe and Sources/xeerpe/Generated/API.swift, relative to
the repository root (the parent of this script's parent directory).

What it reads, and what it writes for each declaration:
- `public static func` in `extension XeerpeEffect`: a static and an
  instance method on XeerpeChain, so a builder line can start with a dot
  and the next line can continue it.
- `public static func` in `extension XeerpeChain` (presets): the instance
  twin.
- `XeerpePreset("id", ...)`: a typed `XeerpePreset.id` member.
In the generated chain methods every `XeerpeValue` parameter accepts any
`XeerpeValueConvertible` (a Double, an Int, a Bool or a signal).
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHECK = "--check" in sys.argv[1:]
ARGS = [a for a in sys.argv[1:] if a != "--check"]
SRC = ARGS[0] if len(ARGS) > 0 else os.path.join(ROOT, "Sources", "xeerpe")
OUT = ARGS[1] if len(ARGS) > 1 else os.path.join(SRC, "Generated", "API.swift")
VALUE = "XeerpeValue"
ANY = "some XeerpeValueConvertible"
# Hand-written in both forms (`shader` exists only where shaders do).
SKIP = {"then", "shader"}
# XeerpePreset members a preset name must not shadow.
RESERVED = {"id", "category", "layers", "motion", "name", "style", "reactive", "init", "named"}


def split_top(s, sep=","):
    """Splits on `sep` outside brackets, parentheses, angle brackets and strings."""
    out, depth, cur, quote = [], 0, "", False
    for ch in s:
        if ch == '"':
            quote = not quote
        if not quote:
            if ch in "([<{":
                depth += 1
            elif ch in ")]>}":
                depth -= 1
        if ch == sep and depth == 0 and not quote:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return [p.strip() for p in out]


def closing(s, start):
    """Index of the parenthesis that closes the one at `start`."""
    depth, quote = 0, False
    for i in range(start, len(s)):
        ch = s[i]
        if ch == '"':
            quote = not quote
        if quote:
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("unbalanced: " + s)


class Param:
    def __init__(self, text):
        head, _, rest = text.partition(":")
        # Attributes such as @XeerpeBuilder come before the names and are kept.
        self.attrs = "".join(t + " " for t in head.split() if t.startswith("@"))
        names = [t for t in head.split() if not t.startswith("@")]
        self.label, self.name = (names[0], names[1]) if len(names) == 2 else (names[0], names[0])
        typ, eq, default = rest.partition("=")
        self.type = typ.strip()
        self.default = default.strip() if eq else None

    def declare(self, convert):
        typ = ANY if convert and self.type == VALUE else self.type
        names = self.name if self.label == self.name else f"{self.label} {self.name}"
        return f"{self.attrs}{names}: {typ}" + (f" = {self.default}" if self.default is not None else "")

    def forward(self, convert):
        arg = f"{self.name}.xeerpeValue" if convert and self.type == VALUE else self.name
        return arg if self.label == "_" else f"{self.label}: {arg}"


class Decl:
    def __init__(self, doc, text, kind):
        self.doc, self.kind = doc, kind
        m = re.match(r"public static (func|var) (\w+)", text)
        self.is_var, self.name = m.group(1) == "var", m.group(2)
        rest = text[m.end():]
        if self.is_var:
            self.generics, self.params = "", []
            self.ret = rest.split(":", 1)[1].split("{", 1)[0].strip()
            return
        self.generics = ""
        if rest.startswith("<"):
            end = rest.index(">(")
            self.generics, rest = rest[:end + 1], rest[end + 1:]
        close = closing(rest, 0)
        self.params = [Param(p) for p in split_top(rest[1:close])]
        self.ret = rest[close + 1:].split("->", 1)[1].split("{", 1)[0].strip()

    def signature(self, convert):
        return f"{self.name}{self.generics}({', '.join(p.declare(convert) for p in self.params)})"

    def call(self, convert):
        return f"{self.name}({', '.join(p.forward(convert) for p in self.params)})"


def scan(path):
    """(extension header, doc lines, declaration text) for each public static member."""
    lines = open(path).read().split("\n")
    ext, i = None, 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("extension "):
            ext = line.strip()
        elif line == "}":
            ext = None
        elif ext and re.match(r"    public static (func|var) \w", line):
            doc, j = [], i - 1
            while j >= 0 and lines[j].startswith("    ///"):
                doc.insert(0, lines[j])
                j -= 1
            text = line.strip()
            while not re.search(r"(->[^{]*|: [^{]*)\{", text) and i + 1 < len(lines):
                i += 1
                text += " " + lines[i].strip()
            yield ext, doc, text
        i += 1


def main():
    effects, presets, names = [], [], []
    files = []
    for d, _, fs in os.walk(SRC):
        files += [os.path.join(d, f) for f in fs if f.endswith(".swift")]
    for path in sorted(files):
        if os.path.abspath(path) == os.path.abspath(OUT):
            continue
        source = open(path).read()
        names += re.findall(r'XeerpePreset\("([a-z0-9-]+)"', source)
        for ext, doc, text in scan(path):
            if ext == "extension XeerpeEffect {" and text.startswith("public static func"):
                d = Decl(doc, text, "effect")
                if d.ret == "XeerpeEffect" and d.name not in SKIP:
                    effects.append(d)
            elif ext == "extension XeerpeChain {" and text.startswith("public static func"):
                d = Decl(doc, text, "preset")
                if d.ret == "XeerpeChain" and d.name not in SKIP:
                    presets.append(d)

    out = ["// Generated by Tools/api/generate.py. Do not edit.", "", "import SwiftUI", ""]
    out.append("extension XeerpeChain {")
    for d in effects:
        out += d.doc
        out.append(f"    public static func {d.signature(True)} -> XeerpeChain {{ XeerpeChain([XeerpeEffect.{d.call(True)}]) }}")
        out += d.doc
        out.append(f"    public func {d.signature(True)} -> XeerpeChain {{ appending(XeerpeEffect.{d.call(True)}) }}")
    for d in presets:
        out += d.doc
        out.append(f"    public func {d.signature(True)} -> XeerpeChain {{ appending(XeerpeChain.{d.call(True)}) }}")
    out += ["}", "", "extension XeerpePreset {"]
    used = set()
    for n in names:
        ident = re.sub(r"-(\w)", lambda m: m.group(1).upper(), n)
        if ident[0].isdigit() or ident in RESERVED or ident in used:
            sys.exit(f"preset id {n!r} gives an unusable member name {ident!r}")
        used.add(ident)
        out.append(f'    public static var {ident}: XeerpePreset {{ .named("{n}") }}')
    out += ["}", ""]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    text = "\n".join(out)
    if os.path.exists(OUT) and open(OUT).read() == text:
        return
    if CHECK:
        sys.exit(f"{OUT} is out of date: run Tools/api/generate.py")
    open(OUT, "w").write(text)
    print(f"wrote {OUT}: {len(effects)} effects, {len(presets)} presets, {len(names)} catalog names")


main()
