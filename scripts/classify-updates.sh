#!/usr/bin/env bash
# Classify the changes between two git refs to decide whether an automatic
# patch release is allowed.
#
# Usage: classify-updates.sh <base-ref> [head-ref]
#        classify-updates.sh --self-test
#
# Watched: the FROM line + ALEXAFHEM_VERSION of the Dockerfile and the
# dependencies of src/package.json. Any other change below src/ or in the
# Dockerfile counts as "other".
#
# Output (stdout): one "<class>|<description>" line per change and a final
#   RESULT=none     nothing changed -> no release
#   RESULT=release  only patch/digest changes -> release
#   RESULT=skip     at least one minor/major/other change -> no release
# Classes: digest, patch, minor, major, other
set -euo pipefail

version_class() { # <old-tag> <new-tag>; prints class (digest if tags equal)
  local re='^([0-9]+)\.([0-9]+)\.([0-9]+)(.*)$' o n
  o="$1"; n="$2"
  [[ "$o" == "$n" ]] && { echo digest; return; }
  if [[ "$o" =~ $re ]]; then local o1=${BASH_REMATCH[1]} o2=${BASH_REMATCH[2]} o3=${BASH_REMATCH[3]} os=${BASH_REMATCH[4]}; else echo other; return; fi
  if [[ "$n" =~ $re ]]; then local n1=${BASH_REMATCH[1]} n2=${BASH_REMATCH[2]} n3=${BASH_REMATCH[3]} ns=${BASH_REMATCH[4]}; else echo other; return; fi
  if [[ "$os" != "$ns" ]]; then echo minor; return; fi   # e.g. alpine3.23 -> alpine3.24
  if (( n1 < o1 || (n1 == o1 && (n2 < o2 || (n2 == o2 && n3 < o3))) )); then echo other; return; fi # downgrade
  if (( n1 != o1 )); then echo major
  elif (( n2 != o2 )); then echo minor
  else echo patch; fi
}

