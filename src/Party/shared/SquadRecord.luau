--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartySettings = require(ReplicatedStorage.shared.Party.PartySettings)

export type Status = "Lobby" | "Idle"
export type Member = { Id: number, Name: string, Status: Status, Joined: number }
export type Record = { Leader: number, Lobby: string, Job: string, Members: { Member }, At: number }
export type DisplayStatus = "Present" | "Idle" | "Away" | "Joining"

const SquadRecord = {}

function SquadRecord.sanitizeMember(raw: any): Member?
	if typeof(raw) ~= "table" or typeof(raw.Id) ~= "number" then
		return nil
	end

	const status: Status = if raw.Status == "Idle" then "Idle" else "Lobby"
	return {
		Id = raw.Id,
		Name = if typeof(raw.Name) == "string" then string.sub(raw.Name, 1, 40) else "",
		Status = status,
		Joined = if typeof(raw.Joined) == "number" then raw.Joined else 0,
	}
end

function SquadRecord.sanitize(raw: any): Record?
	if typeof(raw) ~= "table" then
		return nil
	end

	const members: { Member } = {}
	if typeof(raw.Members) == "table" then
		for _, entry in raw.Members do
			const member = SquadRecord.sanitizeMember(entry)
			if member and #members < PartySettings.MaxSize then
				table.insert(members, member)
			end
		end
	end

	return {
		Leader = if typeof(raw.Leader) == "number" then raw.Leader else 0,
		Lobby = if typeof(raw.Lobby) == "string" then raw.Lobby else "",
		Job = if typeof(raw.Job) == "string" then raw.Job else "",
		Members = members,
		At = if typeof(raw.At) == "number" then raw.At else 0,
	}
end

function SquadRecord.find(record: Record, userId: number): (Member?, number?)
	for index, member in record.Members do
		if member.Id == userId then
			return member, index
		end
	end
	return nil, nil
end

function SquadRecord.promote(record: Record, preferred: { number })
	if SquadRecord.find(record, record.Leader) then
		return
	end

	for _, userId in preferred do
		if SquadRecord.find(record, userId) then
			record.Leader = userId
			return
		end
	end

	const first = record.Members[1]
	record.Leader = if first then first.Id else 0
end

function SquadRecord.ordered(record: Record): { Member }
	const ordered: { Member } = {}
	const leader = SquadRecord.find(record, record.Leader)
	if leader then
		table.insert(ordered, leader)
	end
	for _, member in record.Members do
		if member.Id ~= record.Leader then
			table.insert(ordered, member)
		end
	end
	return ordered
end

function SquadRecord.slot(record: Record, userId: number): number?
	for index, member in SquadRecord.ordered(record) do
		if member.Id == userId then
			return index
		end
	end
	return nil
end

function SquadRecord.display(member: Member, present: boolean, now: number): DisplayStatus
	if present then
		return "Present"
	elseif member.Status == "Idle" then
		return "Idle"
	elseif now - member.Joined < PartySettings.JoinGrace then
		return "Joining"
	end
	return "Away"
end

function SquadRecord.leaderName(record: Record): string
	const leader = SquadRecord.find(record, record.Leader)
	return if leader and leader.Name ~= "" then leader.Name else "the leader"
end

function SquadRecord.remove(record: Record, userId: number): boolean
	const _, index = SquadRecord.find(record, userId)
	if not index then
		return false
	end

	table.remove(record.Members, index)
	SquadRecord.promote(record, {})
	record.At = os.time()
	return true
end

return SquadRecord
