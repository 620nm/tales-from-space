-- Fax policy is a pack hook over generic document, slot, and link helpers.
-- The helpers own job admission, resources, timing, and private reply tokens;
-- this file only translates fax messages and keeps no document body in vars.
-- tg code/modules/paperwork/fax.dm:222-237, :294-351, :406-428.
local content = { id = "fax" }
local viewer_state, viewers, viewer_machines = {}, {}, {}
local refresh
-- One native operation owns each endpoint. These maps retain only the
-- private reply/actor context needed when its completion arrives; the native
-- job retains the source file and all machine reservations.
local pending = {}

local function body(payload)
    if type(payload) ~= "table" or type(payload.chunks) ~= "table" then return nil end
    local text = ""
    for _, chunk in ipairs(payload.chunks) do
        if type(chunk) ~= "string" or #chunk > service.max_chunk then return nil end
        text ..= chunk
        if #text > service.max_payload then return nil end
    end
    return text
end

local function reply(ev, payload)
    if ev.reply ~= nil then
        sim.link.reply({ subject = ev.self, token = ev.reply, payload = payload })
    end
end

local function reply_token(subject, token, payload)
    if token ~= nil then sim.link.reply({ subject = subject, token = token, payload = payload }) end
end

local function start_local_print(ev, text)
    if sim.documents.status(ev.self) ~= nil then return false end
    local accepted = pcall(function()
        sim.documents.start({
            machine = ev.self,
            source = { chunks = service.chunks(text) },
            output = "paper", ext = "md", stem = "fax",
            duration_ticks = printing.fax_ticks, count = 1, eject_input = false,
            color = "monochrome",
            costs = printing.costs(),
        })
    end)
    if accepted and refresh then
        sim.spawn_task(ev.self, function()
            sim.sleep(1)
            refresh(ev.self)
        end)
    end
    return accepted
end

local function start_loaded_send(machine, destination, actor, token, correlation)
    if sim.documents.status(machine) ~= nil then return false end
    local source = machine:item_slot("media")
    if source == nil then return false end
    local readable, document = pcall(sim.documents.read, source, 0)
    if not readable or document == nil then return false end
    local accepted = pcall(function()
        sim.documents.start({
            machine = machine,
            source = { store = source, uid = 0, expected_revision = document.revision },
            to = destination, service = service.send,
            output = "paper", ext = "md", stem = "fax",
            duration_ticks = printing.fax_ticks, count = 1, eject_input = true,
            color = "monochrome",
            costs = printing.costs(),
        })
    end)
    if accepted then
        pending[tostring(machine)] = {
            actor = actor, token = token, success = service.sent,
            correlation = correlation,
        }
        if refresh then
            sim.spawn_task(machine, function()
                sim.sleep(1)
                refresh(machine)
            end)
        end
    end
    return accepted
end

local function receive(ev)
    local payload = type(ev.payload) == "table" and ev.payload or {}
    if ev.service == service.print then
        local text = body(payload)
        if text == nil or not start_local_print(ev, text) then
            reply(ev, { kind = service.failed, correlation = payload.correlation })
            return
        end
        pending[tostring(ev.self)] = {
            token = ev.reply, success = service.printed,
            correlation = payload.correlation,
        }
        return
    end
    -- A controller may ask a named fax to originate a loaded sheet. The
    -- destination is data; native document admission validates its route.
    local destination = payload.to
    if type(destination) ~= "string"
        or not start_loaded_send(ev.self, destination, nil, ev.reply, payload.correlation)
    then
        reply(ev, { kind = service.failed, correlation = payload.correlation })
    end
