# ShotgunFarmers — Roblox Game Project

## Overview
ShotgunFarmers is a first-person arena shooter (FPS) on Roblox where the weapons are vegetable-themed guns and the arenas are small farms. Players fire shotguns/rifles with per-pellet hit registration, plant and harvest "seeds" on `Farmland` parts (weapons and ammo spawn as seeds), and use a movement FSM with slide/crouch.

- **Modes** (`src/Match/shared/GameModes.luau`): `FFA`, `TDM`, `Chicken` (team modes) and `Practice` (infinite round, infinite ammo/grenades).
- **Lobby and match are the same place.** `ServerRoleService` (`src/Match/server/`) decides a server's role (`Lobby` | `Match` | `Router`) from the MemoryStore config of the reserved server (`game.PrivateServerId`). `MatchmakingService`/`RouterService`/`MatchRegistryService` + `TeleportGateway` do `ReserveServer` + `TeleportAsync` into the same place (see `docs/PublishChecklist.md`). Teleport does not work in Studio; use the `ForceRole`/`ForceMode`/`ForceMap` attributes on `workspace` (Studio only).
- Project is a port of an older Modux V2 + Fusion codebase (`docs/MIGRACAO.md`); screens are being integrated step by step (`docs/IntegrationPlan.md`). Not implemented yet: private rooms, Quests, Cosmetics, Shop (buttons exist, they only `print`).

## Tech stack
- **Language:** Luau, `--!strict`, `LuauSolverV2` required (`.vscode/settings.json` enables it). The code uses Luau `const`.
- **Framework:** Modux V3 (`src/Modux`, a copy of the `framework` branch of victorcarmo2003/ModuxV3).
- **Networking:** Lync (`lync` 4.x API: `Lync.define`, `packet`, `query`, `replicate`, `struct`, ...), one namespace per feature.
- **Server reactive state:** Charm (`self.Libs.Charm.atom/batch/effect`). **Client reactive state/UI:** Vide (`source`, `derive`, `effect`, `create`, `mount`). The two do not interoperate.
- **Persistence:** ProfileStore (`ServerPackages/ProfileStore`), wrapped by `src/Profile/server/ProfileService`.
- **UI dev:** UI Labs stories (`DevPackages/UILabs`), `*.story.luau` + `*.storybook.luau`.
- **Admin:** Conch + ConchUI (`src/Admin`).
- **Other packages in `Packages/`:** QuickZone (zones), Spring. Libs in `src/Libs`: Signal, Promise, FSM, Charm, Spring, Net.
- **Tooling (`rokit.toml`):** wally, rojo 7.7.0, rogen, modux (ModuxWatcher), wally-package-types, syncteam.

## Setup / build pipeline
```sh
rokit install
wally install
wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/
rogen build
modux generate
rojo serve
```
- `wally-package-types` is mandatory after every `wally install`, otherwise `Vide.Source` / `Charm.Atom` become `Unknown type`.
- **`rogen build` always before `modux generate`**: `default.project.json` is generated from the folders under `src/` (config in `.rogen.json`).
- `modux check` fails if generated files are stale; `tools/analyze.ps1` runs the Luau analyzer over the whole project (passing means "no errors", not "types exist"; write an access that should fail to confirm `self` is typed). `tools/packages.ps1` runs install + `rogen build`.
- Generated, never edit by hand: `default.project.json`, `src/ModuxTypes/**` (one type file per module), `src/Modux/{client,server}/Manifest/init.luau`, `src/Modux/{client,server}/Modules.luau`, `src/Modux/shared/Libs.luau`. Manual Manifest edits are reconciled by the watcher but should not be needed.
- `wally.toml` lists the real deps (Vide, Charm, Lync, Conch, ConchUI, QuickZone, Spring; ProfileStore server; UILabs dev). `Promise` is local (`src/Libs/Promise`), not a Wally package.

## Structure
Feature-based (rogen): `src/<Feature>/{client,server,shared}`. Path becomes DataModel location: `src/Vital/server/` -> `ServerScriptService.server.Vital`, `src/Vital/shared/` -> `ReplicatedStorage.shared.Vital`, `src/Vital/client/` -> `StarterPlayerScripts.client.Vital`.

