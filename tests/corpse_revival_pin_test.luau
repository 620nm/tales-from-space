-- PINNED AS BUILT, PENDING A DESIGN RULING. Read this before changing
-- anything it touches.
--
-- A corpse can be tended back to life with a hemostat. No revival
-- operation exists in this pack; this is a side effect of three
-- decisions that are each defensible alone:
--
--   1. Surgery reaches the dead. tg's `check_availability` never reads
--      the patient's `stat` (code/modules/surgery/operations/
--      _operation.dm:470-495), so the engine gates corpse work per
--      operation (`dead_only`) and not globally.
--   2. Heals land on terminal bodies. `sim/body/damage.rs` applies the
--      `heal` block whatever state the patient is in, by design -- an
--      engine that refused would be deciding what death means, which
--      is the pack's call.
--   3. This pack's death is a RECOMPUTED threshold, not a latched
--      state. `content/bodies/human.luau`'s `body.threshold.done` hook
--      settles `animate` from the SET of lines the body is currently
--      past, so clearing the `dead` line clears the fact.
--
-- tg cannot do this, and stops it in two independent places: `stat`
-- latches to DEAD and is only cleared by a defib or a revival surgery,
-- and healing surgery scales to a fifth on a corpse
-- (`dead_multiplier`, operation_healing.dm:190). Tales from Space has
-- ported NEITHER. Both divergences are written down in
-- docs/SURGERY.md §6.7 and in content/operations/tend_wounds.luau.
--
-- Whether that is the game's revival mechanism or a hole to close is
-- Josh's ruling, not this spec's. What this spec does is make the
-- behaviour CHOSEN rather than accidental: it fails the moment the
-- answer changes, in either direction, so nobody discovers the ruling
-- by finding a cadaver on its feet.

local ARENA = [==[(
    name: "morgue",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######",
        "#.....#",
        "#.....#",
        "#Gao..#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [(4, 1, "hemostat")],
    structures: [(5, 2, "cadaver_chamber.cadaver", { "dir": "north" })],
    cables: [(1, 3, 2), (2, 3, 3), (3, 3, 1)],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
t.run_ticks(3)

for _ = 1, 3 do
    t.move(surgeon, "east")
    t.run_ticks(8)
end
assert(t.pos(surgeon) == 4, "beside the drawer: " .. t.pos(surgeon))

-- ---- the corpse, as the map delivered it -----------------------------
local chamber = t.target_at(5, 2, "cadaver_chamber.cadaver")
t.click(surgeon, 5, 2, chamber)
t.run_ticks(2)

local function corpse()
    return t.bodies_at(5, 1)[1]
end
local body = corpse()
assert(body ~= nil, "one body rolled out on the slab")
local cid = body.id
assert(body.label == "Dead", "the pack calls it dead")
assert(body.animate == false, "and its own processes have stopped")
assert(body.parts.chest.brute == 200, "200 brute, all of it on the chest")
local before = body.health

-- ---- one application of first aid ------------------------------------
-- `tend_wounds` is `ignore_clothes` and wants INTACT skin
-- (content/operations/tend_wounds.luau), so the jumpsuit stays on and
-- nothing has to be cut first: a hemostat to a clothed cadaver is the
-- whole gesture. It heals a flat 5 brute, which is all it takes to
-- clear a body sitting exactly ON the line.
t.click(surgeon, 4, 1, t.target_at(4, 1, "hemostat"))
t.run_ticks(2)
assert(t.hands(surgeon).held == "hemostat", "the hemostat is in hand")
assert(t.set_zone(surgeon, "chest"), "aiming at the chest")

t.click(surgeon, 5, 1, cid)
-- Waited on the LEDGER rather than on a tick count: the operation's
-- own 2.5 s is multiplied by the patient's state as well as the tool's
-- speed (docs/SURGERY.md §6.3 step 3), and this spec is about what the
-- heal does, not about how long it takes.
local waited = 0
while #t.ledger_rows("Healed") == 0 and waited < 400 do
    t.tick()
    waited = waited + 1
end
assert(#t.ledger_rows("Healed") == 1, "the tend landed, and is on the record")

-- ---- ...and the cadaver is not a cadaver any more ---------------------
body = corpse()
assert(body ~= nil, "still on the slab")
assert(body.parts.chest.brute == 195, "five brute came off: " .. body.parts.chest.brute)
assert(body.health > before,
    "which put it back over the `dead` line at health <= -1 of max_health: " ..
    before .. " -> " .. body.health)
assert(body.animate == true,
    "PINNED: a tended corpse animates again. tg cannot do this (latched " ..
    "DEAD + the 0.2 dead multiplier); TfS has ported neither, and the " ..
    "threshold is recomputed. If this assertion fails, the design ruling " ..
    "has landed -- update this file rather than restoring the behaviour.")
assert(body.label == "Critical",
    "PINNED: it comes back in crit, not on its feet -- the `crit` line at " ..
    "health <= 0 is still crossed and `controllable` is still false: " ..
    tostring(body.label))

print("corpse revival: PINNED as built -- a hemostat clears the dead line")
