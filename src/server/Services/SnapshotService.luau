local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameSettings = require(ReplicatedStorage.Shared.Settings.GameSettings)
local Modux = require(game.ReplicatedStorage.Shared.Modux)

export type SnapshotFrame = {
	Position: Vector3,
	LookAt: Vector3,
	State: number,
	MoveDir: Vector2,
	WeaponID: number,
	Timestamp: number,
}

local SnapshotService = Modux.Service("SnapshotService"):Import("IDService"):Import("PlayerService")
type Self = typeof(SnapshotService)

SnapshotService.History = {} :: { [number]: { SnapshotFrame } }

SnapshotService.RegisterSnapshot = function(self: Self, Player: Player, snapshot)
	local targetID = self.IDService:GetPlayerID(Player)

	local frame: SnapshotFrame = {
		Position = Vector3.new(snapshot.Position.X, snapshot.Position.Y, snapshot.Position.Z),
		LookAt = Vector3.new(snapshot.LookAt.X, snapshot.LookAt.Y, snapshot.LookAt.Z),
		State = snapshot.State,
		MoveDir = snapshot.MoveDir,
		WeaponID = snapshot.WeaponID,
		Timestamp = snapshot.Timestamp,
	}

	local history = self.History[targetID]
	if not history then
		history = {}
		self.History[targetID] = history
	end

	table.insert(history, frame)
end

SnapshotService.GetHistory = function(self: Self, targetID: number): { SnapshotFrame }?
	return self.History[targetID]
end

SnapshotService.GetRewoundPosition = function(self: Self, targetID: number, atTime: number): Vector3?
	local history = self.History[targetID]
	if not history or #history == 0 then
		return nil
	end

	local now = workspace:GetServerTimeNow()
	local clampedTime = math.max(atTime, now - GameSettings.MaxRewindSeconds)

	local before: SnapshotFrame? = nil
	local after: SnapshotFrame? = nil

	for i = 1, #history do
		local frame = history[i]
		if frame.Timestamp <= clampedTime then
			before = frame
		elseif not after then
			after = frame
			break
		end
	end

	if before and after then
		local span = after.Timestamp - before.Timestamp
		local alpha = if span > 0 then (clampedTime - before.Timestamp) / span else 0
		return before.Position:Lerp(after.Position, math.clamp(alpha, 0, 1))
	elseif before then
		return before.Position
	elseif after then
		return after.Position
	end

	return nil
end

SnapshotService.ClearHistory = function(self: Self, targetID: number)
	self.History[targetID] = nil
end

SnapshotService:OnInit(function(self)
	self.Network.Packages.PlayerSnapshot:on(function(data, sender: Player?)
		if not sender then
			return
		end
		self:RegisterSnapshot(sender, data)
	end)

	self.PlayerService:OnPlayerRemoved(function(Player: Player)
		local targetID = self.IDService:GetPlayerID(Player)
		self:ClearHistory(targetID)
	end)
end)

SnapshotService:OnTick(function(self, deltaTime: number)
	local cutoff = workspace:GetServerTimeNow() - GameSettings.SnapshotHistorySeconds

	for _, history in self.History do
		local trimmed = 0
		for i = 1, #history do
			if history[i].Timestamp >= cutoff then
				break
			end
			trimmed += 1
		end
		for _ = 1, trimmed do
			table.remove(history, 1)
		end
	end
end, Modux.TickRate.Hz60)

return SnapshotService
