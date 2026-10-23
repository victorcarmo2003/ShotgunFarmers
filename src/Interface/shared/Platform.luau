--!strict
local UserInputService = game:GetService("UserInputService")

local function isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled
end

return {
	IsMobile = isMobile,
}
