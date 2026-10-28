-- What crosses a level, decided by the pack. Both modes bind these two
-- mode-scoped transforms with `level_crossing.install`; the engine asks
-- `level.sense` once per event, however many listeners it has.
local level_crossing = {}

-- Senses a listener takes in by ear; the rest are sight.
local HEARD: { [string]: boolean } = { sound = true, speech = true }

-- Sound passes an open hole or a see-through floor, up and down: tg adds
-- hearers above and below a transparent turf (`istransparentturf`,
-- code/game/sound/sound.dm:49-67). Speech crossing is Josh's ruling R7, beyond
-- tg: `get_hearers_in_view` stays on one z (code/modules/mob/living/living_say.dm:418).
-- Text, throws and machine feedback reach only viewers above the
-- event: R7's choice, since tg's `visible_message` is one z
-- (code/modules/mob/mob.dm:287).
function level_crossing.sense(ev: LevelSensePayload): { crosses: string, through: string? }
    if HEARD[ev.sense] then
        return { crosses = "both", through = "window" }
    end
    return { crosses = "down" }
end

-- A hand never reaches another level: tg's `/turf/Adjacent` refuses a turf on
-- another z (code/_onclick/adjacent.dm:34). Bound so the refusal is the pack's
-- own decision, not the engine's default.
function level_crossing.reach(_ev: LevelReachPayload): { allowed: boolean }
    return { allowed = false }
end

function level_crossing.install(behavior: Definition): ()
    behavior:handle("level.sense", { kind = "transform", route = "lifecycle" }, level_crossing.sense)
    behavior:handle("level.reach", { kind = "transform", route = "lifecycle" }, level_crossing.reach)
end

return level_crossing
