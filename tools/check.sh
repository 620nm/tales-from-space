#!/bin/sh
# This pack's gate, locally. The engine gate (`lunatic/tools/check.sh`)
# checks the ENGINE over its own demo and fixture packs and needs no
# content; everything it used to assert about THIS pack is here.
#
# THE ENGINE. Resolved as `tools/test.mjs` resolves it: `LUNATIC_ENGINE`,
# else the checkout beside this one. Every cargo verb runs in a subshell
# `cd "$ENGINE"` -- the engine's `.cargo/config.toml` (mold, the wasm
# cfg) is read from the CWD, so a cargo run from here would silently
# build with different flags and thrash the engine's target directory.
# The build itself stays in the engine's own `target/`; never set
# CARGO_TARGET_DIR.
#
# TWO GATES, ONE ENGINE. This gate NEVER writes the engine checkout's
# own served root: that one is the engine gate's demo bake. This pack's bake goes to
# `target/web` HERE and every headless subcommand reads it back with
# `--web`. Cargo's per-layout lock still serializes this gate against an
# engine gate running in the same checkout; point `LUNATIC_ENGINE` at a
# second engine worktree to run both at once.
#
# QUIET. One line per lane; a failing lane's whole log is printed at the
# end, and nothing else is. Logs land in target/gate/log/<lane>.log.
# `VERBOSE=1 sh tools/check.sh` streams everything live instead.
# `sh tools/check.sh <substring>...` runs only the lanes whose names match.
#
# A SKIP MUST NEVER READ AS A PASS. A lane that cannot run says so by
# name, both where it would have run and in the closing
# SKIPPED, SO UNVERIFIED line. A lane whose prerequisite failed is
# BLOCKED -- unverified, not green and not red.
#
# ONE AT A TIME. A run claims $GATE.lock for its whole life and a second
# invocation sharing that state dir is REFUSED (exit 2): the two reset
# each other's bookkeeping, and a wiped failure is the same sin as a
# skip that reads as a pass. Give a second run its own state dir:
# `GATE=$PWD/target/gate2 sh tools/check.sh ...`.
set -e
cd "$(dirname "$0")/.."
PACK=$PWD

# The pack is the subject here, so it is named absolutely and exported:
# `tools/dev.mjs` demands an absolute one, and the engine's three shared
# lints read the pack out of the environment.
if [ ! -f "$PACK/mod.toml" ]; then
  echo "$PACK holds no mod.toml: this is not the content pack" >&2
  exit 1
fi

ENGINE=${LUNATIC_ENGINE:-$PACK/../lunatic}
ENGINE=$(CDPATH= cd -- "$ENGINE" 2>/dev/null && pwd) || ENGINE=
if [ -z "$ENGINE" ] || [ ! -f "$ENGINE/Cargo.toml" ] || [ ! -f "$ENGINE/tools/check.sh" ]; then
  echo "Set LUNATIC_ENGINE or pass the absolute engine checkout path." >&2
  echo "  e.g. LUNATIC_ENGINE=/absolute/path/to/lunatic sh tools/check.sh" >&2
  exit 1
fi
# Unbuilt engine tooling is refused rather than skipped lane by lane: the
# node checks, the UI runtime and the lab all need this one install, and
# a gate whose interface half all skipped would prove nothing.
if [ ! -d "$ENGINE/web/node_modules" ]; then
  echo "$ENGINE/web/node_modules is missing: the engine's node tooling is not installed" >&2
  echo "  npm --prefix \"$ENGINE/web\" ci" >&2
  exit 1
fi
for tool in tools/luau.mjs tools/lint-units.sh tools/lint-tree.sh tools/lint-terms.sh \
  tools/ui-lab.mjs tools/staff-ui-status.mjs tools/world-pointer-live.mjs \
  tools/ui-lab/push-motion-live.mjs; do
  [ -f "$ENGINE/$tool" ] && continue
  echo "$ENGINE/$tool is missing: that engine checkout cannot run this gate" >&2
  exit 1
