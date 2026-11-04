local bloodshed = require("@lib/bloodshed")
local disinfection = require("@lib/medical/disinfection")
local fall = require("@lib/fall")
local ignition = require("@lib/ignition")

sim.define("message", "lunatic/tfs:lib.illness.sneeze", { placeholders = { "name" } })
sim.define("message", "lunatic/tfs:lib.illness.cough", { placeholders = { "name" } })
sim.define("message", "lunatic/tfs:lib.illness.sore_throat", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.illness.mucus", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.illness.feels_better", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.analyzer_pathogens.rhinovirus_body", {
    placeholders = { "name", "stage", "max_stages" },
})
sim.define("message", "lunatic/tfs:lib.analyzer_pathogens.rhinovirus_vessel", {
    placeholders = { "name" },
})
sim.define("message", "lunatic/tfs:lib.analyzer_pathogens.none", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.body_drag.hide_start", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.body_drag.stuff_start", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.climbing.start", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.climbing.completed", { placeholders = {} })
sim.define("message", "lunatic/tfs:lib.climbing.failed", { placeholders = {} })

-- Reasons the engine reports on `climb.done`, then the pack's own veto reasons
-- (`lib/climbing.luau`).
local climb_refusals = {
    "body_unavailable",
    "body_in_motion",
    "support_unavailable",
    "different_plane",
    "out_of_reach",
    "not_disclosed",
    "inaccessible",
    "not_climbable",
    "not_dense",
    "same_tile",
    "reserved",
    "blocked",
    "cross_vetoed",
    "offset_out_of_range",
    "not_applied",
    "body_not_controllable",
    "body_observer",
}
for _, reason in ipairs(climb_refusals) do
    sim.define("message", "lunatic/tfs:lib.climbing.refused." .. reason, { placeholders = {} })
end

-- The shift's fire record.
--
-- `matter.ignition.done` and `matter.extinguished.done` are the matter
-- kernel's own edges: a tile crossed from not-firing to firing, or back
-- again. Nothing here decides whether a fire happens -- the rules in
-- `reactions/` say what burns and the physics says when -- this only
-- keeps the count the end of a shift wants to read. A count of what the
-- whole station did belongs to the round, not to any one thing on it.
sim.define("script_var", "lunatic/tfs:fires_lit", { replicate = "server" })
sim.define("script_var", "lunatic/tfs:fires_out", { replicate = "server" })
sim.define("script_var", "lunatic/tfs:marker_weight", { replicate = "server" })
sim.define("script_var", "lunatic/tfs:marker_jobs", { replicate = "server" })
sim.define("script_var", "lunatic/tfs:marker_roles", { replicate = "server" })
sim.define("script_var", "lunatic/tfs:spawn_role", { replicate = "server" })

local function tally(key)
    return function(_ev)
        sim.script_var.set({
            scope = "round",
            key = key,
            value = (sim.var("round", key) or 0) + 1,
        })
    end
end

sim.handle("matter.ignition.done", { kind = "react" }, tally("fires_lit"))
sim.handle("matter.extinguished.done", { kind = "react" }, tally("fires_out"))

-- What lights a tile (`content/lib/ignition.luau`): a fire tends and
-- spreads from the edge that lit it, and a cut power run sparks, whoever
-- cut it. Unscoped for the same reason as the tallies above.
sim.define("script_var", "lunatic/tfs:flame_tended", { replicate = "server" })
sim.handle("matter.ignition.done", { kind = "react" }, ignition.on_ignited)
sim.handle("flow.segment_split.done", { kind = "react" }, function(ev: FlowSegmentSplitDonePayload)
    if ev.network == "power" then
        ignition.spark(ev.at)
    end
end)

-- Every wound, one answer: bleed stacks on the worst-hurt part, the
-- flesh-impact sound, the spilled blood as matter and the splatter
-- mark (`content/lib/bloodshed.luau`, which owns the gates and the
-- numbers). Subscribed here because a wound belongs to no prototype —
-- the same reason the fire tallies above live here rather than on a
-- thing that burns.
sim.handle("damage.resolved.done", { kind = "react" }, bloodshed.on_wound)

-- Every body and item over an open hole falls, as in tg (`content/lib/fall.luau`
-- cites it). Unscoped on purpose: the engine counts transformers across
-- the whole pack and the current mode, and two answers would leave only
-- the engine's guess, so no gamemode file binds `motion.fall` as well. The
-- landing line is the item's own; a flight of stairs catches a one-level
-- fall and tumbles a body out cold or staggered that nobody pulled.
sim.handle("motion.fall", { kind = "transform", route = "lifecycle" }, fall.answer)
sim.handle("motion.land.done", { kind = "react", route = "land" }, fall.on_land)
sim.define("message", "lunatic/tfs:lib.fall.landed", { placeholders = { "item" } })
sim.define("message", "lunatic/tfs:lib.fall.down_stairs", { placeholders = {} })
sim.event("lunatic/tfs:disinfection.chunk", {
    family = "notification",
    payload = { page = "number" },
})
sim.handle("lunatic/tfs:disinfection.chunk", { kind = "react" }, disinfection.on_chunk)
sim.handle("clock.second", { kind = "react" }, disinfection.on_second)

-- The shift clock's own words. `content/lib/shift.luau` is the policy
-- and every `gamemodes/` file declares the numbers; what lives here is
-- what the pack DECLARES rather than what it decides. The shift keeps
-- no state of its own: the elapsed second it is handed is the whole
-- input, and round-scoped state would stop being legal at exactly the
-- moment finalization starts reading it.
--
-- Each line is one finished sentence with its values passed in, never a
-- fragment another site frames (docs/LOCALIZATION.md §5). The last
-- minute gets its own line rather than a plural carrying a one. What
-- each one SAYS is in `locale/<tag>.json` beside every other word this
-- pack has; declared here because the shift's keys are the pack's own
-- vocabulary whether or not a language renders them.
sim.define("message", "lunatic/tfs:shift_warning", { placeholders = { "minutes" } })
sim.define("message", "lunatic/tfs:shift_final_minute", { placeholders = {} })
sim.define("message", "lunatic/tfs:shift_over", { placeholders = {} })
