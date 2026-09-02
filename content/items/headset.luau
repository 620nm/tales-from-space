-- Common-channel radio headset: carrying one anywhere on you is what
-- makes ';' speak on the radio (docs: closeout step 6d).
--
-- `radio` is BOTH halves of that: declaring a channel is what makes
-- this a radio at all, and the channel's name is the word every
-- listener sees the line bracketed with. The engine knows neither the
-- word "headset" nor the word "Common" -- it asks what you are carrying
-- and stamps the line with whatever the item answered.
local content = {
    id = "headset",
    name = "radio headset",
    sprite = "headset",
    inhand_sprite = { "held_headset_l", "held_headset_r" },
    radio = radio.channels.common,
}

if sim ~= nil then
    -- Without this handler a headset line lands station-wide (the
    -- engine default, docs/content-schema/radio.md). With it, Common is
    -- a signal like every other channel: a few rooms on its own, the
    -- station only where a powered, Common-keyed transceiver carries it
    -- (lib/radio.luau, machines/transceiver.luau).
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("speech.radio", { kind = "transform", route = "item" }, function(ev)
        return radio.deliver(ev)
    end)
end

return content
