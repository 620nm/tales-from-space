-- The closet family's numbers and words. The cadaver chamber, crate, freezer
-- and locker prototypes read the capacities for their `container` blocks and the
-- handlers under `lib/closets/` read the same fields, so each fact has one home.

export type Family = {
	-- Tg's `horizontal` closets take no standing mob (`closets.dm:50,501,583`).
	horizontal: boolean,
	-- The way a tray slides out (`lib/closets/tray.luau`), for a closet with one.
	tray: string?,
}

local data = {}

-- Tg's closet capacities: things, mobs, and the biggest mob that fits
-- (`closets.dm:54-56`). `storage_capacity` counts every content, mobs
-- included (`closets.dm:56,563`); the engine's `capacity` and `body_capacity`
-- stay independent, so the close gather (`closing.luau`) applies tg's total.
data.item_capacity = 30
data.body_capacity = 3
data.max_body_size = 2

-- The `containment_size` of each body plan a close may take in (the engine
-- exposes no read of it): `bodies/human.luau`, tg's MOB_SIZE_HUMAN
-- (`code/__DEFINES/mobs.dm:62-66`). A plan absent here is sizeless and
-- stays out of a gather, as tg refuses a mob over `max_mob_size`
-- (`closets.dm:585`).
data.plan_containment_size = { human = 2 } :: { [string]: number }

-- Tg paralyzes a body stuffed into a closet by another for 40 deciseconds
-- (`closets.dm:1014`; silicons are exempt there and not modelled here).
data.stuff_knockdown_seconds = 4.0
-- Tg paralyzes a climber knocked off a climbed thing the same long
-- (`code/datums/elements/climbable.dm:57`).
data.knocked_off_seconds = 4.0

-- How long a close's pending entrant (`closing.expect`) stays valid; the
-- close runs within the tick it is ordered, so this only retires strays.
data.entrant_seconds = 1.0

-- Tg's `breakout_time = 1200` deciseconds (`closets.dm:47`).
data.breakout_seconds = 120
-- How long an order's completion may take before the order counts as lost.
data.confirm_seconds = 1.0

data.closed_state = "closed"
data.open_state = "open"
-- A cadaver chamber's lit shut faces; only `closed_state` admits an open or
-- holds an occupant (`lib/closets/chamber_watch.luau`).
data.chamber_items_state = "closed_items"
data.chamber_bodies_state = "closed_bodies"
data.welder_prototype = "welder"
data.id_prototypes = {
	"id_assistant",
	"id_medical",
	"id_engineering",
	"id_security",
	"id_captain",
}

data.welded_latch = "welded"
data.locked_latch = "locked"
data.broken_latch = "broken"
-- The latches whose bits keep a closet shut (`closets.dm:1094,1141-1146`).
data.holding_latches = { data.locked_latch, data.welded_latch }

-- Crate and freezer are tg's `horizontal` closets (`crates.dm:8`); the
-- locker is not. A cadaver chamber takes bodies lying, as tg's tray does,
-- and its tray slides out south: it wears the `morgue*_s` face, and tg's
-- tray lands on `get_step(src, dir)` (`morgue.dm:141`).
local families: { [string]: Family } = {
	cadaver_chamber = { horizontal = true, tray = "south" },
	crate = { horizontal = true },
	freezer = { horizontal = true },
	locker = { horizontal = false },
}

-- The family of a closet prototype id or variant id, or nil for anything else.
function data.family_of(prototype: string?): Family?
	if prototype == nil then
		return nil
	end
	local base = string.match(prototype, "^([^.]+)") or prototype
	return families[base]
end

return data
