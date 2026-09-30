local printing = require("@lib/printing")
local service = require("@lib/service")
local writing = require("@lib/writing")

-- Fax policy is a pack handler over the shared print queue (lib/printing.luau)
-- and the addressed link services. A received sheet is printed by the
-- recipient's own queue, spending its own paper and toner; a sent sheet is
-- scanned in the sender's queue while its text travels as `fax.print` chunks.
-- This file keeps no document body in vars.
-- tg code/modules/paperwork/fax.dm:222-237, :294-351, :406-428.
local content = { id = "fax" }
local BUSY = "fax_busy"
type ViewerState = { page: number, target: string?, confirming: boolean? }
type Pending = {
    actor: Handle?,
    token: LinkReplyToken?,
    success: string,
    correlation: unknown,
    exchange: string?,
    rejected: boolean?,
}
type DirectoryRow = { id: string, address: string, name: string, online: boolean }
local viewer_state: { [string]: ViewerState } = {}
local viewers: { [string]: { [string]: Handle } } = {}
local viewer_machines: { [string]: Handle } = {}
-- One job owns each endpoint. This map retains only the private reply/actor
-- context needed when the job settles; the queue retains nothing of the
-- source, and the slot lock holds the sheet itself.
local pending: { [string]: Pending } = {}

local function body(payload: unknown): string?
    if type(payload) ~= "table" or type(payload.chunks) ~= "table" then
        return nil
    end
    local text = ""
    for _, chunk in ipairs(payload.chunks :: { unknown }) do
        if type(chunk) ~= "string" or #chunk > service.max_chunk then
            return nil
        end
        text ..= chunk
        if #text > service.max_payload then
            return nil
        end
    end
    return text
end

local function reply(ev: LinkServiceDeliveryPayload, payload: unknown)
    if ev.reply ~= nil then
        sim.link.reply({ subject = ev.self, token = ev.reply, payload = payload })
    end
end

local function reply_token(subject: Handle, token: LinkReplyToken?, payload: unknown)
    if token ~= nil then
        sim.link.reply({ subject = subject, token = token, payload = payload })
    end
