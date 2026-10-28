-- A lit welder worked on a closet: four seconds of `do_after`, then the weld
-- toggles, or an open closet is cut apart. One operation per actor, dropped
-- the moment its actor, target or tool stops fitting.

local actor_context = require("@lib/closets/actor_context")
local data = require("@lib/closets/data")
local latch_orders = require("@lib/closets/latch_orders")

local welding = {}

type WelderOperation = {
	actor: Handle,
	target: Handle,
	tool: Handle,
	flame_state: string,
	cancelled: boolean,
	task: Task?,
}

-- TG checks one tool unit before its four-second use_tool wait
-- (code/game/objects/structures/crates_lockers/closets.dm:934-967).
local FUEL_MINIMUM_MOL = 0.025
local active_welder_operations: { WelderOperation } = {}
local interruption_handlers_installed = false

local function fuel_moles(tool: Handle): number
	local contents = assert(sim.matter_read(tool)).contents
	local fuel = contents.naphtha
	return if fuel then (fuel.liquid or 0) + (fuel.gas or 0) + (fuel.solid or 0) else 0
end

local function remove_operation(operation: WelderOperation)
	for index = #active_welder_operations, 1, -1 do
		if active_welder_operations[index] == operation then
			table.remove(active_welder_operations, index)
			return
		end
	end
end

local function cancel_operation(operation: WelderOperation)
	operation.cancelled = true
	remove_operation(operation)
	local task = operation.task
	if task ~= nil then
		pcall(function()
			task:cancel()
		end)
	end
end

local function operation_context_usable(operation: WelderOperation): boolean
	if operation.actor.alive ~= true
		or operation.target.alive ~= true
		or operation.tool.alive ~= true
	then
		return false
	end
	return actor_context.actor_ready(operation.actor)
		and actor_context.adjacent(operation.actor, operation.target)
		and operation.tool.state == operation.flame_state
		and actor_context.held_in_hand(operation.actor, operation.tool)
end

function welding.prune_unusable_operations()
	for index = #active_welder_operations, 1, -1 do
		local operation = active_welder_operations[index]
		if not operation_context_usable(operation) then
			cancel_operation(operation)
		end
	end
end

local function cancel_actor_operations(actor: Handle)
	for index = #active_welder_operations, 1, -1 do
		local operation = active_welder_operations[index]
		if operation.actor == actor then
			cancel_operation(operation)
		end
	end
end

local function cancel_on_tool_toggle(tool: Handle)
	welding.prune_unusable_operations()
	for index = #active_welder_operations, 1, -1 do
		local operation = active_welder_operations[index]
		if operation.tool == tool then
			cancel_operation(operation)
		end
	end
end

function welding.install_interruption_handlers()
	welding.prune_unusable_operations()
	if interruption_handlers_installed then
		return
	end
	interruption_handlers_installed = true
	sim.handle("interaction.use.done", { kind = "react" }, function(ev: InteractionUseDonePayload)
		if ev.gesture == "primary" or ev.gesture == "secondary" then
			cancel_on_tool_toggle(ev.subject)
		end
	end)
	sim.handle("interaction.act.done", { kind = "react" }, function(ev: InteractionActDonePayload)
		if ev.channel == "actions" and ev.action == "activate" then
			cancel_on_tool_toggle(ev.subject)
		end
	end)
end

local function ready_welder(
	actor: Handle,
	tool: Handle,
	minimum_fuel_mol: number,
	require_positive_fuel: boolean
): boolean
	if tool.prototype ~= data.welder_prototype then
		return false
	end
	local fuel = fuel_moles(tool)
	if fuel < minimum_fuel_mol or (require_positive_fuel and fuel <= 0) then
		actor_context.send_message(actor, "lunatic/tfs:lib.closets.no_fuel")
		return false
	end
	if tool.state ~= "lit" then
		actor_context.send_message(actor, "lunatic/tfs:lib.closets.needs_lit")
		return false
	end
	return true
end

function welding.begin(
	actor: Handle,
	target: Handle,
	tool: Handle,
	start_state: string,
	welded_snapshot: boolean,
	name_snapshot: string,
	request_deconstruction: (
		Handle,
		(() -> ())?,
		((Handle, TileAddress) -> ())?
	) -> boolean
)
	welding.prune_unusable_operations()
	if not actor_context.actor_ready(actor)
		or not ready_welder(actor, tool, FUEL_MINIMUM_MOL, true)
	then
		return
	end
	local prototype_snapshot = target.prototype
	if prototype_snapshot == nil then
		return
	end
	if start_state == data.open_state and (welded_snapshot or actor_context.has_contents(target)) then
		actor_context.send_message(actor, "lunatic/tfs:lib.closets.salvage_unavailable", name_snapshot)
		return
	end

	cancel_actor_operations(actor)
	local operation: WelderOperation = {
		actor = actor,
		target = target,
		tool = tool,
		flame_state = "lit",
		cancelled = false,
		task = nil,
	}
	local task: Task? = nil
	local spawned = pcall(function()
		task = sim.spawn_task(actor, function()
			local outcome = sim.do_after(actor, sim.ticks(4.0), {})
			remove_operation(operation)
			if operation.cancelled or outcome ~= "ok" then
				return
			end
			if actor.alive ~= true or target.alive ~= true or tool.alive ~= true then
				return
			end
			if not actor_context.actor_ready(actor) or not actor_context.adjacent(actor, target) then
				return
			end
			if target.prototype ~= prototype_snapshot
				or target.state ~= start_state
				or actor_context.latch_on(target, data.welded_latch) ~= welded_snapshot
			then
				return
			end
			if tool.state ~= operation.flame_state or not actor_context.held_in_hand(actor, tool) then
				return
			end
			if not ready_welder(actor, tool, 0, true) then
				return
			end

			if start_state == data.open_state then
				local cut_at: TileAddress? = target.tile
				if welded_snapshot or actor_context.has_contents(target) or cut_at == nil then
					actor_context.send_message(actor, "lunatic/tfs:lib.closets.salvage_unavailable", name_snapshot)
					return
				end
				local receipt_at: TileAddress = cut_at
				if not request_deconstruction(target, function()
					if actor_context.actor_ready(actor) then
						actor_context.play_sound_at(receipt_at, "weld")
						actor_context.send_message(actor, "lunatic/tfs:lib.closets.cut_apart", name_snapshot)
					end
				end) then
					actor_context.send_message(actor, "lunatic/tfs:lib.closets.salvage_unavailable", name_snapshot)
					return
				end
				return
			end

			local welded = not welded_snapshot
			latch_orders.order_toggle(target, data.welded_latch, welded, {
				actor = actor,
				name = name_snapshot,
				sound = "weld",
				message = if welded then "lunatic/tfs:lib.closets.welded_shut" else "lunatic/tfs:lib.closets.unwelded",
			})
		end)
	end)
	if not spawned or task == nil then
		return
	end
	operation.task = task
	table.insert(active_welder_operations, operation)
	if start_state == data.open_state then
		actor_context.send_message(actor, "lunatic/tfs:lib.closets.start_cut", name_snapshot)
	end
end

return welding
