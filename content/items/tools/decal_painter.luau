local action_rules = require("@lib/action_rules")
local item_actions = require("@lib/item_actions")
local decal_paints = require("@lib/decal_paints")

-- The decal painter: tg's `/obj/item/airlock_painter/decal`
-- (code/game/objects/items/tools/engineering/painter/decal_painter.dm:1-30).
--
-- It lays down the markings a station is READ by: the trim round a
-- department, the hazard line across a threshold, the arrow that says
-- which way the cargo goes. What it lays down is supposed to be there,
-- so no mop takes it off. It comes off with the deck it was painted on
-- (decal_painter.dm:3, "Decals break when the floor tiles are
-- removed"), and otherwise with the eraser.
--
-- NOT PORTED: the toner cartridge. tg's painter runs on one
-- (`initial_ink_type = /obj/item/toner/large`, decal_painter.dm:9),
-- refuses when it is empty, and carries an Alt-Click to pull it. This
-- one paints free and unlimited the way `piping/pipe_painter.luau`
-- does, because a consumable needs a supply chain to mean anything and
-- this pack has no lathe to print toner at. A FOLLOW-UP, not a
-- decision against it.
--
-- tg picks decal, colour and direction out of a tgui window with a live
-- preview. We have no such window, so the choice is three dials, the
-- surface the RPD already wears (`piping/rpd.luau`). tg's fourth
-- control, the free colour wheel (`set_painting_tool_color`,
-- decal_painter.dm:135-138), is deliberately absent: the pack declares
-- `decal_colors.free.play = false`, so a raw #RRGGBB in play is refused
-- where it compiles. Free colour is a MAPPER's tool here.
local PAINTS = decal_paints.colors

type DecalChoice = { id: string, label: string, colored: boolean, facing: boolean }

-- Every decal a player may lay down, and what the dial calls it. The
-- ids are `content/compositions.luau`'s `decals` roster. The uncoloured
-- rows take no paint: the stripes and the marks carry tg's own colours
-- in their own pixels.
local DECALS: { DecalChoice } = {
    { id = "trim", label = "Trim line", colored = true, facing = false },
    { id = "trim_fill", label = "Trim line, filled", colored = true, facing = false },
    { id = "tile", label = "Tiling", colored = true, facing = false },
    { id = "hazard_line", label = "Hazard stripes", colored = false, facing = false },
    { id = "hazard_line_red", label = "Hazard stripes, red", colored = false, facing = false },
    { id = "hazard_line_white", label = "Hazard stripes, white", colored = false, facing = false },
    { id = "mark_delivery", label = "Delivery square", colored = false, facing = false },
    { id = "mark_bot", label = "Bot route", colored = false, facing = false },
    { id = "mark_loading", label = "Loading area", colored = false, facing = true },
    { id = "mark_arrow", label = "Arrow", colored = false, facing = true },
    { id = "mark_caution", label = "Caution", colored = false, facing = true },
    { id = "mark_stand_clear", label = "Stand clear", colored = false, facing = true },
}

-- The engine takes a cardinal letter; the dial says the word.
local FACING_WORDS = { "South", "North", "East", "West" }
local FACING_LETTERS = { "s", "n", "e", "w" }

-- The decks a decal may be painted on, duplicated from
-- `content/compositions.luau`'s `decal_decks` because a top-level
-- declaration file exports nothing. Keep the two lists together.
local DECKS = { "station_base", "floor_tiles", "reinforcement" }

local content = {
    interaction_labels = {
        self = { label = "lunatic/tfs:ui.affordance.view_interface" },
    },
    id = "decal_painter",
    visual_layer = "item",
    name_label = "lunatic/tfs:entity.decal_painter.name",
    name = "decal painter",
    -- tg's own art off the device sheet (`icon = 'icons/obj/devices/tool.dmi'`,
    -- `icon_state = "decal_sprayer"`, decal_painter.dm:5-7).
    sprite = "decal_painter",
    inhand_sprite = { "held_decal_painter_l", "held_decal_painter_r" },
    ui = { modules = { "dials" } },
    dials = {
        {
            key = "decal",
            label = "Decal",
            options = (function()
                local names = {}
                for index, choice in ipairs(DECALS) do
                    names[index] = choice.label
                end
                return names
            end)(),
            -- tg opens on `warningline` (decal_painter.dm:15); ours is
            -- the trim line, because a station is trimmed far more
            -- often than it is striped.
            start = 0,
        },
        {
            key = "paint",
            label = "Paint",
            options = (function()
                local names = {}
                for index, paint in ipairs(PAINTS) do
                    names[index] = paint.id
                end
                return names
            end)(),
            colors = (function()
                local hexes = {}
                for index, paint in ipairs(PAINTS) do
                    hexes[index] = paint.hex
                end
                return hexes
            end)(),
            -- tg ships `selected_color = "yellow"` (decal_painter.dm:13),
            -- the fifth entry of `lib/decal_paints.luau`'s roster.
            start = 4,
        },
        {
            key = "facing",
            label = "Facing",
            options = FACING_WORDS,
            -- tg ships `selected_dir = SOUTH` (decal_painter.dm:11).
            start = 0,
        },
    },
}

content.actions = { action_rules.primary("paint_decal", action_rules.deck(table.unpack(DECKS))) }

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    local function open_interface(ev)
        ui.open({ viewer = ev.actor, owner = ev.subject })
        return true
    end

    script_definition:handle(
        "interaction.use",
        { kind = "replace", route = "self" },
        open_interface
    )
    item_actions.attach(script_definition, {
        id = content.id,
        sprite = content.sprite,
        label = "lunatic/tfs:ui.actions.decal_painter",
    }, open_interface)

    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked = ev.claim
        local _x, _y, _choice = x, y, choice
        -- The server appends the validated clicked atom after the
        -- legacy choice slot. A deck click carries a turf or component
        -- claim and nothing else; an entity was aimed at, not a floor.
        -- A decal is never pickable in play, so a painted tile is still
        -- a bare deck click, which is what makes repainting work.
        if clicked ~= nil and clicked.entity ~= nil then
            return { replaced = false }
        end
        local decal = DECALS[assert(sim.dial(self, "decal")).index + 1]
        local paint = if decal.colored
            then PAINTS[assert(sim.dial(self, "paint")).index + 1].id
            else nil
        local facing = if decal.facing
            then FACING_LETTERS[assert(sim.dial(self, "facing")).index + 1]
            else nil
        -- One authority on whether this lands: the engine's own
        -- compile-and-probe. The handler never second-guesses it.
        if not sim.decal_installable(x, y, decal.id, paint) then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.decal_painter.nothing_to_paint_on", {}),
            })
            return true
        end
        sim.place_decal(x, y, decal.id, paint, facing)
        -- tg plays `spray2.ogg` at volume 50 out of `use_paint`
        -- (airlock_painter.dm:52-55); this roster carries no per-clip
        -- gain, so the volume is NOT PORTED.
        sim.sound.play({ asset = "lunatic/tfs:sound/paint_spray", at = ev.at })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.decal_painter.painted", { decal = decal.label }),
        })
        return true
    end)
end

return content
