-- The container escape is the closet's (`closets.dm:1085-1118`); the engine
-- only raises the push. An unsecured closet opens at once; a secured one gives
-- way after its breakout wait, one task per body.

local actor_context = require("@lib/closets/actor_context")
local data = require("@lib/closets/data")
local latch_orders = require("@lib/closets/latch_orders")

local breakout = {}

-- One body's forced way out of one sealed holder (`closets.dm:1085-1118`).
type BreakoutOperation = {
	body: Handle,
	holder: Handle,
	-- Past this tick a task that never reported back no longer absorbs pushes.
	expires_tick: number,
	task: Task?,
}

-- The longest single `do_after` (docs/luau-api/runtime.md); longer waits chain.
local MAX_WAIT_SECONDS = 60.0
-- A task that outlives its wait by this much is presumed dead.
local BREAKOUT_SLACK_SECONDS = 5.0
-- Pack judgment, not tg's shake numbers (`closets.dm:97,99,1129`). tg shakes
-- throughout the wait (`closets.dm:1107,1124-1136`); this pack cues the start
-- (onlooker lines) and shakes once at the bust-open, silent in between. tg's
-- bust-open opens without effects (`closets.dm:1146`); the native open plays
-- its sound here.
local BREAKOUT_SHAKE_STRENGTH = 4
local BREAKOUT_SHAKE_SECONDS = 0.5
local BREAKOUT_ONLOOKER_RADIUS = 7
local active_breakouts: { BreakoutOperation } = {}

local function is_direct_occupant(holder: Handle, body: Handle): boolean
	local contents = holder.contents
	if contents == nil then
		return false
	end
	for _, held in ipairs(contents) do
		if held == body then
			return true
		end
	end
	return false
end

local function remove_breakout(operation: BreakoutOperation)
	for index = #active_breakouts, 1, -1 do
		if active_breakouts[index] == operation then
			table.remove(active_breakouts, index)
			return
		end
	end
end

-- The running breakout of `body` in `holder`, if any. A stale one is dropped
-- on the way: out of time, dead, or for another holder than the push's.
local function find_breakout(body: Handle, holder: Handle): BreakoutOperation?
	local now = sim.tick()
	for index = #active_breakouts, 1, -1 do
		local operation = active_breakouts[index]
		if operation.expires_tick < now
			or operation.body.alive ~= true
			or operation.holder.alive ~= true
			or (operation.body == body and operation.holder ~= holder)
		then
			table.remove(active_breakouts, index)
			local task = operation.task
			if task ~= nil then
				pcall(function()
					task:cancel()
				end)
			end
		elseif operation.body == body then
			return operation
		end
	end
	return nil
end

local function holder_label(holder: Handle): string
	return actor_context.subject_name(holder, holder.prototype or "closet")
end

-- A breakout that ends without opening leaves this row where no engine row
-- would (an interrupted wait already rows `do_after_interrupted`).
local function record_breakout_lapse(operation: BreakoutOperation, reason: string): ()
	if operation.body.alive ~= true or operation.holder.alive ~= true then
		return
	end
	sim.ledger.record({
		kind = "lunatic/tfs:closet_breakout_lapsed",
		fields = { container = operation.holder, body = operation.body, reason = reason },
	})
end

-- tg tells a body still shut in that its push failed (`closets.dm:1117-1118`).
local function tell_breakout_failed(operation: BreakoutOperation): ()
	local body = operation.body
	local holder = operation.holder
	if body.alive == true and holder.alive == true and is_direct_occupant(holder, body) then
		actor_context.send_message(body, "lunatic/tfs:lib.closets.break_out_failed", holder_label(holder))
	end
end

local function lapse_breakout(operation: BreakoutOperation, reason: string): ()
	record_breakout_lapse(operation, reason)
	tell_breakout_failed(operation)
end

-- Why the body cannot push on, or nil while it is still shut in and able:
-- `not_inside` (gone, or the holder opened) or `incapacitated`.
local function unfit_reason(operation: BreakoutOperation): string?
	local body = operation.body
	local holder = operation.holder
	if body.alive ~= true
		or holder.alive ~= true
		or holder.state ~= data.closed_state
		or not is_direct_occupant(holder, body)
	then
		return "not_inside"
	end
	if not actor_context.actor_ready(body) then
		return "incapacitated"
	end
	return nil
end

-- Waits out `total_ticks` inside the holder in `do_after` segments of at
-- most the 60 s ceiling; any interruption ends the breakout.
local function wait_inside(operation: BreakoutOperation, total_ticks: number): boolean
	local segment_cap = sim.ticks(MAX_WAIT_SECONDS)
	local remaining = total_ticks
	while remaining > 0 do
		local segment = math.min(remaining, segment_cap)
		if sim.do_after(operation.body, segment, { inside = operation.holder }) ~= "ok" then
			return false
		end
		remaining -= segment
	end
	return true
end

-- Sleeps a tick at a time until `done()` holds or the confirmation window
-- closes; the first look is one tick after the orders were issued.
local function await_confirmation(done: () -> boolean): boolean
	for _ = 1, sim.ticks(data.confirm_seconds) do
		sim.sleep(1)
		if done() then
			return true
		end
	end
	return false
end

-- tg tells the occupant only the self message and the rest what they see or
-- hear (`closets.dm:1103-1105,1113-1114`). `sim.message.broadcast` has no
-- exclusion: send per onlooker. `heard` goes to those in earshot without sight.
local function tell_onlookers(body: Handle, at: TileAddress, seen: Message, heard: Message?): ()
	for _, onlooker in ipairs(sim.query.range(at, BREAKOUT_ONLOOKER_RADIUS, {})) do
		if onlooker ~= body and sim.body(onlooker) ~= nil then
			if sim.query.los(onlooker, at) then
				sim.message.send({ recipient = onlooker, message = seen })
			elseif heard ~= nil then
				sim.message.send({ recipient = onlooker, message = heard })
			end
		end
	end