done

export LUNATIC_PACK=$PACK
export LUNATIC_ENGINE=$ENGINE

set +e   # every lane reports its own status; see run() below.

# Overridable so a second run can keep its own logs and bookkeeping.
GATE=${GATE:-$PACK/target/gate}
LOGS=$GATE/log
LOCK=$GATE.lock
VERBOSE=${VERBOSE:-0}
ONLY=$*
# This pack's served document root: the whole bake, inside this
# repository, never the engine's. Read back by every headless
# subcommand and by both live browser runners as `--web`. Overridable
# so a check of this gate can point it at a scratch root, and REFUSED
# inside the engine, which makes the promise above enforced rather
# than merely written down.
PACK_WEB=${PACK_WEB:-$PACK/target/web}
case $PACK_WEB in
  "$ENGINE" | "$ENGINE"/*)
    echo "PACK_WEB=$PACK_WEB is inside the engine checkout: that root is the engine gate's" >&2
    exit 1
    ;;
esac
BAKED_ATLAS=$PACK_WEB/assets/atlas.ron
# The roster document the `roster` lane writes -- stdout only, since
# that lane's stderr carries an unbaked NOTE. Read by `placeable`
# (crates/lunatic-client/tests/placeable.rs) and by the pack's own node
# checks over the served roster, which fail hard when it is unreadable.
ROSTER=$GATE/roster.json
# Both are this gate's OUTPUTS, never its inputs, and each is exported
# only once THIS run has produced what it names: a reader handed a path
# is handed a promise, and a promise kept by an earlier run's leftovers
# is how a filtered run reads yesterday's content as today's.
unset LUNATIC_ROSTER
unset LUNATIC_PACK_WEB

# `mkdir` is the atomic claim on every shell this runs under, Git Bash
# included; `kill -0` then tells a live holder from a lock some killed
# run left behind.
alive() { kill -0 "$1" 2>/dev/null; }

read_lock_owner() {
  lock_pid= lock_started= lock_lanes=
  [ -f "$LOCK/owner" ] || return 1
  { read -r lock_pid; read -r lock_started; read -r lock_lanes; } < "$LOCK/owner"
  [ -n "$lock_pid" ]
}

take_lock() {
  mkdir "$LOCK" 2>/dev/null || return 1
  printf '%s\n%s\n%s\n' "$$" "$(date '+%Y-%m-%d %H:%M:%S')" "${ONLY:-all lanes}" \
    > "$LOCK/owner"
  LOCK_HELD=1
}

refuse_second_run() {
  echo "a gate is already running here: pid $lock_pid, started $lock_started, lanes: $lock_lanes" >&2
  echo "  wait for it, or give this run its own state dir: GATE=\$PWD/target/gate2 sh tools/check.sh" >&2
  exit 2
}

LOCK_HELD=0
mkdir -p "$GATE"
if ! take_lock; then
  if read_lock_owner; then
    alive "$lock_pid" && refuse_second_run
  else
    # A holder that just won the mkdir writes `owner` a moment later, so
    # only a lock still unreadable after that moment is abandoned.
    sleep 1
    read_lock_owner && alive "$lock_pid" && refuse_second_run
  fi
  echo "stale gate lock (pid ${lock_pid:-unknown} is gone): taking it over" >&2
  rm -rf "$LOCK"
  take_lock || { echo "cannot claim $LOCK" >&2; exit 2; }
fi

# Releasing checks the owner back: a run that had its lock taken from it
# must not delete the successor's.
release_lock() {
  if [ "$LOCK_HELD" = 1 ]; then
    LOCK_HELD=0
    read_lock_owner && [ "$lock_pid" != "$$" ] && return 0
    rm -rf "$LOCK"
  fi
}
trap release_lock EXIT
trap 'release_lock; exit 130' INT
trap 'release_lock; exit 143' TERM

# The verdict counts THIS run's failures out of THIS run's files, so
# nothing reaching into a shared $GATE can turn a red run green by
# truncating a file it shares.
RUN_DIR=$GATE/run.$$
FAILED=$RUN_DIR/failed
BLOCKED=$RUN_DIR/blocked
SKIPPED=$RUN_DIR/skipped
# The lanes that actually executed and passed. The closing banner names
# these and nothing else: a selection is not a verdict, and a run whose
# every selected lane was blocked or skipped verified nothing at all.
RAN=$RUN_DIR/ran
rm -rf "$LOGS" "$RUN_DIR"
# An earlier run's roster document describes an earlier tree. Nothing
# may read one, so it goes before any lane can be tempted by it.
rm -f "$ROSTER"
for dir in "$GATE"/run.*; do
  [ -d "$dir" ] || continue
  alive "${dir##*/run.}" || rm -rf "$dir"
