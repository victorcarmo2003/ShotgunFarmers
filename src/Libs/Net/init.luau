--!strict
-- O agregador de namespaces.
--
-- Cada feature define o seu em `src/<Feature>/shared/Net.luau`; aqui eles so
-- se juntam num lugar so, para virar `self.Libs.Net.<Feature>.<Definicao>`.
--
-- Por que o agregador precisa existir: o cliente do Lync espera o namespace
-- com `WaitForChild` sem prazo. Um namespace definido so de um lado trava o
-- boot do cliente em silencio, sem erro e sem timeout. Requerer todos daqui,
-- dos dois lados, garante que nenhum fique so num.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	Core = require(ReplicatedStorage.shared.Net.Core),
	Career = require(ReplicatedStorage.shared.Career.Net),
	Character = require(ReplicatedStorage.shared.Character.Net),
	Hit = require(ReplicatedStorage.shared.Hit.Net),
	KillFeed = require(ReplicatedStorage.shared.KillFeed.Net),
	Lobby = require(ReplicatedStorage.shared.Lobby.Net),
	Matchmaking = require(ReplicatedStorage.shared.Matchmaking.Net),
	Options = require(ReplicatedStorage.shared.Options.Net),
	Party = require(ReplicatedStorage.shared.Party.Net),
	Profile = require(ReplicatedStorage.shared.Profile.Net),
	Round = require(ReplicatedStorage.shared.Round.Net),
	Snapshot = require(ReplicatedStorage.shared.Snapshot.Net),
	Stats = require(ReplicatedStorage.shared.Stats.Net),
	Vital = require(ReplicatedStorage.shared.Vital.Net),
	Weapon = require(ReplicatedStorage.shared.Weapon.Net),
}