```
src/
  Admin/        conch commands (give/kill/wipe/tp) + panel; AdminSettings holds admin UserIds
  Audio/        MusicController (playlist from ReplicatedStorage.Assets.Musics)
  Camera/       Camera/FOV/UnlockCamera controllers (first person, killcam)
  Career/       progression/level (CareerService, Net, client)
  Character/    movement FSM, SpawnService, animations (PlayerAnimations, GetAnimations)
  Cosmetics/    client only, not implemented
  DayNight/     day/night cycle on Lighting
  GameSelection/ mode-selection Vide screen + story
  Hit/          HitService (server validation, rewind), HitController, ProjectileController, Body parts
  Input/        InputController (ContextActionService, Gameplay/Menu contexts)
  Interface/    InterfaceController, SurfaceUIController, ScreenKit, shared Fonts/Theme/CreateRaw, Components/ (Counter, ProgressionBar)
  KillFeed/     kill feed queue UI + Net
  Leaderstats/  client leaderboard (Tab)
  Libs/         injected into self.Libs: Charm, FSM, Net (aggregator), Promise, Signal, Spring
  Lobby/        LobbyScreen, OnlineService/OnlineController (global online count)
  Match/        GameModes, Maps, MatchSettings, GameState, ServerRoleService, GameStateService, EnvironmentService, client LobbyController/GameStateController
  Matchmaking/  MatchmakingService, RouterService, MatchRegistryService, TeleportGateway
  Modux/        framework (do not modify)
  ModuxTypes/   generated types per module
  Net/          NetService/NetController (Lync start, Ready handshake, Core.luau, Log.luau)
  Options/      OptionsService/Controller, settings and keybinds
  Party/        squad/party and invites
  Player/       PlayerService, IDService, PlayerBillboardService
  Practice/     PracticeService, PracticeCatalog, practice panel (key B)
  Profile/      ProfileService (ProfileStore + Charm atoms), ProfileController
  Quests/       client only, not implemented
  Round/        RoundService (Starting/Match/Intermission/Vote), RoundController, TimerLabel
  Seed/         plant/harvest on Farmland, SeedSettings
  Settings/     shared GameSettings
  Shared/       Packages index
  Shop/         client/shared, not implemented
  Snapshot/     60 Hz position/look snapshots and history for lag compensation
  Stats/        MatchStatsService (K/D/A/score), TeamService, LeaderstatsController
  Types/        Atomic, Occlude, Struct, Union utility types
  Utils/        GetThumbnail
  Vital/        Vital component (Health/Armor/Stamina), VitalService, VitalController, StatusBar
  Weapon/       Equipment, Gun component, WeaponService, WeaponSpawnService, ThrowableService, GunsData (21 guns), Ballistics, client Weapon/Arms/Throwable/VFX controllers, Crosshair, GunBar
  Zone/         ZoneService (QuickZone)
```
Other top-level: `Assets/`, `docs/` (MIGRACAO, IntegrationPlan, PublishChecklist, GDD pdf), `tools/`, `references/`, `backup/` (old place files), `Extras/`.

## Modux V3 patterns
Modules are declared with a table of options; `Require` injects dependencies into `self.Dependencies`, `Priority` orders lifecycle (higher runs first), `self.Libs` has the `src/Libs` entries, `self.Components.<Name>` the component registry. State is set in a `Setup` method called from `OnInit`; type of fields comes from `:: Type` casts.

Service (server, `src/<Feature>/server/`):
```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const RoundService = Modux.Service("RoundService", {
	Require = { "DayNightService", "NetService", "ServerRoleService" },
	Priority = 600,
})

function RoundService:Setup()
	self.Status = self.Libs.Charm.atom("Starting") :: Charm.Atom<Status>
end

RoundService:OnInit(function(self)
	self:Setup()
end)

RoundService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function() end)
end)

return RoundService
```

Controller (client, `src/<Feature>/client/`):
```luau
const Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
const RoundController = Modux.Controller("RoundController", { Priority = 800 })

function RoundController:Setup()
	self.Status = Vide.source("Starting") :: Vide.Source<Status>
end

RoundController:OnInit(function(self)
	self:Setup()
	self.Libs.Net.Round.State:onClient(function(payload)
		self.Status(payload.Status)
	end)
end)
```

Component (tagged instance; also used per Player, see `Vital`):
```luau
const Vital = Modux.Component("Vital", { Tag = "Vital", Require = { "VitalService" } })

function Vital:Setup()
	self.Owner = self.Instance :: Player
end

Vital:OnTick(function(self) end, 4)
Vital:OnDestroy(function(self) end)
```
Created from a service: `self.Components.Vital:Create(player)`, `:Get(player)`, `:Destroy(player)`. `Gun` (`src/Weapon/server/Gun.luau`) is the weapon component, parametrized by `GunsData` (`GunName` attribute), not one component per gun.

