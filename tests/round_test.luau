-- Round policy is a station behavior: native publishes lifecycle anchors and
-- validates generic Mind reads, while this pack owns selection, objectives,
-- private briefing, and the final audience.
local MAP = [==[(
    name: "round cell",
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
    spawns: [(1, 1), (4, 1)],
    items: [(2, 1, "id_engineering")],
)]==]

local function has(messages, text)
    return table.concat(messages, "\n"):find(text, 1, true) ~= nil
end

-- One deterministic draw, one private briefing, then an explicit all-session
-- reveal after the chosen Mind completes the configured hold objective.
t.world(MAP, 41)
local left = t.join()
local right = t.join()
t.run_ticks(610)
local left_messages = t.messages(left)
local right_messages = t.messages(right)
local left_chosen = has(left_messages, "You are the traitor")
local right_chosen = has(right_messages, "You are the traitor")
assert(left_chosen ~= right_chosen, "exactly one candidate receives the secret briefing")

local chosen = left_chosen and left or right
if chosen == left then
    t.move(chosen, "east")
    t.run_ticks(5)
else
    t.move(chosen, "west")
    t.run_ticks(5)
    t.move(chosen, "west")
    t.run_ticks(5)
end
t.click(chosen, 2, 1, t.target_at(2, 1, "id_engineering"))
t.tick()
assert(t.hands(chosen).held == "id_engineering", "the selected Mind's body holds the target")

t.round_end_in(1)
t.tick()
assert(has(t.messages(left), "SUCCESS"), "the final reveal reaches the left session")
assert(has(t.messages(right), "SUCCESS"), "the final reveal reaches the right session")

-- The same round seed and stable Mind creation order reproduce the draw.
t.world(MAP, 41)
local replay_left = t.join()
local replay_right = t.join()
t.run_ticks(610)
assert(
    has(t.messages(replay_left), "You are the traitor") == left_chosen,
    "the candidate draw is deterministic per round seed"
)

-- The declared target may be absent from this world. The pack then chooses
-- its explicit survive fallback without asking native code for policy.
local NO_TARGET = MAP:gsub('    items: %[%(%d+, %d+, "id_engineering"%)%],\n', "")
t.world(NO_TARGET, 52)
local fallback = t.join()
t.run_ticks(610)
assert(has(t.messages(fallback), "Survive to the end"), "absent target selects fallback")
t.round_end_in(1)
t.tick()
assert(has(t.messages(fallback), "SUCCESS"), "fallback evaluates from Mind continuity")

-- A connected but dead Mind is not an eligible candidate. The task retries
-- without drawing or spending a second policy path, and finalization uses the
-- pack's quiet ending.
t.world(MAP, 41)
local dead = t.join()
t.set_health(dead, { oxy = 500 })
assert(t.body(dead).state == "dead", "the candidate precondition is dead")
t.round_end_in(700)
t.run_ticks(700)
local quiet = t.messages(dead)
assert(not has(quiet, "You are the traitor"), "an ineligible Mind receives no secret")
assert(has(quiet, "reports no threats aboard"), "no candidates produces the quiet reveal")
