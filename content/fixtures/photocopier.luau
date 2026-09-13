-- The copier's player actions are native jobs. This fixture only translates
-- the pack's button vocabulary into those generic helpers.
-- tg code/modules/paperwork/photocopier.dm:281-379, :386-464, :548-619.
local content = { id = "photocopier" }

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:photocopier_count", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:photocopier_color", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:photocopier_failed", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:photocopier_reason", { replicate = "server" })
    local function resource(machine, id)
        for _, row in ipairs(sim.resources.read(machine)) do
            if row.id == id then return row.current end
        end
        return 0
    end
    local function preview(machine)
        local source = machine:item_slot("media")
        if source == nil then return {} end
        local ok, document = pcall(sim.documents.read, source, 0)
        if not ok or document == nil then return {} end
        return writing.fragments(document)
    end
    local function view(machine)
        return {
            kind = "copier", name = machine.name, powered = sim.is_powered(machine),
            original = preview(machine), count = machine.vars.photocopier_count or 1,
            mode = machine.vars.photocopier_color or "bw",
            busy = sim.documents.status(machine) ~= nil,
            paper = resource(machine, "paper"), toner = resource(machine, "toner"),
            failed = machine.vars.photocopier_failed == true,
            reason = machine.vars.photocopier_reason,
        }
    end
    local function open(machine, viewer)
        ui.open({ viewer = viewer, owner = machine, channel = "copier", view = view(machine), actions = {
            set_count = 8, set_color = 8, copy = 16, eject = 8,
        }, presentation_key = "writing/copier" })
    end
    local function update(machine, viewer)
        ui.update({ viewer = viewer, owner = machine, channel = "copier", view = view(machine), actions = {
            set_count = 8, set_color = 8, copy = 16, eject = 8,
        } })
    end
    local function update_all(machine)
        ui.update_all({ owner = machine, channel = "copier", view = view(machine), actions = {
            set_count = 8, set_color = 8, copy = 16, eject = 8,
        } })
    end
    local function refresh_after_admission(machine)
        -- Admission reserves stock and marks the endpoint busy in the native
        -- job transaction. Reproject once after that commit so the panel does
        -- not show the pre-admission idle snapshot.
        sim.spawn_task(machine, function()
            sim.sleep(1)
            update_all(machine)
        end)
    end
    local behavior = sim.define("behavior", "lunatic/tfs:photocopier", { prototype = content.id })

    behavior:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local target = ev.claim and ev.claim.entity
        local held = ev.implement
        if held == nil and (target == nil or target == ev.subject or (target ~= nil and target.prototype == content.id)) then
            open(ev.subject, ev.actor)
            return true
        end
        if held ~= nil and held.prototype == "toner_cartridge" then
            sim.resources.transfer({ from = held, to = ev.subject, resource = printing.toner })
            update(ev.subject, ev.actor)
            return true
        end
        if held ~= nil and held.prototype == "paper_bin" then
            sim.resources.transfer({ from = held, to = ev.subject, resource = printing.paper })
            update(ev.subject, ev.actor)
            return true
        end
        if held == nil or held.prototype ~= "paper" then return { replaced = false } end
        sim.item_slot.insert({ subject = ev.subject, item = held, slot = "media" })
        open(ev.subject, ev.actor)
        refresh_after_admission(ev.subject)
        return true
    end)

    behavior:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        local machine = ev.subject
        if ev.action == "set_count" then
            local count = tonumber(ev.value)
            if count and count % 1 == 0 and count >= 1 and count <= printing.max_copies then
                machine.vars.photocopier_count = count
            end
            update(machine, ev.actor)
            return true
        end
        if ev.action == "set_color" then
            local mode = ev.value
            if mode == "bw" or mode == "color" then machine.vars.photocopier_color = mode end
            update(machine, ev.actor)
            return true
        end
        if ev.action == "copy" then
            local source = machine:item_slot("media")
            if source == nil then
                machine.vars.photocopier_failed = true
                machine.vars.photocopier_reason = "no_source"
                update(machine, ev.actor)
                return true
            end
            local readable, snapshot = pcall(sim.documents.read, source, 0)
            if not readable or snapshot == nil then
                machine.vars.photocopier_failed = true
                machine.vars.photocopier_reason = "unreadable_source"
                update(machine, ev.actor)
                return true
            end
            local count = machine.vars.photocopier_count or 1
            if type(count) ~= "number" or count % 1 ~= 0
                or count < 1 or count > printing.max_copies then return true end
            machine.vars.photocopier_failed = nil
            machine.vars.photocopier_reason = nil
            local accepted, reason = pcall(function()
                sim.documents.start({
                    machine = machine,
                    source = { store = source, uid = 0, expected_revision = snapshot.revision },
                    output = "paper", ext = "md", stem = "paper1",
                    duration_ticks = printing.copy_ticks,
                    count = count,
                    eject_input = false,
                    color = (machine.vars.photocopier_color == "color") and "preserve" or "monochrome",
                    costs = printing.costs(),
                })
            end)
            if not accepted then
                machine.vars.photocopier_failed = true
                machine.vars.photocopier_reason = "admission_failed"
            end
            update(machine, ev.actor)
            if accepted then refresh_after_admission(machine) end
            return true
        end
        if ev.action == "eject" then
            sim.item_slot.eject({ subject = machine, slot = "media" })
            update(machine, ev.actor)
            return true
        end
        return { replaced = false }
    end)

    -- Native jobs publish one private completion for every batch. Refreshing
    -- from that fact keeps the UI honest through partial late failures.
    sim.handle("documents.operation.done", { kind = "react" }, function(ev)
        if ev.self.prototype ~= content.id then return end
        if ev.outcome == "completed" then
            ev.self.vars.photocopier_failed = nil
            ev.self.vars.photocopier_reason = nil
        else
            ev.self.vars.photocopier_failed = true
            ev.self.vars.photocopier_reason = ev.reason or "operation_failed"
        end
        update_all(ev.self)
    end)

    -- Slot and stock commands commit after the interaction handler returns.
    -- These global edges refresh every open panel from committed native state.
    local function refresh_machine(machine)
        if machine == nil or machine.prototype ~= content.id then return end
        update_all(machine)
    end
    sim.handle("item_slot.changed.done", { kind = "react" }, function(ev)
        refresh_machine(ev.subject)
    end)
    sim.handle("resources.transfer.done", { kind = "react" }, function(ev)
        refresh_machine(ev.from)
        refresh_machine(ev.to)
    end)
end

return content
