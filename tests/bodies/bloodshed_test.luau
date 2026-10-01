local ui_controls = require("@helpers/ui_controls")

-- The wound chain: a blow that lands brute on a body with blood in it
-- opens a bleeder on the worst-hurt part, thumps, and leaves blood on
-- the deck as matter and as a mark (`content/lib/bloodshed.luau`).
-- The blow is a swung toolbox — the path a browser takes
-- (tests/bodies/target_zone_test.luau) — and every number below is the
-- pack's: 10 brute a swing, one stack a brute, a tenth of a unit
-- spilled a brute through the 0.025 mol/u bridge.
local BRAWL = [==[(
    name: "brawl",
    legend: { ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])) },
    rows: [ "#####", "#...#", "#####" ],
    structures: [
        (1, 1, "player_spawn", { "jobs": "assistant" }),
        (2, 1, "player_spawn", { "jobs": "medic" }),
    ],
    items: [ (1, 1, "toolbox") ],
)]==]

local function near(got: number, want: number, what: string)
    assert(math.abs(got - want) < 1e-6, ("%s: %.6f, not %.6f"):format(what, got, want))
end

local function num(value: unknown): number
    return ui_controls.number(value)
end

t.world(BRAWL, 0)
local attacker = t.join("assistant")
local victim = t.join("medic")
t.run_ticks(3)

t.click(attacker, 1, 1, t.target_at(attacker, 1, 1, "toolbox"))
t.run_ticks(2)

-- One swing. The zone roll decides WHERE the 10 lands, so every
-- assertion below is zone-independent: totals, not addresses.
t.click(attacker, 2, 1, t.body_target(attacker, victim))
t.run_ticks(10)

-- The blow landed, all 10 of it, on exactly one part.
local parts = assert(t.parts(victim))
local brute_sum, bleed_sum, bleeding_parts = 0, 0, 0
local worst_zone, worst_brute = "", -1
for zone, row in pairs(parts) do
    local brute = num(row.brute or 0)
    brute_sum += brute
    local bleeding = num(row.bleeding or 0)
    bleed_sum += bleeding
    if bleeding > 0 then
        bleeding_parts += 1
    end
    if brute > worst_brute then
        worst_zone, worst_brute = zone, brute
    end
end
near(brute_sum, 10, "one swing lands 10 brute")
assert(bleeding_parts == 1, "and opens exactly one bleeder")
near(bleed_sum, 10, "one stack a brute")
near(num(parts[worst_zone].bleeding or 0), 10, "on the worst-hurt part")

-- The room heard the weapon AND the flesh: the toolbox's own smash
-- under the wound's punch.
local heard: { [string]: boolean } = {}
for _, sound in ipairs(t.sounds(attacker)) do
    heard[sound] = true
end
assert(heard["smash"], "the swing's own crack")
assert(heard["punch"], "and the flesh under it")

-- A tenth of a unit a brute: 10 brute spills 1 unit, 0.025 mol.
local blood = t.matter_totals().substances["blood"] or 0
near(blood, 0.025, "spilled blood on the books")

-- The splatter mark sits on the victim's tile in the wound paint.
local mark = nil
for x = 1, 3 do
    for _, decal in ipairs(t.decals_at(x, 1)) do
        if decal.decal == "blood" then
            mark = decal
        end
    end
end
assert(mark ~= nil, "a blood mark on the deck")
assert(mark.paint == "blood", "in the wound paint, not a crew colour")

-- The bleeder bleeds: 0.5 units/s while stacks remain, so two passes
-- cost a unit net of regeneration and the volume is under full.
t.run_seconds(5)
local body = assert(t.body(victim))
assert(body.blood ~= nil and body.blood < 560, "five seconds of bleeding shows")
near(num(body.bleed_rate or 0), 0.5, "at the flat stack rate")

-- ---------------------------------------------------------------
-- THE KILLING BLOW: splatter without a new bleeder.
-- ---------------------------------------------------------------
-- A precondition, not a blow: the victim at 195 brute, ten health
-- from dead. Actorless, so it bleeds (living) and leaves no trace —
-- no second mint, no thump.
local function stacks(): number
    local total = 0
    for _, row in pairs(assert(t.parts(victim))) do
        total += num(row.bleeding or 0)
    end
    return total
end

t.set_health(victim, { brute = 195 })
t.run_ticks(4)
near(t.matter_totals().substances["blood"] or 0, 0.025, "an actorless wound mints nothing")
assert(#t.sounds(attacker) == 0, "and thumps nothing")
-- Stacks decay a pass at a time, so only the direction is pinned:
-- the living precondition opens far more than time closes. The chest
-- saturates at the engine's 40-stack cap (a pass boundary may have
-- closed one meanwhile).
local opened = stacks()
assert(opened > bleed_sum, "but the living precondition still bleeds")
local chest = num(assert(t.parts(victim)).chest.bleeding or 0)
assert(chest >= 39, "a part holds no more than 40")

-- One more swing kills — 205 past the -100 dead line
-- (HEALTH_THRESHOLD_DEAD, combat.dm:90). The thump and
-- the pool land, but the dead open no bleeder, and the mark repaints
-- rather than stacking.
t.click(attacker, 2, 1, t.body_target(attacker, victim))
t.run_ticks(10)
-- The wound answers on the receipt; death arrives down the cascade
-- (threshold, failed heart, still body), ticks later.
local last: { [string]: boolean } = {}
for _, sound in ipairs(t.sounds(attacker)) do
    last[sound] = true
end
assert(last["smash"] and last["punch"], "a killing blow still lands loud")
near(t.matter_totals().substances["blood"] or 0, 0.05, "and still spills")
local marks = 0
for x = 1, 3 do
    for _, decal in ipairs(t.decals_at(x, 1)) do
        if decal.decal == "blood" then
            marks += 1
        end
    end
end
assert(marks == 1, "one tile, one mark, repainted")
-- The killing wound opens onto a saturated chest: the cap hides its
-- 10 and time only closes, so the count never rises past the opening.
-- (The animate gate itself — no stacks once dead — is pinned from the
-- other side by tests/bodies/surgery_cadaver_test.luau's rolled-out
-- cadaver. A swung tool cannot reach a corpse at all: clicks on one
-- route to `interaction.use`, never combat.)
assert(stacks() <= opened, "the heart beats on the receipt")
t.run_seconds(3)
assert(not assert(t.body(victim)).animate, "and the cascade ends dead")
assert(#t.script_errors() == 0, "the wound chain runs clean")