Lifecycle: `OnInit` (all modules, register Net responders here) -> `OnStart` (everything initialized; scan players already in the server here) -> `OnTick(fn, hz, priority)` -> `OnDestroy`. Loader finishes all `OnInit` before any `OnStart`, both ordered by `Priority`. `NetService` uses `Priority = 1000`.

Signals: `self.Libs.Signal.new() :: SignalLib.Signal<Player>`, with `:Connect`/`:Fire`. Player lifecycle comes from `PlayerService` (`PlayerAdded`, `PlayerRemoving`, `CharacterAdded`, `CharacterRemoving`), including players already in the server.

Net (one namespace per feature, `src/<Feature>/shared/Net.luau`):
```luau
return Lync.define("Round", {
	State = Lync.packet(Lync.struct({
		Status = Lync.enum({ "Starting", "Match", "Intermission", "Vote" }),
		Seconds = Lync.int(0, 3600),
	})),
})
```
- `Lync.replicate` (set) = shared state, late joiners receive current state (`:update(key, patch)`, `:get`, `:remove`, client `:onAdded/:onChanged`). `Lync.packet` = event or private data (`fireClient(to, data)`, `onClient`, `onServer`). `Lync.query` = request/reply (`Hit.Fire`, answered with `:onServer(function(request, player) return reply end)`).
- **Every new `Net.luau` must be added to `src/Libs/Net/init.luau`**, or the client hangs at boot (Lync waits for the namespace without timeout). It then appears as `self.Libs.Net.<Feature>.<Name>`.
- `keyBy` only accepts finite fields (bool/int/quant/angle/enum). UserIds exceed 2^32: use `Lync.f64()` in packets.
- Lync schema is validated at runtime inside `Lync.start()`; the analyzer will not catch it. Net responders only in Service/Controller `OnInit` (never in Components). Server broadcasts go to the `NetService.Audience` group, after the client sent `Ready`; check `NetService:IsRunning()` before sending during shutdown. `src/Net/Log.luau` silences only Lync's `drop.unready` warning.
- Do not put Lync or Vide in `src/Libs`/`self.Libs` (their types break `self` typing project-wide with `Cannot add property ... to table setmetatable<Build<...>>`). Require them directly: `require(ReplicatedStorage.Packages.Lync)` / `.Vide`. `src/Libs/Net` is fine.

Player data: `ProfileService:Get(player)` returns one Charm atom per field (`profile.Coins(100)` writes, `profile.Coins()` reads); writes persist and replicate through an effect. Fields are defined in the Profile template; a new field also needs the replicate step, `Profile/shared/Net`, and `ProfileController` (see `docs/IntegrationPlan.md` finding 3: large data persists in the template but replicates by its own feature packet). Use `ProfileService:Update(player, patch)` for several fields (batched).

UI (Vide, client): components are functions returning instances via `Vide.create`; props are values or functions (`Text: () -> string`). Screens are mounted with `Vide.mount(function() return create("ScreenGui")({ ... }) end)` from a Controller (`InterfaceController`, `LobbyController`), which keeps the returned unmount function and calls it on teardown. Every component gets a `*.story.luau` (`UILabs.CreateVideStory({ vide = Vide, controls = {...} }, function(props) ... end)`) and the feature folder has a `*.storybook.luau`. `create` does not cover `UIStroke`/`UIPadding`/`UIScale`: use `src/Interface/shared/CreateRaw.luau`. Fonts/theme in `src/Interface/shared/{Fonts,Theme}.luau`. Server Charm state reaches the client only through Lync into a Vide `source`.

## Conventions
- **Zero comments in `.luau` code** you write or edit (user rule). Only pre-existing comments inside `src/Modux/` stay. Do not add comments, do not strip existing ones inside `src/Modux`.
- **Never modify `src/Modux/`** (framework) nor generated files (see Setup). If a generated file needs a change, change the source and re-run the pipeline.
- Follow existing Modux patterns for new Services/Controllers/Components; new feature = new folder with its `client/server/shared` halves.
- Clean up per-player state on `PlayerService.PlayerRemoving` (clear tables keyed by Player, destroy components, remove Lync set entries, as `VitalService` and `SpawnService:Forget` do).
- `--!strict` at the top of every file; types via `export type`.
- Reply to the user in **pt-BR**.
- The user wants implementation now: write the code, do not stop at guidance.
- When designing a system, consider: Profile template fields, Net namespace + `Libs/Net` entry, and the dependency chain (`Require`/`Priority`).
- Use `tools/analyze.ps1` after changes; ask the user to test UI manually in Studio (simulated clicks are unreliable). If folders are deleted on disk, Rojo disconnects; ask the user to reconnect before Studio checks.

