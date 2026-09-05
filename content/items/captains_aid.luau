-- The Captain's Aid: "Every captain's greatest ally when exploring the
-- vast emptiness of space, now with a color display!" -- tg's
-- `/obj/item/toy/captainsaid` (code/game/objects/items/toys.dm:398-428).
--
-- It points at a side of the ship. That is the whole product. A player
-- clicks it, it advances to the next direction, and after the last one
-- it turns itself off again -- and then it does that forever, because
-- the joke is that the Aid aids nothing.
--
-- WHY THIS ITEM IS HERE and the rest of the Good Clean Fun Toys shelf
-- is not: it is exactly one dial and one picture per position, which
-- are two mechanisms this engine already has. Nothing is invented for
-- it. The other two things tg stocks beside it need machinery that
-- does not exist -- the Intento is a Simon-says game with a remembered
-- sequence and a per-tick state machine (toys.dm:1627+), and the tail
-- pin box is posters and pins. See machines/games_vendor.luau for the
-- rest of that ruling.
--
-- THE DIAL IS THE ENGINE'S, NOT THIS FILE'S. `modes = 5` mints an
-- anonymous five-position selector per instance and `sim.set_mode`
-- turns it; a number the prototype never declared is refused natively,
-- so the wrap below cannot walk off the end even if this hook is
-- wrong. tg keeps the same state in `current_mode` and does its own
-- bounds check in the hook (toys.dm:420-427) -- one of the two is
-- load-bearing and it is not the one written in the toy.
--
-- Modes are 0-BASED here and 1-based in tg. tg's list starts with
-- "off" at index 1 (`CAPTAINSAID_MODE_OFF`, toys.dm:396); ours starts
-- with "off" at 0, and the roster below is in tg's order so the two
-- files read side by side.
local DIRECTIONS = { "off", "port", "starboard", "fore", "aft" }

local content = {
    id = "captains_aid",
    name = "Captain's Aid",
    -- The resting picture is the off one, which is also the state a
    -- fresh unit mints in: an Aid out of the machine is switched off.
    sprite = "captains_aid",
    modes = #DIRECTIONS,
    mode = 0,
    -- One appearance state per dial position, named for tg's own mode
    -- words. The dial and the picture are separate mechanisms that the
    -- hook below keeps in step -- which is deliberate: `modes` is what
    -- the item IS set to, `states` is what it LOOKS like, and an item
    -- whose look did not follow its setting would still be correctly
    -- set. tg conflates them by writing `icon_state` from the mode list
    -- (toys.dm:427) and gets the same result one line earlier.
    states = DIRECTIONS,
    state = "off",
    state_sprites = {
        ["off"] = "captains_aid_off",
        ["port"] = "captains_aid_port",
        ["starboard"] = "captains_aid_starboard",
        ["fore"] = "captains_aid_fore",
        ["aft"] = "captains_aid_aft",
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = sim.mode(self)
        -- `dial.count` is what the ENGINE minted from `modes`, not
        -- `#DIRECTIONS`: reading the count back means the wrap is
        -- computed against the dial that actually exists.
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        local direction = DIRECTIONS[next_index + 1]
        sim.appearance.set_state({ entity = self, state = direction })
        sim.sound.play({ asset = "lunatic/tfs:sound/switch_click", at = user.tile })
        if direction == "off" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.captains_aid.you_switch_the_captain_s", {}),
            })
        else
            sim.message.send({
                recipient = user,
                message = "The Captain's Aid points " .. direction .. ".",
            })
        end
        return true
    end)
end

return content
