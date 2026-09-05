-- WHAT IS IN THAT SOCKET, and the one-word answer for everyone who
-- does not care.
--
-- `ctx.sockets(body)` is keyed by socket id the way `ctx.parts` is keyed
-- by zone, and every row leads with `ok`: seated, and not failing. Most
-- callers want exactly that and nothing else -- something that will not
-- work for a crewman whose eyes are gone does not need to know how far
-- gone. The rest of the row is for the caller that has to say WHY: what
-- is in there, whose prototype it is, how far its pool has moved, and
-- whether it is failing, decaying, or the kind of organ a body does not
-- live without.
--
-- Five states, in the order a surgeon meets them: whole, damaged,
-- failing, missing, and decaying in a corpse. The socket answers in all
-- five, INCLUDING the empty one -- which is the point of asking about
-- the hole rather than about the organ.
--
-- Read-only, the whole way down: nothing here is an effect, and the
-- surface is the same one a hook gets (`sim.sockets`,
-- docs/LUAU-API.md 7.1).

local ARENA = [==[(
    name: "theatre",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    structures: [(2, 1, "optable")],
    items: [
        (1, 1, "scalpel"), (1, 1, "retractor"), (1, 1, "hemostat"),
        (1, 1, "circular_saw"), (1, 1, "cautery"),
    ],
)]==]

t.world(ARENA, 0)
local surgeon = t.join()
local patient = t.join()
t.run_ticks(3)

-- =====================================================================
-- WHOLE. Every socket the plan declares answers, and every one of them
-- is in working order on a body nothing has happened to.
-- =====================================================================
local sockets = t.sockets(patient)
for _, id in ipairs({ "heart", "lungs", "liver", "brain", "eyes", "ears", "tongue" }) do
    local row = sockets[id]
    assert(row ~= nil, "the human plan declares a " .. id .. " socket")
    assert(row.ok == true, id .. " arrives in working order")
    assert(row.seated ~= false, "with something in it")
    assert(row.damage == 0, "and an untouched pool: " .. tostring(row.damage))
    assert(row.failing == false and row.decaying == false)
    assert(row.id == id, "the row names itself: " .. row.id)
end
assert(sockets.spleen == nil,
    "a socket this plan does not declare is nil, which is how a hook asks")

-- The identity of the hole, not only of what is in it.
assert(sockets.heart.zone == "chest", "the heart socket lives in the chest")
assert(sockets.brain.zone == "head")
assert(sockets.brain.mind_seat == true, "and the brain socket is the seat (7)")
assert(sockets.heart.mind_seat == false)
assert(sockets.heart.organ == "organ_heart", "the prototype in there, by id")
assert(sockets.heart.name == "heart", "and by the name a player would read")
assert(sockets.heart.max == 100,
    "STANDARD_ORGAN_THRESHOLD, DNA.dm:137: " .. tostring(sockets.heart.max))

-- Vitality is the plan's, and the heart is this pack's answer to being
-- alive (content/items/organ_heart.luau, heart_life_test.luau).
assert(sockets.heart.vital == true, "losing the heart is death")
assert(sockets.lungs.vital == false, "losing the lungs is only suffocation")

-- The tags are the socket's unioned with the organ's, which is the same
-- set `parts.chest.socket_tags` answers one call over.
assert(table.concat(sockets.heart.tags, ",")
    == table.concat(t.parts(patient).chest.socket_tags.heart, ","),
    "one union, two surfaces")

-- =====================================================================
-- DAMAGED. A damaged organ is still a WORKING organ: `ok` is about the
-- socket being in order, not about the organ being new.
-- =====================================================================
t.set_organ_damage(patient, "liver", 60)
t.run_ticks(2)
local liver = t.sockets(patient).liver
assert(liver.damage == 60, "the pool moved: " .. tostring(liver.damage))
assert(liver.failing == false, "60 of 100 is not failure")
assert(liver.ok == true, "and a damaged liver is still a liver")

-- =====================================================================
-- FAILING. At its maximum the engine calls it failing, and that is the
-- one thing `ok` is false for while something is still seated.
-- =====================================================================
t.set_organ_damage(patient, "liver", 100)
t.run_ticks(2)
liver = t.sockets(patient).liver
assert(liver.failing == true, "at max_health it has failed")
assert(liver.ok == false, "and the terse answer is no")
assert(liver.seated ~= false, "with the organ still sitting in the socket")
assert(liver.damage == 100 and liver.max == 100)

