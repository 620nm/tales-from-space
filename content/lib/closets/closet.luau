local deconstruction = require("@lib/closets/deconstruction")

local closet = {}

export type Options = {
	secure_variants: { [string]: boolean }?,
	default_access: string?,
	fixture_removal_tool: string?,
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

local WELDED_VAR = "closet_welded"
local LOCKED_VAR = "closet_locked"
local ACCESS_VAR = "closet_access"
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

local function play_sound(target: Handle, sound: string)
	play_sound_at(target.tile, sound)
end

local function is_welded(target: Handle): boolean
	return target.vars[WELDED_VAR] == true
end

local function is_locked(target: Handle, secure: boolean): boolean
	local locked = target.vars[LOCKED_VAR]
	if locked == nil then
		return secure
	end
	return locked == true
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
	for _, row in ipairs(sim.inventory(actor)) do
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
				or is_welded(target) ~= welded_snapshot
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
			target.vars[WELDED_VAR] = welded
			play_sound(target, "weld")
			send_message(
				actor,
				if welded then "lunatic/tfs:lib.closets.welded_shut" else "lunatic/tfs:lib.closets.unwelded",
				name_snapshot
			)
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
	local default_access = opts.default_access or "command"
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
		local locked = is_locked(target, secure)
		local welded = is_welded(target)
		if implement ~= nil
			and fixture_removal_tool ~= nil
			and implement.prototype == fixture_removal_tool
			and target.state == "open"
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
				request_deconstruction(target, nil, function(target_to_remove, original_at)
					remove_fixture_target_elsewhere(actor, target_to_remove, original_at)
				end)
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
			if locked then
				local access = target.vars[ACCESS_VAR]
				if type(access) ~= "string" then
					access = default_access
				end
				if not sim.has_access(actor, access) then
					send_message(actor, "lunatic/tfs:lib.closets.access_denied")
					return true
				end
				target.vars[LOCKED_VAR] = false
				play_sound(target, "closet_unlock")
				send_message(actor, "lunatic/tfs:lib.closets.unlocked", target_name)
			else
				target.vars[LOCKED_VAR] = true
				play_sound(target, "closet_lock")
				send_message(actor, "lunatic/tfs:lib.closets.locked_set", target_name)
			end
			return true
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
end

return closet
