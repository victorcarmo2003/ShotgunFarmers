return {
	-- Diâmetro (Size.Y/Z) do monte de terra -- Size.X fica com o valor já modelado na
	-- part em Studio, só Y/Z crescem. Puramente visual (ver SeedController), o server
	-- nunca lê isso.
	DIRT_START_DIAMETER = 0.5,
	DIRT_END_DIAMETER = 2,
	DIRT_GROW_TIME = 1.5,

	-- Escala (Model.Scale) do model da semente específica da arma, do momento em que
	-- emerge da terra até o tamanho final. Puramente visual (ver SeedController).
	SEED_START_SCALE = 0.15,
	SEED_END_SCALE = 0.4,
	SEED_GROW_TIME = 2,
	-- Quanto o model da semente sobe (studs), de dentro da terra até a posição final.
	SEED_RISE_HEIGHT = 2,

	-- Segundos após o plantio (GunMixin.PlantAt define PlantedAt) até o server liberar
	-- o ProximityPrompt pra colheita -- comparado com workspace:GetServerTimeNow(), não
	-- com o crescimento visual (que é só client agora, ver SeedController). Valor
	-- mantido equivalente ao COLLECT_SCALE_THRESHOLD antigo (0.2 de escala, dentro de um
	-- SEED_GROW_TIME de 2s) -- ajuste livremente se quiser liberar mais cedo/tarde.
	COLLECT_TIME_THRESHOLD = 0.4,

	-- Munição concedida quando o jogador já tem a arma da semente no loadout (ver
	-- SeedComponent.Harvest e EquipmentComponent.AddAmmo).
	AMMO_REWARD_AMOUNT = 8,
}
