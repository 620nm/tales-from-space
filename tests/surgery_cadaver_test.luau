-- Surgery on a body the map arrived holding.
--
-- Every other surgery spec operates on a joined player, who is alive.
-- The thing a surgeon actually meets on a shift is a cadaver out of the
-- morgue: minted by `sim/stock.rs::stand_up_stock_body`, hurt past the
-- plan's own dead line, nobody at the wheel of it. This spec runs the
-- whole loop on one -- pull the drawer, lay it on the table, take the
-- jumpsuit off, cut -- because that loop is what tg's autopsy and
-- revival surgeries are FOR, and tg puts no living requirement on any
-- operation at all (`code/modules/surgery/operations/_operation.dm`
-- declares no such flag; `operation_autopsy.dm` and
-- `operation_revival.dm` are corpse work by definition).
--
-- The console is the same question asked without a hand in it: what
-- this part admits NEXT (`sim/surgery/available.rs`). A corpse a
-- surgeon can cut is a corpse the console must be able to talk about.

local ARENA = [==[(
    name: "morgue theatre",
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
    items: [(4, 1, "scalpel"), (4, 1, "retractor")],
    structures: [
        (3, 2, "optable"),
        (5, 2, "cadaver_chamber.cadaver", { "dir": "north" }),
    ],
    machines: [(2, 2, "operating_computer")],
    cables: [(1, 3, 2), (2, 3, 3), (3, 3, 1)],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
t.run_ticks(3)

local function said(who, needle)
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end
-- The wearables panel is a row model of its own (docs/TGUI.md): one
-- `labels` row per declared equipment slot, named by the slot's LABEL.
local function slot_row(panel, label)
    for _, r in ipairs(panel.labels or {}) do
        if r.label == label then return r end
    end
    return nil
end

-- ...and the operating computer is the ordinary readout model.
local function row(panel, label)
    for _, r in ipairs(panel.readouts or {}) do
        if r.label == label then return r end
    end
    return nil
end

for _ = 1, 3 do
    t.move(surgeon, "east")
    t.run_ticks(8)
end
assert(t.pos(surgeon) == 4, "beside the drawer: " .. t.pos(surgeon))

-- ---- the drawer, and what is in it ------------------------------------
local chamber = t.target_at(5, 2, "cadaver_chamber.cadaver")
assert(chamber ~= nil, "the map stood the occupied variant there")
t.click(surgeon, 5, 2, chamber)
t.run_ticks(2)

local found = t.bodies_at(5, 1)
assert(#found == 1, "one body rolled out on the slab")
local corpse = found[1]
local cid = corpse.id
assert(corpse.player == false, "nobody is at the wheel of it")
assert(corpse.label == "Dead", "and the plan calls it dead")

-- `t.bodies_at` is the only door onto a body nobody is at the wheel of,
-- so every later reading of the cadaver comes back through it.
local function on_table()
    local here = t.bodies_at(3, 2)
    return here[1]
end

-- ---- onto the table ---------------------------------------------------
local optable = t.target_at(3, 2, "optable")
-- Laying a body out TAKES TIME now (`lay_body_secs`,
-- content/tuning.luau), so this waits the do_after out.
t.drag(surgeon, 5, 1, cid, 3, 2, optable)
t.run_ticks(2 * 20 + 2)
assert(on_table() ~= nil, "the cadaver is on the table")
assert(on_table().posture == "lying", "laid out on it")

-- ---- out of the jumpsuit ----------------------------------------------
-- The uniform covers the chest (content/items/uniform_grey.luau), which
-- is the `obstructed` refusal, and the cross-body strip is how it comes
-- off (tests/strip_test.luau).
t.drop(surgeon)
t.run_ticks(2)
t.drag(surgeon, 3, 2, cid, 4, 1, t.body_id(surgeon))
t.run_ticks(2)
local wardrobe = t.ui(surgeon)
assert(wardrobe ~= nil, "the drag opened its wearables")
local worn_row = slot_row(wardrobe, "Uniform")
assert(worn_row ~= nil and worn_row.field == "strip", "it is wearing the jumpsuit")
t.ui_act(surgeon, "toggle", '{"field":"strip","option":"uniform"}')
t.run_ticks(90)
assert(on_table().worn.uniform == nil, "the jumpsuit is off")

-- ---- what the console says BEFORE the first cut -----------------------
-- The other half of the same complaint: a surgeon at the console was
-- told nothing about how to begin. Two causes, and this spec holds both
-- down. The dead gate above was one; the other is that the panel drew a
-- part only once something was already holding it, so it had nothing to
-- say until after the incision it was supposed to be recommending. The
-- AIMED part is drawn now, which is the only part tg's own console ever
-- draws steps for (operating_computer.dm:222-227).
t.move(surgeon, "west")
t.run_ticks(8)
assert(t.pos(surgeon) == 3, "beside the console")
assert(t.set_zone(surgeon, "chest"), "aiming at the chest")
t.click(surgeon, 2, 2, t.target_at(2, 2))
t.run_ticks(2)

local console = t.ui(surgeon)
assert(console ~= nil, "the console opened a window")
local aimed = row(console, "chest")
assert(aimed ~= nil, "the part the next click lands on is on the panel")
assert(aimed.value == "\u{2014}", "with nothing holding it yet: " .. tostring(aimed.value))
local first = row(console, "make an incision")
assert(first ~= nil, "and the console says how to begin")
assert(first.value == "scalpel", "naming the tool: " .. tostring(first.value))
-- A part nothing is wrong with and nobody is aiming at is still not a
-- row: the panel is a readout, not a catalogue of everything possible.
assert(row(console, "left leg") == nil, "an unaimed, untouched part is not a row")

t.move(surgeon, "east")
t.run_ticks(8)
assert(t.pos(surgeon) == 4, "back beside the table")

-- ---- and the cut ------------------------------------------------------
t.click(surgeon, 4, 1, t.target_at(4, 1, "scalpel"))
t.run_ticks(2)
assert(t.hands(surgeon).held == "scalpel", "the scalpel is back in hand")
assert(t.set_zone(surgeon, "chest"), "aiming at the chest")

local parked = #t.ledger_rows("DoAfterStarted")
t.click(surgeon, 3, 2, cid)
t.run_ticks(2)
assert(not said(surgeon, "nothing to do"), "a bare, laid-out cadaver has work in it")
assert(#t.ledger_rows("DoAfterStarted") > parked, "the incision parked")
t.run_ticks(100)
assert(on_table().parts.chest.states.skin_cut == true, "and the chest is open")

print("cadaver surgery: pulled, laid out, stripped and opened")