done
mkdir -p "$LOGS" "$RUN_DIR"
: > "$FAILED"
: > "$BLOCKED"
: > "$RAN"

# Sub-second timings need GNU date; a shell without %N still gets whole
# seconds rather than nothing.
case "$(date +%N 2>/dev/null)" in
  '' | *[!0-9]*) NS=0 ;;
  *) NS=1 ;;
esac
now_ms() {
  if [ "$NS" = 1 ]; then
    date +%s%N | awk '{ print substr($0, 1, length($0) - 6) }'
  else
    echo "$(( $(date +%s) * 1000 ))"
  fi
}
took() { awk -v ms="$1" 'BEGIN { printf "%.1fs", ms / 1000 }'; }

want() {
  [ -z "$ONLY" ] && return 0
  for pat in $ONLY; do
    case "$1" in *"$pat"*) return 0 ;; esac
  done
  return 1
}

# run NAME COMMAND... -- one status line, output to a log, status returned.
run() {
  name=$1
  shift
  want "$name" || return 0
  start=$(now_ms)
  if [ "$VERBOSE" = 1 ]; then
    printf '\n== %s ==\n' "$name"
    "$@"
    rc=$?
  else
    "$@" > "$LOGS/$name.log" 2>&1
    rc=$?
  fi
  elapsed=$(took "$(( $(now_ms) - start ))")
  if [ "$rc" -eq 0 ]; then
    printf 'ok    %-22s %8s\n' "$name" "$elapsed"
    printf '%s\n' "$name" >> "$RAN"
  else
    printf 'FAIL  %-22s %8s\n' "$name" "$elapsed"
    printf '%s\n' "$name" >> "$FAILED"
  fi
  return "$rc"
}

# skip NAME REASON PHRASE -- this lane cannot run here. It prints like a
# status line and its PHRASE reaches the closing banner, so a lane that
# did not execute is never counted as one that passed.
skip() {
  want "$1" || return 0
  printf 'skip  %-22s %8s  (%s)\n' "$1" - "$2"
  printf '%s\n' "$3" >> "$SKIPPED"
}

# note NAME WHAT -- something a lane is doing that a reader would not
# assume from a green line, such as reading art this run did not bake.
note() {
  printf 'note  %-22s %8s  (%s)\n' "$1" - "$2"
}

# blocked NAME REASON -- a prerequisite failed before this lane ran. It
# lands in this run's `blocked`, never its `failed`: a lane that never
# ran is unverified, not red.
blocked() {
  want "$1" || return 0
  printf 'BLOCKED %-22s %8s  (%s)\n' "$1" - "$2"
  printf '%s\n' "$1" >> "$BLOCKED"
}

# gated REASON NAME COMMAND... -- run it, or mark it BLOCKED by REASON.
# An empty REASON means the prerequisite held.
gated() {
  reason=$1
  name=$2
  shift 2
  if [ -z "$reason" ]; then
    run "$name" "$@"
    return $?
  fi
  blocked "$name" "$reason"
  return 0
}

