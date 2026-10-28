-- What closing a closet takes in and when it refuses. The engine asks through
-- `container.closing`; the veto and the gather below are tg's `can_close`
-- and `take_contents` (`closets.dm:493-505,521-533,575-608`), over what a
-- script can read. The engine still enforces size and capacity.

local actor_context = require("@lib/closets/actor_context")
local data = require("@lib/closets/data")

local closing = {}

-- The body a close in flight is meant to take in, per container. It may stand
-- beside the container (tg moves it onto the turf first, `closets.dm:1016-1018`);
-- an entry older than `data.entrant_seconds` is stale and ignored.
type PendingEntrant = { container: Handle, body: Handle, tick: number }
local pending_entrants: { PendingEntrant } = {}

local function pending_index(container: Handle): number?
	local oldest = sim.tick() - sim.ticks(data.entrant_seconds)
	for index = #pending_entrants, 1, -1 do
		local pending = pending_entrants[index]
		if pending.tick < oldest then
			table.remove(pending_entrants, index)
		elseif pending.container == container then
			return index
		end
	end
	return nil
end

local function pending_entrant(container: Handle): Handle?
	local index = pending_index(container)
	return if index ~= nil then pending_entrants[index].body else nil
end

local function forget_entrant(container: Handle): ()
	local index = pending_index(container)
	if index ~= nil then
		table.remove(pending_entrants, index)
	end
end

-- Records `body` as the entrant of the close `container` is about to run.
-- False when this very body is already pending there: a repeated drag.
function closing.expect(container: Handle, body: Handle): boolean
	if pending_entrant(container) == body then
		return false
	end
	forget_entrant(container)
	table.insert(pending_entrants, { container = container, body = body, tick = sim.tick() })
	return true
end

-- Tg's `horizontal && density` (`closets.dm:501,583`): a standing body is
-- dense, a lying one is not. A rider on an open crate stands on its tile and
-- counts (`crates.dm:118-121`, `climbable.dm:110-129`).
local function standing_in_horizontal(container: Handle, readout: { [any]: any }): boolean
	local family = data.family_of(container.prototype)
	return family ~= nil and family.horizontal and readout.posture ~= "lying"
end

-- Tg's `can_close` (`closets.dm:493-505`): another closet in the way, or a
-- standing mob a horizontal closet cannot take. Returns the message key and
-- the name it says, or nil. The pending entrant (`closing.expect`) is exempt
-- as pack judgment: tg has no standing self-hide (`closets.dm:990-991`), but
-- the pack's hide drag (`lib/body_drag.luau`) enters standing. `riders_leave`
-- skips the bodies riding `container`, for a click that knocks them off
-- first (`climbable.dm:48-59`).
function closing.refusal(container: Handle, riders_leave: boolean): (string?, string?)
	local entrant = pending_entrant(container)
	for _, candidate in ipairs(sim.query.range(container.tile, 0, {})) do
		if candidate ~= container then
			if data.family_of(candidate.prototype) ~= nil then
				return "lunatic/tfs:lib.closets.close_blocked_closet",
					actor_context.subject_name(candidate, candidate.prototype or "closet")
			end
			local readout = sim.body(candidate)
			if readout ~= nil
				and candidate ~= entrant
				and not (riders_leave and sim.is_supported_by(candidate, container))
				and standing_in_horizontal(container, readout)
			then
				return "lunatic/tfs:lib.closets.close_blocked_large",
					actor_context.subject_name(container, container.prototype or "closet")
			end
		end
	end
	return nil, nil
end

-- Tells `actor` why a close would be refused, as tg does
-- (`closets.dm:497-498,502-503`); true when it would be. A veto cannot
-- send, so the writable segment that starts the close asks this first.
function closing.tell_refusal(actor: Handle, container: Handle, riders_leave: boolean): boolean
	local key, name = closing.refusal(container, riders_leave)
	if key == nil then
		return false
	end
	actor_context.send_message(actor, key, name)
	return true
end

function closing.veto(ev: ContainerClosingPayload)
	local key = closing.refusal(ev.subject, false)
	if key ~= nil then
		forget_entrant(ev.subject)
	end
	return { cancelled = key ~= nil }
end

-- Tg's `insertion_allowed` for a mob (`closets.dm:575-592`), over what a
-- script can read: a standing mob in a horizontal closet, and a plan with no
-- known size or one over `max_body_size`, stay out.
local function body_taken(container: Handle, readout: { [any]: any }): boolean
	local size = data.plan_containment_size[readout.plan]
	return size ~= nil
		and size <= data.max_body_size
		and not standing_in_horizontal(container, readout)
end

-- Tg's `take_contents` (`closets.dm:521-531`): the tile's things in turf
-- order. Every content, mobs included, counts toward `storage_capacity`
-- and the first candidate met at that total ends the gather
-- (`closets.dm:56,525-529,563`); a mob over the mob count is skipped alone
-- (`closets.dm:587-591`). Structures and machines stay out, as tg skips
-- anchored things. The pending entrant is admitted first, wherever it stands
-- beside the container, and the entry is spent.
function closing.gather(ev: ContainerClosingPayload)
	local container: Handle = ev.subject
	local entrant = pending_entrant(container)
	forget_entrant(container)
	if entrant ~= nil then
		sim.container.insert({ container = container, entity = entrant })
	end
	local total = if entrant ~= nil then 1 else 0
	local bodies = total
	for _, held in ipairs(container.contents or {}) do
		total += 1
		if sim.body(held) ~= nil then
			bodies += 1
		end
	end
	for _, candidate in ipairs(sim.query.range(container.tile, 0, {})) do
		if candidate ~= container and candidate ~= entrant then
			if total >= data.item_capacity then
				break
			end
			if data.family_of(candidate.prototype) == nil then
				local readout = sim.body(candidate)
				if readout ~= nil then
					if bodies < data.body_capacity and body_taken(container, readout) then
						sim.container.insert({ container = container, entity = candidate })
						bodies += 1
						total += 1
					end
				elseif candidate.kind == "item" then
					sim.container.insert({ container = container, entity = candidate })
					total += 1
				end
			end
		end
	end
	return { replaced = true }
end

-- A committed close spends any entry its gather did not.
function closing.on_closed(ev: ContainerCloseDonePayload)
	forget_entrant(ev.self)
end

return closing
