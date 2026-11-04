-- What a shut cadaver chamber does about its contents, one pass a second from
-- its close until it opens or goes: the lamp (`morgue.dm:391-410`), the alarm
-- (`:241,281-283`) and the corpses' held organs (`:278-298`, modelled as the
-- preservation rather than the temperature). The chamber runs on its cord, so
-- power loss drops all three.
--
-- A lamp is a scripted state, and the engine treats only the exact `closed`
-- state as holding an occupant: resist, room air, speech and the occupant's
-- view all stop in any other. So a chamber holding anyone animate stays
-- `closed`, and no lamp shows for them.

local data = require("@lib/closets/data")
local preserved_organ = require("@lib/medical/preserved_organ")

local chamber_watch = {}

local ALERT_SOUND = "lunatic/tfs:sound/cadaver_alert"
-- tg's once a minute (`morgue.dm:241,281-283`).
local ALARM_SECONDS = 60.0
local PASS_SECONDS = 1.0

type ChamberWatch = {
	chamber: Handle,
	-- The bodies whose organs this watch holds.
	held: { Handle },
	-- Survives the door, as tg's `next_beep` does: a cycled door beeps no faster.
	next_alarm_tick: number,
	-- A close starts a fresh task; a task of an older generation stops.
	generation: number,
}

type ChamberContents = {
	items: boolean,
	living: boolean,
	dead: { Handle },
}

local watches: { ChamberWatch } = {}

local function contains(list: { Handle }, wanted: Handle): boolean
	for _, entry in ipairs(list) do
		if entry == wanted then
			return true
		end
	end
	return false
end

local function read_contents(chamber: Handle): ChamberContents
	local reading: ChamberContents = { items = false, living = false, dead = {} }
	for _, held in ipairs(chamber.contents or {}) do
		local body = sim.body.read(held)
		if body == nil then
			reading.items = true
		elseif body.animate == true then
			reading.living = true
		else
			table.insert(reading.dead, held)
		end
	end
	return reading
end

-- Socket by socket in id order, so the ledger rows replay; an empty socket
-- selects nothing.
local function set_preserved(body: Handle, held: boolean): ()
	if body.alive ~= true then
		return
	end
	local sockets = sim.sockets(body) :: { [string]: any }?
	if sockets == nil then
		return
	end
	local ids: { string } = {}
	for id in pairs(sockets) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		sim.set_component_condition(body, id, preserved_organ.condition, held)
	end
end

local function hold_exactly(watch: ChamberWatch, wanted: { Handle }): ()
	for index = #watch.held, 1, -1 do
		local body = watch.held[index]
		if not contains(wanted, body) then
			set_preserved(body, false)
			table.remove(watch.held, index)
		end
	end
	for _, body in ipairs(wanted) do
		if not contains(watch.held, body) then
			set_preserved(body, true)
			table.insert(watch.held, body)
		end
	end
end

local function lamp_for(reading: ChamberContents, powered: boolean): string
	if not powered or reading.living then
		return data.closed_state
	end
	if #reading.dead > 0 then
		return data.chamber_bodies_state
	end
	if reading.items then
		return data.chamber_items_state
	end
	return data.closed_state
end

local function forget(watch: ChamberWatch): ()
	local index = table.find(watches, watch)
	if index ~= nil then
		table.remove(watches, index)
	end
end

-- One look at the chamber. False ends the task: nothing held survives a chamber
-- that opened or was destroyed, and an empty one has nothing to watch. Only
-- destruction forgets the record, which carries the alarm's cooldown.
local function pass(watch: ChamberWatch): boolean
	local chamber = watch.chamber
	if chamber.alive ~= true then
		hold_exactly(watch, {})
		forget(watch)
		return false
	end
	if chamber.state == data.open_state then
		hold_exactly(watch, {})
		return false
	end
	local reading = read_contents(chamber)
	local powered = sim.is_powered(chamber)
	local corpses: { Handle } = if powered then reading.dead else {}
	hold_exactly(watch, corpses)
	local lamp = lamp_for(reading, powered)
	if chamber.state ~= lamp then
		sim.appearance.set_state({ entity = chamber, state = lamp })
	end
	local at = chamber.tile
	if powered and reading.living and at ~= nil and sim.tick() >= watch.next_alarm_tick then
		sim.sound.play({ asset = ALERT_SOUND, at = at })
		watch.next_alarm_tick = sim.tick() + sim.ticks(ALARM_SECONDS)
	end
	return reading.items or reading.living or #reading.dead > 0
end

local function watch_of(chamber: Handle): ChamberWatch
	for _, watch in ipairs(watches) do
		if watch.chamber == chamber then
			return watch
		end
	end
	local watch: ChamberWatch = { chamber = chamber, held = {}, next_alarm_tick = 0, generation = 0 }
	table.insert(watches, watch)
	return watch
end

-- Round-scoped so a destroyed chamber still releases what it held. The task
-- keeps the close's tile as its anchor, which is what lets the alarm sound with
-- nobody near it.
function chamber_watch.start(chamber: Handle): ()
	local watch = watch_of(chamber)
	watch.generation += 1
	local generation = watch.generation
	sim.spawn_task("round", function()
		local pass_ticks = sim.ticks(PASS_SECONDS)
		while watch.generation == generation and pass(watch) do
			sim.sleep(pass_ticks)
		end
	end)
end

return chamber_watch
