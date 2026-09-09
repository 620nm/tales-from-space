-- Lid, power and cartridge gestures: tg laptop.dm:68-105 (a closed lid
-- answers self-use with the lid alone), computer.dm:564 (the power
-- button is its own press), computer.dm:557-562 (disk eject).
-- Desktop policy and where this departs from tg are in docs/LAPTOP.md.
local WALLPAPERS = { "wallpaper_bliss", "wallpaper_moonlake" }

local content = {
    id = "laptop",
    name_label = "lunatic/tfs:entity.laptop.name",
    name = "laptop",
    sprite = "laptop_closed",
    state = "closed",
    states = { "closed", "off", "on" },
    state_sprites = {
        closed = "laptop_closed", off = "laptop_off", on = "laptop_on",
    },
    gestures = {
        "secondary", "alt_primary", "shift_ctrl_primary", "shift_ctrl_secondary",
    },
    -- What is in the two slots, so an eject row is offered only when
    -- there is something to eject.
    hint_flags = { "media", "card" },
    interaction_labels = {
        -- A hand holding something the laptop takes is there to put it
        -- in, not to pick the laptop up.
        primary = { label = "lunatic/tfs:ui.affordance.take", held = {
            floppy = "lunatic/tfs:ui.affordance.insert_disk",
            card = "lunatic/tfs:ui.affordance.insert_id",
        } },
        -- One press, one step: the lid, then the power button, then the
        -- screen. Each state says which step this gesture is now.
        self = { label = "lunatic/tfs:ui.affordance.view_interface", states = {
            closed = "lunatic/tfs:ui.affordance.open_lid",
            off = "lunatic/tfs:ui.affordance.power_on",
        } },
        secondary = { label = "lunatic/tfs:ui.affordance.view_interface", states = {
            closed = "lunatic/tfs:ui.affordance.open_lid",
            off = "lunatic/tfs:ui.affordance.power_on",
        } },
        alt_primary = { label = "lunatic/tfs:ui.desktop.close_lid", states = {
            closed = false,
        } },
        shift_ctrl_primary = {
            label = "lunatic/tfs:ui.affordance.eject_cartridge",
            only_when = { "media" },
        },
        shift_ctrl_secondary = {
            label = "lunatic/tfs:ui.affordance.eject_id",
            only_when = { "card" },
        },
    },
    acts_on_items = true,
    drive = { accepts = { "floppy" } },
    files = { capacity = 65536, files = 16 },
    ui = { modules = { "files", "editor" } },
    card_slot = { equipment = "id" },
}

content.actions = {
    action_rules.primary("connect", action_rules.fact("target.has_network", true),
        action_rules.fact("held.state", "on")),
    {
        id = "insert_disk", gesture = "primary", route = "receiver", uses_held = true,
        label = "lunatic/tfs:ui.affordance.insert_disk",
        held = action_rules.fact("held.tag", "floppy"),
    },
    {
        id = "insert_id", gesture = "primary", route = "receiver", uses_held = true,
        label = "lunatic/tfs:ui.affordance.insert_id",
        held = action_rules.fact("held.tag", "card"),
    },
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

    -- The lid alone: a laptop that kept its charge comes up lit, an
    -- unpowered one shows a dark screen until the power button.
    local function raise(self)
        local powered = self.vars.laptop_powered == true
        sim.appearance.set_state({ entity = self, state = if powered then "on" else "off" })
    end

    local function switch(self, powered, at)
        self.vars.laptop_powered = powered
        sim.appearance.set_state({ entity = self, state = if powered then "on" else "off" })
        sound(if powered then "computer_start" else "computer_end", at)
        refresh(self, powered)
    end

    -- The screen: the file workspace composes only while the machine is
    -- running, so an unpowered desktop opens without native disclosure.
    local function view_interface(self, user)
        local powered = self.vars.laptop_powered == true
        local view, actions = document(self, powered)
        ui.open({
            viewer = user, owner = self, view = view, actions = actions,
            include_native = powered,
        })
    end

    behavior:handle("entity.initialize.done", { kind = "react" }, function(ev)
        local self = ev.entity
        local index = 1 + math.floor(sim.random_for("wallpaper", self) * #WALLPAPERS)
        self.vars.laptop_wallpaper = WALLPAPERS[index]
        self.vars.laptop_powered = false
    end)

    behavior:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self = ev.subject
        if ev.gesture == "alt_primary" then
            if self.state ~= "closed" then close(self) end
        elseif ev.gesture == "shift_ctrl_primary" then
            if self:item_slot("media") ~= nil then
                sim.item_slot.eject({ subject = self, slot = "media" })
            end
        elseif ev.gesture == "shift_ctrl_secondary" then
            if self:item_slot("card") ~= nil then
                sim.item_slot.eject({ subject = self, slot = "card" })
            end
        elseif self.state == "closed" then
            raise(self)
        elseif self.vars.laptop_powered ~= true then
            switch(self, true, ev.at)
        else
            view_interface(self, ev.actor)
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
        -- The eject rows are offered off what is in the slots, so the
        -- flags follow every insertion and every ejection.
        sim.hints.set_flag({
            entity = ev.subject,
            flag = if ev.slot == "card" then "card" else "media",
            on = ev.subject:item_slot(ev.slot) ~= nil,
        })
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
        ui.open({
            viewer = ev.actor, owner = target, contact = self, contact_state = "on",
            channel = "programming", view = { kind = "programming" }, actions = {},
            include_native = true,
        })
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
            switch(self, self.vars.laptop_powered ~= true, ev.at)
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