from_line() { sed -n 's/^FROM \([^ ]*\).*/\1/p' | head -n1; }
arg_version() { sed -n 's/^ARG ALEXAFHEM_VERSION="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | head -n1; }
deps() { # name + version per line (needs node, present on ubuntu runners)
  node -e 'const p=JSON.parse(require("fs").readFileSync(0,"utf8"));const d={...p.dependencies,...p.devDependencies};for(const [k,v] of Object.entries(d))console.log(k+" "+v.replace(/^[\^~]/,""))'
}

run() {
  local base="$1" head="${2:-HEAD}"
  local lines=() class
  emit() { lines+=("$1|$2"); }

  # 1. base image: tag/digest
  local of nf
  of=$(git show "$base:Dockerfile" | from_line); nf=$(git show "$head:Dockerfile" | from_line)
  if [[ "$of" != "$nf" ]]; then
    local on="${of%%@*}" nn="${nf%%@*}"
    local oimg="${on%%:*}" nimg="${nn%%:*}" otag="${on#*:}" ntag="${nn#*:}"
    if [[ "$oimg" != "$nimg" ]]; then class=other
    else class=$(version_class "$otag" "$ntag"); fi
    emit "$class" "Base image $oimg: $otag -> $ntag$([[ "${of#*@}" != "${nf#*@}" ]] && echo ' (digest changed)')"
  fi

  # 2. ALEXAFHEM_VERSION build arg
  local ov nv
  ov=$(git show "$base:Dockerfile" | arg_version); nv=$(git show "$head:Dockerfile" | arg_version)
  [[ "$ov" != "$nv" ]] && emit "$(version_class "$ov" "$nv")" "ARG ALEXAFHEM_VERSION: $ov -> $nv"

  # 3. src/package.json dependencies
  local od nd
  od=$(git show "$base:src/package.json" | deps | sort); nd=$(git show "$head:src/package.json" | deps | sort)
  if [[ "$od" != "$nd" ]]; then
    local name ver oldver
    while read -r name ver; do
      oldver=$(awk -v n="$name" '$1==n{print $2}' <<<"$od")
      [[ "$oldver" == "$ver" ]] && continue
      if [[ -z "$oldver" ]]; then emit other "npm $name added ($ver)"
      else emit "$(version_class "$oldver" "$ver")" "npm $name: $oldver -> $ver"; fi
    done <<<"$nd"
    while read -r name ver; do
      [[ -z "$name" ]] && continue
      awk -v n="$name" '$1==n{f=1} END{exit !f}' <<<"$nd" || emit other "npm $name removed"
    done <<<"$od"
  fi

  # 4. any other change below src/ (except lockfile/package.json handled above) or other Dockerfile edits
  local f
  while read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in src/package.json|src/package-lock.json|src/tests/*) ;; Dockerfile) ;; *) emit other "Changed file: $f" ;; esac
  done < <(git diff --name-only "$base" "$head" -- src)
  # Dockerfile changes outside FROM / ALEXAFHEM_VERSION
  if ! diff -q <(git show "$base:Dockerfile" | grep -v -e '^FROM ' -e '^ARG ALEXAFHEM_VERSION=') \
               <(git show "$head:Dockerfile" | grep -v -e '^FROM ' -e '^ARG ALEXAFHEM_VERSION=') >/dev/null; then
    emit other "Dockerfile changed (other than base image / ALEXAFHEM_VERSION)"
  fi

  local result=release
  if ((${#lines[@]} == 0)); then result=none
  else
    printf '%s\n' "${lines[@]}"
    for l in "${lines[@]}"; do case "${l%%|*}" in digest|patch) ;; *) result=skip ;; esac; done
  fi
  echo "RESULT=$result"
}

self_test() {
  local d fail=0; d=$(mktemp -d); trap 'rm -rf "$d"' RETURN
  git -C "$d" init -q; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  mkdir -p "$d/src"
  mk() { # <from> <argver> <npmver>
    printf 'FROM %s AS base\nARG ALEXAFHEM_VERSION="%s"\nRUN true\n' "$1" "$2" > "$d/Dockerfile"
    printf '{"dependencies":{"alexa-fhem":"%s"}}\n' "$3" > "$d/src/package.json"
  }
  local D1=sha256:aaa D2=sha256:bbb
  mk "node:22.1.1-alpine3.24@$D1" 0.5.65 0.5.65; git -C "$d" add -A; git -C "$d" commit -qm base; git -C "$d" tag base
  check() { # <name> <expected> <from> <argver> <npmver>
    mk "$3" "$4" "$5"; git -C "$d" commit -qam "$1" --allow-empty
    local got; got=$(cd "$d" && run base HEAD | tail -n1)
    if [[ "$got" == "RESULT=$2" ]]; then echo "ok   $1"; else echo "FAIL $1: expected $2, got $got"; fail=1; fi
    git -C "$d" reset -q --hard base
  }
  check "no change"        none    "node:22.1.1-alpine3.24@$D1" 0.5.65 0.5.65
  check "digest only"      release "node:22.1.1-alpine3.24@$D2" 0.5.65 0.5.65
  check "node patch"       release "node:22.1.2-alpine3.24@$D2" 0.5.65 0.5.65
  check "alexa-fhem patch" release "node:22.1.1-alpine3.24@$D1" 0.5.66 0.5.66
  check "node minor"       skip    "node:22.2.0-alpine3.24@$D2" 0.5.65 0.5.65
  check "node major"       skip    "node:24.0.0-alpine3.24@$D2" 0.5.65 0.5.65
  check "alpine bump"      skip    "node:22.1.1-alpine3.25@$D2" 0.5.65 0.5.65
  check "alexa-fhem minor" skip    "node:22.1.1-alpine3.24@$D1" 0.6.0 0.6.0
  check "patch+minor mix"  skip    "node:22.1.2-alpine3.24@$D2" 0.6.0 0.6.0
  # other file changed
  echo x > "$d/src/entry.sh"; git -C "$d" add -A; git -C "$d" commit -qm other
  local got; got=$(cd "$d" && run base HEAD | tail -n1)
  if [[ "$got" == "RESULT=skip" ]]; then echo "ok   other src file"; else echo "FAIL other src file: $got"; fail=1; fi
  return $fail
}

if [[ "${1:-}" == "--self-test" ]]; then self_test; exit $?; fi
[[ $# -ge 1 ]] || { sed -n '2,19p' "$0"; exit 2; }
run "$@"
