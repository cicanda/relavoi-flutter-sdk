#!/usr/bin/env bash
#
# Fail if the tree disagrees with the tag being released.
#
# The iOS SDK has the same check for the same reason: v0.3.2 there was tagged
# with a README still pointing at the previous release, and force-moving a
# published tag made SwiftPM refuse to resolve it, because it had already
# cached the old revision. The version bump belongs in the release commit.
#
# This repository has one more place to drift than the iOS SDK does: the
# CocoaPods podspec carries its own version string, and it had sat at 0.0.1
# while the package was at 0.3.1.
#
#   scripts/check-release-version.sh v0.3.2
#
set -euo pipefail

TAG="${1:-${GITHUB_REF_NAME:-}}"
if [[ -z "$TAG" ]]; then
  echo "usage: $0 <tag>    (e.g. v0.3.2)" >&2
  exit 2
fi
if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "::error::tag '$TAG' is not vMAJOR.MINOR.PATCH" >&2
  exit 1
fi

# A git ref keeps the leading v, unlike SwiftPM. pubspec and the podspec do not.
VERSION="${TAG#v}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
note() { echo "  $*"; }
bad() { echo "::error::$*"; fail=1; }

echo "Releasing $TAG, so pubspec and the podspec must read $VERSION."

# ── pubspec: the package version itself ──────────────────────────────────────
pubspec_version=$(grep -m1 -E '^version:' "$ROOT/pubspec.yaml" | sed -E 's/^version: *//' | tr -d '\r')
if [[ "$pubspec_version" == "$VERSION" ]]; then
  note "pubspec.yaml version: $pubspec_version  ok"
else
  bad "pubspec.yaml is $pubspec_version, but the tag being cut is $TAG."
fi

# ── podspec: what a CocoaPods consumer sees ──────────────────────────────────
podspec="$ROOT/ios/relavoi_flutter.podspec"
podspec_version=$(grep -m1 -E "s\.version +=" "$podspec" | sed -E "s/.*= *'([^']+)'.*/\1/")
if [[ "$podspec_version" == "$VERSION" ]]; then
  note "podspec version: $podspec_version  ok"
else
  bad "$(basename "$podspec") is $podspec_version, expected $VERSION. It sat at 0.0.1 for three releases."
fi

# ── README: the git ref an integrator copies, tag and all ────────────────────
readme_refs=$(grep -oE 'ref: v[0-9]+\.[0-9]+\.[0-9]+' "$ROOT/README.md" | sed -E 's/ref: //' | sort -u || true)
if [[ -z "$readme_refs" ]]; then
  bad "README.md has no 'ref: vX.Y.Z' install snippet to check. If it moved, update this script."
else
  while read -r r; do
    [[ -z "$r" ]] && continue
    if [[ "$r" == "$TAG" ]]; then
      note "README.md install snippet: ref: $r  ok"
    else
      bad "README.md installs $r, but the tag being cut is $TAG."
    fi
  done <<< "$readme_refs"
fi

# ── CHANGELOG: the newest section must be this release ───────────────────────
top=$(grep -m1 -E '^## ' "$ROOT/CHANGELOG.md" | sed -E 's/^## +//' | tr -d '\r')
if [[ "$top" == "$VERSION" ]]; then
  note "CHANGELOG.md newest section: $top  ok"
else
  bad "CHANGELOG.md's newest section is '$top', expected '$VERSION'."
fi

# ── One iOS floor, stated the same everywhere ────────────────────────────────
# Not about the tag, but this is the gate every release passes through, and
# the docs claimed 15.0 while the podspec said 13.0 for three releases.
pod_floor=$(grep -oE "s\.platform *= *:ios, *'[0-9.]+'" "$podspec" | grep -oE "[0-9]+\.[0-9]+")
spm_floor=$(grep -oE '\.iOS\("[0-9.]+"\)' "$ROOT/ios/relavoi_flutter/Package.swift" | grep -oE "[0-9]+\.[0-9]+")
readme_floor=$(grep -oE '^- iOS [0-9]+\.[0-9]+' "$ROOT/README.md" | grep -oE "[0-9]+\.[0-9]+" || true)
if [[ "$pod_floor" == "$spm_floor" && "$pod_floor" == "$readme_floor" ]]; then
  note "iOS floor stated as $pod_floor in the podspec, Package.swift and README  ok"
else
  bad "iOS floor disagrees: podspec=$pod_floor Package.swift=$spm_floor README=$readme_floor"
fi

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "Nothing was published. Fix the tree, amend the release commit, then tag."
  exit 1
fi
echo "Tree agrees with $TAG."
