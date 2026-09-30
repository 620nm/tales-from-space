local ui_controls = require("@helpers/ui_controls")

-- A blast wound aims its mark AWAY: the victim east of the epicenter
-- wears their blood facing east, not the un-aimed north of a brawl
-- (`content/lib/bloodshed.luau` correlates the receipt with the
-- epicenter `content/lib/blast.luau` noted that same tick). The mark
-- stays on the victim's tile: a decal answers to the actor's strict
-- reach, and the armer stands on the tile next door.
t.world(
    [==[(
    name: "blast spray",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: ["######", "#....#", "######"],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "frag_grenade")],
)]==],
    0
)

local armer = t.join()
local victim = t.join()
t.tick()

t.click(armer, 1, 1, t.target_at(armer, 1, 1, "frag_grenade"))
t.tick()
assert(t.hands(armer).held == "frag_grenade", "the grenade is in hand")
t.use_self(armer)
t.tick()
t.drop(armer)
t.tick()

-- The victim steps one east into the ring; the armer stays on the
-- epicenter, inside the direct blast and inside decal reach of it.
t.move(victim, "east")
t.run_ticks(6)
local vx, vy = t.pos(victim)
assert(vx == 2 and vy == 1, "the victim stands in the ring")

t.run_seconds(6)

-- The ring's exact share: 10 burn, at least 15 brute under the volley.
local health = t.health(victim)
assert(
    math.abs(ui_controls.number(health.burn) - 10) < 0.01,
    ("ring burn: %s"):format(tostring(health.burn))
)
assert(
    ui_controls.number(health.brute) >= 15,
    ("ring brute floor: %s"):format(tostring(health.brute))
)

-- The spray still mints its blood.
assert(
    (t.matter_totals().substances["blood"] or 0) > 0,
    "the blast wounds still bleed"
)

-- The victim's mark aims east, in the wound paint. Pellet strikes
-- land on the same tick off the same epicenter, so every repaint
-- agrees about the side.
local mark = nil
for _, decal in ipairs(t.decals_at(2, 1)) do
    if decal.decal == "blood" then
        mark = decal
    end
end
assert(mark ~= nil, "a blood mark on the victim's tile")
assert(mark.paint == "blood", "in the wound paint, not a crew colour")
assert(mark.facing == "e", ("aimed east, got %s"):format(tostring(mark.facing)))
