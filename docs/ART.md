# Art direction

First-party art (drawn for this pack under `assets/originals/art/`) and
every recolour of a baked tg sprite follow this file. The station is
drawn in tgstation's idiom at the revision `assets/tg-revision` pins;
where this file diverges, chiefly in colour identity, it wins. Its
citations and measurements are tg commits and `icons/` paths at
7cb126ac886. The palettes are in
[art-reference/palettes](art-reference/palettes/); references, the file
icon recipe and provenance are in [art-reference](art-reference/README.md).

## tg's current direction

tg keeps the classic 32×32 top-down view with front faces. The Wallening's
3/4 tall walls (4b4e9dff1d7) were reverted twenty days later (9a9b428b61f).
What came back from it is platforms, as frames without windows
(7146a6bb105), signs (b3d0dfa40a0), TVs (c779d0fabd3) and weather planes
(22d319fa860). Its resprites since 2023 share four habits:

- Readability before detail: fewer shades and less noise (68032b2587c,
  "reduce shades and increase visual readability"; ab90ddbf821), and crude
  old art redrawn (53eb764e88d, e3933ba938a).
- One family, one treatment: outlines match within a family (7f24072526b),
  wallmounts drop the hard outline (0d684300114), and a family shares one
  palette (77a90bd99e6 circuit shells, 88fb9423904 one command blue,
  9d045f7cb69 medbots matching medkits).
- Greyscale art coloured by configuration (GAGS), clothing above all
  (2427db409ef, 38dc2369ef1), with job colours as defines meant to keep
  every job recognisable at a glance (229910f33dd,
  `code/__DEFINES/preferences.dm:185-201`).
- Metal holds its hue and gains saturation as value drops (`lathes.dmi`:
  hue 228–232°, saturation 5% to 42%). Cloth hue-shifts, shadows toward
  violet and highlights toward yellow (`rsecurity` 330° to 3°, `centcom`
  150° to 120°); a reversed shift is a bug (ab90ddbf821).

Its department colours are settled: `COLOR_*` since 86ef806f1ae (2022)
and `CIRCUIT_COLOR_*` since b7cb5cea163 (2021).

## Form

Sprites are 32×32 RGBA on the tile grid. Solid sprites take binary alpha
with no anti-aliasing and no dithering; glass, glows and effects may use
partial alpha, as tg's windows and airlock lights do. Block the
silhouette first; a sprite must read in greyscale before it gets colour.
Light falls from the top of the screen: top faces take the highlight and
south faces sit darker, with no left/right bias. Across 1,363
south-facing tg machine, storage and structure sprites the top third
averages luma 103, the bottom third 81, and the left and right thirds 91
and 90.

A primary or material ramp's step 1 is its outline. Secondaries, glass
and signals sit inside another ramp's outline; wallmounts take no hard
outline, signals and screens none at all. A department primary has five
steps and its secondary three; gold has five because medals and insignia
also stand alone; structural metal has up to eight. Review every sprite
at 1× on light and dark backgrounds before accepting it.

## Palettes

| File | Holds | Use for |
| --- | --- | --- |
| `station.gpl` | structure, machine and neutral steel; glass, black, whites and paper; wood; safety paint; signals | every regular station object |
| `departments.gpl` | leadership gold; Command; CentCom; the departments and Service's trades | crew character designs, signage, department-tinted machines |
| `enemies.gpl` | void blacks; blood crimson | antagonist character designs |

Every ramp runs dark to light, and each section names its tg source or
says TfS. Sprites are RGB, so loading another palette in Aseprite never
remaps pixels: draw structure from `station.gpl`, then load the
department or enemy palette for identity paint. The file icons keep
their own fixed colours ([art-reference](art-reference/README.md)).

## Departments

The pack declares no department roster; these are identities for art.
They follow tg's departments with one regrouping: tg runs Cargo as its
own department under the Quartermaster
(`code/modules/jobs/departments/departments.dm:166`), and this pack
counts it as a Service trade. A department is a primary and a secondary.
The primary carries identity: the uniform body, a sign field, a stripe,
a department machine's tint (tg's `CIRCUIT_COLOR_*` role). The secondary
is trim: collars, cuffs, piping, lettering.

| Department | Primary | Secondary | Its head wears |
| --- | --- | --- | --- |
| Command | command blue | gold | Captain: command blue + gold |
| Security | navy | ice white | Head of Security: navy + gold |
| Medical | medical blue | sterile white | Chief Medical Officer: medical blue + gold |
| Science | research violet | orchid | Research Director: violet + gold |
| Engineering | hi-vis yellow | safety orange | Chief Engineer: yellow + gold |
| Service | leaf green | linen | Head of Personnel: green + gold |
| Cargo (Service) | russet | khaki | Quartermaster: russet + gold |
| CentCom (roleplay) | military green | gold | all CentCom staff |

