# ShotgunFarmers — Roblox Game Project

## Overview
ShotgunFarmers is a Roblox tower defense game built on the **Modux** framework — a custom service/controller/component architecture for organizing game logic.

## Tech Stack
- **Language:** Luau (Roblox's typed Lua variant)
- **Framework:** Modux (custom, located at `src/shared/Modux/`)
- **Networking:** lync (binary packet system inside Modux)
- **Data persistence:** ProfileService (custom wrapper around Roblox ProfileStore)
- **UI:** Fusion (reactive UI library)
- **ECS:** jecs (Entity Component System)
- **Tooling:** Rokit/Aftman for tool management, Wally for package management
- **Packages:** promise, spring, sera, quickzone, fusion, jecs, lync

## Project Structure
```
src/
├── server/
│   ├── ModuxInit.server.luau          -- Server entry point
│   ├── Services/                       -- Server singletons (game logic)
│   │   ├── ProfileService/             -- Player data persistence
│   │   ├── GameService.luau            -- Game state FSM (Break/Wave/Boss)
│   │   ├── VitalService.luau           -- Health/vital system
│   │   ├── HitService.luau             -- Hit detection/registration
│   │   ├── PlayerService.luau          -- Player lifecycle management
│   │   ├── DayNightService.luau        -- Day/night cycle
│   │   ├── ZoneService.luau            -- Zone tracking
│   │   ├── LeaderstatsService.luau     -- Leaderboard stats
│   │   ├── PlayerBillboardService.luau -- Player name displays
│   │   └── MovementService.luau        -- Movement handling
│   └── Components/                     -- Tagged instance components
│       ├── ZoneComponent.luau          -- Zone detection via tagged parts
│       └── Player/
│           ├── MovementComponent.luau
│           ├── VitalComponent.luau     -- Player health component
│           └── DebugVitalComponent.luau
├── client/
│   ├── init.client.luau                -- Client entry point
│   └── Controllers/                    -- Client singletons
│       ├── ProfileController.luau      -- Receives player data
│       ├── ScreenController.luau       -- Screen/UI management
│       ├── DayCycleController.luau     -- Client-side day/night
│       ├── MovementController.luau     -- Client movement
│       ├── VitalController.luau        -- Client vital/health display
│       ├── NotificationController.luau -- UI notifications
│       ├── UIAnimationsController.luau -- UI animation system
│       └── InputController.luau        -- Input handling
└── shared/
    ├── Modux/                          -- Framework (DO NOT MODIFY)
    ├── Templates/Profile.luau          -- Player data schema
    ├── Components/                     -- Shared components
    │   ├── PlayerZoneComponent.luau
    │   └── RegionComponent.luau
    ├── Settings/                       -- Game configuration
    │   ├── AreasConfig.luau            -- Area/map configuration
    │   ├── DayCycle.luau               -- Day/night cycle settings
    │   ├── EnemyTypes.luau             -- Enemy type definitions
    │   ├── SpawnArea.luau              -- Spawn area config
    │   └── WaveSettings.luau           -- Wave progression config
    ├── Datas/
    │   └── Resources.luau              -- Resource definitions
    └── Utils/                          -- Utility modules
        ├── FSM.luau                    -- Finite State Machine
        ├── GetThumbnail.luau
        └── ScreenGuiType.luau
```

## Modux Framework Patterns

### Creating a Service (server-side)
```luau
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MyService = Modux.Service("MyService")
MyService:Import("DependencyService")

MyService:OnInit(function(self)
    -- Setup phase: connections, initial state
end)

MyService:OnStart(function(self)
    -- Start phase: begin game logic (all modules are initialized)
end)

return MyService
```

### Creating a Controller (client-side)
```luau
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MyController = Modux.Controller("MyController")

MyController:OnInit(function(self)
    -- Listen to network packets
    self.Network.Packages.PacketName:on(function(data, sender, timestamp)
    end)
end)

return MyController
```

### Creating a Component (tagged instances)
```luau
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MyComponent = Modux.Component("MyComponent"):Tag("TagName"):ClassName("Instance")
MyComponent:Extend("ExtensionName"):Import("SomeService")

MyComponent:OnStart(function(self)
    -- self.Instance = the tagged instance
end)

MyComponent:OnDestroy(function(self) end)

return MyComponent
```

### Key conventions
- Services are **server-only** singletons in `src/server/Services/`
- Controllers are **client-only** singletons in `src/client/Controllers/`
- Components are **tagged-instance** handlers in `src/server/Components/`, `src/client/Components/`, or `src/shared/Components/`
- Dependencies are declared via `:Import("Name")` — the framework injects them
- Lifecycle: `OnInit` (setup) -> `OnStart` (all modules ready) -> `OnDestroy` (cleanup)
- Network: server sends via `self.Network.Packages.X:send(data, Player)`, client receives via `:on(callback)`
- Signals: `MyService.Signal.new()` for custom events
- Promises: `self.Promise.new(function(resolve, reject) end)` for async operations
- `--modux ignore file` / `--modux ignore line` to opt out of Modux's auto-loading

### Player data
The Profile template (`src/shared/Templates/Profile.luau`) defines all persistent fields. Any feature that stores player data must add fields here and use ProfileService to read/write them.

## Agent Workflow
This project uses a structured agent pipeline:
1. **Revisor** (Sonnet) — Reviews code, tracks progress, identifies gaps
2. **Architector** (Opus) — Designs system architecture following Modux patterns
3. **FeaturePlanner** (Haiku) — Breaks architecture into concrete implementation tasks

Flow: User completes work -> Revisor reviews -> Architector designs next steps -> FeaturePlanner creates tasks

## Task Board (`.claude/tasks.json`)

All agents **MUST** read and update `.claude/tasks.json` — this is the single source of truth for task tracking. The user views these tasks in a VSCode Kanban board extension.

### JSON Schema
```json
{
  "columns": ["todo", "in-progress", "done"],
  "tasks": [
    {
      "id": "task-unique-id",
      "title": "Short task title",
      "description": "What to implement and key details",
      "column": "todo | in-progress | done",
      "tags": ["system-name", "server|client|shared"],
      "priority": "low | medium | high",
      "createdAt": "YYYY-MM-DD",
      "updatedAt": "YYYY-MM-DD"
    }
  ]
}
```

### Agent rules for tasks.json
- **Revisor**: After reviewing, move completed tasks to `done`, flag blocked tasks in description, and add new tasks for issues found.
- **Architector**: When designing a new system, create tasks for each file/module needed. Use tags to group by system.
- **FeaturePlanner**: Break Architector designs into granular tasks with clear acceptance criteria in description. Order via `depends:task-id` in description.
- **All agents**: Always preserve existing task IDs. Generate new IDs with format `task-{system}-{number}` (e.g., `task-tower-001`). Update `updatedAt` on any change.

## Rules
- **Never modify** files inside `src/shared/Modux/` — it's the framework
- **Always follow** existing Modux patterns for new Services/Controllers/Components
- **Clean up** player data in `OnPlayerRemoved` handlers to prevent memory leaks
- **Use Portuguese** for inline code comments when the user writes in Portuguese
- The user wants **guidance**, not direct code generation — explain the structure and let them implement
- When designing new systems, always consider: what data goes in the Profile template, what network packets are needed, and what the dependency chain looks like