end

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:fax_name", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:fax_advertised", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:fax_busy", { replicate = "server" })
    local function resource(machine: Handle, id: string)
        for _, row in ipairs(sim.resources.read(machine)) do
            if row.id == id then
                return row.current
            end
        end
        return 0
    end
    local function loaded(machine: Handle)
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
    local function directory(machine: Handle, page_index: number)
        local rows: { DirectoryRow } = {}
        local names: { [string]: number } = {}
        local page = sim.query.link_directory(machine, service.send, (page_index or 0) * 32)
        for _, row in ipairs(page.rows or {}) do
            local name = row.name or row.mac
            names[name] = (names[name] or 0) + 1
            table.insert(rows, { id = row.mac, address = row.mac, name = name, online = true })
        end
        for _, row in ipairs(rows) do
            if names[row.name] > 1 then
                row.name = row.name .. " [" .. row.address .. "]"
            end
        end
        return rows, page.next ~= nil
    end
    -- Target and confirmation are session-local UI state. They are keyed by
    -- the viewer supplied by the native UI envelope, never by a remote fax
    -- entity or by a document body.
    local function viewer_key(machine: Handle, viewer: Handle)
        return tostring(machine) .. ":" .. tostring(viewer)
    end
    local function state_for(machine: Handle, viewer: Handle): ViewerState
        local key = viewer_key(machine, viewer)
        viewer_state[key] = viewer_state[key] or { page = 0 }
        return viewer_state[key]
    end
    local function remember_viewer(machine: Handle, viewer: Handle?)
        if viewer == nil then
            return
        end
        local key = tostring(machine)
        viewer_machines[key] = machine
        viewers[key] = viewers[key] or {}
        viewers[key][tostring(viewer)] = viewer
    end
    local function view(machine: Handle, viewer: Handle?)
        local selected: ViewerState = if viewer then state_for(machine, viewer) else { page = 0 }
        local state = sim.link_state(machine)
        local directory_rows, directory_more = directory(machine, selected.page or 0)
        return {
            kind = "fax",
            name = machine.vars.fax_name or "",
            powered = sim.is_powered(machine),
            address = state and state.mac,
            network = state and state.parent,
            advertised = machine.vars.fax_advertised == true,
            loadedpaper = loaded(machine),
            paper = resource(machine, "paper"),
            toner = resource(machine, "toner"),
            busy = printing.busy(machine, BUSY),
            directory = directory_rows,
            directory_more = directory_more,
            directory_page = selected.page or 0,
            target = selected.target,
            confirming = selected.confirming == true,
        }
    end
    local function open(machine: Handle, viewer: Handle)
        remember_viewer(machine, viewer)
        ui.open({
            viewer = viewer,
            owner = machine,
            channel = "fax",
            view = view(machine, viewer),
            actions = {
                advertise = 8,
                name = 64,
                target = 64,
                page = 8,
                confirm = 64,
                cancel = 8,
                send = 64,
                eject = 8,
            },
            presentation_key = "writing/fax",
        })
    end
    local function update(machine: Handle, viewer: Handle)
        ui.update({
            viewer = viewer,
            owner = machine,
            channel = "fax",
            view = view(machine, viewer),
            actions = {
                advertise = 8,
                name = 64,
                target = 64,
                page = 8,
                confirm = 64,
                cancel = 8,
                send = 64,
                eject = 8,
            },
        })
    end
    local function refresh(machine: Handle): ()
        local rows = viewers[tostring(machine)] or {}
        for key, viewer in pairs(rows) do
            local ok = pcall(update, machine, viewer)
            if not ok then
                rows[key] = nil
            end
        end
    end

    -- Answers whoever asked for the job: the link reply token and, for a
    -- panel send, the pressing player's message.
    local function settle(machine: Handle, succeeded: boolean)
        local key = tostring(machine)
        local request = pending[key]
        if request == nil then
            return
        end
        pending[key] = nil
        local message = if succeeded then request.success else service.failed
        reply_token(machine, request.token, { kind = message, correlation = request.correlation })
        if request.actor ~= nil then
            local text = message == service.printed and "lunatic/tfs:items.fax.printed"
                or message == service.sent and "lunatic/tfs:items.fax.sent"
                or "lunatic/tfs:items.fax.failed"
            sim.message.send({ recipient = request.actor, message = sim.msg(text, {}) })
        end
    end

    -- A job that ends before its last page or scan fails its request.
    local function stopped(machine: Handle, _reason: string)
        settle(machine, false)
        refresh(machine)
    end

    -- A scan that ran its course succeeds unless the recipient already
    -- refused the sheet.
    local function scanned(machine: Handle)
        local request = pending[tostring(machine)]
        settle(machine, request ~= nil and request.rejected ~= true)
        refresh(machine)
    end

    local function start_local_print(ev: LinkServiceDeliveryPayload, text: string)
        local refusal = printing.start(ev.self, {
            busy_key = BUSY,
            source = { chunks = service.chunks(text) },
            stem = "fax",
            color = "monochrome",
            pages = 1,
            seconds = printing.fax_seconds,
            began = service.began(ev.payload),
            stopped = stopped,
        })
        if refusal == nil then
            refresh(ev.self)
        end
        return refusal == nil
    end

    -- The loaded sheet is held for the scan and its text streams to the
    -- destination's `fax.print` service; the recipient's own queue prints it.
    local function start_loaded_send(
        machine: Handle,
        destination: string,
        actor: Handle?,
        token: LinkReplyToken?,
        correlation: unknown
    )
        local source = machine:item_slot("media")
        if source == nil then
            return false
        end
        local readable, document = pcall(sim.documents.read, source, 0)
        if not readable or document == nil or #document.body > service.max_payload then
            return false
        end
        local refusal = printing.scan(machine, {
            busy_key = BUSY,
            seconds = printing.fax_seconds,
            slot = "media",
            finished = scanned,
            stopped = stopped,
        })
        if refusal ~= nil then
            return false
        end
        local exchange = tostring(sim.tick()) .. ":" .. tostring(machine)
        pending[tostring(machine)] = {
            actor = actor,
            token = token,
            success = service.sent,
            correlation = correlation,
            exchange = exchange,
        }
        sim.link.send({
            subject = machine,
            to = destination,
            service = service.print,
            payload = {
                chunks = service.chunks(document.body),
                correlation = exchange,
                began = service.stamp(),
            },
            request = true,
        })
        return true
    end

    local function receive(ev: LinkServiceDeliveryPayload)
        local payload: unknown = ev.payload
        local correlation: unknown = nil
        local destination: unknown = nil
        if type(payload) == "table" then
            local fields = payload :: { [unknown]: unknown }
            correlation = fields.correlation
            destination = fields.to
        end
        if ev.service == service.print then
            local text = body(payload)
            if text == nil or not start_local_print(ev, text) then
                reply(ev, { kind = service.failed, correlation = correlation })
                return
            end
            pending[tostring(ev.self)] = {
                token = ev.reply,
                success = service.printed,
                correlation = correlation,
            }
            return
        end
        -- A controller may ask a named fax to originate a loaded sheet. The
        -- destination is data; native link routing validates it.
        if
            type(destination) ~= "string"
            or not start_loaded_send(ev.self, destination, nil, ev.reply, correlation)
        then
            reply(ev, { kind = service.failed, correlation = correlation })
        end
    end

    local behavior = sim.define("behavior", "lunatic/tfs:fax", { prototype = content.id })

    -- Directory changes are a topology-wide hint. Reproject only remembered
    -- open viewers; the table contains no retained document data or handles
    -- supplied by a guest.
    local function refresh_all_faxes()
        for key, rows in pairs(viewers) do
            local machine = viewer_machines[key]
            if machine ~= nil then
                for viewer_key, viewer in pairs(rows) do
                    if not pcall(update, machine, viewer) then
                        rows[viewer_key] = nil
                    end
                end
            end
        end
    end
    sim.handle("link.directory.changed", { kind = "react" }, function()
        refresh_all_faxes()
    end)
    sim.handle("link.service.advertise.done", { kind = "react" }, function(ev)
        if ev.self == nil or ev.self.prototype ~= content.id then
            return
        end
        if ev.outcome ~= "completed" or ev.service == nil then
            ev.self.vars.fax_advertised = false
        else
            ev.self.vars.fax_advertised = true
        end
        refresh(ev.self)
    end)

    -- Each page's completion is the authoritative receive result. It
    -- distinguishes a refused page from a printed one while the private reply
    -- token stays in this endpoint's own request table.
    behavior:handle("documents.materialize.done", { kind = "react" }, function(ev)
        settle(ev.self, ev.outcome == "completed")
        refresh(ev.self)
    end)

    -- The recipient's refusal, or a send that never left, spoils the scan's
    -- verdict; the sheet still stays held until the scan ends.
    behavior:handle("link.service.reply", { kind = "react" }, function(ev)
        local request = pending[tostring(ev.self)]
        local payload: unknown = ev.payload
        if request == nil or type(payload) ~= "table" then
            return
        end
        local fields = payload :: { [unknown]: unknown }
        if fields.kind == service.failed and fields.correlation == request.exchange then
            request.rejected = true
        end
    end)
    sim.handle("link.service.send.done", { kind = "react" }, function(ev)
        local request = pending[tostring(ev.self)]
        if
            request ~= nil
            and ev.self.prototype == content.id
            and ev.service == service.print
            and ev.outcome ~= "completed"
        then
            request.rejected = true
        end
    end)

    -- Native slot and resource commands commit after their initiating action.
    -- Refreshing from those edges keeps loaded paper and stock truthful for
    -- every viewer, including a refill or eject performed by another player.
    local function refresh_machine(machine: Handle?)
        if machine == nil or machine.prototype ~= content.id then
            return
        end
        refresh(machine)
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
        if printing.busy(ev.subject, BUSY) then
            return true
        end
        sim.item_slot.insert({ subject = ev.subject, item = held, slot = "media" })
        open(ev.subject, ev.actor)
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
                        sim.link.advertise({
                            subject = machine,
                            service = service.print,
                            name = name,
                        })
                        sim.link.advertise({
                            subject = machine,
                            service = service.send,
                            name = name,
                        })
                    end)
                    if not ok then
                        machine.vars.fax_advertised = false
                    end
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
                        sim.link.advertise({
                            subject = machine,
                            service = service.print,
                            name = name,
                        })
                        sim.link.advertise({
                            subject = machine,
                            service = service.send,
                            name = name,
                        })
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
            if type(ev.value) == "string" then
                selected.target = ev.value
            end
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
            if type(ev.value) == "string" and #ev.value > 0 then
                selected.target = ev.value
            end
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
            if printing.busy(machine, BUSY) then
                return true
            end
            sim.item_slot.eject({ subject = machine, slot = "media" })
            update(machine, ev.actor)
            return true
        end
        if ev.action ~= "send" then
            return { replaced = false }
        end
        local source = machine:item_slot("media")
        local selected = state_for(machine, ev.actor)
        local destination = selected.target
        if
            not selected.confirming
            or type(ev.value) ~= "string"
            or ev.value ~= destination
            or source == nil
            or type(destination) ~= "string"
            or printing.busy(machine, BUSY)
        then
            return true
        end
        local correlation = tostring(sim.tick()) .. ":" .. tostring(machine)
        if not start_loaded_send(machine, destination, ev.actor, nil, correlation) then
            return true
        end
        selected.confirming = false
        selected.target = nil
        update(machine, ev.actor)
        return true
    end)

    -- Addressed traffic re-enters after the link batch. Native delivery keeps
    -- `ev.reply` opaque; only this endpoint may spend it in a reply.
    behavior:handle("link.service.delivery", { kind = "react" }, function(ev)
        if ev.service == service.print or ev.service == service.send then
            receive(ev)
        end
    end)
end

return content
