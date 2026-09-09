# Reference files and preset disks

`reference/manifest.ron` maps stable IDs to packaged text files. An entry
owns the in-game stem and extension separately from its source path:

```ron
[
    (id: "airlock_controller", name: "airlock", ext: "disl",
        path: "scripts/airlock.luau"),
    (id: "airlock_instructions", name: "readme", ext: "md",
        path: "text/airlock.md"),
]
```

Paths are relative to `reference/`. They must stay inside that directory.
Every extension comes from `content/filetypes.luau`; text and source files
use the same mechanism. References are loaded as data, never as trusted
content modules.

An item, structure or machine can preload these files into its store:

```luau
files = {
    capacity = 737280,
    files = 112,
    seed = {
        { reference = "airlock_controller" },
        { reference = "airlock_instructions" },
    },
}
```

The reference supplies the name, extension and exact body. Do not combine
`reference` with inline `name`, `ext` or `body` fields. Store capacities,
duplicate names and registered filetypes are checked during loading.
Original seeds are fixed; copying one creates an ordinary editable file.
Use [laptop contact](../LAPTOP.md#contact-programming) to install a program
from a preset disk onto a host's store and load its socket.

## Editing DiSL

Edit `reference/scripts/airlock.luau` directly in a Lua/Luau IDE. It is the
guest source itself, with no enclosing string, escaping or generated copy.
The catalog gives it the in-game `.disl` extension. Saving a player copy
changes that copy; it does not rewrite the packaged reference.

`reference/scripts/.luaurc` declares `event`, `devices` and `mem` for Luau
analysis using [Luau's configuration format](https://rfcs.luau.org/config-luaurc).
It does not create runtime bindings. The host supplies those values as
documented in [controllers.md](controllers.md), and the guest returns its
result at the top level. Other guest hosts should declare their own analysis
globals in their source directory.
