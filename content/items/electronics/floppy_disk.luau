local physical_profiles = require("@lib/physical_profiles")
local strange_disk = require("@lib/strange_disk/init")
local strange_disk_reader = require("@lib/file_readers/strange_disk")
-- A 3.5-inch diskette: a sleeve of plastic with a store of named text
-- inside it, and no way to read one in your hand. It is the whole of
-- what this station has for carrying a file from one machine to
-- another -- pocket it, walk, put it in a drive.
--
-- THE NUMBERS ARE THE REAL DISK. 737,280 bytes is a double-density
-- 3.5" floppy formatted at 80 tracks, 9 sectors, two sides, 512 bytes
-- a sector; 112 is FAT12's root-directory entry limit on that format,
-- which is why a disk with room left on it can still refuse a file.
-- Neither number is tg's -- tg's disks are 16/64/256 "GQ"
-- (code/modules/modular_computers/computers/item/disks/computer_disk.dm:4,49-59)
-- and it counts no entries at all. These are the ones the fiction is
-- actually about, and the engine's own ceilings are exactly them
-- (docs/CONTENT-SCHEMA.md 1.10d), so this is the largest medium the
-- substrate can carry as well as the largest one that ever existed.
--
-- No `drive` block and no `ui`: a store is read at the terminal it is
-- fitted in. Reading one in a pocket would be a second gesture, and
-- there is nothing in a hand to read it WITH.
local content = {
    id = "floppy_disk",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.floppy_disk.name",
    name = "floppy disk",
    -- First-party `art/items/electronics/floppy_disk.aseprite` (`unlabeled`),
    -- tinted to the dark sleeve of tg's `/obj/item/disk` (`datadisk3`,
    -- code/game/objects/items/floppy_disk.dm:41-45).
    sprite = "floppy_disk",
    examine = {
        flavor = "Nine centimeters of hard plastic around a disc of "
            .. "something softer. The shutter slides back under a "
            .. "thumbnail, which is the last thing anybody should be "
            .. "doing to it.",
    },
    -- Not a shortcut: tg's disk declares `inhand_icon_state = "card-id"`
    -- against the idcard hand sheets (floppy_disk.dm:46-48), which is
    -- the same cell the pack's id cards already bake
    -- (assets/sprites/30-inhand-and-worn.ron). A flat rectangle held
    -- between finger and thumb is a flat rectangle either way.
    inhand_sprite = { "held_id_l", "held_id_r" },
    files = { capacity = 737280, files = 112 },
    -- What a machine with a drive calls this while a hand holds it.
    hint_tags = { "floppy" },
    -- tg precolors the sleeves as skins of one disk
    -- (code/game/objects/items/floppy_disk.dm:6-39): the same medium in
    -- a different color of plastic. The keys are the sheet's cells
    -- (assets/sprites/74-files.ron).
    variants = {
        strange = {
            name_label = "lunatic/tfs:entity.floppy_disk.strange.name",
            name = "strange disk",
        },
        red = {
            name_label = "lunatic/tfs:entity.floppy_disk.red.name",
            name = "red floppy disk",
            sprite = "floppy_disk_red",
        },
        dark_blue = {
            name_label = "lunatic/tfs:entity.floppy_disk.dark_blue.name",
            name = "dark blue floppy disk",
            sprite = "floppy_disk_dark_blue",
        },
        yellow = {
            name_label = "lunatic/tfs:entity.floppy_disk.yellow.name",
            name = "yellow floppy disk",
            sprite = "floppy_disk_yellow",
        },
        green = {
            name_label = "lunatic/tfs:entity.floppy_disk.green.name",
            name = "green floppy disk",
            sprite = "floppy_disk_green",
        },
        purple = {
            name_label = "lunatic/tfs:entity.floppy_disk.purple.name",
            name = "purple floppy disk",
            sprite = "floppy_disk_purple",
        },
        gray = {
            name_label = "lunatic/tfs:entity.floppy_disk.gray.name",
            name = "gray floppy disk",
            sprite = "floppy_disk_gray",
        },
        light_blue = {
            name_label = "lunatic/tfs:entity.floppy_disk.light_blue.name",
            name = "light blue floppy disk",
            sprite = "floppy_disk_light_blue",
        },
        -- The disk stock scripts ship on: the orange datadisk12 sleeve
        -- (floppy_disk.dm:36-39), written with the fixed originals from
        -- reference/manifest.ron. More stock atmos programs land in this
        -- seed list.
        atmos_stock = {
            name_label = "lunatic/tfs:entity.floppy_disk.atmos_stock.name",
            name = "atmos stock disk",
            sprite = "floppy_disk_atmos_stock",
            files = {
                seed = {
                    { reference = "airlock_controller" },
                    { reference = "airlock_instructions" },
                },
            },
        },
    },
}

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:strange_disk", { prototype = "floppy_disk" })
	strange_disk_reader.register()

    local function sample_tile(samples: { string }, tile: TileAddress?)
		if tile == nil then
			table.insert(samples, "edge")
			return
		end
		table.insert(samples, sim.turf.material_at(tile) or "none")
		local matter = sim.matter_read(tile.matter)
		if matter == nil then
			table.insert(samples, "void")
			return
		end
		table.insert(samples, string.format("%.3f:%.3f", matter.temp_k, matter.pressure_kpa))
		local names = {}
		for id in pairs(matter.contents) do table.insert(names, id) end
		table.sort(names)
		for _, id in ipairs(names) do
			local row = matter.contents[id]
			table.insert(samples, string.format("%s:%.4f:%.4f:%.4f", id,
				row.gas or 0, row.liquid or 0, row.solid or 0))
		end
	end

	local function map_fingerprint(self: Handle): string
		local center = self.site
        if center == nil then
			return "placeless:" .. string.format("%.9f", sim.random_for("strange_disk/placeless", self))
		end
		local extent = sim.map_extent(center)
		if extent.width == 0 or extent.height == 0 then
			return "empty-map:" .. tostring(center.z)
		end
		local samples = { "map", tostring(extent.width), tostring(extent.height), "level", tostring(center.z) }
		for row = 0, 2 do
			for column = 0, 2 do
				local x = math.floor((column * 2 + 1) * extent.width / 6)
				local y = math.floor((row * 2 + 1) * extent.height / 6)
				table.insert(samples, string.format("global:%d:%d", x, y))
				sample_tile(samples, sim.map_tile(center, x, y, center.z))
			end
		end
		table.insert(samples, string.format("local:%d:%d", center.x, center.y))
        for dy = -1, 1 do
            for dx = -1, 1 do
				local x, y = center.x + dx, center.y + dy
				if x < 0 or y < 0 or x >= extent.width or y >= extent.height then
					table.insert(samples, "local-edge")
				else
					sample_tile(samples, sim.map_tile(center, x, y, center.z))
				end
            end
        end
        return table.concat(samples, "|")
    end

    local function seed_for(self: Handle, fingerprint: string, purpose: string): number
        local seed = math.floor(sim.random_for("strange_disk/" .. purpose, self) * 4294967296)
        for index = 1, #fingerprint do
            seed = (seed * 33 + string.byte(fingerprint, index)) % 4294967296
        end
        return seed
    end

    local function draws(initial: number): (count: number) -> number
        local seed = initial
        return function(count: number): number
            seed = (seed * 1664525 + 1013904223) % 4294967296
            return math.floor(seed / 4294967296 * math.pow(2, count))
        end
    end

    behavior:handle("entity.initialize.done", { kind = "react" }, function(ev)
        local self = ev.entity
        if self.prototype ~= "floppy_disk.strange" then return end
        local fingerprint = map_fingerprint(self)
        local presentation = strange_disk.generate(
            draws(seed_for(self, fingerprint, "raster")),
            draws(seed_for(self, fingerprint, "song")),
            sim.bitmap.rasterize,
            sim.bitmap.mode_filter
        )
        local body = strange_disk.serialize(presentation)
        assert(body ~= nil, "generated disk media exceeds its format")
        sim.documents.seed({
            store = self,
            files = { { name = "Adam", ext = "HC", body = body } },
        })
    end)
end

return content
