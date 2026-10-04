local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Version = require(ReplicatedStorage.Shared.Version)
local Server = script.Parent

local Landscape = require(Server.Landscape)
local Props = require(Server.Props)
local World = require(Server.World)
local DevHooks = require(Server.DevHooks)
local DevActions = require(Server.DevActions)
local PlayerState = require(Server.PlayerState)
local Plots = require(Server.Plots)
local Movement = require(Server.Movement)
local Wheel = require(Server.Wheel)
local Carry = require(Server.Carry)
local Nests = require(Server.Nests)
local Guardians = require(Server.Guardians)
local Vault = require(Server.Vault)
local Showcase = require(Server.Showcase)
local DummyBase = require(Server.DummyBase)
local Bat = require(Server.Bat)

Remotes.createAll()
-- The land is written in the background while the scenery packs download, nearest the district
-- first. Nobody is let in until all of it is down (below).
local landReady = false
task.spawn(function()
	local ok, err = pcall(Landscape.build)
	if not ok then
		warn(`[Landscape] the land was not written: {err}`)
	end
	landReady = true
end)
-- The licensed scenery packs first: World uses them where they arrived (Props).
Props.load()
local world = World.build()

-- Services connect to PlayerState signals first; PlayerState.start() then announces players.
Plots.start()
Movement.start()
Wheel.start()
Carry.start()
Nests.start(world.nests)
Guardians.start(world.nests)
Vault.start()
Showcase.start()
DummyBase.start()
Bat.start()

DevHooks.register("world", function()
	return { nests = #world.nests, curbRadius = world.curbRadius }
end)
DevActions.start()
DevHooks.start()

while not landReady do
	task.wait()
end
workspace:SetAttribute("PlayersAdmittedAt", os.clock())
PlayerState.start()

print(`[{Version.name}] server booted ({Version.stage})`)
