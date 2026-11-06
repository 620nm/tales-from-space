-- The closet family's latch switches. Each is an order whose completion
-- (`latch.set.done`) reaches the closet's scope whoever switched it, so an
-- order is matched by its subject, latch and request id before it is answered.

local actor_context = require("@lib/closets/actor_context")
local data = require("@lib/closets/data")

local latch_orders = {}

-- What a toggle's order says once its `latch.set.done` lands successfully.
export type LatchFeedback = {
	actor: Handle,
	name: string,
	sound: string,
	message: string,
}

-- An outstanding toggle: the weld or the ID lock.
type PendingLatchOrder = {
	target: Handle,
	latch: string,
	on: boolean,
	feedback: LatchFeedback,
}

-- An outstanding order of a bust-open, read back by the escape task.
export type BreakoutOrder = {
	holder: Handle,
	latch: string,
	on: boolean,
	answered: boolean,
	success: boolean,
}

local pending_latch_orders: { [string]: PendingLatchOrder } = {}
local breakout_orders: { [string]: BreakoutOrder } = {}
local latch_order_count = 0

-- Orders one latch switch; the actor hears of it when the order lands.
function latch_orders.order_toggle(target: Handle, latch: string, on: boolean, feedback: LatchFeedback): ()
	latch_order_count += 1
	local request_id = "closet_latch_" .. latch_order_count
	local refused = sim.latch.set({ subject = target, latch = latch, on = on, request_id = request_id })
	if refused == nil then
		pending_latch_orders[request_id] = { target = target, latch = latch, on = on, feedback = feedback }
	end
end

-- Orders one latch switch of a bust-open and returns its request id. A
-- refused order fires no completion, so it is answered as failed at once.
function latch_orders.order_breakout(holder: Handle, latch: string, on: boolean): string
	latch_order_count += 1
	local request_id = "closet_breakout_" .. latch_order_count
	local refused = sim.latch.set({ subject = holder, latch = latch, on = on, request_id = request_id })
	breakout_orders[request_id] =
		{ holder = holder, latch = latch, on = on, answered = refused ~= nil, success = false }
	return request_id
end

-- Whether the completion of a bust-open order has landed.
function latch_orders.breakout_answered(request_id: string): boolean
	local order = breakout_orders[request_id]
	return order ~= nil and order.answered
end

-- Forgets a bust-open order and returns what it learned, nil when unknown.
function latch_orders.take_breakout(request_id: string): BreakoutOrder?
	local order = breakout_orders[request_id]
	breakout_orders[request_id] = nil
	return order
end

function latch_orders.on_done(ev: LatchSetDonePayload): ()
	local breakout_order = breakout_orders[ev.request_id]
	if breakout_order ~= nil then
		if ev.subject == breakout_order.holder and ev.latch == breakout_order.latch then
			breakout_order.answered = true
			breakout_order.success = ev.success
		end
		return
	end
	local pending = pending_latch_orders[ev.request_id]
	if pending == nil or ev.subject ~= pending.target or ev.latch ~= pending.latch then
		return
	end
	local feedback = pending.feedback
	pending_latch_orders[ev.request_id] = nil
	if not ev.success then
		return
	end
	actor_context.play_sound_at(ev.at, feedback.sound)
	if feedback.actor.alive == true then
		actor_context.send_message(feedback.actor, feedback.message, feedback.name)
	end
end

-- Whether `request_id` is an outstanding order of this lib for exactly this switch.
local function has_order_for(request_id: string, subject: Handle, latch: string?, on: boolean?): boolean
	local breakout_order = breakout_orders[request_id]
	if breakout_order ~= nil then
		return not breakout_order.answered
			and breakout_order.holder == subject
			and breakout_order.latch == latch
			and breakout_order.on == on
	end
	local pending = pending_latch_orders[request_id]
	return pending ~= nil and pending.target == subject and pending.latch == latch and pending.on == on
end

-- A latch order carries no actor; the toggle paths check the actor's access
-- themselves, so only a switch carrying the id of an order this lib issued is
-- admitted. That admit is also what lets the bust-open write its latches.
function latch_orders.on_permission(ev: AccessPermissionPayload)
	local request_id = ev.request_id
	if ev.operation == "set_latch"
		and ev.actor == nil
		and request_id ~= nil
		and has_order_for(request_id, ev.subject, ev.latch, ev.on)
	then
		return { allowed = true }
	end
	return { allowed = ev.allowed }
end

-- A closet is secured while any holding latch is on (`closets.dm:1094`).
function latch_orders.is_secured(holder: Handle): boolean
	local latches = sim.latch.of(holder)
	if latches == nil then
		return false
	end
	for _, latch in ipairs(data.holding_latches) do
		if latches[latch] == true then
			return true
		end
	end
	return false
end

return latch_orders
