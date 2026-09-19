local composition = require("@helpers/composition")
local ui_controls = require("@helpers/ui_controls")

-- What a blast leaves on the deck: a quarter mole of ash as ordinary
-- solid matter, cloudy fallout over the blast area's floor tiles, and
-- shards where the pellets came down. The ash half is minted on the
-- blast tile, rests solid, and is not something a mop lifts. The
-- cloudy half rides the fallout verb at detonate time
-- (`sim.volley_fallout_deposit` per floor tile, seven on the center
-- and one on each ring tile, walls refused); the shard half rides the
-- landing verb off the settle signals (`sim.volley_residue_deposit`
-- per landing, none where a pellet struck). Every mop stroke sweeps
-- its tile's every kind clean (`sim.volley_residue_clear`). All three
-- halves are asserted here -- the ash by matter and mint, the dirt by
-- ledger rows and by sight -- with tools/test-residue-tiers.mjs
-- pinning the file's own numbers beside them.
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
-- DIRT: the burst whose fragments they are. One discharge, one
-- settle, and two halves of dirt. The cloudy half grounds at
-- detonate time over the blast area's four floor tiles -- the order
-- is the detonation's: gone, ash, blast, fallout, volley, settle.
-- The shard half lands later where the pellets came down, after the
-- settle, none where a pellet struck the armer down the row.
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

-- The blast area's four floor tiles: the 3x3 round (1, 1) minus its
-- five walls. Every cloudy row names one of them.
local blast_floors = { "1,1", "1,2", "2,1", "2,2" }
local function is_blast_floor(x: number, y: number): boolean
    for _, floor in ipairs(blast_floors) do
        if floor == ("%d,%d"):format(x, y) then
            return true
        end
    end
    return false
end

local dirt = t.ledger_rows("residue_settled")
local cloudy = 0
local cloudy_resting = 0
local shards = 0
local shards_far = 0
for _, row in ipairs(dirt) do
    local at = ui_controls.array(row.at)
    local ax, ay = ui_controls.number(at[1]), ui_controls.number(at[2])
    local share = ui_controls.number(row.fragments)
    if row.kind == 1 then
        assert(row.seq > minted[1].seq, "every fallout grounds after the ash")
        assert(row.seq < discharged[1].seq, "and before the volley")
        assert(is_blast_floor(ax, ay), ("fallout stays on the blast floors, not (%d, %d)"):format(ax, ay))
        if ax == 1 and ay == 1 then
            assert(share == 7, ("the center heaps seven, got %d"):format(share))
        else
            assert(share == 1, "the ring dusts one each")
        end
        cloudy += 1
        cloudy_resting += share
    else
        assert(row.kind == 0, "two kinds rest, no third")
        assert(row.seq > settled[1].seq, "shards land after the settle")
        assert(ax >= 1 and ax <= 5 and ay >= 1 and ay <= 3, ("no shard on a wall (%d, %d)"):format(ax, ay))
        if not is_blast_floor(ax, ay) then
            shards_far += 1
        end
        shards += share
    end
end
assert(cloudy == 4, ("four floor tiles wear fallout, got %d"):format(cloudy))
assert(cloudy_resting == 10, ("the blast grounds ten, got %d"):format(cloudy_resting))
assert(shards == 13, ("thirteen pellets settle, got %d"):format(shards))
assert(shards_far == 6, ("six landings past the blast floors, got %d"):format(shards_far))

-- The blast tile keeps the heap, and the deck shows it: the dominant
-- kind's tier-one sprite, drawn but never pickable, so a click lands
-- on the turf.
local function shows(x: number, y: number, sprite: string): boolean
    for _, seen in ipairs(t.seen_composition(p, x, y)) do
        if seen.sprite == sprite and not seen.pickable then
            return true
        end
    end
    return false
end
local function shows_dirt(x: number, y: number): boolean
    return shows(x, y, "blast_shards") or shows(x, y, "dust")
end
assert(shows_dirt(1, 1), "the blast tile wears its dirt")
assert(shows_dirt(2, 2), "diagonal to it, the ring keeps its one")

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

-- The stroke's silent half: the blast tile's whole heap lifts in one
-- row -- cloudy and shards together -- and only that tile's. The ring
-- tile diagonal to it keeps its dirt.
local blast_total = 0
local blast_kinds = 0
for _, row in ipairs(dirt) do
    local at = ui_controls.array(row.at)
    if at[1] == 1 and at[2] == 1 then
        blast_total += ui_controls.number(row.fragments)
        blast_kinds += 1
    end
end
local swept = t.ledger_rows("residue_cleared")
assert(#swept == 1, ("one sweep, one lifting, got %d"):format(#swept))
local swept_at = ui_controls.array(swept[1].at)
assert(swept_at[1] == 1 and swept_at[2] == 1, "naming the stroked tile")
assert(swept[1].kinds == blast_kinds, "lifting every kind that rested there")
assert(
    ui_controls.number(swept[1].fragments) == blast_total,
    "lifting the tile's whole heap"
)
assert(not shows_dirt(1, 1), "the blast tile is swept clean")
assert(shows_dirt(2, 2), "diagonal to it, the ring keeps its dirt")