end

local function announce_breakout(operation: BreakoutOperation, at: TileAddress): ()
	local body = operation.body
	local holder = operation.holder
	sim.visual.shake({ at = at, strength = BREAKOUT_SHAKE_STRENGTH, duration = BREAKOUT_SHAKE_SECONDS })
	local subject = holder_label(holder)
	actor_context.send_message(body, "lunatic/tfs:lib.closets.break_out_self", subject)
	local name = body.name
	local broke_out = if name ~= nil and name ~= ""
		then sim.msg("lunatic/tfs:lib.closets.broke_out", { name = name, subject = subject })
		else sim.msg("lunatic/tfs:lib.closets.broke_out_unnamed", { subject = subject })
	tell_onlookers(body, at, broke_out, nil)
end

-- The onlookers' start cue (`closets.dm:1103,1105`).
local function announce_breakout_start(operation: BreakoutOperation): ()
	local at = operation.holder.tile
	if at == nil then
		return
	end
	local subject = holder_label(operation.holder)
	tell_onlookers(
		operation.body,
		at,
		sim.msg("lunatic/tfs:lib.closets.shake_seen", { subject = subject }),
		sim.msg("lunatic/tfs:lib.closets.shake_heard", { subject = subject })
	)
end

-- Bust-open (`closets.dm:1141-1146`): every holding latch off, the lock
-- broken where declared, then the occupant opens the door. The latch writes
-- are orders, so the open waits for their completions.
local function bust_open(operation: BreakoutOperation): ()
	local holder = operation.holder
	local latches = sim.latch.of(holder) or {}
	local request_ids: { string } = {}
	local cleared: { string } = {}
	for _, latch in ipairs(data.holding_latches) do
		if latches[latch] == true then
			table.insert(request_ids, latch_orders.order_breakout(holder, latch, false))
			table.insert(cleared, latch)
		end
	end
	local broken: string? = nil
	if latches[data.broken_latch] == false then
		table.insert(request_ids, latch_orders.order_breakout(holder, data.broken_latch, true))
		broken = data.broken_latch
	end
	-- The orders apply when this segment commits; their completions follow.
	local confirmed = #request_ids == 0
		or await_confirmation(function()
			for _, request_id in ipairs(request_ids) do
				if not latch_orders.breakout_answered(request_id) then
					return false
				end
			end
			return true
		end)
	for _, request_id in ipairs(request_ids) do
		local order = latch_orders.take_breakout(request_id)
		if order == nil or not order.answered or not order.success then
			confirmed = false
		end
	end
	if not confirmed then
		lapse_breakout(operation, "latch_unconfirmed")
		return
	end
	local unfit = unfit_reason(operation)
	if unfit ~= nil then
		lapse_breakout(operation, unfit)
		return
	end
	sim.ledger.record({
		kind = "lunatic/tfs:closet_broken_out",
		fields = {
			container = holder,
			body = operation.body,
			cleared = table.concat(cleared, ","),
			broken = broken,
		},
	})
	sim.container.open({ container = holder })
	local opened = await_confirmation(function()
		return holder.alive ~= true or holder.state == data.open_state
	end)
	local at = holder.tile
	if not opened or holder.alive ~= true or at == nil then
		lapse_breakout(operation, "open_refused")
		return
	end
	announce_breakout(operation, at)
end

local function run_breakout(operation: BreakoutOperation, total_ticks: number): ()
	-- The push committed before this task started: the first segment needs
	-- a body still shut in and able.
	local unfit = unfit_reason(operation)
	if unfit ~= nil then
		lapse_breakout(operation, unfit)
		return
	end
	if not wait_inside(operation, total_ticks) then
		tell_breakout_failed(operation)
		return
	end
	-- Recheck after the wait (`closets.dm:1110`): the next push opens a
	-- closet that no longer holds.
	unfit = unfit_reason(operation)
	if unfit ~= nil then
		lapse_breakout(operation, unfit)
		return
	end
	if not latch_orders.is_secured(operation.holder) then
		lapse_breakout(operation, "not_secured")
		return
	end
	bust_open(operation)
end

-- The task is spawned before the operation is listed, and the listing is
-- dropped however the task ends. A Luau error is raised again after the
-- cleanup, so it still surfaces as the script error. The body is the scope
-- so a destroyed holder interrupts the wait and resumes it; a task cancelled
-- by its scope runs no Luau, and `find_breakout` sweeps that listing.
local function begin_breakout(body: Handle, holder: Handle): ()
	local total_ticks = sim.ticks(data.breakout_seconds)
	local operation: BreakoutOperation = {
		body = body,
		holder = holder,
		expires_tick = sim.tick() + total_ticks + sim.ticks(BREAKOUT_SLACK_SECONDS),
		task = nil,
	}
	operation.task = sim.spawn_task(body, function()
		local completed, failure = pcall(run_breakout, operation, total_ticks)
		remove_breakout(operation)
		if not completed then
			error(failure, 0)
		end
	end)
	table.insert(active_breakouts, operation)
	actor_context.send_message(body, "lunatic/tfs:lib.closets.start_breakout")
	announce_breakout_start(operation)
end

-- An unsecured closet opens at once; a secured one starts one escape per body.
function breakout.on_resist(ev: ContainerResistPayload)
	local holder: Handle = ev.subject
	local body: Handle = ev.actor
	if not latch_orders.is_secured(holder) then
		sim.container.open({ container = holder })
		return { replaced = true }
	end
	if find_breakout(body, holder) == nil then
		begin_breakout(body, holder)
	end
	return { replaced = true }
end

return breakout
