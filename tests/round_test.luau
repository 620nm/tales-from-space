-- The hour belongs to the pack. Native publishes one second of sim time
-- at a time and replaces the world only after content has asked; the
-- warnings, the closing line and the length of a shift are all
-- `content/lib/shift.luau` reading the numbers a mode declared.
local MAP = [==[(
    name: "shift cell",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(1, 1), (4, 1)],
)]==]

local function count(messages, needle)
    local n = 0
    for _, line in ipairs(messages) do
        if line:find(needle, 1, true) ~= nil then
            n += 1
        end
    end
    return n
end

-- Every line the station said this window, for both sessions at once: a
-- fact about the shift is a fact for whoever is still watching it, so
-- the dead spectator is held to the same expectation as the crewman
-- with a pulse (content/audiences.luau).
local function heard(sessions, needle)
    local seen = nil
    for _, p in ipairs(sessions) do
        local n = count(t.messages(p), needle)
        if seen ~= nil and n ~= seen then
            error("sessions disagreed about " .. needle .. ": " .. seen .. " and " .. n)
        end
        seen = n
    end
    return seen
end

-- 60 minutes, warnings at 10, 5 and 1 remaining
-- (content/gamemodes/space_station.luau).
t.world(MAP, 0)
local crew = t.join("engineer")
local ghost = t.join("assistant")
t.set_health(ghost, { oxy = 500 })
assert(t.body(ghost).animate == false, "the spectator is dead in the pack's terms")
local watching = { crew, ghost }
heard(watching, "The shift")

t.run_seconds(2999)
assert(heard(watching, "The shift") == 0, "nothing is announced before the first mark")

t.run_seconds(1)
assert(heard(watching, "The shift ends in 10 minutes.") == 1, "ten minutes out, at 3000 s")

t.run_seconds(299)
assert(heard(watching, "The shift") == 0, "and nothing between the marks")

t.run_seconds(1)
assert(heard(watching, "The shift ends in 5 minutes.") == 1, "five minutes out, at 3300 s")

t.run_seconds(239)
assert(heard(watching, "The shift") == 0, "still nothing between the marks")

-- Not "in 1 minutes": the last mark is its own sentence
-- (docs/LOCALIZATION.md §5).
t.run_seconds(1)
assert(heard(watching, "The shift ends in one minute.") == 1, "one minute out, at 3540 s")

t.run_seconds(59)
assert(heard(watching, "The shift") == 0, "the last minute passes quietly")

-- The world keeps ticking through the grace the mode declared, and the
-- clock keeps publishing through it, so what matters is that the ending
-- is said ONCE rather than once a second.
t.run_seconds(1)
local ending = t.messages(crew)
local ghost_ending = t.messages(ghost)
t.run_seconds(5)
for _, line in ipairs(t.messages(crew)) do
    table.insert(ending, line)
end
for _, line in ipairs(t.messages(ghost)) do
    table.insert(ghost_ending, line)
end
assert(count(ending, "The shift is over.") == 1, "the end of the shift is announced once, at 3600 s")
assert(count(ghost_ending, "The shift is over.") == 1, "and the dead spectator hears that too")
assert(count(ending, "The shift ends") == 0, "no warning rides along with the ending")

-- One request, granted, for the grace the mode asked for. A second of
-- grace asking again would move no deadline, and the pack does not ask.
local requests = t.ledger_rows("RoundEndRequested")
assert(#requests == 1, "the shift is ended exactly once")
assert(requests[1].applied == true, "and that request is the one that ended it")
assert(requests[1].grace_ticks == 600, "30 s of grace, in ticks")

-- A crewman the pack calls dead may leave the body behind. The corpse
-- stays aboard; the session goes back to the board as somebody new and
-- takes whatever job is still open.
t.world(MAP, 0)
local dead = t.join("assistant")
t.set_health(dead, { oxy = 500 })
assert(t.body(dead).animate == false, "the precondition is a body nobody can steer")
t.respawn(dead, "engineer")
assert(t.body(dead).animate, "the session steers a living body again")
assert(t.worn(dead).id == "id_engineering", "wearing the kit of the job it just picked")
assert(#t.ledger_rows("ReturnedToLobby") == 1, "one abandonment, attributed")
assert(#t.ledger_rows("Respawned") == 0, "a persistent mode never swaps one body for the next")

-- ...and a living one may not. The offer is the mode's `respawn` policy,
-- and the claim is revalidated where it lands rather than trusted.
local alive = t.join("medic")
local body = t.body_id(alive)
t.respawn(alive)
assert(t.body_id(alive) == body, "a living crewman cannot walk out of their body")
assert(#t.ledger_rows("ReturnedToLobby") == 1, "and leaves no second row behind")

-- The sandbox runs the same hour on the same library. Its point is the
-- map coming back fresh, and a mode whose shift was an exception would
-- be a second answer to when a round ends.
t.world(MAP, 0, "free_build")
local builder = t.join()
t.run_seconds(3601)
assert(
    count(t.messages(builder), "The shift is over.") == 1,
    "Free Build ends on the clock every other mode keeps"
)
