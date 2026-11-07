-- TempleOS GodSong.HC:Adam/God/GodSong.HC:57-171; defaults in lines 3-55.
export type Note = { pitch: number, duration: number }
export type Song = { tempo: number, gate: number, notes: { Note } }
export type Random = (count: number) -> number

local song = {}

local function phrase(random: Random): { Note }
	local notes: { Note } = {}
	for _ = 1, 8 do
		local choice = random(3)
		while choice >= 5 do choice = random(3) end
		local durations: { number }
		if choice < 2 then durations = { 12 }
		elseif choice == 2 then durations = { 6, 6 }
		elseif choice == 3 then durations = { 4, 4, 4 }
		else durations = { 3, 3, 3, 3 } end
		for _, duration in ipairs(durations) do
			table.insert(notes, { pitch = random(3), duration = duration })
		end
	end
	return notes
end

function song.generate(random: Random): Song
	local first, second = phrase(random), phrase(random)
	local notes: { Note } = {}
	for _ = 1, 2 do
		for _, note in ipairs(first) do table.insert(notes, note) end
	end
	for _ = 1, 2 do
		for _, note in ipairs(second) do table.insert(notes, note) end
	end
	return { tempo = 150, gate = 90, notes = notes }
end

return song
