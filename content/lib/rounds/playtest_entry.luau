-- Playtest entry: who a participant drops in as when a playtest round
-- seats them. The engine owns admission and body construction; this
-- file owns the pack's answer — the name, and the job where the mode
-- wants one. Both modes bind it; an ordinary round never fires it.
local crew_names = require("@lib/crew/names")
local map_markers = require("@lib/map_markers")

local playtest_entry = {}

local STREAM = "playtest_entry.name"
local NO_SPAWN_POINT = "lunatic/tfs:lib.playtest_entry.no_spawn_point"

-- Participants an assignment was answered for this round, by player
-- key: at join-done, one still bodiless whose spawn ask answered
-- empty gets the words for it instead of silence.
local attempted: { [string]: boolean } = {}

local function roll(count: number): number
    return math.min(count, math.floor(sim.random(STREAM) * count) + 1)
end

local function generated_name(): string
    local given = crew_names.given[roll(#crew_names.given)]
    return given .. " " .. crew_names.family[roll(#crew_names.family)]
end

local function on_join(ev: ParticipantJoinDonePayload): ()
    local player = ev.participant
    local was_attempted = attempted[player.key] == true
    attempted[player.key] = nil
    if not was_attempted or player.body ~= nil or not map_markers.take_spawn_refusal(player.key) then
        return
    end
    for _, mind in ipairs(sim.query.minds()) do
        if mind.player == player then
            sim.message.notify({ audience = mind, message = sim.msg(NO_SPAWN_POINT, {}) })
            return
        end
    end
end

-- Binds the assign handler on `behavior`. `job` is the role a
-- playtester takes in this mode, or nil to drop in jobless under the
-- mode's own outfit. The name is always a generated crew name: a
-- playtest has no draft to honor.
function playtest_entry.install(behavior: Definition, job: string?): ()
    behavior:handle(
        "round.playtest_assign",
        { kind = "transform", route = "lifecycle" },
        function(ev: RoundPlaytestAssignPayload): { assignments: { PlaytestAssignment } }
            attempted[ev.participant.key] = true
            return {
                assignments = {
                    {
                        participant = ev.participant,
                        name = generated_name(),
                        job = job,
                    },
                },
            }
        end
    )
    behavior:handle("participant.join.done", { kind = "react" }, on_join)
end

return playtest_entry
