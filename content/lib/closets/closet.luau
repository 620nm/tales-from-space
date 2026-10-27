local deconstruction = require("@lib/closets/deconstruction")
local climbing = require("@lib/climbing")

local closet = {}

export type Options = {
	secure_variants: { [string]: boolean }?,
	fixture_removal_tool: string?,
}

-- What a latch order says once its `latch.set.done` lands successfully.
type LatchFeedback = {
	actor: Handle,
	name: string,
	sound: string,
	message: string,
}

-- An outstanding order, matched by its subject, latch and request id.
type PendingLatchOrder = {
	target: Handle,
	latch: string,
	feedback: LatchFeedback,
}

type WelderOperation = {
	actor: Handle,
	target: Handle,
	tool: Handle,
	flame_state: string,
	cancelled: boolean,
	task: Task?,
}

type FixtureExternalRemoval = {
	at: TileAddress,
	prototype: string,
}

local WELDED_LATCH = "welded"
local LOCKED_LATCH = "locked"
local BROKEN_LATCH = "broken"
-- Pack judgment, not tg's shake numbers (`closets.dm:97,99,1129`).
local BREAKOUT_SHAKE_STRENGTH = 4
local BREAKOUT_SHAKE_SECONDS = 0.5
local BREAKOUT_ONLOOKER_RADIUS = 7
local WELDER_PROTOTYPE = "welder"
local FIXTURE_MAP_SOURCE = "closet_cut_test"
local FIXTURE_MAP_LOGICAL = "lunatic/tfs:closet_cut_test"
local ID_PROTOTYPES: { [string]: boolean } = {
	id_assistant = true,
	id_medical = true,
	id_engineering = true,
	id_security = true,
	id_captain = true,
}
-- TG checks one tool unit before its four-second use_tool wait
-- (code/game/objects/structures/crates_lockers/closets.dm:934-967).
local FUEL_MINIMUM_MOL = 0.025
local active_welder_operations: { WelderOperation } = {}
local interruption_handlers_installed = false
local pending_latch_orders: { [string]: PendingLatchOrder } = {}
local latch_order_count = 0

local function send_message(actor: Handle, key: string, subject: string?)
	local arguments: { [string]: string | number | boolean | UnsafeMarkup } = {}
	if subject ~= nil then
		arguments.subject = subject
	end
	sim.message.send({ recipient = actor, message = sim.msg(key, arguments) })
end

local function subject_name(target: Handle, prototype: string): string
	local name = target.name
	if name ~= nil and name ~= "" then
		return name
	end
	return prototype
end

local function play_sound_at(at: TileAddress?, sound: string)
	if at ~= nil then
		sim.sound.play({ asset = "lunatic/tfs:sound/" .. sound, at = at })
	end
end

local function latch_on(target: Handle, latch: string): boolean
	local latches = sim.latch.of(target)
	return latches ~= nil and latches[latch] == true
end

-- Orders one latch switch; the actor hears of it when the order lands.
local function order_latch(target: Handle, latch: string, on: boolean, feedback: LatchFeedback): ()
	latch_order_count += 1
	local request_id = "closet_latch_" .. latch_order_count
	sim.latch.set({ subject = target, latch = latch, on = on, request_id = request_id })
	pending_latch_orders[request_id] = { target = target, latch = latch, feedback = feedback }
end

local function on_latch_done(ev: LatchSetDonePayload): ()
	-- A completion reaches every definition's handler; only this closet's own
	-- order (subject, latch and id) is ours to answer.
	local pending = pending_latch_orders[ev.request_id]
	if pending == nil or ev.subject ~= pending.target or ev.latch ~= pending.latch then
		return
	end
	local feedback = pending.feedback
	pending_latch_orders[ev.request_id] = nil
	if not ev.success then
		return
	end
	play_sound_at(ev.at, feedback.sound)
	if feedback.actor.alive == true then
		send_message(feedback.actor, feedback.message, feedback.name)
	end
end

-- A latch order carries no actor; the toggle paths below check the actor's
-- access themselves, so only an actor-less switch is admitted here.
local function on_access_permission(ev: AccessPermissionPayload)
	if ev.operation == "set_latch" and ev.actor == nil then
		return { allowed = true }
	end
	return { allowed = ev.allowed }
end

local function fuel_moles(tool: Handle): number
	local contents = assert(sim.matter_read(tool)).contents
	local fuel = contents.naphtha
	return if fuel then (fuel.liquid or 0) + (fuel.gas or 0) + (fuel.solid or 0) else 0
