-- The full station round: persistent characters, finite supplies, and the
-- pack-owned antagonist/objective/round-end flow.
local round = {
    -- TfS timings retained from the prior mode policy; these are not copied
    -- tg tunings. A task starts at the fixed task-resume point and sleeps to
    -- the absolute arm tick, then retries only while the candidate set is empty.
    arm_after_ticks = 600,
    retry_ticks = 200,
    announcer = "Charter Command",
    channel = "Common",
    briefing = "You are the traitor. Objective: {objective}",
    steal_target = "id_engineering",
    steal_objective = "Steal the engineering ID card and hold it when the shift ends.",
    survive_objective = "Survive to the end of the shift.",
    quiet_ending = "The shift is over. Charter Command reports no threats aboard. Good work.",
    revealed_ending = "The shift is over. The traitor was {name}. Objective: {objective} — {verdict}.",
    success = "SUCCESS",
    failure = "FAILURE",
}

local content = {
    id = "space_station",
    name = "Space Station",
    default = true,
    rules = {
        bodies = "persistent",
        respawn = "never",
        body = "human",
        infinite_vending = false,
        round_logic = true,
        -- Plain pack data. The native mode loader checks only that lifecycle
        -- modes carry bounded data; this file is its sole interpreter.
        round = round,
        environment = {
            sink_k = 2.7,
            rolls = {
                { id = "dead_space", name = "dead space", weight = 4, insolation = 0 },
                { id = "orbit", name = "orbit", weight = 3, insolation = 1361 },
                { id = "sunward", name = "close solar orbit", weight = 1, insolation = 2700 },
            },
        },
    },
}

local function nonempty(name, value)
    if type(value) ~= "string" or #value == 0 then
        error("rules.round." .. name .. " must be a non-empty string")
    end
end

for _, key in ipairs({
    "announcer",
    "channel",
    "briefing",
    "survive_objective",
    "quiet_ending",
    "revealed_ending",
    "success",
    "failure",
}) do
    nonempty(key, round[key])
end
local function wait_ticks(name, value)
    if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or value > 1200 then
        error("rules.round." .. name .. " must be an integer from 1 to 1200 ticks")
    end
end
wait_ticks("arm_after_ticks", round.arm_after_ticks)
wait_ticks("retry_ticks", round.retry_ticks)
if (round.steal_target == nil) ~= (round.steal_objective == nil) then
    error("rules.round steal_target and steal_objective must be declared together")
end
if round.steal_target ~= nil then
    nonempty("steal_target", round.steal_target)
    nonempty("steal_objective", round.steal_objective)
end

if sim ~= nil then
    if round.steal_target ~= nil then
        -- Definition-stage projection makes a typo a load-only failure. No
        -- handler or random stream runs while this dependency is checked.
        sim.require("item", round.steal_target)
    end
    -- The assignment is the round's authoritative secret: server-only
    -- replication until the pack itself reveals it (docs/SCRIPTING.md
    -- §8.1). Declaring it is what makes the write legal at all.
    sim.define("script_var", "lunatic/tfs:round_assignment", { replicate = "server" })
    sim.define("message", "lunatic/tfs:round_briefing", {
        template = round.briefing,
        placeholders = { "objective" },
    })
    sim.define("message", "lunatic/tfs:round_quiet", {
        template = round.quiet_ending,
        placeholders = {},
    })
    sim.define("message", "lunatic/tfs:round_reveal", {
        template = round.revealed_ending,
        placeholders = { "name", "objective", "verdict" },
    })
    local behavior = sim.define("behavior", "lunatic/tfs:space_station_round", {
        prototype = content.id,
    })

    behavior:handle("round.start", { kind = "react" }, function()
        sim.spawn_task("round", function()
            local remaining = round.arm_after_ticks - sim.tick()
            if remaining > 0 then
                sim.sleep(remaining)
            end
            while true do
                -- tg filters willing living clients before shuffling, then
                -- promotes chosen clients to Minds:
                -- code/controllers/subsystem/dynamic/_dynamic_ruleset.dm:273-308
                -- code/controllers/subsystem/dynamic/_dynamic_ruleset.dm:231-241
                local candidates = sim.query.eligible_minds()
                if #candidates > 0 then
                    local mind = candidates[math.floor(sim.random("round_draw") * #candidates) + 1]
                    local objective = {
                        kind = "survive",
                        text = round.survive_objective,
                    }
                    if round.steal_target ~= nil and sim.query.any(round.steal_target) then
                        objective = {
                            kind = "hold",
                            target = round.steal_target,
                            text = round.steal_objective,
                        }
                    end
                    -- Role continuity attaches to the Mind, not its current body:
                    -- code/controllers/subsystem/dynamic/dynamic_ruleset_roundstart.dm:34-44
                    -- code/datums/mind/_mind.dm:35-53
                    mind.vars.round_assignment = objective
                    sim.message.notify({
                        audience = mind,
                        message = sim.msg("lunatic/tfs:round_briefing", {
                            objective = objective.text,
                        }),
                    })
                    return
                end
                sim.sleep(round.retry_ticks)
            end
        end)
    end)

    behavior:handle("round.end", { kind = "react" }, function()
        local assigned = nil
        for _, mind in ipairs(sim.query.minds()) do
            if mind.vars.round_assignment ~= nil then
                if assigned ~= nil then
                    error("multiple Minds carry the single round assignment")
                end
                assigned = mind
            end
        end
        local summary = sim.msg("lunatic/tfs:round_quiet", {})
        local success = false
        if assigned ~= nil then
            local objective = assigned.vars.round_assignment
            success = assigned.alive
            if objective.kind == "hold" then
                -- Objective ownership and end evaluation remain Mind-scoped:
                -- code/modules/antagonists/_common/antag_datum.dm:6-24
                -- code/game/gamemodes/objective.dm:680-703
                success = success and assigned:contains(objective.target)
            else
                -- code/game/gamemodes/objective.dm:558-568
                success = success and objective.kind == "survive"
            end
            summary = sim.msg("lunatic/tfs:round_reveal", {
                name = assigned.name,
                objective = objective.text,
                verdict = success and round.success or round.failure,
            })
        end
        -- tg's end report reveals the antagonist and objective to the round:
        -- code/modules/antagonists/traitor/datum_traitor.dm:248-298
        sim.message.notify({
            audience = "all",
            sender = round.announcer,
            channel = round.channel,
            message = summary,
        })
        -- The shift's outcome as data, for the ledger row native
        -- finalization writes. Nothing reads it back into the round.
        if assigned == nil then
            return { outcome = "quiet" }
        end
        return {
            outcome = "revealed",
            name = assigned.name,
            objective = assigned.vars.round_assignment.kind,
            verdict = success and round.success or round.failure,
        }
    end)
end

return content
