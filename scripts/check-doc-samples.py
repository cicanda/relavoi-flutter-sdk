#!/usr/bin/env python3
"""Analyze every Dart sample in a markdown file against this package.

Reads ```dart fences out of the files given on the command line, writes one
library per sample into a throwaway Flutter package that depends on the SDK by
path, and runs `flutter analyze` over it. A sample an integrator could not
compile fails here.

The package is depended on by path, so --sdk can point at a different
checkout: the docs repository runs this script from main against the newest
released tag, because the tag is the version its readers install.

See scripts/doc-samples/README.md for the fence annotations and the prelude.

    check-doc-samples.py README.md
    check-doc-samples.py ../relavoi-docs/docs/sdks/flutter
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field

LANG = "dart"
MARKS = {"fragment", "reference", "manifest", "no-compile"}
HERE = pathlib.Path(__file__).resolve().parent.parent

# Flutter's own imports. A page shows `package:flutter/material.dart` where it
# matters and elides it in a three-line snippet, and debugPrint comes from
# foundation; neither is our API, so neither is what this check is about.
# Nothing from package:relavoi_flutter is supplied to a complete sample: that
# import is the page's job, which is how a rename here shows up as a failing
# doc sample.
PLATFORM_IMPORTS = [
    # material re-exports foundation, so debugPrint and ValueNotifier come
    # with it. Importing both makes the analyzer complain about the second.
    "package:flutter/material.dart",
]
FRAGMENT_IMPORTS = ["package:relavoi_flutter/relavoi_flutter.dart"]

NAMED = re.compile(r"^\s*(?:abstract\s+)?(class|enum|mixin|typedef)\s+(\w+)", re.M)
# A method or top-level function, so a listing of a signature is checked too.
# The sessions page lists `Future<Session> create({...})`, which is exactly the
# shape that went stale when 0.3.0 dropped two of its parameters.
FUNC = re.compile(
    r"^(?P<indent>[ \t]*)(?:static\s+)?(?:Future|Stream)?<?[\w<>?,\s]*?>?\s+"
    r"(?P<name>\w+)\s*\(",
    re.M,
)
IMPORT = re.compile(r"""^\s*import\s+['"]([^'"]+)['"]""")


@dataclass
class Sample:
    path: pathlib.Path
    line: int
    mark: str
    reason: str
    code: str
    lib: str = ""
    declares: set[str] = field(default_factory=set)
    linemap: dict[int, int] = field(default_factory=dict)

    @property
    def where(self) -> str:
        return f"{self.path}:{self.line}"


def extract(path: pathlib.Path) -> list[Sample]:
    out: list[Sample] = []
    lines = path.read_text().split("\n")
    i = 0
    while i < len(lines):
        m = re.match(r"^```(\S+)(.*)$", lines[i])
        if not m:
            i += 1
            continue
        lang, meta = m.group(1), m.group(2).strip()
        j = i + 1
        body: list[str] = []
        while j < len(lines) and not re.match(r"^```\s*$", lines[j]):
            body.append(lines[j])
            j += 1
        if lang == LANG:
            words = meta.split()
            mark, reason = "", ""
            if words and words[0] in MARKS:
                mark, reason = words[0], " ".join(words[1:])
            elif words:
                print(
                    f"::error file={path},line={i + 1}::unknown fence annotation "
                    f"{words[0]!r}. Use one of: {', '.join(sorted(MARKS))}"
                )
                sys.exit(2)
            s = Sample(path=path, line=i + 1, mark=mark, reason=reason, code="\n".join(body))
            s.declares = {n for _k, n in NAMED.findall(s.code)}
            out.append(s)
        i = j + 1
    return out


def markdown_files(args: list[str]) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for a in args:
        p = pathlib.Path(a)
        files += sorted(p.rglob("*.md")) if p.is_dir() else [p]
    return [f for f in files if f.name != "CLAUDE.md"]


# ── the reference check ──────────────────────────────────────────────────────


def brace_body(src: str, from_index: int) -> str:
    start = src.find("{", from_index)
    if start < 0:
        return ""
    depth, k = 0, start
    while k < len(src):
        if src[k] == "{":
            depth += 1
        elif src[k] == "}":
            depth -= 1
            if depth == 0:
                return src[start : k + 1]
        k += 1
    return src[start:]


def paren_body(src: str, from_index: int) -> str:
    start = src.find("(", from_index - 1)
    if start < 0:
        return ""
    depth, k = 0, start
    while k < len(src):
        if src[k] == "(":
            depth += 1
        elif src[k] == ")":
            depth -= 1
            if depth == 0:
                return src[start : k + 1]
        k += 1
    return src[start:]


PARAM = re.compile(r"(?:^|[({,])\s*(?:required\s+)?(?:this\.)?[\w<>?,\s]*?\b(\w+)\s*(?=[,)=])", re.M)


def functions(src: str) -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for m in FUNC.finditer(src):
        name = m.group("name")
        if name in ("if", "for", "while", "switch", "return", "catch", "assert", "print"):
            continue
        parens = paren_body(src, m.end())
        params = {p for p in PARAM.findall(parens) if p not in ("required", "this")}
        out.setdefault(name, set()).update(params)
    return out


def declarations(src: str) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for m in NAMED.finditer(src):
        kind, name = m.group(1), m.group(2)
        body = brace_body(src, m.end())
        if not body:
            continue
        fields = set(re.findall(r"^\s*(?:final\s+|const\s+|late\s+)*[\w<>?,\s]+?\s(\w+)\s*(?:;|=)",
                                body, re.M))
        entries: set[str] = set()
        if kind == "enum":
            head = body.split("}")[0]
            head = head.split(";")[0]
            entries = {e.strip() for e in re.split(r"[,\n{]", head) if re.fullmatch(r"[a-z]\w*", e.strip())}
        out.setdefault(name, {"kind": kind, "fields": fields, "entries": entries})
    return out


def sdk_declarations(sdk: pathlib.Path) -> tuple[dict[str, dict], dict[str, set[str]]]:
    found: dict[str, dict] = {}
    funcs: dict[str, set[str]] = {}
    for f in sorted((sdk / "lib").rglob("*.dart")):
        src = f.read_text()
        for name, info in declarations(src).items():
            if name in found:
                found[name]["fields"] |= info["fields"]
                found[name]["entries"] |= info["entries"]
            else:
                found[name] = info
        for name, params in functions(src).items():
            funcs.setdefault(name, set()).update(params)
    return found, funcs


def check_reference(s: Sample, decls: dict[str, dict],
                    funcs: dict[str, set[str]]) -> list[str]:
    problems: list[str] = []
    if not declarations(s.code):
        # A signature listing rather than a type listing.
        for name, params in functions(s.code).items():
            real = funcs.get(name)
            if real is None:
                problems.append(
                    f"{s.where}: reference listing declares {name}(), which is not "
                    f"declared in lib/."
                )
                continue
            for param in sorted(params - real):
                problems.append(
                    f"{s.where}: reference listing gives {name}() a parameter "
                    f"`{param}` that {name}() does not take."
                )
    for name, info in declarations(s.code).items():
        real = decls.get(name)
        if real is None:
            problems.append(
                f"{s.where}: reference listing declares {info['kind']} {name}, which is "
                f"not declared in lib/. Either the package renamed it or the listing "
                f"invented it."
            )
            continue
        for fld in sorted(info["fields"] - real["fields"]):
            problems.append(
                f"{s.where}: reference listing gives {name} a field `{fld}` "
                f"that {name} does not have."
            )
        for e in sorted(info["entries"] - real["entries"]):
            problems.append(
                f"{s.where}: reference listing gives {name} a value `{e}` "
                f"that {name} does not have."
            )
        if info["entries"] and real["entries"] - info["entries"]:
            missing = ", ".join(sorted(real["entries"] - info["entries"]))
            problems.append(
                f"{s.where}: reference listing of {name} is missing {missing}. "
                f"A reader writing an exhaustive switch from this listing will not compile."
            )
    return problems


# ── generation ───────────────────────────────────────────────────────────────

WRAPPER = [
    "// Wrapped by check-doc-samples.py: this fence is marked `fragment`, so it",
    "// is statements rather than declarations, and Dart has no top-level",
    "// statements to put them in.",
    "Future<void> _docSample() async {",
]


def render(s: Sample, inherited: set[str], prelude: list[tuple[str, str]]) -> tuple[str, dict[int, int]]:
    body = [(s.line + 1 + i, t) for i, t in enumerate(s.code.split("\n"))]
    own = {m.group(1) for t in (t for _, t in body) if (m := IMPORT.match(t))}
    baseline = set(PLATFORM_IMPORTS) | inherited
    if s.mark == "fragment":
        baseline |= set(FRAGMENT_IMPORTS)
    prelude_imports = {
        m.group(1) for _n, text in prelude for line in text.split("\n") if (m := IMPORT.match(line))
    }
    supply = sorted((baseline | prelude_imports) - own)

    out: list[tuple[int | None, str]] = [
        (None, f"// {s.where} — generated from the markdown; do not edit."),
        # The prelude is appended whole to every sample, so most of it is
        # unused in any one of them. That is not a finding about the docs.
        (None, "// ignore_for_file: unused_element, unused_local_variable, "
               "unused_import, unused_field"),
    ]
    out += [(None, f"import '{m}';") for m in supply]
    code = [(n, t) for n, t in body if not IMPORT.match(t)]
    out += [(n, t) for n, t in body if IMPORT.match(t)]
    out += [(None, "")]
    if s.mark == "fragment":
        out += [(None, w) for w in WRAPPER]
        out += code
        out += [(None, "}")]
    else:
        out += code
    # The prelude goes at the bottom, in the same library, because the docs
    # call private helpers (_updateUi) and a private name is visible only
    # inside its own library. Appending keeps the sample's own lines at the top
    # so a reported line number still means something.
    out += [(None, ""), (None, "// ── harness prelude ──")]
    for _name, text in prelude:
        for line in text.split("\n"):
            if not IMPORT.match(line):
                out += [(None, line)]
    text = "\n".join(t for _, t in out) + "\n"
    return text, {i + 1: n for i, (n, _) in enumerate(out) if n is not None}


PUBSPEC = """name: doc_samples
description: Generated from markdown by scripts/check-doc-samples.py. Not published.
publish_to: none
version: 0.0.0

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  relavoi_flutter:
    path: {sdk}
