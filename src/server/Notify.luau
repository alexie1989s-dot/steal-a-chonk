-- Server side of player feedback: a toast with its tone and sound, or a sound on its own.
-- The client decides how a tone looks; the server decides which tone a message has (Sounds).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Notify = {}

-- A Strings.Toasts message by key. Unknown keys send nothing, as the old per-module helpers did.
function Notify.toast(player: Player, key: string)
	local text = Strings.Toasts[key]
	if not text then
		return
	end
	local style = Sounds.Toasts[key]
	Remotes.get("Toast"):FireClient(player, text, style and style.tone, style and style.sound)
end

-- Already formatted text, styled by a Sounds.Theft key.
function Notify.theft(player: Player, key: string, text: string)
	local style = Sounds.Theft[key]
	Remotes.get("Toast"):FireClient(player, text, style and style.tone, style and style.sound)
end

-- A sound with no message, heard only by this player.
function Notify.sound(player: Player, key: string)
	Remotes.get("Sfx"):FireClient(player, key)
end

return Notify
