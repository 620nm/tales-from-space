local actor_context = require("@lib/closets/actor_context")
local breakout = require("@lib/closets/breakout")
local climbing = require("@lib/climbing")
local closing = require("@lib/closets/closing")
local data = require("@lib/closets/data")
local deconstruction = require("@lib/closets/deconstruction")
local latch_orders = require("@lib/closets/latch_orders")
local welding = require("@lib/closets/welding")

local closet = {}

export type Options = {
	secure_variants: { [string]: boolean }?,
	fixture_removal_tool: string?,
}

type FixtureExternalRemoval = {
	at: TileAddress,
	prototype: string,
}

local FIXTURE_MAP_SOURCE = "closet_cut_test"
local FIXTURE_MAP_LOGICAL = "lunatic/tfs:closet_cut_test"
local ID_PROTOTYPES: { [string]: boolean } = {
	id_assistant = true,
	id_medical = true,
	id_engineering = true,
	id_security = true,
	id_captain = true,
}

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

function closet.attach(proto_id: string, opts: Options)
	local secure_variants = opts.secure_variants or {}
	local fixture_removal_tool = opts.fixture_removal_tool
	welding.install_interruption_handlers()

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
		welding.prune_unusable_operations()
		local actor: Handle = ev.actor
		local target: Handle = ev.subject
		local implement: Handle? = ev.implement
		local prototype = target.prototype
		if prototype == nil then
			return { replaced = false }
		end
		local target_name = actor_context.subject_name(target, prototype)
		local implement_prototype = if implement ~= nil then implement.prototype else nil
		local secure = secure_variants[prototype] == true
		local locked = actor_context.latch_on(target, data.locked_latch)
		local welded = actor_context.latch_on(target, data.welded_latch)
		if ev.gesture == "alt_primary" and climbing.supports_prototype(prototype) then
			climbing.begin(actor, target)
			return true
		end
		if implement ~= nil
			and fixture_removal_tool ~= nil
			and implement.prototype == fixture_removal_tool
			and (target.state == data.open_state or target.state == data.closed_state)
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
				if not actor_context.actor_ready(actor)
					or not actor_context.adjacent(actor, target)
					or not actor_context.held_in_hand(actor, implement)
				then
					return
				end
				if target.state == data.closed_state then
					if actor_context.latch_on(target, data.welded_latch)
						or actor_context.latch_on(target, data.locked_latch)
					then
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

		if implement ~= nil and implement_prototype == data.welder_prototype then
			if target.state == data.open_state or target.state == data.closed_state then
				welding.begin(
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

		if target.state == data.closed_state
			and secure
			and implement ~= nil
			and implement_prototype ~= nil
			and ID_PROTOTYPES[implement_prototype] == true
		then
			-- A broken lock takes no further ID toggle (`closets.dm:1169-1170`).
			if actor_context.latch_on(target, data.broken_latch) then
				actor_context.send_message(actor, "lunatic/tfs:lib.closets.broken", target_name)
				return true
			end
			if locked then
				local requirements = sim.access.requirement_of(target)
				local requires = if requirements ~= nil then requirements.container else nil
				if not sim.access.check({ actor = actor, requires = requires or "" }).allowed then
					actor_context.send_message(actor, "lunatic/tfs:lib.closets.access_denied")
					return true
				end
				latch_orders.order_toggle(target, data.locked_latch, false, {
					actor = actor,
					name = target_name,
					sound = "closet_unlock",
					message = "lunatic/tfs:lib.closets.unlocked",
				})
			else
				latch_orders.order_toggle(target, data.locked_latch, true, {
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
		if target.state == data.closed_state and welded then
			actor_context.send_message(actor, "lunatic/tfs:lib.closets.welded", target_name)
			return true
		end
		if target.state == data.closed_state and locked then
			actor_context.send_message(actor, "lunatic/tfs:lib.closets.locked", target_name)
			return true
		end
		return { replaced = false }
	end)
	behavior:handle("climb.done", { kind = "react" }, climbing.on_done)
	behavior:handle("latch.set.done", { kind = "react" }, latch_orders.on_done)
	behavior:handle("access.permission", { kind = "transform" }, latch_orders.on_permission)
	behavior:handle("container.resist", { kind = "replace", route = "interact" }, breakout.on_resist)
	behavior:handle("container.closing", { kind = "veto", route = "interact" }, closing.veto)
	behavior:handle("container.closing", { kind = "replace", route = "interact" }, closing.gather)
	behavior:handle("container.close.done", { kind = "react" }, closing.on_closed)
end

return closet
