local T = require("./TestLib")
local Sounds = require("../src/shared/Sounds")
local Strings = require("../src/shared/Strings")

local SOURCES = { Roblox = true, ProSoundEffects = true, APM = true }

T.test("every catalogue sound has an id, a sane volume and an allowed source", function()
	for key, entry in Sounds.Catalog do
		T.expectTrue(type(entry.id) == "number" and entry.id > 0, `{key} id`)
		T.expectTrue(entry.volume > 0 and entry.volume <= 1, `{key} volume`)
		T.expectTrue(SOURCES[entry.source], `{key} source {entry.source}`)
		T.expectEqual(Sounds.uri(key), `rbxassetid://{entry.id}`)
	end
end)

local function checkStyles(styles: { [string]: Sounds.Style }, keys: { [string]: string }, label: string)
	for key in keys do
		local style = styles[key]
		T.expectTrue(style ~= nil, `{label}.{key} has no style`)
		T.expectTrue(Sounds.Tones[style.tone], `{label}.{key} tone {style.tone}`)
		T.expectTrue(Sounds.Catalog[style.sound] ~= nil, `{label}.{key} sound {style.sound}`)
	end
	for key in styles do
		T.expectTrue(keys[key] ~= nil, `{label} style for unknown key {key}`)
	end
end

T.test("every toast string has a tone and a sound, and no style is left over", function()
	checkStyles(Sounds.Toasts, Strings.Toasts, "Toasts")
end)

T.test("every theft message has a tone and a sound, and no style is left over", function()
	checkStyles(Sounds.Theft, Strings.Theft, "Theft")
end)
