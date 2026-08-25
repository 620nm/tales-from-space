-- The toolbox as a weapon: ten robust hits put a crewman in crit, ten
-- more kill him, every swing is a Script-attributed ledger row naming
-- the file that decided the damage and the player who swung, and both
-- parties hear the thud. (Port of the Rust m4 melee test.)
t.world([==[(
    name: "arena",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1), (2, 1)],
    items: [(1, 1, "toolbox")],
)]==], 7)

local attacker = t.join()
local victim = t.join()
t.tick()

-- The ledger's join rows are how a spec learns a body's wire id: the
-- actor of `joined_job` IS the joining player, in join order.
local joins = t.ledger_rows("joined_job")
assert(#joins == 2, "two crewmen signed on")
local attacker_id, victim_id = joins[1].actor.id, joins[2].actor.id
assert(attacker_id ~= victim_id)

t.click(attacker, 1, 1, t.target_at(1, 1, "toolbox")) -- the toolbox underfoot
t.tick()
assert(t.hands(attacker).held == "toolbox", "picked it up")
assert(t.vitals(victim) == nil, "nobody has been hurt yet")

-- The fourth argument is the pixel-perfect claim a real client sends
-- when the cursor is over a sprite: an attack is a click that NAMED
-- the crewman, never a click that merely shares his tile.
for _ = 1, 10 do
    t.click(attacker, 2, 1, victim_id)
    t.tick()
end
local h = t.health(victim)
assert(math.abs(h.brute - 100) < 0.01, "10 hits x 10 brute: " .. h.brute)
-- What a hundred brute COSTS depends on where it landed. A blow that
-- named no zone rolls (docs/BIOLOGY.md §3.2), and each part weighs its
-- own damage into the body's health -- the chest at 1, a limb at 0.75
-- (LIMB_BODY_DAMAGE_COEFFICIENT, bodyparts.dm:23-26). So the pools say
-- a hundred and the health says somewhere between 0 and 25.
assert(h.health <= 25.0 and h.health >= 0.0,
    "a hundred brute weighted by where it landed: " .. h.health)
local pushed = t.vitals(victim)
assert(pushed and pushed.brute > 0, "damage pushes vitals immediately")

-- Every swing lands on SOME part, and the record says which.
local zoned = 0
for _, row in ipairs(t.ledger_rows("Damaged")) do
    if row.zone then
        zoned = zoned + 1
    end
end
assert(zoned == 10, "every blow named the part it landed on: " .. zoned)

-- Keep swinging. Crit arrives when the weighted damage reaches
-- max_health and death when it reaches dead_at, however the rolls fell.
local swings = 0
while t.health(victim).state == "alive" and swings < 40 do
    t.click(attacker, 2, 1, victim_id)
    t.tick()
    swings = swings + 1
end
assert(t.health(victim).state == "crit", "the weighted damage reached crit_at")
while t.health(victim).state ~= "dead" and swings < 120 do
    t.click(attacker, 2, 1, victim_id)
    t.tick()
    swings = swings + 1
end
assert(t.health(victim).state == "dead", "and then dead_at")
assert(t.sprite(victim) == "human_dead", "and the body lies down")

-- Every swing is on the record, attributed to the FILE that decided
-- the damage and the player whose click triggered it.
local function pool_amount(row, id)
    for _, entry in ipairs(row.pools or {}) do
        if entry[1] == id then
            return entry[2]
        end
    end
    return 0
end
local hits = 0
for _, row in ipairs(t.ledger_rows("Damaged")) do
    if math.abs(pool_amount(row, "brute") - 10) < 0.01
        and row.target == victim_id
        and row.actor.kind == "script"
        and row.actor.file == "items/toolbox.luau"
        and row.actor.triggered_by == attacker_id
    then
        hits += 1
    end
end
assert(hits == 10 + swings,
    "every hit is a Script-attributed ledger row, got " .. hits)
-- One life-state row, and it is the one that ends the shift for this
-- body: the engine names no state, so the spec reads the flag the
-- entered state carries.
local ended = 0
for _, row in ipairs(t.ledger_rows("LifeStateChanged")) do
    if row.terminal then
        ended += 1
    end
end
assert(ended == 1, "the death is on the record")

-- Both parties heard the thud and read the message.
local swung = table.concat(t.messages(attacker), "\n")
assert(swung:find("You rob", 1, true), "the attacker read the swing: " .. swung)
assert(table.concat(t.sounds(attacker), "\n"):find("smash", 1, true), "the thud")
local hurt = table.concat(t.messages(victim), "\n")
assert(hurt:find("robs you", 1, true), "the victim read the hit: " .. hurt)
