local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Version = require(ReplicatedStorage.Shared.Version)
local Server = script.Parent

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
local Bat = require(Server.Bat)

Remotes.createAll()
local world = World.build()

-- Services connect to PlayerState signals first; PlayerState.start() then announces players.
Plots.start()
Movement.start()
Wheel.start()
Carry.start()
Nests.start(world.nests)
Guardians.start(world.nests)
Vault.start()
Bat.start()

DevHooks.register("world", function()
	return { nests = #world.nests, curbRadius = world.curbRadius }
end)
DevActions.start()
DevHooks.start()

PlayerState.start()

print(`[{Version.name}] server booted ({Version.stage})`)
