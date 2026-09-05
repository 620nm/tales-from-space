-- Four sides. tg calls it "the nerd's caltrop" and means it literally:
-- `/obj/item/dice/d4` fits a caltrop component that does 1-4 brute to
-- anybody who walks over it (code/game/objects/items/dice.dm:132-142).
-- Deliberately not ported -- a caltrop is a check on the MOVEMENT seam,
-- one rule for every sharp thing on the deck, not a hook a single die
-- carries. The die ships; the tack in the carpet waits for the seam.
--
-- The rest is d6.luau, which is this family's header: two hooks because
-- tg rolls at exactly two moments (`attack_self` in the hand and
-- `throw_impact` where it lands, dice.dm:68-75), one declared appearance
-- state per face, and the picture following the roll rather than being
-- pasted onto an icon name. Read that file for the whole of why.
--
-- WHAT IS MISSING HERE and is present on every bigger die: the remark.
-- tg only comments on a roll when `sides > MIN_SIDES_ALERT` (5,
-- dice.dm:1-3, 90-91), and four is under it -- rolling the worst face
-- one time in four is not bad luck, it is Tuesday. So this file has no
-- `comment` function at all, and that absence is the port.
local SIDES = 4

local content = {
    id = "d4",
    name = "d4",
    sprite = "d4",
    states = { "1", "2", "3", "4" },
    -- Minted on four: the face `sprite = "d4"` is baked showing.
    state = "4",
    state_sprites = {
        ["1"] = "d4_1",
        ["2"] = "d4_2",
        ["3"] = "d4_3",
        ["4"] = "d4_4",
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = user.tile })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.d4.roll", { face = result }),
        })
        return true
    end)
    script_definition:handle("throw.land.done", { kind = "react", route = "land" }, function(ev)
        local self, user, x, y = ev.entity, ev.thrower, ev.at.x, ev.at.y
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = ev.at })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.d4.land", { face = result }),
        })
    end)
end

return content
