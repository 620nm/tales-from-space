-- The tray side of a closet that has one (a cadaver chamber): tg's
-- `open()` puts what it held on the turf it faces (`morgue.dm:134-147`) and
-- `close()` takes back what lies there (`:149-169`). Here what the open
-- released steps onto that tile through the ordinary movement rules, so a
-- wall or a dense thing there keeps it on the closet's own tile; `closing`
-- gathers from both tiles.

local data = require("@lib/closets/data")

local tray = {}

local STEP: { [string]: { x: number, y: number } } = {
	north = { x = 0, y = -1 },
	south = { x = 0, y = 1 },
	east = { x = 1, y = 0 },
	west = { x = -1, y = 0 },
}

-- The tile `container`'s tray slides out onto, or nil for a closet with no
-- tray or a facing tile off its map.
function tray.tile(container: Handle): TileAddress?
	local family = data.family_of(container.prototype)
	local step = if family ~= nil and family.tray ~= nil then STEP[family.tray] else nil
	if step == nil then
		return nil
	end
	local at = container.tile
	return sim.map_tile(at, at.x + step.x, at.y + step.y, at.z)
end

-- `container.open.done`: each item and body the open left on the closet's
-- tile steps one tile out the tray's way (tg's `forceMove(dump_turf)`,
-- `morgue.dm:139-144`). Other closets stay, as `closing` never takes them.
function tray.slide_out(ev: ContainerOpenDonePayload): ()
	local container: Handle = ev.subject
	local family = data.family_of(container.prototype)
	if ev.outcome ~= "completed" or family == nil or family.tray == nil then
		return
	end
	for _, candidate in ipairs(sim.query.range(container.tile, 0, {})) do
		if candidate ~= container
			and data.family_of(candidate.prototype) == nil
			and (candidate.kind == "item" or sim.body(candidate) ~= nil)
		then
			sim.entity.step({ entity = candidate, direction = family.tray })
		end
	end
end

return tray
