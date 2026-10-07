--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Category = "Firearm" | "Melee" | "Throwable"

export type Entry = {
	ID: number,
	Name: GetGun.GunNames,
	Image: string,
	Category: Category,
	Slot: number,
}

export type Section = {
	Category: Category,
	Label: string,
	Entries: { Entry },
}

const MODE = "Practice"
const INFINITE_AMMO = "InfiniteAmmo"
const INFINITE_GRENADES = "InfiniteGrenades"

const SECTIONS: { { Category: Category, Label: string, Slot: number } } = {
	{ Category = "Firearm", Label = "WEAPONS", Slot = 1 },
	{ Category = "Melee", Label = "MELEE", Slot = 3 },
	{ Category = "Throwable", Label = "GRENADES", Slot = 2 },
}

local function build(): ({ Section }, { [number]: Entry })
	const sections: { Section } = {}
	const byID: { [number]: Entry } = {}

	for _, info in SECTIONS do
		const entries: { Entry } = {}
		for name, gunData in GetGun.All do
			if gunData.Disabled or gunData.PoseKind ~= info.Category then
				continue
			end

			const entry: Entry = {
				ID = gunData.ID,
				Name = name :: GetGun.GunNames,
				Image = gunData.ImageID,
				Category = info.Category,
				Slot = info.Slot,
			}
			table.insert(entries, entry)
			byID[entry.ID] = entry
		end

		table.sort(entries, function(a: Entry, b: Entry): boolean
			return a.ID < b.ID
		end)
		table.insert(sections, { Category = info.Category, Label = info.Label, Entries = entries })
	end

	return sections, byID
end

const sections, byID = build()

return {
	MODE = MODE,
	INFINITE_AMMO = INFINITE_AMMO,
	INFINITE_GRENADES = INFINITE_GRENADES,
	Sections = sections,
	ByID = byID,
}
