--!strict
local Players = game:GetService("Players")

local GetThumbnail = {}

local function fetch(player: Player, kind: Enum.ThumbnailType, size: Enum.ThumbnailSize): (string?, boolean)
	const ok, content, isReady = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, kind, size)
	end)

	if not ok then
		warn(`[GetThumbnail] falhou para {player.Name}: {content}`)
		return nil, false
	end

	return content, isReady == true
end

function GetThumbnail.AvatarBust(player: Player, size: Enum.ThumbnailSize?): (string?, boolean)
	return fetch(player, Enum.ThumbnailType.AvatarBust, size or Enum.ThumbnailSize.Size420x420)
end

function GetThumbnail.AvatarThumbnail(player: Player, size: Enum.ThumbnailSize?): (string?, boolean)
	return fetch(player, Enum.ThumbnailType.AvatarThumbnail, size or Enum.ThumbnailSize.Size150x150)
end

function GetThumbnail.HeadShot(player: Player, size: Enum.ThumbnailSize?): (string?, boolean)
	return fetch(player, Enum.ThumbnailType.HeadShot, size or Enum.ThumbnailSize.Size150x150)
end

return GetThumbnail
