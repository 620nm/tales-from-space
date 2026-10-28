-- What closing a closet takes in and when it refuses. The engine asks through
-- `container.closing`; the veto and the gather below are tg's `can_close`
-- and `take_contents` (`closets.dm:493-505,521-533,575-608`), over what a
-- script can read. The engine still enforces size and capacity.

local data = require("@lib/closets/data")

local closing = {}

local KNOCKDOWN_SECONDS = 4.0

-- A body riding the closet's top is not in the tile the close takes from.
local function rides_on(body: Handle, container: Handle): boolean
	return sim.is_supported_by(body, container)
end

-- Tg's `horizontal && density` (`closets.dm:501,583`): a standing body is
-- dense, a lying one is not.
local function standing_in_horizontal(container: Handle, readout: { [any]: any }): boolean
	local family = data.family_of(container.prototype)
	return family ~= nil and family.horizontal and readout.posture ~= "lying"
end

-- Tg's `can_close`: another closet in the way, or a standing mob a
-- horizontal closet cannot take. The entering body is the close's own cause.
function closing.veto(ev: ContainerClosingPayload)
	local container: Handle = ev.subject
	for _, candidate in ipairs(sim.query.range(container.tile, 0, {})) do
		if candidate ~= container then
			if data.family_of(candidate.prototype) ~= nil then
				return { cancelled = true }
			end
			local readout = sim.body(candidate)
			if readout ~= nil
				and candidate ~= ev.entrant
				and not rides_on(candidate, container)
				and standing_in_horizontal(container, readout)
			then
				return { cancelled = true }
			end
		end
	end
	return nil
end

-- Tg's `insertion_allowed` for a mob, over what a script can read: not a
-- rider, and not a standing mob in a horizontal closet.
local function body_taken(container: Handle, body: Handle): boolean
	local readout = sim.body(body)
	return readout ~= nil
		and not rides_on(body, container)
		and not standing_in_horizontal(container, readout)
end

-- Tg's `take_contents`: the tile's things in turf order until full. Items and
-- bodies fill independently; the entrant is the engine's, admitted first.
function closing.gather(ev: ContainerClosingPayload)
	local container: Handle = ev.subject
	local entrant: Handle? = ev.entrant
	local items = 0
	local bodies = if entrant ~= nil then 1 else 0
	for _, held in ipairs(container.contents or {}) do
		if sim.body(held) ~= nil then
			bodies += 1
		else
			items += 1
		end
	end
	for _, candidate in ipairs(sim.query.range(container.tile, 0, {})) do
		if candidate ~= container
			and candidate ~= entrant
			and data.family_of(candidate.prototype) == nil
		then
			if sim.body(candidate) ~= nil then
				if bodies < data.body_capacity and body_taken(container, candidate) then
					sim.container.insert({ container = container, entity = candidate })
					bodies += 1
				end
			elseif items < data.item_capacity then
				sim.container.insert({ container = container, entity = candidate })
				items += 1
			end
		end
	end
	return { replaced = true }
end

-- Every body the close took in is knocked down and told so.
function closing.on_closed(ev: ContainerCloseDonePayload)
	for _, body in ipairs(ev.bodies) do
		body:hold_posture("knockdown", KNOCKDOWN_SECONDS)
		sim.message.send({
			recipient = body,
			message = sim.msg("lunatic/tfs:lib.closets.close_knockdown", {}),
		})
	end
end

return closing