## Agents (`.claude/agents/`)
- **Architector** (opus) — designs Services/Controllers/Components, public APIs, data flow and dependencies.
- **FeaturePlanner** (haiku) — breaks Architector designs into ordered, concrete tasks.
- **Revisor** (sonnet) — reviews code, tracks progress, validates Modux patterns, updates the board.
- **RobloxAPIResearch** (sonnet) — read-only research of Roblox engine API (create.roblox.com docs, robloxapi.github.io).

There is no dedicated coder agent; implementation is done by the main session.
Flow: Revisor reviews -> Architector designs -> FeaturePlanner creates tasks -> implementation -> Revisor reviews.

## Task Board (`.claude/tasks.json`)
All agents **MUST** read and update `.claude/tasks.json` — single source of truth for task tracking. The board is viewed in `.claude/kanban.html` (reads `tasks.json`, auto-refreshes).

```json
{
  "columns": ["todo", "in-progress", "awaiting-approval", "done"],
  "tasks": [
    {
      "id": "task-unique-id",
      "title": "Short task title",
      "description": "What to implement and key details",
      "column": "todo | in-progress | awaiting-approval | done",
      "tags": ["system-name", "server|client|shared"],
      "priority": "low | medium | high",
      "createdAt": "YYYY-MM-DD",
      "updatedAt": "YYYY-MM-DD"
    }
  ]
}
```

### Agent rules for tasks.json
- **Finished work goes to `awaiting-approval`, never straight to `done`.** Only the user moves a task to `done` after testing it in Studio.
- Items coming from the playtest carry the tag `playtest`.
- **Revisor**: after reviewing, flag blocked tasks in the description and add new tasks for issues found; completed work stays in `awaiting-approval`.
- **Architector**: when designing a new system, create tasks for each file/module needed. Use tags to group by system.
- **FeaturePlanner**: break designs into granular tasks with acceptance criteria in the description. Order via `depends:task-id`.
- **All agents**: preserve existing task IDs. New IDs use `task-{system}-{number}` (e.g. `task-weapon-012`). Update `updatedAt` on any change.
- Tasks tagged `out-of-scope` (e.g. `tower-system`, `enemy-system`) are leftovers from an old tower-defense misunderstanding; do not work on them.

## Known gotchas
- `Players.CharacterAutoLoads = false` (set in `SpawnService:OnInit`). Spawning/respawning is done by `SpawnService` (`LoadCharacter`); death goes through `VitalService:Kill`, which calls `SpawnService:Respawn(player, 3)`. Do not rely on default Roblox respawn.
- `ReplicatedStorage.Assets.{Weapons,Seeds,Sounds,Musics}` (plus `VFX`) and maps (`ServerStorage.Maps`, `ServerStorage.Lighting`) exist only in the Studio place, not in Rojo; `.rogen.json` declares the folders only so the sourcemap types them. Do not declare leaf instances there; read them with `FindFirstChild` and cast. Save the place before publishing.
- Weapon seeds spawn via `WeaponSpawnService` on parts tagged `WeaponSpawn` (fallback `Farmland`); a map with neither gives no weapons.
- `Hit.Fire` has no Lync rate limit; cadence is a per-player token bucket in `HitService` (`FIRES_PER_SECOND`, `FIRE_BURST`).
- Teleport does not run in Studio (`TeleportGateway` simulates `ReserveServer`/teleport when `RunService:IsStudio()`); MemoryStore needs "Enable Studio Access to API Services".
- Admin commands need real UserIds in `src/Admin/shared/AdminSettings.luau` before publishing.
- Lync handshake: do not send Lync frames to a client before its `Ready`; use the `NetService` audience / `IsReady(player)`. `ProfileService:Replicate` waits for `ClientReady` for this reason.
- A lib added to `src/Libs` that contains an unreducible type function makes every module report `Cannot add property`; remove it from `Libs` and require it directly.
- Do not use `Tab`/`M` for new binds without checking `docs/IntegrationPlan.md` (used by leaderstats and Options); LeftAlt (hold = free cursor), C, R, 1-3, Mouse1, F2 are taken; Q is free.