end

local function actor_ready(actor: Handle): boolean
	if actor.alive ~= true then
		return false
	end
	local body = sim.body(actor)
	return body ~= nil and body.controllable == true
end

local function held_in_hand(actor: Handle, item: Handle): boolean
	for _, row in ipairs(sim.inventory(actor, { nested = false })) do
		if row.item == item and row.location.kind == "hand" then
			return true
		end
	end
	return false
end

local function has_contents(target: Handle): boolean
	local contents = target.contents
	return contents ~= nil and #contents > 0
end

local function knock_off_riders(actor: Handle, support: Handle): ()
	local actor_tile = actor.tile
	local support_tile = support.tile
	if actor_tile == nil or support_tile == nil then
		return
	end
	for _, candidate in ipairs(sim.query.range(support_tile, 0, {})) do
		if candidate ~= actor
			and sim.body(candidate) ~= nil
			and sim.is_supported_by(candidate, support)
		then
			local candidate_tile = candidate.tile
			if candidate_tile ~= nil then
				local direction_x = candidate_tile.x - actor_tile.x
				local direction_y = candidate_tile.y - actor_tile.y
				if direction_x ~= 0 or direction_y ~= 0 then
					sim.force.directed({
						target = candidate,
						direction_x = direction_x,
						direction_y = direction_y,
						strength = 70,
					})
					candidate:hold_posture("knockdown", 4.0)
				end
			end
		end
	end
end

local function adjacent(actor: Handle, target: Handle): boolean
	local actor_tile = actor.tile
	local target_tile = target.tile
	if actor_tile == nil or target_tile == nil then
		return false
	end
	if actor_tile.instance ~= target_tile.instance or actor_tile.z ~= target_tile.z then
		return false
	end
	return math.max(math.abs(actor_tile.x - target_tile.x), math.abs(actor_tile.y - target_tile.y)) <= 1
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
	return actor_ready(operation.actor)
		and adjacent(operation.actor, operation.target)
		and operation.tool.state == operation.flame_state
		and held_in_hand(operation.actor, operation.tool)
end

local function prune_unusable_operations()
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
	prune_unusable_operations()
	for index = #active_welder_operations, 1, -1 do
		local operation = active_welder_operations[index]
		if operation.tool == tool then
			cancel_operation(operation)
		end
	end
end

local function install_interruption_handlers()
	prune_unusable_operations()
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
	if tool.prototype ~= WELDER_PROTOTYPE then
		return false
	end
	local fuel = fuel_moles(tool)
	if fuel < minimum_fuel_mol or (require_positive_fuel and fuel <= 0) then
		send_message(actor, "lunatic/tfs:lib.closets.no_fuel")
		return false
	end
	if tool.state ~= "lit" then
		send_message(actor, "lunatic/tfs:lib.closets.needs_lit")
		return false
	end
	return true
end