# Every cargo verb: the engine's workspace, built with the engine's own
# cargo configuration and into the engine's own target directory.
engine_cargo() {
  (cd "$ENGINE" && cargo "$@")
}
server() {
  engine_cargo run -q --manifest-path "$ENGINE/Cargo.toml" -p lunatic-server -- "$@"
}

# ---------------------------------------------------------------- lanes

# Strict Luau over every trusted source this pack ships (AGENTS.md,
# "Content design rules"): the one check that needs no build at all.
lane_luau() {
  run luau node "$ENGINE/tools/luau.mjs" check "$PACK"
}

# One spelling per unit across this pack's content/ and tests/. The
# script prints its no-pack branch and exits 0, which under a quiet gate
# would land beneath a green banner -- here that branch is a FAILURE,
# because a pack half that did not run is not a pack that passed.
lint_units_check() {
  sh "$ENGINE/tools/lint-units.sh" > "$GATE/lint-units.out" 2>&1
  rc=$?
  cat "$GATE/lint-units.out"
  if grep -q 'the pack went unchecked' "$GATE/lint-units.out"; then
    echo "lint-units never read this pack: an unrun half is not a pass" >&2
    rc=1
  fi
  return $rc
}

# The three lints the engine owns and this pack is scanned by. Each also
# walks the engine tree it lives in, so a red lane here can name an
# engine file; the pack half is the half this gate exists for
# (README.md's tree-debt table, docs/architecture/vocabulary.md's `pack:`
# rows).
lane_lints() {
  run lint-units lint_units_check
  run tree-shape sh "$ENGINE/tools/lint-tree.sh"
  run terms sh "$ENGINE/tools/lint-terms.sh"
}

# This pack's art, baked into this repository's own served root. Needs
# LUNATIC_TG for the tg-sourced sheets `assets/tg-revision` pins. One
# bake covers every domain this pack publishes, fonts included
# (crates/xtask/src/pipeline.rs, `Domain::ALL`), so `assets/fonts/`
# needs no verb of its own.
bake_check() {
  engine_cargo run -q --manifest-path "$ENGINE/Cargo.toml" -p xtask -- \
    bake-atlas --content "$PACK/assets" --web "$PACK_WEB"
}

# Whether this engine's `build-ui` can be pointed at a served root. The
# binary's own usage line answers it, in the `build-ui` clause alone:
# the `--web` earlier in that line is the baker's, which every engine
# has had for as long as this gate has existed.
build_ui_takes_web() {
  engine_cargo run -q --manifest-path "$ENGINE/Cargo.toml" -p xtask -- 2>&1 \
    | grep -q 'build-ui[^|]*--web'
}

# This pack's interface, compiled against that engine's SDK. It reads
# the bake: a declared font must already be published as an object, so
# an engine that cannot be pointed at this pack's served root looks for
# this pack's fonts in the object store of whichever pack the engine
# checkout last baked (web/scripts/build-pack-ui.mjs, `packFonts`,
# which resolves `assets/obj` against its own working directory).
pack_ui_build_check() {
  if build_ui_takes_web; then
    engine_cargo run -q --manifest-path "$ENGINE/Cargo.toml" -p xtask -- \
      build-ui --pack "$PACK" --web "$PACK_WEB"
  else
    echo "pack interface fonts (matched against the engine checkout's bake, not --web)" \
      >> "$SKIPPED"
    engine_cargo run -q --manifest-path "$ENGINE/Cargo.toml" -p xtask -- \
      build-ui --pack "$PACK"
  fi
}

# The binaries the live browser runners launch with `--no-build`, and
# the baker every content lane goes through.
build_check() {
  engine_cargo build -q --manifest-path "$ENGINE/Cargo.toml" \
    -p lunatic-server -p lunatic-gateway -p xtask
}

