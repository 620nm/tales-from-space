-- What the closet handlers ask of an actor and a target before acting, and
-- the two ways they answer a player: a message and a sound.

local actor_context = {}

function actor_context.send_message(actor: Handle, key: string, subject: string?)
	local arguments: { [string]: string | number | boolean | UnsafeMarkup } = {}
	if subject ~= nil then
		arguments.subject = subject
	end
	sim.message.send({ recipient = actor, message = sim.msg(key, arguments) })
end

function actor_context.subject_name(target: Handle, prototype: string): string
	local name = target.name
	if name ~= nil and name ~= "" then
		return name
	end
	return prototype
end

function actor_context.play_sound_at(at: TileAddress?, sound: string)
	if at ~= nil then
		sim.sound.play({ asset = "lunatic/tfs:sound/" .. sound, at = at })
	end
end

function actor_context.latch_on(target: Handle, latch: string): boolean
	local latches = sim.latch.of(target)
	return latches ~= nil and latches[latch] == true
end

function actor_context.actor_ready(actor: Handle): boolean
	if actor.alive ~= true then
		return false
	end
	local body = sim.body.read(actor)
	return body ~= nil and body.controllable == true
end

function actor_context.held_in_hand(actor: Handle, item: Handle): boolean
	for _, row in ipairs(sim.inventory(actor, { nested = false })) do
		if row.item == item and row.location.kind == "hand" then
			return true
		end
	end
	return false
end

function actor_context.has_contents(target: Handle): boolean
	local contents = target.contents
	return contents ~= nil and #contents > 0
end

function actor_context.adjacent(actor: Handle, target: Handle): boolean
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

return actor_context
