-- What closing a closet takes in and when it refuses. The engine asks through
-- `container.closing`; the veto and the gather below are tg's `can_close`
-- and `take_contents` (`closets.dm:493-505,521-533,575-608`), over what a
-- script can read. The engine still enforces size and capacity.

local actor_context = require("@lib/closets/actor_context")
local data = require("@lib/closets/data")

local closing = {}

-- Tg's `horizontal && density` (`closets.dm:501,583`): a standing body is
-- dense, a lying one is not. A rider on an open crate stands on its tile and
-- counts (`crates.dm:118-121`, `climbable.dm:110-129`).
local function standing_in_horizontal(container: Handle, readout: { [any]: any }): boolean
	local family = data.family_of(container.prototype)
	return family ~= nil and family.horizontal and readout.posture ~= "lying"
end

-- Tells the closer why the close is refused, as tg does
-- (`closets.dm:497-498,502-503`), and answers the veto.
local function refuse_close(ev: ContainerClosingPayload, key: string, subject: Handle)
	local name = actor_context.subject_name(subject, subject.prototype or "closet")
	actor_context.send_message(ev.actor, key, name)
	return { cancelled = true }
end

-- Tg's `can_close` (`closets.dm:493-505`): another closet in the way, or a
-- standing mob a horizontal closet cannot take. The entering body is exempt
-- as pack judgment: tg stuffs a body only after paralyzing it
-- (`closets.dm:1014`) and has no standing self-hide (`closets.dm:990-991`),
-- but the pack's hide drag (`lib/body_drag.luau`) enters standing.
function closing.veto(ev: ContainerClosingPayload)
	local container: Handle = ev.subject
	for _, candidate in ipairs(sim.query.range(container.tile, 0, {})) do
		if candidate ~= container then
			if data.family_of(candidate.prototype) ~= nil then
				return refuse_close(ev, "lunatic/tfs:lib.closets.close_blocked_closet", candidate)
			end
			local readout = sim.body(candidate)
			if readout ~= nil
				and candidate ~= ev.entrant
				and standing_in_horizontal(container, readout)
			then
				return refuse_close(ev, "lunatic/tfs:lib.closets.close_blocked_large", container)
			end
		end
	end
	return { cancelled = false }
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
-- anchored things. The entrant is the engine's, admitted first.
function closing.gather(ev: ContainerClosingPayload)
	local container: Handle = ev.subject
	local entrant: Handle? = ev.entrant
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

-- A body stuffed in by another is knocked down (`closets.dm:1014`); one who
-- climbs in or is gathered by the close is not.
function closing.on_entered(ev: ContainerEnterDonePayload)
	if ev.outcome ~= "completed" or ev.actor == ev.body then
		return
	end
	ev.body:hold_posture("knockdown", data.stuff_knockdown_seconds)
end

return closing