"""

# Errors only. A doc sample is not held to the package's own lint rules: it is
# written to be read, so `prefer_const_constructors` is noise here, and failing
# a page over it would push whoever is fixing it toward deleting the check.
ANALYSIS_OPTIONS = """analyzer:
  errors:
    todo: ignore
"""


def write_package(out: pathlib.Path, sdk: pathlib.Path, samples: list[Sample],
                  prelude: dict[str, str]) -> None:
    if out.exists():
        shutil.rmtree(out)
    (out / "lib").mkdir(parents=True)
    (out / "pubspec.yaml").write_text(PUBSPEC.format(sdk=sdk.resolve()))
    (out / "analysis_options.yaml").write_text(ANALYSIS_OPTIONS)
    inherited: dict[pathlib.Path, set[str]] = {}
    for i, s in enumerate(samples, start=1):
        stem = re.sub(r"\W+", "_", s.path.stem).lower()
        s.lib = f"s{i:03d}_{stem}.dart"
        use = [(n, t) for n, t in prelude.items() if n not in s.declares]
        page = inherited.setdefault(s.path, set())
        text, s.linemap = render(s, set(page), use)
        page |= {m.group(1) for line in s.code.split("\n") if (m := IMPORT.match(line))}
        (out / "lib" / s.lib).write_text(text)


DIAG = re.compile(r"^\s*(error|warning|info)\s+-\s+(.+?):(\d+):(\d+)\s+-\s+(.*)$")
DIAG2 = re.compile(r"^\s*(error|warning|info)\s+•\s+(.*?)\s+•\s+(.+?):(\d+):(\d+)\s*(?:•\s*(\S+))?$")


def analyze(out: pathlib.Path, samples: list[Sample]) -> int:
    by_lib = {s.lib: s for s in samples}
    subprocess.run(["flutter", "pub", "get"], cwd=out, capture_output=True, text=True)
    cmd = ["flutter", "analyze", "--no-pub"]
    print("$ " + " ".join(cmd) + f"   (in {out})")
    proc = subprocess.run(cmd, cwd=out, capture_output=True, text=True)
    text = proc.stdout + proc.stderr
    buckets: dict[str, dict[str, list[str]]] = {"error": {}, "warning": {}, "info": {}}
    for line in text.split("\n"):
        sev = f = ln = msg = None
        m = DIAG.match(line)
        if m:
            sev, f, ln, _col, msg = m.groups()
        else:
            m = DIAG2.match(line)
            if m:
                sev, msg, f, ln, _col, _rule = m.groups()
        if not sev:
            continue
        s = by_lib.get(pathlib.Path(f).name)
        if s is None:
            continue
        orig = s.linemap.get(int(ln))
        where = f"{s.path}:{orig}" if orig else f"{s.where} (harness prelude)"
        entry = f"  {where}: {msg}"
        b = buckets[sev].setdefault(s.where, [])
        if entry not in b:
            b.append(entry)

    for sev in ("info", "warning"):
        if buckets[sev]:
            print(f"\n{sev.capitalize()}s (not fatal):")
            for where, msgs in sorted(buckets[sev].items()):
                print(f"  {where}")
                print("\n".join(msgs))

    if not buckets["error"]:
        if proc.returncode != 0 and not buckets["warning"] and not buckets["info"]:
            print("\nflutter analyze failed without a diagnostic this script could place:")
            print(text[-6000:])
            return 1
        return 0
    print("\nSamples that do not analyze:\n")
    for where, msgs in sorted(buckets["error"].items()):
        print(f"::error::{where} does not compile")
        print("\n".join(msgs))
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--sdk", default=str(HERE),
                    help="the package checkout to analyze against; defaults to this one")
    ap.add_argument("--out", default="")
    ap.add_argument("--keep", action="store_true")
    args = ap.parse_args()
    sdk = pathlib.Path(args.sdk).resolve()

    prelude_dir = pathlib.Path(__file__).resolve().parent / "doc-samples" / "prelude"
    prelude = {p.stem: p.read_text() for p in sorted(prelude_dir.glob("*.dart"))}

    files = markdown_files(args.files)
    samples: list[Sample] = []
    for f in files:
        samples += extract(f)
    if not samples:
        print(f"::error::no ```{LANG} fences found in {', '.join(map(str, files))}")
        return 2

    census: dict[str, int] = {}
    for s in samples:
        census[s.mark or "compiled"] = census.get(s.mark or "compiled", 0) + 1
    print(f"{len(samples)} dart fences in {len(files)} file(s):")
    for k in ("compiled", "fragment", "reference", "manifest", "no-compile"):
        if census.get(k):
            print(f"  {census[k]:3d}  {k}")
    for s in samples:
        if s.mark == "no-compile":
            if not s.reason:
                print(f"::error file={s.path},line={s.line}::`no-compile` needs a reason.")
                return 2
            print(f"  not checked: {s.where}: {s.reason}")

    decls, funcs = sdk_declarations(sdk)
    problems: list[str] = []
    for s in samples:
        if s.mark == "reference":
            problems += check_reference(s, decls, funcs)
    if problems:
        print("\nReference listings that disagree with lib/:\n")
        for p in problems:
            print(f"::error::{p}")
        return 1
    print(f"\nReference listings agree with lib/ ({census.get('reference', 0)} checked).")

    todo = [s for s in samples if s.mark in ("", "fragment")]
    if not todo:
        return 0
    out = pathlib.Path(args.out) if args.out else pathlib.Path(
        os.environ.get("TMPDIR", "/tmp")
    ) / "relavoi-doc-samples-dart"
    write_package(out, sdk, todo, prelude)
    rc = analyze(out, todo)
    if rc == 0:
        print(f"\nAll {len(todo)} compiled samples analyze against {sdk}.")
        if not args.keep:
            shutil.rmtree(out, ignore_errors=True)
    else:
        print(f"\nGenerated package left at {out} for inspection.")
    return rc


if __name__ == "__main__":
    sys.exit(main())