# One roster run serves both readers. Only stdout is the document: the
# subcommand writes an unbaked-atlas NOTE to stderr, which stays in this
# lane's log rather than in the JSON.
roster_check() {
  server roster "$PACK" --web "$PACK_WEB" > "$ROSTER"
}

# Whether the engine's palette test can be pointed at a web root. Until
# it can, its ART half reads `Atlas::baked()`, which resolves the ENGINE
# checkout's own served root at COMPILE time
# (crates/lunatic-client/src/delivery.rs, `repo_web_root`) -- the wrong
# pack's bake here. The probe reads the file that would read the
# variable, so this arms itself with the engine change and needs no
# edit here.
placeable_reads_a_web_root() {
  grep -q LUNATIC_WEB_ROOT "$ENGINE/crates/lunatic-client/tests/placeable.rs" 2>/dev/null
}

# Is what this pack declares actually offered in the map editor? The
# server dumps the roster it would serve and a client test builds the
# palette the browser builds. Where the art half cannot reach this
# pack's bake, the RUNNER declares that skip by name and the shape
# rules over this pack's roster still run.
placeable_check() {
  if placeable_reads_a_web_root; then
    (cd "$ENGINE" && env LUNATIC_ROSTER="$ROSTER" LUNATIC_WEB_ROOT="$PACK_WEB" \
      cargo nextest run --cargo-quiet --manifest-path "$ENGINE/Cargo.toml" \
      -p lunatic-client --test placeable)
  else
    echo "placeable art rule (the test reads the engine checkout's own bake, not --web)" \
      >> "$SKIPPED"
    (cd "$ENGINE" && env LUNATIC_ROSTER="$ROSTER" LUNATIC_PLACEABLE_NO_ATLAS=1 \
      cargo nextest run --cargo-quiet --manifest-path "$ENGINE/Cargo.toml" \
      -p lunatic-client --test placeable)
  fi
}

# Every map round-trips, and every `tests/maps/` fixture is named with
# the specs that boot it (tools/map-fixture-coverage.mjs). An engine
# whose `maps` never walks `tests/maps/` is a failure, not a pass: its
# count must be printed and must be every fixture on disk.
map_fixture_check() {
  node "$PACK/tools/map-fixture-coverage.mjs" || return $?
  server maps "$PACK" --web "$PACK_WEB" > "$GATE/maps.out" 2>&1
  rc=$?
  cat "$GATE/maps.out"
  [ "$rc" -eq 0 ] || return "$rc"
  want_fixtures=$(find "$PACK/tests/maps" -maxdepth 1 -name '*.ron' 2>/dev/null | wc -l)
  got_fixtures=$(sed -n 's/.*tests\/maps: \([0-9][0-9]*\) checked.*/\1/p' "$GATE/maps.out")
  if [ "$got_fixtures" != "$((want_fixtures))" ]; then
    echo "maps checked ${got_fixtures:-no} tests/maps/ fixtures; $((want_fixtures)) are on disk" >&2
    return 1
  fi
}

# The whole spec run, then its `--json` report read back: each named
# fixture spec ran exactly once and passed.
spec_fixture_check() {
  report=$GATE/spec-results.json
  rm -f "$report"
  server test "$PACK" --web "$PACK_WEB" --json "$report" || return $?
  node "$PACK/tools/map-fixture-coverage.mjs" "$report"
}

# ---------------------------------------------------- browser lanes

browser_skip() {
  node -e "import(require('node:url').pathToFileURL('$ENGINE/tools/ui-lab/cdp.mjs').href).then(async (m) => process.exit(await m.findChrome() ? 0 : 1))" \
    || { echo "no Chromium (set CHROME)"; return; }
}

# The live pair serves this pack's bake through the ENGINE's compiled
# client and shell, so both must exist (tools/dev/artifacts.mjs,
# checkArtifacts).
live_pair_skip() {
  [ -f "$ENGINE/web/pkg/lunatic_client_bg.wasm" ] \
    || { echo "no compiled client (sh $ENGINE/tools/build-web.sh)"; return; }
  [ -f "$ENGINE/web/dist/pack-ui/worker.js" ] \
    || { echo "no built web shell (npm --prefix $ENGINE/web run build)"; return; }
  browser_skip
}

