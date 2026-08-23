-- Which organs a surgeon can reach, and self-surgery (docs/SURGERY.md
-- §6.4/§6.5). A socket's `requires` is the saw lock: the brain and the
-- chest organs sit behind a sawed bone, the eyes and ears do not. And a
-- patient can cauterise their OWN wound, which no second party can do
-- for them.

local ARENA = [==[(
    name: "ward",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    structures: [(2, 1, "optable")],
    items: [ (1, 1, "scalpel"), (1, 1, "shard"), (1, 1, "retractor"), (1, 1, "hemostat"), (1, 1, "welder") ],
)]==]

local function has(states, name) return states[name] == true end

-- =====================================================================
-- The saw lock: open a HEAD without sawing, and the eyes are reachable
-- but the brain is not.
-- =====================================================================
t.world(ARENA, 0)
local surgeon = t.join()
local patient = t.join()
t.run_ticks(3)
t.rest(patient, true)
t.run_ticks(2)
local PX, PY = 2, 1
local pid = t.body_id(patient)
-- The head is bare (the jumpsuit covers the torso and limbs, not the
-- head), so no strip is needed; the surgeon just aims there.
t.set_zone(surgeon, "head")

local function hold(id)
    if t.hands(surgeon).held then t.drop(surgeon); t.tick() end
    t.click(surgeon, 1, 1, t.target_at(1, 1, id)); t.run_ticks(2)
end
local function step(tool, secs, done, why)
    hold(tool)
    t.click(surgeon, PX, PY, pid); t.run_ticks(math.ceil(secs * 20) + 3)
    assert(done(), why)
end

step("scalpel", 1.6, function() return has(t.parts(patient).head.states, "skin_cut") end, "head incised")
step("retractor", 2.4, function() return has(t.parts(patient).head.states, "skin_open") end, "head retracted")
-- A shard, not the scalpel: a scalpel is edged AND force 10, so it also
-- matches saw_bone and would open the choice window here (tg's own
-- ambiguity); a shard (force 5) cannot saw, so it cleanly incises. Its
-- 2.25 multiplier makes the real delay 2.4 x 2.25 = 5.4 s.
step("shard", 5.4, function() return has(t.parts(patient).head.states, "organs_cut") end, "head organs cut")

-- No saw: the brain is locked, the eyes and ears are not. A hemostat here
-- opens the window over the reachable organs.
hold("hemostat")
t.click(surgeon, PX, PY, pid); t.run_ticks(2)
local win = t.ui(surgeon)
assert(win and win.kind == "surgery", "several head organs to reach: the window opened")
local labels = {}
for _, tg in ipairs(win.toggles) do labels[#labels + 1] = tg.label end
local blob = table.concat(labels, " || ")
assert(blob:find("eyes", 1, true), "the eyes are reachable without a saw: " .. blob)
assert(not blob:find("brain", 1, true), "the brain is NOT -- it needs the bone sawed: " .. blob)
t.ui_close(surgeon)

-- =====================================================================
-- Self-surgery: a patient cauterises their OWN incision.
-- =====================================================================
t.world(ARENA, 0)
local doc = t.join()
local pat = t.join()
t.run_ticks(3)
t.rest(pat, true)
t.unequip(pat, "uniform") -- into a hand; drop it so the hand is free
t.drop(pat)
t.run_ticks(2)
local ppid = t.body_id(pat)

-- The doctor makes the incision (incise is not self-operable).
t.click(doc, 1, 1, t.target_at(1, 1, "scalpel")); t.run_ticks(2)
for _ = 1, 30 do
    if has(t.parts(pat).chest.states, "skin_cut") then break end
    t.click(doc, 2, 1, ppid); t.run_ticks(85)
end
assert(has(t.parts(pat).chest.states, "skin_cut"), "the doctor opened the chest")

-- Now the patient takes the welder off the next tile (in reach), lights
-- it, and closes their OWN wound (close_incision_self is self_only -- no
-- second party can perform it). The patient clicks themselves.
t.click(pat, 1, 1, t.target_at(1, 1, "welder"))
t.run_ticks(2)
assert(t.hands(pat).held == "welder", "the patient holds the welder")
t.use_self(pat) -- strike it on
t.run_ticks(2)

local ppx, ppy = t.pos(pat)
for _ = 1, 40 do
    local s = t.parts(pat).chest.states
    if not has(s, "skin_cut") and not has(s, "skin_open") then break end
    t.click(pat, ppx, ppy, t.body_id(pat)) -- click YOURSELF
    t.run_ticks(math.ceil(4.8 * 20) + 3)
end
local s = t.parts(pat).chest.states
assert(not has(s, "skin_cut") and not has(s, "skin_open"), "the patient sealed their own wound")
-- The self-cauterise costs 5 burn.
assert(t.parts(pat).chest.burn > 0, "and it burned to do it (5 burn)")

print("sockets: eyes reachable without a saw, brain not; self-cauterise works")
