local composition = require("@helpers/composition")
local ui_controls = require("@helpers/ui_controls")

-- What a blast leaves on the deck: a quarter mole of ash as ordinary
-- solid matter, and a blast's worth of dust as engine residue. The ash
-- half is minted on the blast tile, rests solid, and is not something
-- a mop lifts. The dust half rides the volley residue verbs: the
-- settle handler lays one blast's worth down where the pellets landed
-- (`sim.volley_residue_deposit` per landing tile) and every mop stroke
-- sweeps its tile clean (`sim.volley_residue_clear`). Both halves are
-- asserted here -- the ash by matter and mint, the dust by ledger rows
-- and by sight -- with tools/test-residue-tiers.mjs pinning the file's
-- own numbers beside them.
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
-- DUST: the burst whose fragments it is. One discharge, one settle,
-- and one blast's worth of dust across the landing tiles. The order
-- is the detonation's: gone, ash, blast, volley, settle, and only
-- then the dirt the settle handler laid.
-- ---------------------------------------------------------------
local discharged = t.ledger_rows("volley_discharged")
local settled = t.ledger_rows("volley_settled")
assert(#discharged == 1, "one blast, one volley")
assert(#settled == 1, "settled by the tick")
assert(discharged[1].radius == 10, "thrown to ten tiles")
assert(discharged[1].fragments == 15, "fifteen pellets in the air")
assert(discharged[1].damage == 14, "at tg's shrapnel force")
assert(settled[1].fragments == 15, "fifteen pellets home")
assert(discharged[1].seq < settled[1].seq, "the pair brackets the flight")

local gone = t.ledger_rows("item_destroyed")
assert(#gone == 1, "one fuse, one detonation")
assert(gone[1].seq < minted[1].seq, "gone before the ash")
assert(minted[1].seq < discharged[1].seq, "ash before the volley")

local dirt = t.ledger_rows("residue_settled")
assert(#dirt >= 1 and #dirt <= 15, ("one row per landing tile, got %d"):format(#dirt))
local resting = 0
for _, row in ipairs(dirt) do
    assert(row.kind == 0, "every landing rests kind 0")
    assert(row.seq > settled[1].seq, "every landing rests after the settle")
    resting += ui_controls.number(row.fragments)
end
assert(resting == 15, ("what flies is what rests, got %d"):format(resting))

-- The blast tile keeps its share, and the deck shows it: tier one's
-- dust, drawn but never pickable, so a click lands on the turf.
local blast_share = 0
for _, row in ipairs(dirt) do
    local at = ui_controls.array(row.at)
    if at[1] == 1 and at[2] == 1 then
        blast_share = ui_controls.number(row.total)
    end
end
assert(blast_share > 0, "the blast tile keeps its share")
local function shows_dust(x: number, y: number): boolean
    for _, seen in ipairs(t.seen_composition(p, x, y)) do
        if seen.sprite == "dust" and not seen.pickable then
            return true
        end
    end
    return false
end
assert(shows_dust(1, 1), "the blast tile wears its dust")

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

-- The stroke's silent half: the blast tile's whole share lifts in one
-- row, and only that tile's -- a landing two tiles down keeps its dust.
local swept = t.ledger_rows("residue_cleared")
assert(#swept == 1, ("one sweep, one lifting, got %d"):format(#swept))
local swept_at = ui_controls.array(swept[1].at)
assert(swept_at[1] == 1 and swept_at[2] == 1, "naming the stroked tile")
assert(swept[1].kinds == 1, "lifting the one kind that rested there")
assert(swept[1].fragments == blast_share, "lifting the tile's whole share")
assert(not shows_dust(1, 1), "the blast tile is swept clean")
assert(shows_dust(1, 3), "two tiles down, the dust stays")