# Without `--web`, `shot` reads the atlas out of the engine checkout's
# own served root (tools/ui-lab/routes.mjs, `bakeRoot`), which after the
# gate split holds the engine's demo bake -- this pack's fixtures would
# be drawn against another pack's art. An engine that cannot be pointed
# at this pack's bake does not draw it at all.
ui_lab_takes_web() {
  node "$ENGINE/tools/ui-lab.mjs" --help 2>/dev/null | grep -q -- '--web'
}
UI_SHOTS_RUNNER=host
# The lab's own words, either straight or through the pinned image. The
# wrapper reads `--pack` and `--web` out of these and mounts both at
# their canonical paths, rewriting the command to match -- which it does
# only for the `shot ...` form, not for `--run`.
ui_shots_run() {
  if [ "$UI_SHOTS_RUNNER" = reference ]; then
    node tools/ui-lab/reference.mjs "$@"
  else
    node tools/ui-lab.mjs "$@"
  fi
}
# The lab draws through the engine's compiled shell and worker whichever
# runner shoots, and the pinned image carries its own browser -- so a
# host Chromium is wanted only where the host is the runner.
ui_shots_skip() {
  [ -f "$ENGINE/web/dist/pack-ui/worker.js" ] \
    || { echo "no built worker (npm --prefix $ENGINE/web run build)"; return; }
  [ "$UI_SHOTS_RUNNER" = host ] || return 0
  browser_skip
}
ui_shots_shoot() (
  # A subshell: the wrapper and the lab both address the engine's own
  # files relatively, and this gate's cwd stays the pack.
  cd "$ENGINE" || exit 1
  ui_shots_run shot all --check --lint \
    --pack "$PACK" --web "$PACK_WEB" > "$GATE/ui-shots.out" 2>&1
  rc=$?
  if node tools/staff-ui-status.mjs; then
    ui_shots_run shot all --check --lint \
      --pack "$PACK" --web "$PACK_WEB" --audience staff >> "$GATE/ui-shots.out" 2>&1 || rc=1
  else
    status=$?
    case "$status" in
      3) echo "SKIP ui-shots: this pack declares no optional staff UI" >> "$GATE/ui-shots.out" ;;
      *) rc=$status ;;
    esac
  fi
  exit $rc
)
ui_shots_check() {
  ui_shots_shoot
  rc=$?
  cat "$GATE/ui-shots.out"
  sed -n 's/^SKIP ui-shots: /pack UI shots (/p' "$GATE/ui-shots.out" | sed 's/$/)/' >> "$SKIPPED"
  return $rc
}

# Trusted pointer input and a held shove, in the real client against
# THIS pack's bake. Artifacts land under this repository's target/, so a
# concurrent engine gate's runs are never overwritten.
world_pointer_check() {
  env WORLD_POINTER_OUTPUT="$GATE/world-pointer-live" \
    node "$ENGINE/tools/world-pointer-live.mjs" \
    "$PACK/tests/fixtures/world-pointer.json" --web "$PACK_WEB"
}
push_motion_check() {
  env PUSH_MOTION_OUTPUT="$GATE/push-motion-live" \
    node "$ENGINE/tools/ui-lab/push-motion-live.mjs" \
    "$PACK/tests/fixtures/push-motion.json" --web "$PACK_WEB"
}

# ------------------------------------------------------------- the run

gate_start=$(now_ms)

lane_luau
lane_lints

run build build_check || BUILD="build failed"

