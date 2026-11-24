-- Playtest entry: who a participant drops in as when a playtest round
-- seats them. The engine owns admission and body construction; this
-- file owns the pack's answer — the name, and the job where the mode
-- wants one. Both modes bind it; an ordinary round never fires it.
local crew_names = require("@lib/crew/names")
local map_markers = require("@lib/map_markers")

local playtest_entry = {}

local STREAM = "playtest_entry.name"

local function roll(count: number): number
    return math.min(count, math.floor(sim.random(STREAM) * count) + 1)
end

local function generated_name(): string
    local given = crew_names.given[roll(#crew_names.given)]
    return given .. " " .. crew_names.family[roll(#crew_names.family)]
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
            map_markers.note_playtest()
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
end

return playtest_entry