Service is the most varied department. A trade keeps its department's
primary and swaps the secondary: Botany is leaf green with apron blue,
and Atmospherics, an Engineering trade, is hi-vis yellow with atmos teal.
Cargo is the one trade with its own primary. The clown is a motley of
pink and coral that borrows engineering yellow. A new Service trade
(bar, kitchen, janitorial, chapel) adds one three-step secondary under
Service.

Leadership swaps its secondary for gold. Gold is trim, insignia and rank
marks, never a field, and it stays 20 ΔE2000 from the field's steps 2–4.
On engineering yellow that leaves gold 1, so gold marks there are drawn
in it or outlined with it; on cargo russet use gold 4–5; on every other
primary any step clears. Each department's secondary stays at least 12
ΔE2000 from gold 2–4, so a head never reads as crew. Gold as identity
paint belongs to leadership alone, and no other department colour is
amber (hue 30–45° at 50% saturation or more). Gold as a material (coins,
bars, gold walls and airlocks) keeps tg's material colours.

The Captain, Head of Security and Chief Medical Officer all wear blue
with gold and part by value: navy is dark, command blue mid, medical
blue light (their mid tones lie 16–39 ΔE2000 apart). The Head of
Personnel's leaf green and CentCom's forest green part by hue (21
ΔE2000).

## What antagonists reserve

Black is everyday station paint: outlines, screens, hazard stripes,
machine housings. The reservation covers character designs, meaning
what a character is or wears: mobs, uniforms, suits, armour.

- Black: an antagonist may be built on black, from `enemies.gpl`'s void
  ramp. A crew design keeps black to outlines and small accents (boots,
  gloves, belts) taken from `station.gpl`, never its main field;
  `departments.gpl` holds no colour whose brightest channel is below
  `0x20`.
- Black with red: the antagonist signature. The syndicate MOD lays
  crimson over near-black. No crew design pairs a black field with red.
- The brightest reds: hue 345–10°, saturation 70% or more, value 76% or
  more. Crew paint stays out of that band and at least 10 ΔE2000 from
  every reserved red in `enemies.gpl`; the clown's red is coral.

Objects keep every black and red: tg's own extinguisher cabinets
(`obj/wallmounts.dmi`) supply `station.gpl`'s fire red. Antagonists may
use any other colour too, and identities beyond black and red
(`COLOR_HERETIC_GREEN`, `COLOR_VOID_PURPLE`, `BLOOD_COLOR_XENO`) keep
tg's values. The rule removes tg's crew/antagonist overlaps: its
security MOD shares four reds (`#3f010d`, `#5b0010`, `#820a16`,
`#b22c20`) and the near-black `#0d0c19` with the syndicate MOD, its
roboticist wears black with dark red (`rnd.dmi` `robotics`), and
`COLOR_SECURITY_RED` `#cb0000` sits inside the band.

## Where TfS diverges from tg

| tg at the pinned revision | Tales from Space |
| --- | --- |
| Security red: `COLOR_SECURITY_RED` `#cb0000`, `rsecurity` | navy + ice white, after tg's blue formal sets (`officerblueclothes`, `blueshift`) |
| Captain in navy-violet `#3d4379`, matched by the HoP (88fb9423904) | Captain in command blue at `COLOR_COMMAND_BLUE` `#1b67a5`; HoP in leaf green + gold; navy is Security's |
| Gold on command radio `#fcdf03`, captain trim, magnate MOD | gold identity paint is leadership's alone |
| CentCom green uniforms, blue ID trim (`COLOR_CENTCOM_BLUE`) | military green + gold throughout |
| Engineering amber `#ffa62b`, ochre airlock `#a28226` | hi-vis yellow + safety orange |
| Cargo khaki `#b7793d`, beside gold | khaki drab, clear of gold |
| Roboticist in black with dark red | no crew design pairs black with red |
| Clown in pure `#ff0000` | coral |

Baked tg sprites keep tg's pixels until someone redraws or recolours
them. The shipped security uniform is still red-trimmed: `uniform_sec`
reads `rsecurity` and `worn_uniform_sec_*` reads the grey `security`
state (`assets/sprites/10-turf-fixtures-and-tools.ron`). Its navy
replacement starts from tg's `officerblueclothes`.

## Workflow

First-party sources follow the engine's originals contract (the
engine's `docs/assets/importers.md`): a PNG is one 32×32 still, and an
Aseprite document names its states with tags or its parts with layers.
`assets/sprites/95-originals.ron` registers them, and a note beside a
source says what it shows (`utility_outlet_port.md`). Sheets that
`convert-dmi` writes under `assets/originals/` hold tg's pixels and are
never hand-edited; a TfS look for one is a new drawing or a `Tinted`
recipe. Bake from the engine checkout (`README.md` §Running). A palette
change edits this file in the same commit when it moves a rule, a
reserved range or a department colour.
