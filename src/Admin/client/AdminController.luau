--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ConchUI = require(ReplicatedStorage.Packages.ConchUI)
local conch = require(ReplicatedStorage.Packages.Conch)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TOGGLE_KEY = Enum.KeyCode.F2

const AdminController = Modux.Controller("AdminController", { Priority = 350 })

AdminController:OnStart(function(_self)
	conch.initiate_default_lifecycle()
	ConchUI.bind_to(TOGGLE_KEY)
end)

return AdminController
