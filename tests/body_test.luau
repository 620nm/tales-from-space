-- What a human body IS, read through the seam a client uses
-- (docs/BIOLOGY.md §1–§3). The engine's arithmetic is tested on the
-- fixture pack's meaning-free plan; this is the other half — that the
-- HUMAN plan in `content/bodies/human.luau` says what it means to say.
--
-- Every number asserted here is the plan's, not the engine's: change
-- `human.luau` and this file is what tells you what you changed. What a
-- spec cannot do here it genuinely cannot do yet — nothing in the game
-- takes an organ out until the surgery segment lands, so the scenarios
-- that start with a missing heart live in the Rust suite against the
-- shipped plan.
local ARENA = [==[(
    name: "ward",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    spawns: [(1, 1), (2, 1), (3, 1)],
)]==]

-- ---------------------------------------------------------------
-- The plan a crewman wears, and the shape of it.
-- ---------------------------------------------------------------
t.world(ARENA, 0)
local p = t.join()
t.tick()

local body = t.body(p)
assert(body.plan == "human", "the shift's crew are humans: " .. body.plan)
assert(body.state == "alive" and body.conscious, "and alive and awake")
assert(body.posture == "standing", "and on their feet")
assert(math.abs(body.health - 100) < 0.01,
    "MAX_LIVING_HEALTH, mobs.dm:236: " .. body.health)
assert(math.abs(body.blood - 560) < 0.01,
    "BLOOD_VOLUME_NORMAL, mobs.dm:20: " .. body.blood)

local parts = t.parts(p)
for _, zone in ipairs({ "head", "chest", "l_arm", "r_arm", "l_leg", "r_leg" }) do
    assert(parts[zone], "a human has a " .. zone)
    assert(parts[zone].present, "and arrives with it attached")
    assert(parts[zone].brute == 0 and parts[zone].burn == 0, "and unhurt")
end
assert(math.abs(parts.chest.max - 200) < 0.01,
    "LIMB_MAX_HP_CORE, bodyparts.dm:11: " .. parts.chest.max)
assert(math.abs(parts.l_arm.max - 50) < 0.01,
    "LIMB_MAX_HP_DEFAULT, bodyparts.dm:9: " .. parts.l_arm.max)

-- The sockets are in the parts that host them, and every one of them
-- arrives seated.
assert(parts.chest.organs.heart, "the heart sits in the chest")
assert(parts.chest.organs.lungs and parts.chest.organs.liver)
assert(parts.head.organs.brain, "and the brain in the head")
assert(parts.head.organs.eyes and parts.head.organs.ears)
assert(t.organ_damage(p, "heart") == 0, "all of them whole")
assert(t.organ_damage(p, "brain") == 0)

-- The tags a capacity reads are on the socket, not on the engine.
assert(table.concat(parts.chest.socket_tags.heart, ",") == "heart",
    "the heart socket carries the tag `blood` reads")
assert(table.concat(parts.head.socket_tags.brain, ",") == "brain")

-- A limb carries the tags the movement and grip capacities read.
local leg_tags = table.concat(parts.l_leg.tags, ",")
assert(leg_tags:find("leg", 1, true), "a leg is tagged a leg: " .. leg_tags)

-- Every role the engine can consume is bound, and every one of them
-- reads 1 on a body nothing has happened to yet.
for _, id in ipairs({ "consciousness", "moving", "manipulation", "sight",
                      "hearing", "speech", "breathing", "blood", "metabolism" }) do
    local level = t.capacity(p, id)
    assert(level ~= nil, "the human plan declares " .. id)
    assert(math.abs(level - 1.0) < 0.01,
        id .. " reads 1 on a whole body, not " .. level)
end
assert(t.capacity(p, "no_such_capacity") == nil,
    "and nothing else: a capacity the plan lacks is nil, not 1")

-- ---------------------------------------------------------------
-- Damage lands on a PART, and what it costs the body is that part's
-- own weight (§3.3).
-- ---------------------------------------------------------------
t.world(ARENA, 0)
local q = t.join()
t.tick()

-- The chest carries its damage at coefficient 1
-- (LIMB_BODY_DAMAGE_COEFFICIENT_TOTAL, bodyparts.dm:25), and a blow
-- that named no zone lands on the plan's `default_zone`.
t.set_health(q, { brute = 20 })
local hurt = t.parts(q)
assert(math.abs(hurt.chest.brute - 20) < 0.01,
    "a zone-less blow lands on the default zone: " .. hurt.chest.brute)
assert(math.abs(t.body(q).health - 80) < 0.01,
    "and twenty on the chest is twenty off the body: " .. t.body(q).health)
assert(math.abs(t.health(q).brute - 20) < 0.01,
    "the old three-number readout still sums the parts")

-- A part's ceiling discards the overflow rather than spilling it
-- (tg `can_inflict`, _bodyparts.dm:780-786). Four hundred brute at a
-- body that can hold six hundred, rolled across the zones, still never
-- puts more into any one part than that part's own file allows.
t.set_health(q, { brute = 400 })
for zone, part in pairs(t.parts(q)) do
    assert(part.brute + part.burn <= part.max + 0.01,
        zone .. " holds no more than its own ceiling: "
            .. (part.brute + part.burn) .. " of " .. part.max)
end
assert(t.body(q).state == "dead", "and four hundred brute is a body")

-- ---------------------------------------------------------------
-- Oxygen knocks a crewman out long before it kills them: tg's
-- OXYLOSS_PASSOUT_THRESHOLD is 50 (mobs.dm:14) and it is a knockout,
-- never a death (§2, the `step` on the consciousness formula).
-- ---------------------------------------------------------------
t.world(ARENA, 0)
local r = t.join()
t.tick()

t.set_health(r, { oxy = 40 })
assert(t.body(r).conscious, "forty is survivable and you stay awake")
assert(t.body(r).state == "alive")

t.set_health(r, { oxy = 60 })
assert(not t.body(r).conscious, "past fifty you are out cold")
assert(t.body(r).state == "alive",
    "but NOT in crit — a faint is not a crit (§3.4): " .. t.body(r).state)
assert(t.body(r).posture == "lying", "and you are on the deck")
assert(math.abs(t.capacity(r, "sight")) < 0.01,
    "an unconscious body sees nothing (awake_only)")
assert(math.abs(t.capacity(r, "hearing")) < 0.01, "and hears nothing")
assert(math.abs(t.capacity(r, "breathing") - 1.0) < 0.01,
    "but it still breathes: the vital capacities opt out")

-- Coming back up is the same rule read the other way.
t.set_health(r, { oxy = 10 })
assert(t.body(r).conscious, "and you come round when it clears")
assert(t.body(r).posture == "standing", "and get up by yourself")

-- ---------------------------------------------------------------
-- An unconscious crewman says nothing, and nobody hears them: no
-- tongue, no lungs and no consciousness are all one gate (§3.4).
-- ---------------------------------------------------------------
t.world(ARENA, 0)
local a = t.join()
local b = t.join()
t.tick()

t.say(a, "still here")
t.run_ticks(2)
assert(#t.ledger_rows("said") == 1, "a conscious crewman is heard")

t.set_health(a, { oxy = 60 })
assert(math.abs(t.capacity(a, "speech")) < 0.01,
    "no consciousness, no speech: " .. t.capacity(a, "speech"))
t.say(a, "help")
t.run_ticks(2)
assert(#t.ledger_rows("said") == 1,
    "and an unconscious one is not: " .. #t.ledger_rows("said"))
assert(table.concat(t.messages(b), "\n"):find("help", 1, true) == nil,
    "nothing reached the crewman standing next to them")
