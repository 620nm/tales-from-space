# Bucket

`content/items/vessels/bucket.luau`, a plain `content/lib/vessel.luau` vessel.
Decisions read as in `docs/janitorial/mop.md`. No row needs an engine change.
tg path: `_cup.dm` is
`code/modules/reagents/reagent_containers/cups/_cup.dm`.

| tg | Behaviour | Decision |
| --- | --- | --- |
| `_cup.dm:586-594` | Name, description, sprites, in-hands | api: same words and art |
| `_cup.dm:595` | Fill pictures at 50 and 90 percent | api: `fill_sprites` |
| `_cup.dm:596` | Iron cost | omitted: items have no material cost here |
| `_cup.dm:597` | Normal weight class | api: default size |
| `_cup.dm:598` | Pours 20 u | adapted: a third of a litre, 740 vessel units |
| `_cup.dm:599` | Selectable transfer amounts | omitted: one vessel pour size here |
| `_cup.dm:600` | Holds 70 u | adapted: 1167 mL, tg's ratio to the mop head |
| `_cup.dm:176-195` | Refill, drain, drink by click | api: `vessel` pour and sip |
| `_cup.dm:197` | Pour concrete | omitted: no concrete |
| `reagent_containers.dm:144,223-226,239` | Splash and spill on a throw | api: `spill = true`, the vessel's throw landing |
| `_cup.dm:601-602,654-661` | Worn as a hat, contents spill over you | omitted: `content/part_tree.luau` has no head slot; adding one is a design call |
| `_cup.dm:604,619-622` | Armor as a hat | omitted: as the hat |
| `_cup.dm:605-613,667-674` | Quick-equip avoids a full head slot | omitted: as the hat |
| `_cup.dm:617` | Cuffable | omitted: no restraint target for items |
| `_cup.dm:624-634` | Wooden bucket | omitted: not requested |
| `_cup.dm:636-644` | Douses a mop | adapted: mop wrings into the bucket (`mop.md`) |
| `_cup.dm:645-650` | Cleanbot assembly with a prox sensor | omitted: no cleanbot |
| `cargo/packs/service.dm:30-50` | Bought by cargo | adapted: the tool vendor stocks three |
