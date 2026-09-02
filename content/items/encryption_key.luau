-- An encryption key: the stock part that lends a transceiver its
-- channel (machines/transceiver.luau), and -- carried loose -- a radio
-- of its own.
--
-- tg's `/obj/item/encryptionkey` family is one blank cylinder and a
-- row of pre-cut department issues that headsets swallow
-- (code/game/objects/items/devices/radio/encryption_keys.dm). Here the
-- socket it fills is the tower's rather than the headset's, and the
-- `radio` half is the same field the headset itself declares
-- (docs/content-schema/radio.md): declaring a channel is what makes a
-- thing a radio at all, so a department key in a pocket talks and
-- hears on its word exactly as a headset does. That is intended -- the
-- key IS the radio; the tower is just the biggest thing you can plug
-- one into.
--
-- The blank base declares NO channel on purpose: a key stamped with
-- nothing is silent in a pocket and silent in a tower, and it is the
-- plain rung every mapped socket arrives holding
-- (docs/MAP-PROPERTIES.md, the property sheet). There is one tier and
-- there is not meant to be a second -- nothing about carrying a word
-- is done better by a nicer key (the network card's argument,
-- items/network_card.luau).
local content = {
    id = "encryption_key",
    name = "encryption key",
    sprite = "encryption_key",
    category = "machine components",
    examine = {
        flavor = "A stubby cylinder of cipher circuitry. The word cut "
            .. "into it is the channel it talks on; blank, it says nothing.",
    },
    component = { kind = "encryption", tier = 1, efficiency = stock_parts.efficiency[1] },
    -- The department issues override ONLY the words, the picture and
    -- the channel. Never `component`: overriding a tier or an
    -- efficiency claims a rung of the ladder, and a key ladder with a
    -- rung per department would let a swap "upgrade" Lifeline into
    -- Wrench (docs/content-schema/variants.md).
    variants = {
        engineering = {
            name = "encryption key (" .. radio.channels.engineering .. ")",
            sprite = "encryption_key_eng",
            radio = radio.channels.engineering,
        },
        medical = {
            name = "encryption key (" .. radio.channels.medical .. ")",
            sprite = "encryption_key_med",
            radio = radio.channels.medical,
        },
        security = {
            name = "encryption key (" .. radio.channels.security .. ")",
            sprite = "encryption_key_sec",
            radio = radio.channels.security,
        },
        command = {
            name = "encryption key (" .. radio.channels.command .. ")",
            sprite = "encryption_key_com",
            radio = radio.channels.command,
        },
        common = {
            name = "encryption key (" .. radio.channels.common .. ")",
            sprite = "encryption_key_common",
            radio = radio.channels.common,
        },
    },
}

if sim ~= nil then
    -- A line transmitted THROUGH a carried key is delivered by this
    -- pack's signal policy rather than station-wide: `speech.radio` is
    -- scoped to the transmitting item's prototype, variants inherit
    -- the base's handler, and the policy itself lives in `lib/radio.luau`
    -- beside every number it reads (docs/luau-api/speech-radio.md).
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("speech.radio", { kind = "transform", route = "item" }, function(ev)
        return radio.deliver(ev)
    end)
end

return content
