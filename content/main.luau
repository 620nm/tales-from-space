-- Script-visible sound resources. The namespaced registry id is the command
-- capability; `asset` is the logical delivery key baked from assets/sounds.ron.
-- Keeping the mapping in content means Rust validates ownership without
-- learning any Tales from Space vocabulary.
local sounds = {
    "card_flip",
    "card_shuffle",
    "click",
    "crowbar",
    "crowbar_pry",
    "dice_roll",
    "drink",
    "glass_break",
    "ratchet",
    "smash",
    "spray",
    "switch_click",
    "vend",
    "wirecutter",
}

for _, asset in sounds do
    sim.define("sound", "lunatic/tfs:sound/" .. asset, { asset = asset })
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
