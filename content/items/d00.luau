-- Ten sides that read as tens. tg: "Works better for d100 rolls than a
-- golf ball." (`/obj/item/dice/d00`, code/game/objects/items/dice.dm:
-- 218-222), and it is the d10's other half -- rolled together they are
-- a percentile, which is why the bag carries both (items/dice_bag.luau).
--
-- THE FACE AND THE READING ARE DIFFERENT THINGS, and this is the only
-- die where that is true. tg rolls 1..10 like every other ten-sider,
-- paints the overlay from the RAW result -- `"[icon_state]-[result]"`,
-- dice.dm:114-116, so the cell is `d00-7` -- and only then runs the
-- number through `manipulate_result`, which returns `(original - 1) * 10`
-- (dice.dm:222-223). So the seventh cell is the one showing 60.
--
-- The port keeps both halves separate for the same reason tg does: the
-- appearance STATE is the cell (1..10, exactly as on the d10), and
-- `reading()` is what a player is told. Naming the states "0".."90"
-- would have been a nicer sentence and a lie about which picture is
-- baked, and this pack's rule is that a state resolves to one cell that
-- was checked at load.
--
-- ORDER MATTERS, and it is tg's: the remark is decided on the RAW roll,
-- before the tens are applied (dice.dm:90-93 runs above dice.dm:98). A
-- d00 landing on its first face therefore reads "0" and still earns
-- "Ouch, bad luck." -- which is correct, because rolling the bottom of
-- a ten-sider is exactly the thing the remark is about.
--
-- d6.luau is the family header: two hooks, one state per face, the
-- picture following the roll.
local SIDES = 10

-- tg's `#define MIN_SIDES_ALERT 5` (dice.dm:1-3). Ten is over it.
local MIN_SIDES_ALERT = 5

local function comment(face)
    if SIDES > MIN_SIDES_ALERT and face == 1 then
        return " Ouch, bad luck."
    end
    return ""
end

-- tg's `manipulate_result` (dice.dm:222-223): 0, 10, 20 ... 90.
local function reading(face)
    return (face - 1) * 10
end

local content = {
    id = "d00",
    name = "d00",
    sprite = "d00",
    -- The CELLS, not the readings. See the header.
    states = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
    -- Minted on the tenth cell -- ninety -- which is the face
    -- `sprite = "d00"` is baked showing.
    state = "10",
    state_sprites = {
        ["1"] = "d00_1",
        ["2"] = "d00_2",
        ["3"] = "d00_3",
        ["4"] = "d00_4",
        ["5"] = "d00_5",
        ["6"] = "d00_6",
        ["7"] = "d00_7",
        ["8"] = "d00_8",
        ["9"] = "d00_9",
        ["10"] = "d00_10",
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local face = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = user.tile })
        sim.appearance.set_state({ entity = self, state = tostring(face) })
        sim.message.send({ recipient = user, message = "You roll the d00. It lands on " .. reading(face) .. "." .. comment(face) })
        return true
    end)
    script_definition:handle("throw.land.done", { kind = "react", route = "land" }, function(ev)
        local self, user, x, y = ev.entity, ev.thrower, ev.at.x, ev.at.y
        local face = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = ev.at })
        sim.appearance.set_state({ entity = self, state = tostring(face) })
        sim.message.send({ recipient = user, message = "The d00 rolls to a stop, landing on " .. reading(face) .. "." .. comment(face) })
    end)
end

return content
