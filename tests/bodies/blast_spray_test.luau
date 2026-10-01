local ui_controls = require("@helpers/ui_controls")

-- A blast wound aims its mark AWAY: the victim east of the epicenter
-- wears their blood facing east (`content/lib/bloodshed.luau`
-- correlates the receipt with a recent epicenter). Pellets fly for
-- ticks, so wounds two tiles out land past the correlation window and
-- wear the un-aimed north of a brawl — but an aimed mark is never
-- repainted north: a later uncorrelated wound leaves its facing alone.
-- The mark stays on the victim's tile either way.
t.world(
    [==[(
    name: "blast spray",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: ["######", "#....#", "#....#", "#....#", "######"],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "frag_grenade"), (1, 1, "toolbox")],
)]==],
    0
)

local armer = t.join()
local victim = t.join()
local diag = t.join()
local far = t.join()
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
-- Two tiles out off-axis, and three: past the direct blast, pellets only.
t.move(diag, "east")
t.run_ticks(6)
t.move(diag, "east")
t.run_ticks(6)
t.move(diag, "south")
t.run_ticks(6)
local dx, dy = t.pos(diag)
assert(dx == 3 and dy == 2, "the diagonal victim stands off-axis")
t.move(far, "east")
t.run_ticks(6)
t.move(far, "east")
t.run_ticks(6)
t.move(far, "east")
t.run_ticks(6)
t.move(far, "south")
t.run_ticks(6)
local fx, fy = t.pos(far)
assert(fx == 4 and fy == 2, "the far victim stands downrange")

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

-- The victim's mark aims east, in the wound paint: the direct wound
-- lands on the detonation tick off the fresh epicenter, and the
-- pellets that found them flew in beside it, still correlated.
local mark = nil
for _, decal in ipairs(t.decals_at(2, 1)) do
    if decal.decal == "blood" then
        mark = decal
    end
end
assert(mark ~= nil, "a blood mark on the victim's tile")
assert(mark.paint == "blood", "in the wound paint, not a crew colour")
assert(mark.facing == "e", ("aimed east, got %s"):format(tostring(mark.facing)))

-- Past the window: pellets only, no burn, and every strike landed
-- mid-flight, past correlation — so both downrange marks wear the
-- un-aimed north, in the wound paint all the same.
local function downrange(who: number, x: number, y: number, tag: string): ()
    local hurt = t.health(who)
    assert(
        ui_controls.number(hurt.brute) > 0,
        ("%s took pellets, got %s brute"):format(tag, tostring(hurt.brute))
    )
    assert(ui_controls.number(hurt.burn) == 0, ("%s took no burn"):format(tag))
    local worn = nil
    for _, decal in ipairs(t.decals_at(x, y)) do
        if decal.decal == "blood" then
            worn = decal
        end
    end
    assert(worn ~= nil, ("%s wears a blood mark"):format(tag))
    assert(worn.paint == "blood", "in the wound paint, not a crew colour")
    assert(worn.facing == "n", ("%s wears it un-aimed, got %s"):format(tag, tostring(worn.facing)))
end
downrange(diag, 3, 2, "two tiles out")
downrange(far, 4, 2, "three tiles out")

-- THE BRAWL AFTER: an uncorrelated wound never repaints an aimed
-- mark. Long past the settle, the armer swings a toolbox at the ring
-- victim — 10 more brute, and the mark still faces east.
t.click(armer, 1, 1, t.target_at(armer, 1, 1, "toolbox"))
t.run_ticks(2)
assert(t.hands(armer).held == "toolbox", "the toolbox is in hand")
local before = ui_controls.number(t.health(victim).brute)
t.click(armer, 2, 1, t.body_target(armer, victim))
t.run_ticks(10)
local after = ui_controls.number(t.health(victim).brute)
assert(
    math.abs(after - before - 10) < 1e-6,
    ("the swing lands 10, got %.2f"):format(after - before)
)
local kept = nil
for _, decal in ipairs(t.decals_at(2, 1)) do
    if decal.decal == "blood" then
        kept = decal
    end
end
assert(kept ~= nil, "the mark is still on the victim's tile")
assert(kept.facing == "e", ("still aimed east, got %s"):format(tostring(kept.facing)))
assert(#t.script_errors() == 0, "the blast and its settle run clean")
