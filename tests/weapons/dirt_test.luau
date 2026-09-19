local composition = require("@helpers/composition")
local ui_controls = require("@helpers/ui_controls")

-- What a blast leaves on the deck: a quarter mole of ash as ordinary
-- solid matter, and a blast's worth of dust as engine residue. The ash
-- half is asserted here -- minted on the blast tile, resting solid,
-- and not something a mop lifts. The dust half rides the volley
-- residue verbs (`sim.volley_residue_deposit` on the blast,
-- `sim.volley_residue_clear` in every mop stroke); its rows land with
-- the engine wiring, and its tiers are pinned by
-- tools/test-residue-tiers.mjs until a spec can see them.
t.world(
    [==[(
    name: "blast floor",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#######",
        "#.....#",
        "#.....#",
        "#.....#",
        "#######",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "frag_grenade"), (1, 1, "mop")],
)]==],
    0
)

local p = t.join()
t.tick()

local function ash_total(): number
    return t.matter_totals().substances.ash or 0
end

local function said(): string
    local lines = t.messages(p)
    return lines[#lines] or ""
end

assert(ash_total() == 0, "the deck starts clean")

t.click(p, 1, 1, t.target_at(p, 1, 1, "frag_grenade"))
t.tick()
t.use_self(p)
t.tick()
t.drop(p)
t.tick()

-- Clear of the blast while the fuse burns: three tiles east.
t.move(p, "east")
t.run_ticks(6)
t.move(p, "east")
t.run_ticks(6)
t.move(p, "east")
t.run_ticks(6)
local px, py = t.pos(p)
assert(px == 4 and py == 1, "the armer stands clear")

t.run_seconds(6)
assert(#t.ledger_rows("item_destroyed") == 1, "the grenade went off")

-- ---------------------------------------------------------------
-- ASH: minted on the blast tile as solid matter.
-- ---------------------------------------------------------------
assert(
    math.abs(ash_total() - 0.25) < 1e-9,
    ("a quarter mole of ash rests on the deck, got %g"):format(ash_total())
)
local minted = t.ledger_rows("minted")
assert(#minted == 1, ("one mint on the record, got %d"):format(#minted))
assert(minted[1].substance == "ash", "naming ash")
assert(
    math.abs(ui_controls.number(minted[1].moles) - 0.25) < 1e-9,
    "naming the whole quarter mole"
)
assert(minted[1].actor.kind == "script", "attributed to the file that asked")
local liquids = assert(t.room_liquid(1, 1), "the blast tile breathes")
assert((liquids.ash or 0) == 0, "ash rests solid, not liquid")

-- ---------------------------------------------------------------
-- MOP: a stroke on the ashy tile finds no liquid to lift. Ash is a
-- solid and the head takes liquids, so the deck reads dry and the ash
-- stays where it lay; dust is what a stroke sweeps, and it sweeps it
-- silently beside whatever the head answers for.
-- ---------------------------------------------------------------
t.move(p, "west")
t.run_ticks(6)
t.move(p, "west")
t.run_ticks(6)
px, py = t.pos(p)
assert(px == 2 and py == 1, "back beside the blast")
t.click(p, 1, 1, t.target_at(p, 1, 1, "mop"))
t.tick()
assert(t.hands(p).held == "mop", "the mop survived the blast")

composition.click_deck(p, 1, 1)
t.tick()
assert(said() == "The deck here is dry.", "no liquid to lift: " .. said())
assert(
    math.abs(ash_total() - 0.25) < 1e-9,
    "and the ash stays where it lay"
)

-- ---------------------------------------------------------------
-- DUST: the burst whose fragments it is. One discharge, one settle;
-- the deposit the blast issued and the sweep the stroke issued ride
-- the residue verbs beside them.
-- ---------------------------------------------------------------
assert(#t.ledger_rows("volley_discharged") == 1, "one blast, one volley")
assert(#t.ledger_rows("volley_settled") == 1, "settled by the tick")
