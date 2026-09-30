-- Hides prompts meant for someone else (heist plan, "Prompt attributes"). The server tags owner-only and
-- thief-only prompts with `Plot` and `Audience`; this compares them with the local player's `Plot` attribute.
-- A prompt with no `Audience` is shown to everyone. The server still re-checks every trigger.
local Players = game:GetService("Players")

local PromptFilter = {}

local localPlayer = Players.LocalPlayer

local function apply(prompt: ProximityPrompt)
	local audience = prompt:GetAttribute("Audience")
	if audience == nil then
		return
	end
	local mine = localPlayer:GetAttribute("Plot")
	local isOwner = mine ~= nil and prompt:GetAttribute("Plot") == mine
	prompt.Enabled = if audience == "owner" then isOwner else not isOwner
end

local function applyAll()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			apply(descendant)
		end
	end
end

function PromptFilter.start()
	workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("ProximityPrompt") then
			apply(descendant)
		end
	end)
	localPlayer:GetAttributeChangedSignal("Plot"):Connect(applyAll)
	applyAll()
end

return PromptFilter