-- =====================================================================
-- MISSING. The hole answers too, and it answers about what BELONGS
-- there -- which is the question somebody looking into an open chest is
-- actually asking.
--
-- Emptied the way this game empties a socket: on the table, with the
-- tools (docs/SURGERY.md 6.3). The lungs rather than the heart,
-- because the patient has to survive to be asked about.
-- =====================================================================
t.rest(patient, true)
t.unequip(patient, "uniform") -- bare the chest
t.run_ticks(2)
assert(t.body(patient).posture == "lying", "the patient is on the table")

local PX, PY = 2, 1
local pid = t.body_id(patient)

-- What a candidate button says. An operation ON AN ORGAN is the
-- `procedure.on_organ` id carrying the two words as arguments; a plain
-- one is content's own word (docs/tgui/labels.md).
local function face(label)
    if type(label) ~= "table" then return tostring(label) end
    if label.args and label.args.organ then
        return tostring(label.args.operation) .. " " .. tostring(label.args.organ)
    end
    return tostring(label.text or label.id)
end

local function hold(id)
    if t.hands(surgeon).held ~= nil then t.drop(surgeon); t.tick() end
    t.click(surgeon, 1, 1, t.target_at(1, 1, id))
    t.run_ticks(2)
    assert(t.hands(surgeon).held == id, "the surgeon holds the " .. id)
end

local function step(tool, secs, state)
    hold(tool)
    t.click(surgeon, PX, PY, pid)
    t.run_ticks(math.ceil(secs * 20) + 3)
    assert(t.parts(patient).chest.states[state] == true, "the chest is " .. state)
end

step("scalpel", 1.6, "skin_cut")
step("retractor", 2.4, "skin_open")
step("hemostat", 2.4, "vessels_clamped")
step("circular_saw", 5.4, "bone_sawed")
step("scalpel", 2.4, "organs_cut")

-- Several organs are reachable, so a hemostat opens the CHOICE window
-- rather than performing one thing.
hold("hemostat")
t.click(surgeon, PX, PY, pid)
t.run_ticks(2)
local win = t.ui(surgeon)
assert(win ~= nil and win.presentation == "choices", "the choice document opened")
local pick
for _, toggle in ipairs(win.toggles) do
    if face(toggle.label):find("lungs", 1, true) then pick = toggle.option end
end
assert(pick, "the window lists the lungs among the organs to remove")
t.ui_act(surgeon, "toggle", string.format('{"field":"operation","option":"%s"}', pick))
t.run_ticks(23)

local hole = t.sockets(patient).lungs
assert(hole ~= nil, "the socket is still declared")
assert(hole.ok == false, "an empty socket is not in working order")
assert(hole.seated == false, "and says so as `false`, never nil")
assert(hole.organ == nil and hole.damage == nil and hole.max == nil,
    "there is no organ to have a pool")
assert(hole.failing == false and hole.decaying == false,
    "nothing in there is failing, because nothing is in there")
assert(hole.zone == "chest", "the hole is still in the chest")
assert(hole.vital == false,
    "and the plan still knows what BELONGS here, and that it is not vital")
assert(t.capacity(patient, "breathing") == 0,
    "which is the reading everything downstream of the hole actually uses")

-- =====================================================================
-- DECAYING. A corpse's organs go off, and the socket says which ones
-- are on their way.
-- =====================================================================
t.set_health(patient, { brute = 200 })
t.run_ticks(3)
assert(t.body(patient).animate == false, "200 brute is past the dead line")
local corpse = t.sockets(patient)
assert(corpse.brain.decaying == true,
    "the brain is going off, which is the revival window (docs/BIOLOGY.md 5)")
assert(corpse.brain.ok == true,
    "...and is still in working order while it does: decay is not failure")
assert(corpse.lungs.decaying == false, "an empty socket decays nothing")
t.run_seconds(30)
local later = t.sockets(patient).brain
assert(later.damage > corpse.brain.damage,
    "and the pool actually climbs: " .. corpse.brain.damage .. " -> " .. later.damage)
assert(later.decaying == true, "still going")
