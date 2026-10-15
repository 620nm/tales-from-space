// The roster document the engine serves for this pack (`lunatic-server
// roster <pack>`), shared by the node tests that read pack facts off it.
//
// It arrives one of two ways: the gate bakes it once and names it in
// LUNATIC_ROSTER, else this runs the engine itself. Neither available is
// `{ missing }`, which a caller reports as a SKIP by name -- never a silent
// pass. Only stdout is the document; `roster` writes its "no atlas baked"
// NOTE to stderr.
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const pack = resolve(fileURLToPath(new URL("..", import.meta.url)));
const engine = resolve(process.argv[2] ?? process.env.LUNATIC_ENGINE ?? join(pack, "..", "lunatic"));

// The gate's own copy, written before any lane ran. Unreadable or
// unparseable is a failure, not a skip: the gate promised this file.
function rosterFromGate() {
  const path = process.env.LUNATIC_ROSTER;
  if (!path) return null;
  return { source: `LUNATIC_ROSTER=${path}`, text: readFileSync(path, "utf8") };
}

// The fallback, for a bare `node tools/test.mjs <engine>`: one roster
// run against this pack. `--web` only where the gate named the root its
// bake wrote to, so this never adopts the engine checkout's own atlas.
function rosterFromEngine() {
  const manifest = join(engine, "Cargo.toml");
  if (!existsSync(manifest)) return { missing: `no LUNATIC_ROSTER, and no engine checkout at ${engine}` };
  const web = process.env.LUNATIC_PACK_WEB;
  const args = ["run", "-q", "--manifest-path", manifest, "-p", "lunatic-server", "--", "roster", pack];
  if (web) args.push("--web", web);
  const run = spawnSync("cargo", args, { cwd: engine, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  if (run.error?.code === "ENOENT") return { missing: "no LUNATIC_ROSTER, and cargo is not on PATH" };
  if (run.error) throw run.error;
  if (run.status !== 0) {
    throw new Error(`cargo run -p lunatic-server -- roster ${pack} exited ${run.status}\n${run.stderr ?? ""}`);
  }
  return { source: `cargo run -p lunatic-server -- roster ${pack}`, text: run.stdout };
}

/** `{ roster, source }` once parsed, or `{ missing }`; throws when the document is unreadable. */
export function servedRoster() {
  const got = rosterFromGate() ?? rosterFromEngine();
  if (got.missing) return { missing: got.missing };
  return { roster: JSON.parse(got.text), source: got.source };
}
