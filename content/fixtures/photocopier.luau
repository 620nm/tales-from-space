local printing = require("@lib/printing")
local writing = require("@lib/writing")

-- The copier's player actions are jobs on the shared print queue
-- (lib/printing.luau). This fixture only translates the pack's button
-- vocabulary into it.
-- tg code/modules/paperwork/photocopier.dm:281-379, :386-464, :548-619.
local content = { id = "photocopier" }
local BUSY = "photocopier_busy"

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:photocopier_count", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:photocopier_color", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:photocopier_failed", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:photocopier_reason", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:photocopier_busy", { replicate = "server" })
    local function resource(machine: Handle, id: string): number
        for _, row in ipairs(sim.resources.read(machine)) do
            if row.id == id then
                return row.current
            end
        end
        return 0
    end
    local function preview(machine: Handle)
        local source = machine:item_slot("media")
        if source == nil then
            return {}
        end
        local ok, document = pcall(sim.documents.read, source, 0)
        if not ok or document == nil then
            return {}
        end
        return writing.fragments(document)
    end
    local function view(machine: Handle)
        return {
            kind = "copier",
            name = machine.name,
            powered = sim.is_powered(machine),
            original = preview(machine),
            count = machine.vars.photocopier_count or 1,
            mode = machine.vars.photocopier_color or "bw",
            busy = printing.busy(machine, BUSY),
            paper = resource(machine, "paper"),
            toner = resource(machine, "toner"),
            failed = machine.vars.photocopier_failed == true,
            reason = machine.vars.photocopier_reason,
        }
    end
    local function open(machine: Handle, viewer: Handle)
        ui.open({
            viewer = viewer,
            owner = machine,
            channel = "copier",
            view = view(machine),
            actions = {
                set_count = 8,
                set_color = 8,
                copy = 16,
                eject = 8,
            },
            presentation_key = "writing/copier",
        })
    end
    local function update(machine: Handle, viewer: Handle)
        ui.update({
            viewer = viewer,
            owner = machine,
            channel = "copier",
            view = view(machine),
            actions = {
                set_count = 8,
                set_color = 8,
                copy = 16,
                eject = 8,
            },
        })
    end
    local function update_all(machine: Handle)
        ui.update_all({
            owner = machine,
            channel = "copier",
            view = view(machine),
            actions = {
                set_count = 8,
                set_color = 8,
                copy = 16,
                eject = 8,
            },
        })
    end
    -- A job that ends before its last page (power lost, stock gone, a raise
    -- in the task) leaves its reason on the panel.
    local function stopped(machine: Handle, reason: string)
        machine.vars.photocopier_failed = true
        machine.vars.photocopier_reason = reason
        update_all(machine)
    end
    local behavior = sim.define("behavior", "lunatic/tfs:photocopier", { prototype = content.id })

    behavior:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local target = ev.claim and ev.claim.entity
        local held = ev.implement
        if
            held == nil
            and (
                target == nil
                or target == ev.subject
                or (target ~= nil and target.prototype == content.id)
            )
        then
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
        if held == nil or held.prototype ~= "paper" then
            return { replaced = false }
        end
        sim.item_slot.insert({ subject = ev.subject, item = held, slot = "media" })
        open(ev.subject, ev.actor)
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
            if mode == "bw" or mode == "color" then
                machine.vars.photocopier_color = mode
            end
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
            if
                type(count) ~= "number"
                or count % 1 ~= 0
                or count < 1
                or count > printing.max_copies
            then
                return true
            end
            machine.vars.photocopier_failed = nil
            machine.vars.photocopier_reason = nil
            local document_source: DocumentFileSource =
                { store = source, uid = 0, expected_revision = snapshot.revision }
            local color: DocumentColor = if machine.vars.photocopier_color == "color"
                then "preserve"
                else "monochrome"
            local refusal = printing.start(machine, {
                busy_key = BUSY,
                source = document_source,
                stem = "paper1",
                color = color,
                pages = count,
                seconds = printing.copy_seconds,
                slot = "media",
                stopped = stopped,
            })
            if refusal ~= nil then
                machine.vars.photocopier_failed = true
                machine.vars.photocopier_reason = refusal
            end
            update(machine, ev.actor)
            return true
        end
        if ev.action == "eject" then
            sim.item_slot.eject({ subject = machine, slot = "media" })
            update(machine, ev.actor)
            return true
        end
        return { replaced = false }
    end)

    -- Every page answers with its own completion. Refreshing from that fact
    -- keeps the panel honest through a late failure on any page of a batch.
    behavior:handle("documents.materialize.done", { kind = "react" }, function(ev)
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
        if machine == nil or machine.prototype ~= content.id then
            return
        end
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
