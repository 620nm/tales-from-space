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