# The bake this run's content lanes read. A filtered run that did not
# select `bake` may legitimately reuse the last one -- that is the fast
# path while iterating on one lane -- but it says so and dates it, so a
# green line is never mistaken for art this run produced. With no bake
# at all, every lane that reads one BLOCKS by name.
BAKE=$BUILD
# Every lane that reads the bake, so the reuse note is told to a run
# that cares and withheld from one that does not.
wants_the_bake() {
  for reader in content maps lint-assets roster placeable pack-node specs \
    ui-shots world-pointer push-motion; do
    want "$reader" && return 0
  done
  return 1
}
if want bake; then
  if [ -n "$BUILD" ]; then
    blocked bake "$BUILD"
  elif run bake bake_check; then
    BAKE=
    BAKE_FRESH=1
  else
    BAKE="bake failed"
  fi
fi
if [ -z "$BAKE" ]; then
  if [ ! -f "$BAKED_ATLAS" ]; then
    BAKE="nothing baked in $PACK_WEB (sh tools/check.sh bake)"
  else
    if [ -z "$BAKE_FRESH" ] && wants_the_bake; then
      note bake "reusing the bake of $(date -r "$BAKED_ATLAS" '+%Y-%m-%d %H:%M' \
        2>/dev/null || echo 'an earlier run')"
    fi
    export LUNATIC_PACK_WEB=$PACK_WEB
  fi
fi

# Content, then every map, then the sprite names, all read back out of
# this pack's own bake.
gated "$BAKE" content server test "$PACK" --load-only --web "$PACK_WEB"
gated "$BAKE" maps map_fixture_check
gated "$BAKE" lint-assets server lint-assets "$PACK" --web "$PACK_WEB"

# The roster document is promised to its readers only once THIS run has
# written it: a reader handed the path must never be handed a file an
# earlier run left behind.
if want roster; then
  if [ -n "$BAKE" ]; then
    blocked roster "$BAKE"
  elif run roster roster_check; then
    export LUNATIC_ROSTER=$ROSTER
  else
    ROSTER_FAILED="roster failed"
  fi
fi

if want placeable; then
  if ! command -v cargo-nextest > /dev/null 2>&1; then
    skip placeable "cargo install cargo-nextest --locked" \
      "editor palette rules (no cargo-nextest)"
  elif [ ! -f "$ROSTER" ]; then
    blocked placeable \
      "${ROSTER_FAILED:-${BAKE:-no roster in this run (sh tools/check.sh roster placeable)}}"
  else
    run placeable placeable_check
  fi
fi

# The interface, compiled after the bake it reads and before anything
# reads IT: tools/test-ui-*.mjs hard-fail on an unbuilt ui/bundle.json.
gated "$BAKE" pack-ui-build pack_ui_build_check \
  || UI_BUILT="pack-ui-build failed"
# Whatever stopped the bake stopped this too, so one reason carries
# both to every lane downstream.
UI_BUILT=${UI_BUILT:-$BAKE}

# Every node check this pack owns, against that engine's SDK: the theme
# and message lints, the UI runtime tests, the baked-art lints and the
# checks over the served roster document. The last two read what the
# `bake` and `roster` lanes produced, through LUNATIC_PACK_WEB and
# LUNATIC_ROSTER -- each exported only where this run produced it, so a
# check this run cannot supply takes its own fallback rather than
# reading an earlier run's leavings.
gated "$UI_BUILT" pack-node node "$PACK/tools/test.mjs" "$ENGINE"

gated "$BAKE" specs spec_fixture_check

if want ui-shots; then
  if [ -n "$UI_BUILT" ]; then
    blocked ui-shots "$UI_BUILT"
  elif ! ui_lab_takes_web; then
    skip ui-shots "ui-lab has no --web: it reads the engine's own bake" \
      "pack UI shots (ui-lab reads the engine checkout's bake; it needs --web <root>)"
  elif ! UI_SHOTS_RUNNER=$(cd "$ENGINE" && node tools/ui-lab/reference.mjs --runner 2>&1); then
    skip ui-shots "no ui-lab runner: $UI_SHOTS_RUNNER" \
      "pack UI shots (no ui-lab runner)"
  else
    reason=$(ui_shots_skip)
    if [ -n "$reason" ]; then
      skip ui-shots "$reason" "pack UI shots ($reason)"
    else
      run ui-shots ui_shots_check
    fi
  fi
