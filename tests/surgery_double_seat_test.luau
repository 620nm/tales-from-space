-- Two surgeons racing to seat an organ into ONE empty socket
-- (docs/SURGERY.md §6.4). Seating an organ writes no surgical STATE, so
-- the parked guard's mask check cannot see a rival empty-then-fill the
-- socket. Without the completion socket re-check the loser's insert would
-- OVERWRITE the winner's organ, stranding the first with an owner but no
-- socket and no tile -- an invisible leak that never decays. With it, the
-- loser's completion sees the socket already full and is interrupted (or
-- its seat displaces the winner's organ to the deck): either way the
-- organ census is conserved and nothing is orphaned.

local ARENA = [==[(
    name: "double theatre",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1), (3, 1)],
    structures: [(2, 1, "optable")],
    items: [
        (1, 1, "scalpel"), (1, 1, "retractor"), (1, 1, "shard"),
        (1, 1, "hemostat"),
        (1, 1, "organ_eyes"), (3, 1, "organ_eyes"),
    ],
)]==]
-- The two organ_eyes above are donor eyes, one within reach of each
-- surgeon; the patient's own eyes come out during the spec.

local function has(states, name) return states[name] == true end

t.world(ARENA, 0)
local left = t.join()       -- (1,1): opens the patient, then races
local patient = t.join()    -- (2,1): on the optable
local right = t.join()      -- (3,1): the rival surgeon
t.run_ticks(3)
t.rest(patient, true)
t.run_ticks(2)

local PX, PY = 2, 1
local pid = t.body_id(patient)
-- The head is bare (the jumpsuit covers the torso and limbs), so both
-- surgeons simply aim there; the eyes sit outside the bone lock.
t.set_zone(left, "head")
t.set_zone(right, "head")

local function left_holds(id)
    if t.hands(left).held then t.drop(left); t.tick() end
    t.click(left, 1, 1, t.target_at(1, 1, id))
    t.run_ticks(2)
    assert(t.hands(left).held == id, "left holds the " .. id)
end
local function step(id, secs, done, why)
    left_holds(id)
    t.click(left, PX, PY, pid)
    t.run_ticks(math.ceil(secs * 20) + 3)
    assert(done(), why)
end

-- Open the head down to the organs (no saw needed: the eyes are not
-- bone-locked). A shard, not the scalpel, incises the organs -- a scalpel
-- is edged AND force 10, so it would also offer saw_bone and open the
-- choice window (see surgery_sockets_test).
step("scalpel", 1.6, function() return has(t.parts(patient).head.states, "skin_cut") end, "incised")
step("retractor", 2.4, function() return has(t.parts(patient).head.states, "skin_open") end, "retracted")
step("shard", 5.4, function() return has(t.parts(patient).head.states, "organs_cut") end, "organs cut")

-- A whole body: every organ seated, nothing stranded.
local whole = t.organ_census()
assert(whole.orphan == 0, "a whole body strands no organ")
assert(whole.seated == whole.total - 2, "the two donor eyes are the only loose organs")

-- Take the eyes out. The head holds several reachable organs, so a
-- hemostat opens the choice window; pick the eyes.
left_holds("hemostat")
t.click(left, PX, PY, pid)
t.run_ticks(2)
local win = t.ui(left)
assert(win and win.kind == "surgery", "the head's organs open the choice window")
local pick
for _, tg in ipairs(win.toggles) do
    if tg.label:find("eyes", 1, true) then pick = tg.option end
end
assert(pick, "the eyes are among the organs to remove")
t.ui_act(left, "toggle", string.format('{"field":"operation","option":"%s"}', pick))
t.run_ticks(23) -- the 1 s removal
assert(t.organ_damage(patient, "eyes") == nil, "the eyes socket is empty")

-- Both surgeons pick up a donor eye (left's by its feet, right's by its).
t.drop(left); t.tick() -- drop the hemostat first
t.click(left, 1, 1, t.target_at(1, 1, "organ_eyes"))
t.run_ticks(2)
t.click(right, 3, 1, t.target_at(3, 1, "organ_eyes"))
t.run_ticks(2)
assert(t.hands(left).held == "organ_eyes" and t.hands(right).held == "organ_eyes",
    "both surgeons hold an eye")

-- The census just before the race: the socket empty, both eyes in hand
-- (held organs read as loose -- no host until seated), the patient's own
-- eyes loose on the deck.
local before = t.organ_census()
assert(before.orphan == 0, "still nothing orphaned going in")

-- SAME TICK: both clicks land before any step, so both park the 1 s
-- insert on the one empty eyes socket and both wake in the same pump.
-- One seats; the other's completion must find the socket full.
t.click(left, PX, PY, pid)
t.click(right, PX, PY, pid)
t.run_ticks(23)

-- The socket is seated exactly once, and the census is conserved with
-- nothing orphaned -- the leak the completion re-check forbids. (Without
-- it: the loser overwrites, seated stays the same but one eye is stranded
-- with host set and no socket -> orphan == 1.)
assert(t.organ_damage(patient, "eyes") ~= nil, "an eye is seated in the socket")
local after = t.organ_census()
assert(after.orphan == 0, "no organ is stranded with an owner but no socket")
assert(after.total == before.total, "no organ was created or destroyed")
assert(after.seated == before.seated + 1, "exactly one eye was seated -- the loser did not also land")

print(string.format(
    "double-seat: one socket, two surgeons -- total %d conserved, seated %d->%d, orphan %d",
    after.total, before.seated, after.seated, after.orphan))