local function begin_welder_operation(
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
	prune_unusable_operations()
	if not actor_ready(actor)
		or not ready_welder(actor, tool, FUEL_MINIMUM_MOL, true)
	then
		return
	end
	local prototype_snapshot = target.prototype
	if prototype_snapshot == nil then
		return
	end
	if start_state == "open" and (welded_snapshot or has_contents(target)) then
		send_message(actor, "lunatic/tfs:lib.closets.salvage_unavailable", name_snapshot)
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
			if not actor_ready(actor) or not adjacent(actor, target) then
				return
			end
			if target.prototype ~= prototype_snapshot
				or target.state ~= start_state
				or latch_on(target, WELDED_LATCH) ~= welded_snapshot
			then
				return
			end
			if tool.state ~= operation.flame_state or not held_in_hand(actor, tool) then
				return
			end
			if not ready_welder(actor, tool, 0, true) then
				return
			end

			if start_state == "open" then
				local cut_at: TileAddress? = target.tile
				if welded_snapshot or has_contents(target) or cut_at == nil then
					send_message(actor, "lunatic/tfs:lib.closets.salvage_unavailable", name_snapshot)
					return
				end
				local receipt_at: TileAddress = cut_at
				if not request_deconstruction(target, function()
					if actor_ready(actor) then
						play_sound_at(receipt_at, "weld")
						send_message(actor, "lunatic/tfs:lib.closets.cut_apart", name_snapshot)
					end
				end) then
					send_message(actor, "lunatic/tfs:lib.closets.salvage_unavailable", name_snapshot)
					return
				end
				return
			end

			local welded = not welded_snapshot
			order_latch(target, WELDED_LATCH, welded, {
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
	if start_state == "open" then
		send_message(actor, "lunatic/tfs:lib.closets.start_cut", name_snapshot)
	end
end

function closet.attach(proto_id: string, opts: Options)
	local secure_variants = opts.secure_variants or {}
	local fixture_removal_tool = opts.fixture_removal_tool
	install_interruption_handlers()

	local behavior = sim.define("behavior", "lunatic/tfs:" .. proto_id, { prototype = proto_id })
	local request_deconstruction = deconstruction.attach(behavior, proto_id, {
		definition = "metal",
		count = 2,
		units = 1,
	})
	local fixture_map_request: RequestId? = nil
	local fixture_map_ready = false
	local fixture_external_removal: FixtureExternalRemoval? = nil
	if fixture_removal_tool ~= nil then
		behavior:handle("maps.instantiate.done", { kind = "react" }, function(ev: MapsInstantiateDonePayload)
			if fixture_map_request == nil or ev.request ~= fixture_map_request then
				return
			end
			fixture_map_request = nil
			fixture_map_ready = ev.outcome == "completed"
		end)
		behavior:handle("entity.despawn.done", { kind = "react" }, function(ev: EntityDespawnDonePayload)
			local pending = fixture_external_removal
			if pending == nil
				or ev.outcome ~= "completed"
				or ev.reason ~= nil
				or ev.identity ~= pending.prototype
				or ev.at ~= pending.at
			then
				return
			end
			fixture_external_removal = nil
			fixture_map_ready = false
			sim.maps.release({ map = FIXTURE_MAP_LOGICAL })
		end)
	end

	local function remove_fixture_target_elsewhere(
		actor: Handle,
		target: Handle,
		original_at: TileAddress
	): ()
		if fixture_map_request == nil and not fixture_map_ready then
			fixture_map_request = sim.maps.instantiate({
				source = FIXTURE_MAP_SOURCE,
				logical = FIXTURE_MAP_LOGICAL,
				placement = { plane = 1, origin = { x = 100, y = 40 } },
			})
		end

		for poll = 1, 20 do
			if fixture_map_ready then
				break
			end
			if fixture_map_request == nil then
				return
			end
			local outcome = sim.do_after(actor, sim.ticks(0.1), {})
			if outcome ~= "ok" or actor.alive ~= true or target.alive ~= true then
				return
			end
		end
		if not fixture_map_ready or actor.alive ~= true or target.alive ~= true then
			return
		end

		local destination = sim.map_tile(FIXTURE_MAP_LOGICAL, 0, 0, 0)
		if destination == nil or destination == original_at then
			return
		end
		sim.entity.transfer({ entity = target, to = destination })
		local outcome = sim.do_after(actor, sim.ticks(0.1), {})
		if outcome ~= "ok" or actor.alive ~= true or target.alive ~= true then
			return
		end
		local transferred_at = target.tile
		if transferred_at == nil or transferred_at == original_at or transferred_at ~= destination then
			return
		end
		local prototype = target.prototype
		if prototype == nil then
			return
		end
		fixture_external_removal = { at = destination, prototype = prototype }
		sim.entity.despawn({ entity = target })
	end

	behavior:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
		prune_unusable_operations()
		local actor: Handle = ev.actor
		local target: Handle = ev.subject
		local implement: Handle? = ev.implement
		local prototype = target.prototype
		if prototype == nil then
			return { replaced = false }
		end
		local target_name = subject_name(target, prototype)
		local implement_prototype = if implement ~= nil then implement.prototype else nil
		local secure = secure_variants[prototype] == true
		local locked = latch_on(target, LOCKED_LATCH)
		local welded = latch_on(target, WELDED_LATCH)
		if ev.gesture == "alt_primary" and climbing.supports_prototype(prototype) then
			climbing.begin(actor, target)
			return true
		end
		if implement ~= nil
			and fixture_removal_tool ~= nil
			and implement.prototype == fixture_removal_tool
			and (target.state == "open" or target.state == "closed")
		then
			sim.spawn_task(actor, function()
				local outcome = sim.do_after(actor, sim.ticks(0.1), {})
				if outcome ~= "ok"
					or actor.alive ~= true
					or target.alive ~= true
					or implement.alive ~= true
				then
					return
				end
				if not actor_ready(actor) or not adjacent(actor, target) or not held_in_hand(actor, implement) then
					return
				end
				if target.state == "closed" then
					if latch_on(target, WELDED_LATCH) or latch_on(target, LOCKED_LATCH) then
						return
					end
					request_deconstruction(target)
				else
					request_deconstruction(target, nil, function(target_to_remove, original_at)
						remove_fixture_target_elsewhere(actor, target_to_remove, original_at)
					end)
				end
			end)
			return true
		end

		if implement ~= nil and implement_prototype == WELDER_PROTOTYPE then
			if target.state == "open" or target.state == "closed" then
				begin_welder_operation(
					actor,
					target,
					implement,
					target.state,
					welded,
					target_name,
					request_deconstruction
				)
				return true
			end
			return { replaced = false }
		end

		if target.state == "closed"
			and secure
			and implement ~= nil
			and implement_prototype ~= nil
			and ID_PROTOTYPES[implement_prototype] == true
		then
			-- A broken lock takes no further ID toggle (`closets.dm:1169-1170`).
			if latch_on(target, BROKEN_LATCH) then
				send_message(actor, "lunatic/tfs:lib.closets.broken", target_name)
				return true
			end
			if locked then
				local requirements = sim.access.requirement_of(target)
				local requires = if requirements ~= nil then requirements.container else nil
				if not sim.access.check({ actor = actor, requires = requires or "" }).allowed then
					send_message(actor, "lunatic/tfs:lib.closets.access_denied")
					return true
				end
				order_latch(target, LOCKED_LATCH, false, {
					actor = actor,
					name = target_name,
					sound = "closet_unlock",
					message = "lunatic/tfs:lib.closets.unlocked",
				})
			else
				order_latch(target, LOCKED_LATCH, true, {
					actor = actor,
					name = target_name,
					sound = "closet_lock",
					message = "lunatic/tfs:lib.closets.locked_set",
				})
			end
			return true
		end

		if ev.gesture == "primary" and implement == nil and climbing.supports_prototype(prototype) then
			knock_off_riders(actor, target)
		end
		if target.state == "closed" and welded then
			send_message(actor, "lunatic/tfs:lib.closets.welded", target_name)
			return true
		end
		if target.state == "closed" and locked then
			send_message(actor, "lunatic/tfs:lib.closets.locked", target_name)
			return true
		end
		return { replaced = false }
	end)
	behavior:handle("climb.done", { kind = "react" }, climbing.on_done)
	behavior:handle("latch.set.done", { kind = "react" }, on_latch_done)
	behavior:handle("access.permission", { kind = "transform" }, on_access_permission)
	-- The break-out cues are the pack's (`closets.dm:1113`); tg shakes during
	-- the wait (`closets.dm:1107,1124-1136`), this pack at the bust-open. The
	-- native open already plays the container's open sound.
	behavior:handle("container.breakout.done", { kind = "react" }, function(ev: ContainerBreakoutDonePayload)
		local holder: Handle = ev.self
		local at = holder.tile
		if at == nil then
			return
		end
		local prototype = holder.prototype
		sim.visual.shake({ at = at, strength = BREAKOUT_SHAKE_STRENGTH, duration = BREAKOUT_SHAKE_SECONDS })
		local name = ev.body.name
		local broke_out = if name ~= nil and name ~= ""
			then sim.msg("lunatic/tfs:lib.closets.broke_out", {
				name = name,
				subject = subject_name(holder, prototype or proto_id),
			})
			else sim.msg("lunatic/tfs:lib.closets.broke_out_unnamed", {
				subject = subject_name(holder, prototype or proto_id),
			})
		-- tg tells the occupant only the self message (`closets.dm:1113-1114`),
		-- and `sim.message.broadcast` has no exclusion: send per onlooker.
		for _, onlooker in ipairs(sim.query.range(at, BREAKOUT_ONLOOKER_RADIUS, {})) do
			if onlooker ~= ev.body and sim.body(onlooker) ~= nil and sim.query.los(onlooker, at) then
				sim.message.send({ recipient = onlooker, message = broke_out })
			end
		end
	end)
	behavior:handle("container.close.done", { kind = "react" }, function(ev: ContainerCloseDonePayload)
		for _, body in ipairs(ev.bodies) do
			body:hold_posture("knockdown", 4.0)
			sim.message.send({
				recipient = body,
				message = sim.msg("lunatic/tfs:lib.closets.close_knockdown", {}),
			})
		end
	end)
end

return closet
