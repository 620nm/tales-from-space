-- The file is inert generated media inspired by TempleOS HolyC programs.
export type Note = { pitch: number, duration: number }
export type Song = { tempo: number, gate: number, notes: { Note } }
export type Bitmap = { width: number, height: number, palette: { string }, pixels: string }
export type Presentation = { width: number, height: number, palette: { string }, pixels: string, song: Song }

local format = {}
local LIMIT = 8192
local PIXELS = 64 * 48
local PITCH_TEXT = { "0", "1", "2", "3", "4", "5", "6", "7" }
local DURATION_TEXT = { [3] = "3", [4] = "4", [6] = "6", [12] = "12" }
local PALETTE = { "000000", "AA0000", "AAAAAA", "555555", "FFFFFF" }

local function line_at(source: string, start: number): (string?, number)
	local stop = string.find(source, "\n", start, true)
	if stop == nil then return nil, start end
	return string.sub(source, start, stop - 1), stop + 1
end

local function encode_notes(notes: { Note }): string
	local parts: { string } = table.create(#notes, "")
	for index = 1, #notes do
		local note = notes[index]
		parts[index] = PITCH_TEXT[note.pitch + 1] .. ":" .. DURATION_TEXT[note.duration]
	end
	return table.concat(parts, ",")
end

local function valid_aabb(notes: { Note }): boolean
	local elapsed = 0
	local first_end, second_end, third_end = 0, 0, 0
	for index = 1, #notes do
		local note = notes[index]
		elapsed += note.duration
		if elapsed > 384 then return false end
		if elapsed == 96 then first_end = index
		elseif elapsed == 192 then second_end = index
		elseif elapsed == 288 then third_end = index
		end
	end
	if elapsed ~= 384 or first_end == 0 or second_end == 0 or third_end == 0 then return false end
	local first_length, second_length = first_end, second_end - first_end
	if first_length ~= second_length then return false end
	for index = 1, first_length do
		local first, repeat_note = notes[index], notes[first_end + index]
		if first.pitch ~= repeat_note.pitch or first.duration ~= repeat_note.duration then return false end
	end
	local third_length, fourth_length = third_end - second_end, #notes - third_end
	if third_length ~= fourth_length then return false end
	for index = 1, third_length do
		local third, repeat_note = notes[second_end + index], notes[third_end + index]
		if third.pitch ~= repeat_note.pitch or third.duration ~= repeat_note.duration then return false end
	end
	return true
end

local function decode_notes(source: string): { Note }?
	local notes: { Note } = {}
	local cursor = 1
	local total = 0
	while cursor <= #source do
		local comma = string.find(source, ",", cursor, true) or (#source + 1)
		local token = string.sub(source, cursor, comma - 1)
		local colon = string.find(token, ":", 1, true)
		if colon == nil then return nil end
		local pitch, duration = tonumber(string.sub(token, 1, colon - 1)), tonumber(string.sub(token, colon + 1))
		if pitch == nil or duration == nil or pitch % 1 ~= 0 or duration % 1 ~= 0
			or pitch < 0 or pitch > 7
			or (duration ~= 3 and duration ~= 4 and duration ~= 6 and duration ~= 12) then return nil end
		total += duration
		if total > 384 or #notes >= 128 then return nil end
		table.insert(notes, { pitch = pitch, duration = duration })
		cursor = comma + 1
	end
	if total ~= 384 or #notes == 0 or not valid_aabb(notes) then return nil end
	return notes
end

function format.serialize(presentation: Presentation): string?
	if presentation.width ~= 64 or presentation.height ~= 48
		or type(presentation.pixels) ~= "string" or #presentation.pixels ~= PIXELS
		or #presentation.palette ~= #PALETTE then return nil end
	for index = 1, #PALETTE do if presentation.palette[index] ~= PALETTE[index] then return nil end end
	local pixel_text = presentation.pixels
	local score = presentation.song
	if score.tempo ~= 150 or score.gate ~= 90 then return nil end
	if #score.notes > 128 or not valid_aabb(score.notes) then return nil end
	local body_parts: { string } = {
			"STRANGE1\n64x48\n000000,AA0000,AAAAAA,555555,FFFFFF\n",
		pixel_text,
		"\n150,90\n",
		encode_notes(score.notes),
		"\n",
	}
	local body = table.concat(body_parts)
	if #body > LIMIT then return nil end
	return body
end

function format.parse(source: string): Presentation?
	if #source > LIMIT then return nil end
	local magic, cursor = line_at(source, 1)
	local dimensions; dimensions, cursor = line_at(source, cursor)
	local palette_line; palette_line, cursor = line_at(source, cursor)
	local encoded; encoded, cursor = line_at(source, cursor)
	local settings; settings, cursor = line_at(source, cursor)
	local score; score, cursor = line_at(source, cursor)
	if magic ~= "STRANGE1" or dimensions ~= "64x48" or palette_line ~= "000000,AA0000,AAAAAA,555555,FFFFFF"
		or encoded == nil or #encoded ~= PIXELS
		or settings ~= "150,90" or score == nil or cursor ~= #source + 1 then return nil end
	if string.find(encoded, "[^0-4]") ~= nil then return nil end
	local notes = decode_notes(score)
	if notes == nil then return nil end
	return { width = 64, height = 48, palette = table.clone(PALETTE), pixels = encoded,
		song = { tempo = 150, gate = 90, notes = notes } }
end

return format