fi

# Serial, and after the builders: several headless Chrome/SwiftShader
# instances at once flaked a pixel-diff baseline on the engine's gate.
for lane in world-pointer push-motion; do
  want "$lane" || continue
  case "$lane" in
    world-pointer) fixture=$PACK/tests/fixtures/world-pointer.json ;;
    push-motion) fixture=$PACK/tests/fixtures/push-motion.json ;;
  esac
  if [ ! -f "$fixture" ]; then
    # This pack SHIPS both fixtures; their absence is a deleted check,
    # not a pack that declares none.
    printf 'FAIL  %-22s %8s\n' "$lane" -
    echo "$fixture is missing: this pack ships it" > "$LOGS/$lane.log"
    printf '%s\n' "$lane" >> "$FAILED"
    continue
  fi
  if [ -n "$UI_BUILT" ]; then
    blocked "$lane" "$UI_BUILT"
    continue
  fi
  reason=$(live_pair_skip)
  if [ -n "$reason" ]; then
    skip "$lane" "$reason" "$lane browser check ($reason)"
  else
    case "$lane" in
      world-pointer) run world-pointer world_pointer_check ;;
      push-motion) run push-motion push_motion_check ;;
    esac
  fi
done

total=$(took "$(( $(now_ms) - gate_start ))")

if [ -s "$FAILED" ]; then
  if [ "$VERBOSE" != 1 ]; then
    while IFS= read -r g; do
      printf '\n===== %s =====\n' "$g"
      [ -f "$LOGS/$g.log" ] && cat "$LOGS/$g.log"
    done < "$FAILED"
  fi
  printf '\nGATE FAILED in %s: %s\n' "$total" "$(tr '\n' ' ' < "$FAILED")" >&2
  if [ -s "$BLOCKED" ]; then
    printf 'BLOCKED, SO UNVERIFIED: %s\n' "$(tr '\n' ' ' < "$BLOCKED")" >&2
  fi
  if [ -s "$SKIPPED" ]; then
    printf 'SKIPPED, SO UNVERIFIED: %s\n' \
      "$(tr '\n' ';' < "$SKIPPED" | sed 's/;$//; s/;/, /g')" >&2
  fi
  exit 1
fi

printf 'total %-22s %8s\n' '' "$total"
# A blocked lane is unverified whichever way the run ended, so it is
# reported beside a green banner exactly as it is beside a red one.
if [ -s "$BLOCKED" ]; then
  printf 'BLOCKED, SO UNVERIFIED: %s\n' "$(tr '\n' ' ' < "$BLOCKED")" >&2
fi
# Nothing executed: every selected lane was blocked or skipped, or the
# words named no lane at all. Either way this run is evidence of
# nothing, and it says so rather than printing a banner over it.
if [ ! -s "$RAN" ]; then
  printf 'NOTHING RAN%s\n' "${ONLY:+: $ONLY matched no lane that could run}" >&2
  if [ -s "$SKIPPED" ]; then
    printf 'SKIPPED, SO UNVERIFIED: %s\n' \
      "$(tr '\n' ';' < "$SKIPPED" | sed 's/;$//; s/;/, /g')" >&2
  fi
  exit 1
fi
if [ -n "$ONLY" ]; then
  echo "SELECTED PACK GATES GREEN: $(tr '\n' ' ' < "$RAN")"
else
  echo "ALL PACK GATES GREEN"
fi
if [ -s "$SKIPPED" ]; then
  echo "SKIPPED, SO UNVERIFIED: $(tr '\n' ';' < "$SKIPPED" | sed 's/;$//; s/;/, /g')"
fi