end

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:fax_name", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:fax_advertised", { replicate = "server" })
    local function resource(machine, id)
        for _, row in ipairs(sim.resources.read(machine)) do
            if row.id == id then return row.current end
        end
        return 0
    end
    local function loaded(machine)
        local source = machine:item_slot("media")
        if source == nil then return {} end
        local ok, document = pcall(sim.documents.read, source, 0)
        if not ok or document == nil then return {} end
        return writing.fragments(document)
    end
    local function directory(machine, page_index)
        local rows, names = {}, {}
        local page = sim.query.link_directory(
            machine, service.send, (page_index or 0) * 32
        )
        for _, row in ipairs(page.rows or {}) do
            local name = row.name or row.mac
            names[name] = (names[name] or 0) + 1
            table.insert(rows, { id = row.mac, address = row.mac, name = name, online = true })
        end
        for _, row in ipairs(rows) do
            if names[row.name] > 1 then row.name = row.name .. " [" .. row.address .. "]" end
        end
        return rows, page.next ~= nil
    end
    -- Target and confirmation are session-local UI state. They are keyed by
    -- the viewer supplied by the native UI envelope, never by a remote fax
    -- entity or by a document body.
    local function viewer_key(machine, viewer)
        return tostring(machine) .. ":" .. tostring(viewer)
    end
    local function state_for(machine, viewer)
        local key = viewer_key(machine, viewer)
        viewer_state[key] = viewer_state[key] or { page = 0 }
        return viewer_state[key]
    end
    local function remember_viewer(machine, viewer)
        if viewer == nil then return end
        local key = tostring(machine)
        viewer_machines[key] = machine
        viewers[key] = viewers[key] or {}
        viewers[key][tostring(viewer)] = viewer
    end
    local function view(machine, viewer)
        local selected = viewer and state_for(machine, viewer) or {}
        local state = sim.link_state(machine)
        local directory_rows, directory_more = directory(machine, selected.page or 0)
        return {
            kind = "fax", name = machine.vars.fax_name or "", powered = sim.is_powered(machine),
            address = state and state.mac, network = state and state.parent,
            advertised = machine.vars.fax_advertised == true,
            loadedpaper = loaded(machine), paper = resource(machine, "paper"),
            toner = resource(machine, "toner"), busy = sim.documents.status(machine) ~= nil,
            directory = directory_rows, directory_more = directory_more,
            directory_page = selected.page or 0,
            target = selected.target, confirming = selected.confirming == true,
        }
    end
    local function open(machine, viewer)
        remember_viewer(machine, viewer)
        ui.open({ viewer = viewer, owner = machine, channel = "fax", view = view(machine, viewer), actions = {
            advertise = 8, name = 64, target = 64, page = 8,
            confirm = 64, cancel = 8, send = 64, eject = 8,
        }, presentation_key = "writing/fax" })
    end
    local function update(machine, viewer)
        ui.update({ viewer = viewer, owner = machine, channel = "fax", view = view(machine, viewer), actions = {
            advertise = 8, name = 64, target = 64, page = 8,
            confirm = 64, cancel = 8, send = 64, eject = 8,
        } })
    end
    local function update_viewers(machine)
        local rows = viewers[tostring(machine)] or {}
        for key, viewer in pairs(rows) do
            local ok = pcall(update, machine, viewer)
            if not ok then rows[key] = nil end
        end
    end
    refresh = update_viewers
    local behavior = sim.define("behavior", "lunatic/tfs:fax", { prototype = content.id })

    -- Directory changes are a topology-wide hint. Reproject only remembered
    -- open viewers; the table contains no retained document data or handles
    -- supplied by a guest.
    local function refresh_all_faxes()
        for key, rows in pairs(viewers) do
            local machine = viewer_machines[key]
            if machine ~= nil then
                for viewer_key, viewer in pairs(rows) do
                    if not pcall(update, machine, viewer) then rows[viewer_key] = nil end
                end
            end
        end
    end
    sim.handle("link.directory.changed", { kind = "react" }, function()
        refresh_all_faxes()
    end)
    sim.handle("link.service.advertise.done", { kind = "react" }, function(ev)
        if ev.self == nil or ev.self.prototype ~= content.id then return end
        if ev.outcome ~= "completed" or ev.service == nil then
            ev.self.vars.fax_advertised = false
        else
            ev.self.vars.fax_advertised = true
        end
        refresh(ev.self)
    end)

    -- The native operation completion is the only authoritative receive
    -- result. It distinguishes a preflight refusal from a late failure while
    -- keeping the private reply token in this endpoint's own request table.
    sim.handle("documents.operation.done", { kind = "react" }, function(ev)
        if ev.self.prototype ~= content.id then return end
        -- The terminal event has no remote entity handle. Reproject every
        -- remembered fax panel so a recipient's reservation and output clear
        -- at the same deadline as the sender's source ejection.
        refresh_all_faxes()
        local request = pending[tostring(ev.self)]
        if request ~= nil then
            pending[tostring(ev.self)] = nil
            reply_token(ev.self, request.token, {
                kind = ev.outcome == "completed" and request.success or service.failed,
                correlation = request.correlation,
            })
            if request.actor ~= nil then
                local message = ev.outcome == "completed" and request.success or service.failed
                local key = message == service.printed and "lunatic/tfs:items.fax.printed"
                    or message == service.sent and "lunatic/tfs:items.fax.sent"
                    or "lunatic/tfs:items.fax.failed"
                sim.message.send({ recipient = request.actor, message = sim.msg(key, {}) })
            end
        end
    end)

    -- Native slot and resource commands commit after their initiating action.
    -- Refreshing from those edges keeps loaded paper and stock truthful for
    -- every viewer, including a refill or eject performed by another player.
    local function refresh_machine(machine)
        if machine == nil or machine.prototype ~= content.id then return end
        if refresh then refresh(machine) end
    end
    sim.handle("item_slot.changed.done", { kind = "react" }, function(ev)
        refresh_machine(ev.subject)
    end)
    sim.handle("resources.transfer.done", { kind = "react" }, function(ev)
        refresh_machine(ev.from)
        refresh_machine(ev.to)
    end)

    behavior:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local target = ev.claim and ev.claim.entity
        local held = ev.implement
        if held == nil and (target == nil or target == ev.subject or (target ~= nil and target.prototype == content.id)) then
            open(ev.subject, ev.actor); return true
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
        if sim.documents.status(ev.subject) ~= nil then return true end
        sim.item_slot.insert({ subject = ev.subject, item = held, slot = "media" })
        open(ev.subject, ev.actor)
        sim.spawn_task(ev.subject, function()
            sim.sleep(1)
            if refresh then refresh(ev.subject) end
        end)
        return true
    end)

    behavior:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        local machine = ev.subject
        if ev.action == "name" then
            local name = type(ev.value) == "string" and ev.value:match("^%s*(.-)%s*$")
            if name and #name > 0 and #name <= 64 and not name:find("%c") then
                machine.vars.fax_name = name
                if machine.vars.fax_advertised then
                    local ok = pcall(function()
                        sim.link.advertise({ subject = machine, service = service.print, name = name })
                        sim.link.advertise({ subject = machine, service = service.send, name = name })
                    end)
                    if not ok then machine.vars.fax_advertised = false end
                end
            end
            update(machine, ev.actor)
            return true
        end
        if ev.action == "advertise" then
            if ev.value == "on" then
                local name = machine.vars.fax_name
                if type(name) == "string" and #name > 0 then
                    local ok = pcall(function()
                        sim.link.advertise({ subject = machine, service = service.print, name = name })
                        sim.link.advertise({ subject = machine, service = service.send, name = name })
                    end)
                    machine.vars.fax_advertised = ok
                end
            elseif ev.value == "off" then
                sim.link.advertise({ subject = machine, service = nil })
                machine.vars.fax_advertised = false
            end
            update(machine, ev.actor)
            return true
        end
        if ev.action == "target" then
            local selected = state_for(machine, ev.actor)
            if type(ev.value) == "string" then selected.target = ev.value end
            selected.confirming = false
            update(machine, ev.actor)
            return true
        end
        if ev.action == "page" then
            local page = tonumber(ev.value)
            if page and page % 1 == 0 and page >= 0 and page <= 31 then
                state_for(machine, ev.actor).page = page
            end
            update(machine, ev.actor)
            return true
        end
        if ev.action == "confirm" then
            local selected = state_for(machine, ev.actor)
            if type(ev.value) == "string" and #ev.value > 0 then selected.target = ev.value end
            selected.confirming = selected.target ~= nil
            update(machine, ev.actor)
            return true
        end
        if ev.action == "cancel" then
            state_for(machine, ev.actor).confirming = false
            update(machine, ev.actor)
            return true
        end
        if ev.action == "eject" then
            if sim.documents.status(machine) ~= nil then return true end
            sim.item_slot.eject({ subject = machine, slot = "media" })
            update(machine, ev.actor)
            return true
        end
        if ev.action ~= "send" then return { replaced = false } end
        local source = machine:item_slot("media")
        local selected = state_for(machine, ev.actor)
        local destination = selected.target
        if not selected.confirming or type(ev.value) ~= "string"
            or ev.value ~= destination or source == nil
            or type(destination) ~= "string"
            or sim.documents.status(machine) ~= nil then return true end
        local correlation = tostring(sim.tick()) .. ":" .. tostring(machine)
        if not start_loaded_send(machine, destination, ev.actor, nil, correlation) then return true end
        selected.confirming = false
        selected.target = nil
        update(machine, ev.actor)
        return true
    end)

    -- Addressed traffic re-enters after the link batch. Native delivery keeps
    -- `ev.reply` opaque; only this endpoint may spend it in a reply.
    behavior:handle("link.service.delivery", { kind = "react" }, function(ev)
        if ev.service == service.print or ev.service == service.send then receive(ev) end
    end)
end

return content
