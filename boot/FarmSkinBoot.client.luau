--!strict
if workspace:GetAttribute("FarmSkin") == false then
	return
end
local FarmSkin = require(script.Parent:WaitForChild("client"):WaitForChild("Interface"):WaitForChild("FarmSkin"))
FarmSkin.Start()
