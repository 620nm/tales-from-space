-- What closing a closet takes in and when it refuses. The engine asks through
-- `container.closing`; the veto and the gather below are tg's `can_close`
-- and `take_contents` (`closets.dm:493-505,521-533,575-608`), over what a
-- script can read. The engine still enforces size and capacity.

local actor_context = require("@lib/closets/actor_context")
local data = require("@lib/closets/data")
local tray = require("@lib/closets/tray")

local closing = {}

-- The body a close in flight is meant to take in, per container, and who
-- closes it: only that actor's close honors the entry. The body may stand
-- beside the container (tg moves it onto the turf first, `closets.dm:1016-1018`);
-- an entry older than `data.entrant_seconds` is stale and ignored.
type PendingEntrant = { container: Handle, actor: Handle, body: Handle, tick: number }
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

local function pending_entrant(container: Handle, actor: Handle): Handle?
	local index = pending_index(container)
	if index == nil or pending_entrants[index].actor ~= actor then
		return nil
	end
	return pending_entrants[index].body
end

local function forget_entrant(container: Handle): ()
	local index = pending_index(container)
	if index ~= nil then
		table.remove(pending_entrants, index)
	end
end

-- Records `body` as the entrant of the close `actor` is about to run on
-- `container`. False when this very body is already pending there: a repeated drag.
function closing.expect(container: Handle, actor: Handle, body: Handle): boolean
	if pending_entrant(container, actor) == body then
		return false
	end
	forget_entrant(container)
	table.insert(pending_entrants, { container = container, actor = actor, body = body, tick = sim.tick() })
	return true
end

-- What stands where a close takes from: the container's own tile, then its
-- tray's (`lib/closets/tray.luau`; tg's `close_loc`, `morgue.dm:156`), each
-- with whether it lies on the tray.
type Candidate = { entity: Handle, on_tray: boolean }
local function candidates(container: Handle): { Candidate }
	local found: { Candidate } = {}
	for _, entity in ipairs(sim.query.range(container.tile, 0, {})) do
		table.insert(found, { entity = entity, on_tray = false })
	end
	local tray_tile = tray.tile(container)
	if tray_tile ~= nil then
		for _, entity in ipairs(sim.query.range(tray_tile, 0, {})) do
			table.insert(found, { entity = entity, on_tray = true })
		end
	end
	return found
end

-- Tg's `horizontal && density` (`closets.dm:501,583`): a standing body is
-- dense, a lying one is not. A rider on an open crate stands on its tile and
-- counts (`crates.dm:118-121`, `climbable.dm:110-129`).
local function standing_in_horizontal(container: Handle, readout: { [any]: any }): boolean
	local family = data.family_of(container.prototype)
	return family ~= nil and family.horizontal and readout.posture ~= "lying"
end

-- Tg's `can_close` (`closets.dm:493-505`): another closet in the way, or a
-- standing mob a horizontal closet cannot take, on its own tile; one on its
-- tray's tile is taken in by `gather` instead. Returns the message key and
-- the name it says, or nil. `actor`'s pending entrant (`closing.expect`) is exempt
-- as pack judgment: tg has no standing self-hide (`closets.dm:990-991`), but
-- the pack's hide drag (`lib/body_drag.luau`) enters standing. `riders_leave`
-- skips the bodies riding `container`, for a click that knocks them off
-- first (`climbable.dm:48-59`).
function closing.refusal(container: Handle, actor: Handle, riders_leave: boolean): (string?, string?)
	local entrant = pending_entrant(container, actor)
	for _, candidate in ipairs(sim.query.range(container.tile, 0, {})) do
		if candidate ~= container then
			if data.family_of(candidate.prototype) ~= nil then
				return "lunatic/tfs:lib.closets.close_blocked_closet",
					actor_context.subject_name(candidate, candidate.prototype or "closet")
			end
			local readout = sim.body.read(candidate)
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
	local key, name = closing.refusal(container, actor, riders_leave)
	if key == nil then
		return false
	end
	actor_context.send_message(actor, key, name)
	return true
end

function closing.veto(ev: ContainerClosingPayload)
	local key = closing.refusal(ev.subject, ev.actor, false)
	if key ~= nil then
		forget_entrant(ev.subject)
	end
	return { canceled = key ~= nil }
end

-- Tg's `insertion_allowed` for a mob (`closets.dm:575-592`), over what a
-- script can read: a standing mob in a horizontal closet, and a plan with no
-- known size or one over `max_body_size`, stay out. A standing mob on the
-- tray's tile goes in, as tg's tray `close()` takes any living mob that is
-- not incorporeal (`morgue.dm:157-167`).
local function body_taken(container: Handle, readout: { [any]: any }, on_tray: boolean): boolean
	local size = data.plan_containment_size[readout.plan]
	return size ~= nil
		and size <= data.max_body_size
		and (on_tray or not standing_in_horizontal(container, readout))
end

-- Tg's `take_contents` (`closets.dm:521-531`): the tile's things in turf
-- order, then the tray tile's. Every content, mobs included, counts toward
-- `storage_capacity` and the first candidate met at that total ends the
-- gather (`closets.dm:56,525-529,563`); a mob over the mob count is
-- skipped alone (`closets.dm:587-591`). Structures and machines stay out,
-- as tg skips anchored things. The pending entrant is admitted first,
-- wherever it stands beside the container, and the entry is spent.
function closing.gather(ev: ContainerClosingPayload)
	local container: Handle = ev.subject
	local entrant = pending_entrant(container, ev.actor)
	forget_entrant(container)
	if entrant ~= nil then
		sim.container.insert({ container = container, entity = entrant })
	end
	local total = if entrant ~= nil then 1 else 0
	local bodies = total
	for _, held in ipairs(container.contents or {}) do
		total += 1
		if sim.body.read(held) ~= nil then
			bodies += 1
		end
	end
	for _, place in ipairs(candidates(container)) do
		local candidate = place.entity
		if candidate ~= container and candidate ~= entrant then
			if total >= data.item_capacity then
				break
			end
			if data.family_of(candidate.prototype) == nil then
				local readout = sim.body.read(candidate)
				if readout ~= nil then
					if bodies < data.body_capacity and body_taken(container, readout, place.on_tray) then
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
