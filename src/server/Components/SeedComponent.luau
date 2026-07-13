local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeedSettings = require(ReplicatedStorage.Shared.Settings.SeedSettings)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)
local Modux = require(game.ReplicatedStorage.Shared.Modux)

-- Só lógica de colheita aqui -- crescimento/visual da semente é 100% client
-- (ver Interface/Controllers/SeedController.luau), o server nunca interpola
-- CFrame/Scale nem clona o SeedModel. Toda decisão de tempo ("já pode colher?")
-- compara workspace:GetServerTimeNow() contra o instante do plantio (PlantedAt).
local SeedComponent = Modux.Component("SeedComponent"):Tag("SeedComponent"):ClassName("Part")

SeedComponent.Setup = function(self)
	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.Parent = self.Instance
	ProximityPrompt.ActionText = "COLLECT"
	ProximityPrompt.ObjectText = self.GunData.DisplayName
	ProximityPrompt.HoldDuration = 0.5
	ProximityPrompt.Enabled = false
	self.Proximity = ProximityPrompt
end

-- Conecta o listener de coleta ANTES de liberar o Proximity (ligado pelo OnTick assim
-- que COLLECT_TIME_THRESHOLD passa) -- o listener precisa já existir nesse ponto.
SeedComponent.Harvest = function(self)
	self._harvested = false :: boolean
	self:Cleanup(self.Proximity.Triggered:Connect(function(Player: Player)
		-- Debounce: dois jogadores podem completar o HoldDuration do mesmo prompt quase
		-- ao mesmo tempo -- sem isso, ambos os Triggered rodam (nenhum dá yield antes do
		-- Destroy), concedendo a recompensa em dobro antes da instância sumir de verdade.
		if self._harvested then
			return
		end
		self._harvested = true

		local equipment = self:GetComponent(Player, "EquipmentComponent")
		if not equipment then
			print(`[SeedComponent] Harvest abortado -- {Player.Name} sem EquipmentComponent`)
			return
		end

		print(`[SeedComponent] {Player.Name} colheu {self.GunName} em {self.Instance:GetFullName()}`)

		if equipment:HasGun(self.GunName) then
			equipment:AddAmmo(self.GunName, SeedSettings.AMMO_REWARD_AMOUNT)
		else
			equipment:GrantWeapon(self.GunName)
		end

		self.Instance:Destroy()
	end))
end

SeedComponent:OnStart(function(self)
	local gunName = self.Instance:GetAttribute("GunName") :: string?
	local gunData = gunName and GetGun:GetByName(gunName :: any)
	print(`[SeedComponent] OnStart em {self.Instance:GetFullName()} -- GunName={tostring(gunName)}`)

	if not gunData then
		warn(`[SeedComponent] GunName inválido/ausente ("{tostring(gunName)}") -- plantado sem GunMixin.PlantAt?`)
		self.Instance:Destroy()
		return
	end

	self.GunName = gunName :: string
	self.GunData = gunData :: GetGun.GunData

	-- GunMixin.PlantAt grava este atributo (workspace:GetServerTimeNow() no momento do
	-- plantio) -- fallback pro agora só cobre sementes coladas manualmente no Studio
	-- (sem passar por PlantAt), pra não travar o Proximity pra sempre nesse caso.
	self.PlantedAt = (self.Instance:GetAttribute("PlantedAt") :: number?) or workspace:GetServerTimeNow()

	self:Setup()
	self:Harvest()
end)

SeedComponent:OnTick(function(self, deltaTime: number)
	if self.Proximity.Enabled then
		return
	end

	local elapsed = workspace:GetServerTimeNow() - self.PlantedAt
	if elapsed >= SeedSettings.COLLECT_TIME_THRESHOLD then
		print(`[SeedComponent] {self.Instance:GetFullName()} liberado pra colheita (elapsed={elapsed})`)
		self.Proximity.Enabled = true
	end
end, Modux.TickRate.Hz10)

return SeedComponent
