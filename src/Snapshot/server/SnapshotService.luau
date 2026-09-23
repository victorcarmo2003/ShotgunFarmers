--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local Modux = require(ServerScriptService.server.Modux)

type MovementState = CharacterNet.MovementState

export type SnapshotFrame = {
	Position: Vector3,
	LookAt: Vector3,
	State: MovementState,
	MoveDir: Vector2,
	WeaponID: number,
	Timestamp: number,
}

const SnapshotService = Modux.Service("SnapshotService", { Require = { "IDService", "PlayerService" }, Priority = 690 })

function SnapshotService:Setup()
	self.History = {} :: { [number]: { SnapshotFrame } }
	self.Recorded = {} :: { [Player]: number }
end

function SnapshotService:RegisterSnapshot(player: Player, frame: SnapshotFrame)
	const targetID = self.Dependencies.IDService:GetPlayerID(player)
	self.Recorded[player] = targetID

	local history = self.History[targetID]
	if not history then
		history = {}
		self.History[targetID] = history
	end

	const last = history[#history]
	if last and frame.Timestamp <= last.Timestamp then
		return
	end

	table.insert(history, frame)
end

function SnapshotService:GetHistory(targetID: number): { SnapshotFrame }?
	return self.History[targetID]
end

function SnapshotService:GetRewoundPosition(targetID: number, atTime: number): Vector3?
	const history = self.History[targetID]
	if not history or #history == 0 then
		return nil
	end

	const clamped = math.max(atTime, workspace:GetServerTimeNow() - GameSettings.MaxRewindSeconds)

	local before: SnapshotFrame? = nil
	local after: SnapshotFrame? = nil

	for _, frame in history do
		if frame.Timestamp <= clamped then
			before = frame
		else
			after = frame
			break
		end
	end

	if before and after then
		const span = after.Timestamp - before.Timestamp
		const alpha = if span > 0 then (clamped - before.Timestamp) / span else 0
		return before.Position:Lerp(after.Position, math.clamp(alpha, 0, 1))
	elseif before then
		return before.Position
	elseif after then
		return after.Position
	end

	return nil
end

function SnapshotService:ClearHistory(targetID: number)
	self.History[targetID] = nil
end

function SnapshotService:Prune()
	const cutoff = workspace:GetServerTimeNow() - GameSettings.SnapshotHistorySeconds

	for _, history in self.History do
		local trimmed = 0
		for _, frame in history do
			if frame.Timestamp >= cutoff then
				break
			end
			trimmed += 1
		end

		for _ = 1, trimmed do
			table.remove(history, 1)
		end
	end
end

SnapshotService:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Snapshot.Frame:onServer(function(frame, player)
		self:RegisterSnapshot(player, frame)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		const targetID = self.Recorded[player]
		if not targetID then
			return
		end

		self.Recorded[player] = nil
		self:ClearHistory(targetID)
	end)
end)

SnapshotService:OnTick(function(self)
	self:Prune()
end, 10)

return SnapshotService
