--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

return (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance
