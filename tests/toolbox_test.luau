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

t.click(attacker, 1, 1) -- the toolbox underfoot
t.tick()
assert(t.hands(attacker).held == "toolbox", "picked it up")
assert(t.vitals(victim) == nil, "nobody has been hurt yet")

for _ = 1, 10 do
    t.click(attacker, 2, 1)
    t.tick()
end
local h = t.health(victim)
assert(math.abs(h.brute - 100) < 0.01, "10 hits x 10 brute: " .. h.brute)
assert(h.state == "crit", "crit at 100 total damage")
local pushed = t.vitals(victim)
assert(pushed and pushed.brute > 0, "damage pushes vitals immediately")

for _ = 1, 10 do
    t.click(attacker, 2, 1)
    t.tick()
end
assert(t.health(victim).state == "dead", "twenty hits is a body")
assert(t.sprite(victim) == "human_dead", "and the body lies down")

-- Every swing is on the record, attributed to the FILE that decided
-- the damage and the player whose click triggered it.
local hits = 0
for _, row in ipairs(t.ledger_rows("Damaged")) do
    if math.abs(row.brute - 10) < 0.01
        and row.target == victim_id
        and row.actor.kind == "script"
        and row.actor.file == "items/toolbox.luau"
        and row.actor.triggered_by == attacker_id
    then
        hits += 1
    end
end
assert(hits == 20, "every hit is a Script-attributed ledger row, got " .. hits)
assert(#t.ledger_rows("Died") == 1, "the death is on the record")

-- Both parties heard the thud and read the message.
local swung = table.concat(t.messages(attacker), "\n")
assert(swung:find("You rob", 1, true), "the attacker read the swing: " .. swung)
assert(table.concat(t.sounds(attacker), "\n"):find("smash", 1, true), "the thud")
local hurt = table.concat(t.messages(victim), "\n")
assert(hurt:find("robs you", 1, true), "the victim read the hit: " .. hurt)
