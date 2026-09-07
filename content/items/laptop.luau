-- Lid and cartridge gestures: tg laptop.dm:68-122, computer.dm:557-562.
-- Desktop policy and the deliberate one-step boot are in docs/LAPTOP.md.
local WALLPAPERS = { "wallpaper_bliss", "wallpaper_moonlake" }

local content = {
    id = "laptop",
    name = "laptop",
    sprite = "laptop_closed",
    state = "closed",
    states = { "closed", "off", "on" },
    state_sprites = {
        closed = "laptop_closed", off = "laptop_off", on = "laptop_on",
    },
    gestures = { "secondary", "alt", "ctrl_shift" },
    interaction_labels = {
        primary = { label = "lunatic/tfs:ui.affordance.take" },
        self = { label = "lunatic/tfs:ui.affordance.view_interface", states = {
            closed = "lunatic/tfs:ui.affordance.open_lid",
        } },
        secondary = { label = "lunatic/tfs:ui.affordance.view_interface", states = {
            closed = "lunatic/tfs:ui.affordance.open_lid",
        } },
        alt = { label = "lunatic/tfs:ui.affordance.close_lid", states = {
            closed = "lunatic/tfs:ui.affordance.lid_closed",
        } },
        ctrl_shift = { label = "lunatic/tfs:ui.affordance.eject_cartridge" },
    },
    acts_on_items = true,
    drive = {},
    files = { capacity = 65536, files = 16 },
    ui = { modules = { "files", "editor" } },
    card_slot = { equipment = "id" },
}

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:laptop_wallpaper", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:laptop_powered", { replicate = "server" })
    local behavior = sim.define("behavior", "lunatic/tfs:laptop", { prototype = "laptop" })

    local function sound(asset, at)
        sim.sound.play({ asset = "lunatic/tfs:sound/" .. asset, at = at })
    end

    local function document(self, powered)
        local card = self:item_slot("card") ~= nil
        local cartridge = self:item_slot("media") ~= nil
        local view = {
            kind = "desktop",
            wallpaper = self.vars.laptop_wallpaper,
            powered = powered,
            card = card,
            cartridge = cartridge,
        }
        local actions = { power = 0, close = 0 }
        if card then actions.eject_id = 0 end
        if cartridge then actions.eject_cartridge = 0 end
        return view, actions
    end

    local function refresh(self, powered)
        local view, actions = document(self, powered)
        ui.update_all({ owner = self, view = view, actions = actions, include_native = powered })
    end

    local function close(self)
        sim.appearance.set_state({ entity = self, state = "closed" })
        ui.close_all({ owner = self })
    end

    local function open(self, user, at)
        local powered = self.vars.laptop_powered == true
        if not powered then
            self.vars.laptop_powered = true
            sound("computer_start", at)
        end
        sim.appearance.set_state({ entity = self, state = "on" })
        refresh(self, true)
        local view, actions = document(self, true)
        ui.open({ viewer = user, owner = self, view = view, actions = actions, include_native = true })
    end

    behavior:handle("entity.initialize.done", { kind = "react" }, function(ev)
        local self = ev.entity
        local index = 1 + math.floor(sim.random_for("wallpaper", self) * #WALLPAPERS)
        self.vars.laptop_wallpaper = WALLPAPERS[index]
        self.vars.laptop_powered = false
    end)

    behavior:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self = ev.subject
        if ev.gesture == "alt" then
            if self.state ~= "closed" then close(self) end
        elseif ev.gesture == "ctrl_shift" then
            if self:item_slot("media") ~= nil then
                sim.item_slot.eject({ subject = self, slot = "media" })
            end
        else
            open(self, ev.actor, ev.at)
        end
        return true
    end)

    behavior:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local self, held = ev.subject, ev.implement
        if held == nil then return { replaced = false } end
        for _, slot in ipairs({ "card", "media" }) do
            if self:item_slot_accepts(slot, held) then
                sim.item_slot.insert({ subject = self, item = held, slot = slot })
                return true
            end
        end
        return true
    end)

    behavior:handle("item_slot.changed.done", { kind = "react" }, function(ev)
        if ev.outcome ~= "completed" then return end
        sound(if ev.slot == "card" then "terminal_insert_disc" else "card_slide", ev.at)
        if ev.subject.state ~= "closed" then
            refresh(ev.subject, ev.subject.vars.laptop_powered == true)
        end
    end)

    behavior:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, target = ev.subject, ev.claim and ev.claim.entity
        if self.state == "closed" or self.vars.laptop_powered ~= true
            or target == nil or sim.link_state(target) == nil then
            return { replaced = false }
        end
        local clip = 1 + math.floor(sim.random("keyboard") * 7)
        sound("keyboard_clicks_" .. tostring(clip), ev.actor.tile)
        return true
    end)

    behavior:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        local self = ev.subject
        if self.state == "closed" then return true end
        if ev.action == "close" then
            close(self)
        elseif ev.action == "power" then
            local powered = self.vars.laptop_powered ~= true
            self.vars.laptop_powered = powered
            sim.appearance.set_state({ entity = self, state = if powered then "on" else "off" })
            sound(if powered then "computer_start" else "computer_end", ev.at)
            refresh(self, powered)
        elseif ev.action == "eject_id" then
            sim.item_slot.eject({ subject = self, slot = "card" })
        elseif ev.action == "eject_cartridge" then
            sim.item_slot.eject({ subject = self, slot = "media" })
        else
            return { replaced = false }
        end
        return true
    end)
end

return content
