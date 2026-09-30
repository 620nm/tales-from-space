-- The print queue shared by the copier and the fax. A machine runs its own
-- task: it sleeps out a page's run time, then lands the page with one atomic
-- documents.materialize (the engine's docs/luau-api/documents.md). Durations
-- are seconds of physical time: 4 s a copy, 2 s a fax page (80/40 ticks at
-- this pack's 20 Hz). The queue converts them with sim.ticks once per job,
-- which is exact at every integer rate; nothing here assumes a tick count.
local printing = {
    paper = "paper",
    toner = "toner",
    max_copies = 10,
    copy_seconds = 4,
    fax_seconds = 2,
}

export type PrintRefusal = "busy" | "offline" | "insufficient_supplies"

-- `busy_key` is the fixture's declared script var: true from acceptance until
-- the job settles. `slot` stays locked against insert and eject until then.
-- `stopped` hears why a job ended before its last page. `began` is the tick
-- its clock started, the acceptance tick when omitted.
export type PrintJob = {
    busy_key: string,
    source: DocumentFileSource | DocumentTextSource,
    stem: string,
    color: DocumentColor,
    pages: number,
    seconds: number,
    slot: string?,
    began: number?,
    stopped: ((machine: Handle, reason: string) -> ())?,
}

-- A sheet held in `slot` for `seconds`, then ejected onto the machine's tile
-- whatever happened meanwhile. `finished` hears a scan that ran its course.
export type ScanJob = {
    busy_key: string,
    seconds: number,
    slot: string,
    finished: ((machine: Handle) -> ())?,
    stopped: ((machine: Handle, reason: string) -> ())?,
}

-- Each page is paid for by its own materialize; the queue lists the
-- per-output amount once, so a batch never charges count².
function printing.costs(): { { resource: string, amount: number } }
    return {
        { resource = printing.paper, amount = 1 },
        { resource = printing.toner, amount = 1 },
    }
end

local function stock(machine: Handle, id: string): number
    for _, row in ipairs(sim.resources.read(machine)) do
        if row.id == id then
            return row.current
        end
    end
    return 0
end

-- Whether `pages` more outputs are affordable now: a powered machine holding
-- at least that many of every costed resource. Nothing is reserved; each page
-- is checked again when it lands.
function printing.affordable(machine: Handle, pages: number): PrintRefusal?
    if not sim.is_powered(machine) then
        return "offline"
    end
    for _, cost in ipairs(printing.costs()) do
        if stock(machine, cost.resource) < cost.amount * pages then
            return "insufficient_supplies"
        end
    end
    return nil
end

function printing.busy(machine: Handle, busy_key: string): boolean
    return machine.vars[busy_key] == true
end

-- Sleeps until `due`, never less than one tick.
local function sleep_until(due: number)
    sim.sleep(math.max(1, due - sim.tick()))
end

-- Marks `machine` busy, holds `slot`, and spawns the task that runs `body`.
-- The body is pcalled and the cleanup is unconditional: a raise would
-- otherwise discard the buffered unlock, and a task ending never releases a
-- slot lock on its own. `body` returns the reason it stopped early, or nil.
local function enqueue(
    machine: Handle,
    busy_key: string,
    slot: string?,
    eject: boolean,
    started: number,
    body: (started: number) -> string?,
    ended: (reason: string?) -> ()
)
    machine.vars[busy_key] = true
    if slot ~= nil then
        sim.item_slot.lock({ entity = machine, slot = slot, locked = true })
    end
    sim.spawn_task(machine, function()
        local ok, stop = pcall(body, started)
        if slot ~= nil then
            sim.item_slot.lock({ entity = machine, slot = slot, locked = false })
            if eject then
                sim.item_slot.eject({ subject = machine, slot = slot })
            end
        end
        machine.vars[busy_key] = nil
        -- The notice is best effort: a raise here would discard the cleanup
        -- above along with it.
        pcall(ended, if ok then stop :: string? else "operation_failed")
    end)
end

local function land_pages(machine: Handle, job: PrintJob, started: number): string?
    local per_page = sim.ticks(job.seconds)
    for page = 1, job.pages do
        sleep_until(started + page * per_page)
        local refusal = printing.affordable(machine, 1)
        if refusal ~= nil then
            return refusal
        end
        sim.documents.materialize({
            source = job.source,
            output = "paper",
            ext = "md",
            stem = job.stem,
            color = job.color,
            costs = printing.costs(),
        })
    end
    return nil
end

-- Accepts a print job on `machine` at the current tick or names why not. The
-- first page lands `job.seconds` after this tick, the next `job.seconds`
-- later, and a batch that cannot be fully supplied never starts.
function printing.start(machine: Handle, job: PrintJob): PrintRefusal?
    if printing.busy(machine, job.busy_key) then
        return "busy"
    end
    local refusal = printing.affordable(machine, job.pages)
    if refusal ~= nil then
        return refusal
    end
    enqueue(machine, job.busy_key, job.slot, false, job.began or sim.tick(), function(started)
        return land_pages(machine, job, started)
    end, function(stop)
        if stop ~= nil and job.stopped ~= nil then
            job.stopped(machine, stop)
        end
    end)
    return nil
end

-- Accepts a scan at the current tick: the sheet leaves `job.seconds` later.
function printing.scan(machine: Handle, job: ScanJob): PrintRefusal?
    if printing.busy(machine, job.busy_key) then
        return "busy"
    end
    if not sim.is_powered(machine) then
        return "offline"
    end
    enqueue(machine, job.busy_key, job.slot, true, sim.tick(), function(started)
        sleep_until(started + sim.ticks(job.seconds))
        return if sim.is_powered(machine) then nil else "offline"
    end, function(stop)
        if stop == nil then
            if job.finished ~= nil then
                job.finished(machine)
            end
        elseif job.stopped ~= nil then
            job.stopped(machine, stop)
        end
    end)
    return nil
end

return printing
