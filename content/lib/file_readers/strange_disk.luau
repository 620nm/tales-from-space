local strange_disk = require("@lib/strange_disk/init")

export type Presentation = {
	bitmap: {
		width: number,
		height: number,
		palette: { string },
		pixels: string,
	},
	score: {
		bpm: number,
		gate_pct: number,
		range_tiles: number,
		gain_pct: number,
		notes: { { midi: number, duration_units: number } },
	},
}

local COLORS = { "#000000", "#AA0000", "#AAAAAA", "#555555", "#FFFFFF" }
local MIDI_PITCHES = { 67, 69, 71, 72, 74, 76, 77, 79 }
local reader = {}

function reader.read(body: string): Presentation?
	local decoded = strange_disk.parse(body)
	if decoded == nil then return nil end
	local notes: { { midi: number, duration_units: number } } = {}
		for _, note in ipairs(decoded.song.notes) do
			local midi = MIDI_PITCHES[note.pitch + 1]
			if midi == nil then return nil end
			table.insert(notes, { midi = midi, duration_units = note.duration })
	end
	return {
		bitmap = {
			width = decoded.width,
			height = decoded.height,
			palette = COLORS,
			pixels = decoded.pixels,
		},
		score = {
			bpm = decoded.song.tempo,
			gate_pct = decoded.song.gate,
			range_tiles = 7,
			gain_pct = 25,
			notes = notes,
		},
	}
end

function reader.register()
	sim.documents.reader.register("strange_disk", reader.read)
end

return reader
