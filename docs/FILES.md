# Computer file readers

`ui/files-reader.ts` owns the pack's preview grammar. Files remain available
through the text editor; previews do not execute programs or confer authority.

Markdown (`.md`) previews headings, quoted lines, lists and fenced code as
text nodes. Lists retain their authored markers. Inline Markdown, links,
images and raw HTML remain inert text. No preview loads a URL. Previews use
at most 96 nodes, 4096 UTF-16 units per node and 65536 source units; a notice
identifies truncation. Full contents remain in the editor.

Atmosphere records (`.atmo`) are JSON objects with these fields:

| Field | Contract |
| --- | --- |
| `version` | Required integer `1` |
| `title` | Optional string, at most 160 UTF-16 units |
| `temperature_k` | Required finite, nonnegative number in kelvin |
| `pressure_kpa` | Required finite, nonnegative number in kilopascals |
| `gases` | Required array of at most 32 gas records |

A gas record contains exactly `id` (nonblank string, at most 80 UTF-16 units)
and `moles` (finite, nonnegative number). Gas IDs must be unique. Unknown
fields, unsupported versions, missing required fields, empty documents,
oversized documents and invalid JSON select the ordinary text editor.
Records report only their authored values, never live atmosphere telemetry.

Access material (`.pem`) previews ordinary text with an access-material label.
Creating, copying or editing it creates no credentials or authentication rights.
Source (`.disl`) uses the trusted Luau editor and native diagnostics.

Reader and buffer regression checks use the engine checkout's installed esbuild:

```sh
LUNATIC_ENGINE=/absolute/path/to/lunatic node tools/test-file-readers.mjs
LUNATIC_ENGINE=/absolute/path/to/lunatic node tools/test-file-buffers.mjs
```

Both commands also accept the engine path as their first argument. Set an
absolute engine path when running from a pack worktree.
