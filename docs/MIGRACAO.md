# Migracao ShotgunFarmers (Modux V2 + Fusion) para Modux V3 + Vide

Origem: `D:/Documents - Windows/Roblox-Games/ShotgunFarmers/src`
Destino: este repo (template Modux V3).

Cada fase entra com `tools/analyze.ps1` em zero erro antes da proxima.

## O que existe na origem

| | |
|---|---|
| codigo de jogo | 120 arquivos, ~17 mil linhas |
| fora da conta | `shared/Modux/` (framework V2 + folhas auto-geradas + lync 2.3.3 vendorizado), `shared/Packages/`, `server/ServerPackages/`, `client/Interface/Fusion/` (67 arquivos) |
| UI real | 37 arquivos: 16 wrappers de elemento, 10 GameComponents, 6 stories, Enums/TableMerge, `Interface/init.luau` |
| rede | **um arquivo so**: `shared/Modux/src/Network/init.luau`, 19 "Packages" |
| Fusion reativo | ~100 usos em ~29 arquivos (28 nos Controllers, 71 na UI) |

## Decisoes

**Wrappers de UI morrem.** Os 16 `Components/Elements/*` e `Components/Buttons/*`
existem porque o Fusion 1.2.5 pede `scope:New("X")(props)` na mao e nao tem
defaults. No Vide, `create "TextLabel" { ... }` ja e isso. Sobram so
`Utils/Enums/Fonts` e, se aparecer repeticao real, um modulo de defaults por
elemento. O `TableMerge` morre com eles.

Nota do Vide 0.4.1: a lista de classes do `create` nao cobre `UIStroke`,
`UIPadding` nem `UIScale` — para essas vai o alias `createRaw`.

**Estado dos controllers vira `source`/`derive` do Vide.** O mapa e 1:1 com o
que existe hoje:

| Fusion | Vide |
|---|---|
| `scope:Value(x)` | `source(x)` |
| `scope:Computed(function(use) ... use(a) ... end)` | `derive(function() ... a() ... end)` |
| `Observer(x):onChange(f)` | `effect(function() ... x() ... end)` |
| `peek(x)` | `x()` (ler sem rastrear e outra coisa; ver nota) |
| `scope:Tween`/`Spring` | `spring` do Vide, ou a lib `Spring` do wally |
| `ForPairs`/`ForKeys`/`ForValues` | `indexes` / `values` |
| `[Children] = { ... }` | filhos posicionais no proprio `create` |
| `scoped(Fusion)` / `innerScope` / `doCleanup` | escopo implicito do Vide + `cleanup` |

O Vide entra por require direto, **nunca** em `self.Libs`: lib de terceiro ali
derruba a tipagem inteira do self (Lync e Vide fazem isso; o Net proprio passa).

**Rede: estado vira set, evento continua packet.** Um namespace do Lync 4 por
feature em `src/<Feature>/shared/Net.luau`, mais o agregador em `src/Libs/Net`
(o cliente faz `WaitForChild` sem prazo: namespace que existe de um lado so
trava o boot).

Os 19 Packages da origem, pre-classificados:

| origem (V2) | destino (Lync 4) | por que |
|---|---|---|
| `VitalKey` + `GetVitals` (query) | set `Vitals` keyBy Player | estado continuo; o set entrega a quem chega e mata a query |
| `WeaponKey` + `GetWeapon` (query) | set `Weapons` keyBy Player | WeaponID, Ammo por slot, ActiveSlot. **O `DrawLock` fica de fora**: e duracao relativa ao timestamp do pacote, evento e nao estado |
| `Data` + `DataKey` | ver o que o template ja faz no Profile | perfil por jogador; nao duplicar o caminho do template |
| `RoundState` | set `Round` (uma linha) | State + Seconds, e quem entra no meio precisa do valor atual |
| `DayCycle`, `SecondsCycle`, `TransitionCycle` | set `DayNight` (uma linha) | tres packets que juntos sao um estado |
| `MovementState`, `ChangeWalkSpeed`, `ChangeMovement` | decidir na fase do Character | hoje vao so para o dono; o snapshot ja carrega State para os outros |
| `PlayerSnapshot` | packet `:unreliable():newest(hz)` | 60 Hz, posicao/olhar; o Lync 4 tem os dois modificadores |
| `Fire` (query) | query | pede resposta (Accepted, Hits) |
| `SwitchSlot`, `DiscardWeapon`, `KillFeed`, `ZoneNotification` | packet 1:1 | evento pontual |

**Buraco conhecido:** o `Fire` da origem passa
`rateLimit = { maxPerSecond = 15, burst = 10 }` e um `validate` para o Lync 2.
O Lync 4 tem `validate` como modificador de codec, mas **nao tem rateLimit por
packet** — o orcamento dele e de bytes por namespace. O limite de cadencia
vira token bucket por jogador no WeaponService, e isso precisa de teste.

**Dependencias.** Entram: `quickzone`, `spring`, `conch` + `conch-ui` (o
painel de admin; o `conch-ui@0.4.0` ja depende de Vide `^0.4.0`, entao nao
reintroduz Fusion). Ficam fora: `jecs` e `sera` (zero usos no codigo de jogo),
`iris` (painel de debug), `fusion` (substituido).

## O que existe na origem, por feature

120 arquivos de jogo (os outros 67 do `src` eram o Fusion vendorizado).

| feature | arquivos | o que e |
|---|---|---|
| Weapon | 11 | loadout de 3 slots, munição por slot, viewmodel com PoseMachine, 21 armas em `Guns.luau` |
| Hit/Projectile | 5 | raycast por pellet no cliente, validação com rewind no servidor, trail de bala |
| Vital | 4 | Health/Armor/Stamina, regen, morte, dessaturação de tela |
| KillFeed | 3 | fila de 5 entradas com thumbnail |
| Round | 4 | FSM Starting/Match/Intermission/Vote com contador de 1 Hz |
| Character/Movement | 10 | FSM de movimento autoritativa, slide, rig R6 de braços, animações |
| Snapshot | 3 | posição/olhar a 60 Hz, histórico e rewind para lag comp |
| Camera | 4 | first person, killcam, FOV, unlock do mouse |
| Seed | 3 | planta ao atirar no Farmland, cresce, colhe arma ou munição |
| Zone | 4 | zona/safezone por jogador sobre o quickzone |
| DayNight | 3 | ciclo com spring no Lighting |
| Admin | 3 | comandos conch + painel Iris |
| Profile/Player | 7 | ProfileStore, GameID por jogador, spawn, billboard |
| Interface | 31 | 16 wrappers, 10 GameComponents, 6 stories |
| Audio | 1 | playlist com crossfade |

## O que foi descartado, e por que

| descartado | linhas | motivo |
|---|---|---|
| `KeyframeLoader/` + `ViewmodelKeyframes` | 1119 (8 arquivos) | nenhum require no projeto inteiro; um deles importa um `KeyboardService` que nao existe |
| `UIAnimationsController` | 1277 | zero consumidores, e as tags `UI.*` que ele espera nao sao criadas em lugar nenhum; o Vide ja tem `spring` |
| `WaveSettings`, `EnemyTypes`, `AreasConfig`, `SpawnArea` | 231 | feature de ondas/aliens nao existe em codigo: sem spawner, sem componente de inimigo. As duas ultimas ainda requerem `Shared.Enums.Aliens`, que nao existe |
| `RegionComponent` | 19 | no-op garantido: passa `OnEnter`/`OnExit` em chaves que o mixin ignora |
| `GunNameLabel`, `ScreenGuiType` | 16 | nunca montado; arquivo vazio |
| `NotificationController`, `LeaderstatsService`, `DayCycleController`, `ProfileController` (V2) | 43 | corpo vazio ou so handlers vazios |
| `ProfileService/Profile.luau` | 1801 | ProfileStore vendorizado; no destino e a dependencia do Wally |
| `Extras/` | — | dois scripts de engenharia reversa de API, nunca referenciados |

## Um bug que trava o jogo, e a decisao que ele forcou

`EquipmentComponent.DEFAULT_LOADOUT` e `M6Bean`, e o componente da arma e
resolvido por `gunName .. "Component"`. So existem `ShotgunComponent` e
`PeavolverComponent`, entao com o loadout default o `HitService` rejeita
**todo** tiro. 19 das 21 armas de `Guns.luau` estao na mesma situacao.

Em vez de escrever 19 componentes, **um componente `Gun` parametrizado**: o
comportamento que diferia entre Shotgun e Peavolver era so o numero de pellets,
entao isso vira dado em `Guns.luau` (`Kind = "Multi" | "Single"`, `Pellets`) e o
componente le `GunData`. As 21 armas passam a funcionar.

## Plano de fases

| fase | escopo |
|---|---|
| **0** | infra: dependencias, `.rogen.json`, rede em namespace por feature, docs |
| **1** | dados e settings: `Guns`, `GetGun`, `Body`, `GetBodyPart`, `PlayerAnimations`, `GetAnimations`, `GameSettings`, `RoundSettings`, `SeedSettings`, `DayCycle`, `Profile` template, `GetThumbnail` |
| **2** | **UI em Vide + stories** — os 10 GameComponents e as 6 stories, rodando com controls do UILabs, sem depender de controller |
| **3** | Player, Character/Movement, Vital, Profile, Round (MERGE com o que o template ja traz) |
| **4** | Weapon, Hit, Snapshot — o laco central |
| **5** | Seed, Zone, DayNight, Audio, Camera |
| **6** | Admin: comandos no conch, console do conch-ui |
| **7** | ligacao do InterfaceController ao estado real, conferencia arquivo a arquivo |

A UI vem antes do servidor de proposito: story do UILabs roda com `controls`,
nao precisa de estado real, entao da para desenhar e ajustar tela enquanto o
resto e portado.

## O que so o Studio resolve

A origem **nao mapeia asset nenhum no disco**: o `default.project.json` dela
tem cinco nos (`Shared`, `Server`, `Client`, `Packages`, `ServerPackages`).
Mapas, modelos, GUIs e Lighting existem so dentro de `backup/12_07_26.rbxl`.

O `.rogen.json` daqui declara as pastas esperadas (`ReplicatedStorage.Assets`
com `Weapons`, `Seeds`, `Sounds`, `Musics`) como `$className: "Folder"` sem
`$path`: isso as poe no sourcemap para a tipagem, sem tentar sincronizar
conteudo que so existe no place. Instancia-folha (o `bullet_trail`, o
`PlayerBillboard`) **nao** se declara — declarar retipa a instancia; o codigo
le com `FindFirstChild` e cast.

Pendente do dono: abrir o `.rbxl` e exportar o que virar asset.

## Fase 1 — dados e settings (feito)

| origem | destino | nota |
|---|---|---|
| `shared/Datas/Guns.luau` | `src/Weapon/shared/GunsData.luau` | 21 armas |
| `shared/Utils/GetGun.luau` | `src/Weapon/shared/GetGun.luau` | virou funcoes livres: `GetGun.ByName`, `GetGun.ByID`, `GetGun.All` |
| `shared/Templates/Body.luau` | `src/Hit/shared/Body.luau` | |
| `shared/Utils/GetBodyPart.luau` | `src/Hit/shared/GetBodyPart.luau` | funcao livre |
| `shared/Settings/PlayerAnimations.luau` | `src/Character/shared/PlayerAnimations.luau` | |
| `shared/Utils/GetAnimations.luau` | `src/Character/shared/GetAnimations.luau` | funcoes livres |
| `shared/Settings/GameSettings.luau` | `src/Shared/Settings/GameSettings.luau` | |
| `shared/Settings/RoundSettings.luau` | `src/Round/shared/RoundSettings.luau` | |
| `shared/Settings/SeedSettings.luau` | `src/Seed/shared/SeedSettings.luau` | |
| `shared/Settings/DayCycle.luau` | `src/DayNight/shared/DayCycleSettings.luau` | renomeado: `DayCycle` era ambiguo com o controller |
| `shared/Utils/GetThumbnail.luau` | `src/Shared/Utils/GetThumbnail.luau` | `AvatarBurst` virou **`AvatarBust`** (o nome estava com erro de digitacao) |

O `self` sem tipo dos acessores (`GetGun:GetByName`) nao passa em strict, e
nenhum deles guardava estado — por isso viraram funcoes livres. Cada chamada
muda de `:` para `.` quando a feature dona for portada.

### O componente `Gun` ja estava parametrizado no dado

`ShotgunComponent` e `PeavolverComponent` diferem **so no numero de pellets**,
e o `Guns.luau` ja carrega `BulletType` ("Multi"/"Single") e `Bullets` (6 no
Shotgun, 1 no Peavolver). Entao o componente unico nao precisa de campo novo:
le `GunData.Bullets` e roda o mesmo laco. Nao ha o que inventar no dado.

### As duas bases de animacao, conferidas

`animations_new.luau` (fora da arvore, 8/set) e `PlayerAnimations.luau` sao
quase o mesmo conjunto: **251 dos 260 IDs antigos estao no novo**.

- **So no antigo (9 IDs):** todo o Shotgun (Hold, Aim, ShootHip, ShootAim, e o
  viewmodel) e o `Core` inteiro (Idle, Walk, CrouchIdle, CrouchWalk). O arquivo
  novo **nao tem Shotgun nem animacao de corpo sem arma**.
- **So no novo (66 IDs):** transicoes que a estrutura atual nao tem campo para
  guardar — `VM_Aim_In` (14 armas), `VM_Aim_out` (12), `RIG_Aim_In` (7),
  `VM_Automatic Save` (7), `VM_PinOut_Idle` (5), `RIG_Holding_Shoot` (5).
- **Os 19 campos vazios do antigo nao sao preenchiveis pelo novo:** 11 sao
  `Reload` (que nao existe em nenhum dos dois arquivos), 4 sao `Core`
  (Run/Jump/Fall/Land) e o resto e Shotgun.

Conclusao: o antigo continua sendo a fonte, porque e o unico que tem Core e
Shotgun. O novo esta guardado em `docs/referencia/animations_new.luau` e entra
na fase 3, quando o `AnimationSet` ganhar os campos de transicao (`AimIn`,
`AimOut`, `PinOut`) que hoje nao existem.

## Fase 2 — a UI em Vide (feito)

| origem (Fusion) | destino (Vide) | linhas |
|---|---|---|
| `GameComponents/ProgressionBar.luau` | `src/Interface/client/Components/ProgressionBar/init.luau` | 106 -> 99 |
| `GameComponents/StatusBar.luau` | `src/Vital/client/StatusBar.luau` | 80 -> 117 |
| `GameComponents/TimerLabel.luau` | `src/Round/client/TimerLabel.luau` | 11 -> 32 |
| `GameComponents/WeaponSlot.luau` | `src/Weapon/client/WeaponSlot.luau` | 95 -> 105 |
| `GameComponents/GunBar.luau` | `src/Weapon/client/GunBar.luau` | 62 -> 54 |
| `GameComponents/Crosshair.luau` | `src/Weapon/client/Crosshair.luau` | 129 -> 109 |
| `GameComponents/HitMarker.luau` | `src/Hit/client/HitMarker.luau` | 60 -> 77 |
| `GameComponents/KillFeed.luau` | `src/KillFeed/client/KillFeed.luau` | 36 -> 47 |
| `GameComponents/KillFeedEntry.luau` | `src/KillFeed/client/KillFeedEntry.luau` | 95 -> 110 |
| `Components/Utils/Enums/Fonts.luau` | `src/Interface/shared/Fonts.luau` | |
| os 16 wrappers + `TableMerge` | — | 460 linhas que deixaram de existir |

Cada componente tem story ao lado, e o `Interface.storybook.luau` varre o
client inteiro (`storyRoots = { script.Parent.Parent }`), entao story mora
dentro da feature dela.

### O que a conversao exigiu, alem do 1:1

**Props reativas viram getter (`() -> T`).** Nem Source nem valor: getter. A
story passa o control, o jogo passa um `derive`, e o componente nao sabe a
diferenca.

**Spring nao e o mesmo numero.** O Fusion toma **frequencia angular** (rad/s),
o Vide toma **periodo** (s): `T = 2*pi/speed`. O `speed 20` da cor do
WeaponSlot virou `0,3 s`, o `speed 24` da abertura do Crosshair virou
`0,25 s`. Ficaram como constante nomeada, para afinar olhando a story. Errar
isso da animacao varias vezes mais rapida sem erro de tipo nenhum.

**`ForPairs` do KillFeed virou `values`, nao `indexes`.** Cada kill tem
identidade: entra quando alguem morre, sai sozinha quando o tempo acaba. O
`values` casa item com o Frame que ja existe e destroi so o que saiu — que e o
que o `innerScope` fazia na mao. Com `indexes`, o Frame da posicao 1 seria
reciclado para a kill seguinte e a entrada velha nunca morreria.

**O `effect` roda uma vez na criacao.** O HitMarker anima quando o `Trigger`
incrementa; sem cuidado, ele pisca sozinho ao montar. A saida foi guardar o
valor anterior fora do effect e so animar quando muda de verdade.

**`derive`, `effect` e `spring` exigem escopo reativo** (`Vide.root` ou
`Vide.mount`). A story do UI Labs ja monta num root, entao ela passa mesmo
onde o jogo quebraria — o InterfaceController da fase 7 precisa montar.

### Um bug que o type-check nao pega

Em story de Vide do UI Labs 2.4.2, **cada control chega como `Vide.Source`**,
isto e, funcao (`InferVideControls` mapeia `T` para `Vide.Source<T>`). Ler sem
chamar (`props.controls.Percent`) type-checa, porque o tipo e `any`, e so
quebra em runtime — e nunca fica reativo. O proprio `Counter.story.luau` do
template estava assim; corrigido aqui junto com as outras seis.

### Dois bugs de tamanho corrigidos no KillFeedEntry

`GunImage` e os labels de nome tinham `UDim2.fromScale(0, 18)`: largura zero
(o icone da arma nunca aparecia) e altura 18x a do pai. Viraram
`fromOffset(18, 18)` e `fromScale(0, 1)` com `AutomaticSize.X`.

### Duas esquisitices preservadas de proposito

O `WeaponSlot` herda `AnchorPoint (0.5, 0.5)` do wrapper antigo e o
`UIListLayout` nao compensa isso, entao cada slot desloca meia altura. O
`GunBar` fica em `Position = 1.05`, 5% para fora da borda direita. As duas
coisas sao fieis ao que roda hoje; as stories sobrescrevem a posicao para dar
para ver. Se for para consertar, e decisao de design, nao de migracao.

## Fase 3 — Player, Character, Vital, Profile, Round (feito)

| origem | destino | nota |
|---|---|---|
| `server/Services/PlayerService.luau` | — | **nao veio**: o hub de callbacks do V2 e exatamente o que os quatro Signals do PlayerService do template ja fazem |
| `server/Services/IDService.luau` | `src/Player/server/IDService.luau` | GameID por jogador, via atributo (nao usa rede) |
| `server/Services/SpawnService.luau` | `src/Character/server/SpawnService.luau` | pendura no `CharacterAdded`, entao cobre spawn e respawn com um gancho so |
| `server/Services/CharacterService.luau` | `src/Character/server/CharacterService.luau` | |
| `server/Services/PlayerBilboardService.luau` | `src/Player/server/PlayerBillboardService.luau` | o V2 registrava com um `l` so |
| `server/Components/Player/MovementComponent.luau` | `src/Character/server/Movement.luau` | |
| `server/Services/MovementService.luau` | `src/Character/server/MovementService.luau` | ganhou o responder da query |
| `client/Controllers/MovementController.luau` | `src/Character/client/MovementController.luau` | |
| `client/Controllers/AnimateController.luau` | `src/Character/client/AnimateController.luau` | |
| `client/Controllers/Arms/RigBuilder.luau` | `src/Character/client/RigBuilder.luau` | funcoes livres, sem consumidor ainda |
| `server/Components/Player/VitalComponent.luau` | `src/Vital/server/Vital.luau` | MERGE: o do template ja era superset |
| `client/Controllers/VitalController.luau` | `src/Vital/client/VitalController.luau` | MERGE + dessaturacao |
| `client/Controllers/ColorCorrectionController.luau` | `src/Camera/client/ColorCorrectionController.luau` | `self.Instance` virou `self.Effect`: `Instance` e campo de Component no V3 |
| `server/Services/GameService.luau` | `src/Round/server/RoundService.luau` | MERGE: as quatro fases entraram no lugar de Waiting/Playing/Ending |
| `client/Controllers/RoundController.luau` | `src/Round/client/RoundController.luau` | MERGE |
| `server/Services/ProfileService/init.luau` | `src/Profile/server/ProfileService/init.luau` | MERGE: 20 campos no lugar de Coins/Level/Playtime |
| `shared/Templates/Profile.luau` | `src/Profile/server/ProfileService/Template.luau` | |

### A rede de movimento: dois packets viraram um set

`MovementState` e `ChangeWalkSpeed` iam so para o dono e, juntos, descrevem um
estado. Viraram o set `Movement`, chaveado por UserId, com `State` e
`WalkSpeed` **no mesmo record** — separados, dava para o cliente ver a
velocidade de agachado com o estado de andando. Quem entra no meio da partida
recebe tudo pelo `onAdded`.

`ChangeMovement` virou `query`: o cliente pede a acao e o servidor responde se
a FSM aceitou. O V2 mandava e nao conferia, porque o packet nao respondia. O
slide agora comeca local na hora e **se desfaz** se a resposta vier
`CanDo = false`.

### `ForceState` entrou no FSM

A tabela de transicoes nao lista saida de `Dead`, entao o respawn nao consegue
voltar para `Walking` por `Transition`. O `src/Libs/FSM.luau` ganhou
`ForceState`, que entra no estado ignorando a tabela e avisa os listeners do
mesmo jeito. `Transition` e `ForceState` passaram a dividir o mesmo `enter`
interno em vez de duplicar o disparo de listeners.

### Tres bugs do V2 corrigidos na passagem

1. **Degrau na dessaturacao.** A rampa de saturacao terminava em -0,5 e o ramo
   de cima devolvia 0,5: a tela dava um pulo ao cruzar 50% de vida. Agora a
   rampa termina no mesmo valor do ramo de cima.
2. **Volume que era interruptor.** `MusicVolume` e `SoundVolume` viajavam como
   `int(0, 1)`, entao so 0 ou 1 passava. Viraram `quant(0, 1, 0.01)`.
3. **`PlayerBilboardService`** registrado com um `l` a menos que o arquivo.

### O que nao veio, e por que

- **O tipo `R6` (90 linhas)** do PlayerService: zero consumidores escritos a
  mao. Os ~30 hits de `R6` na origem estao todos em arquivo gerado pelo
  proprio V2, que so existiam porque o servico o exportava.
- **`GetAllPlayers`/`GetAllCharacters`**: zero consumidores, e
  `Players:GetPlayers()` cobre.
- **Os quatro Signals do GameService** (`OnStarting`, `OnMatch`,
  `OnIntermission`, `OnVote`): nenhum modulo do projeto os escutava.
- **`DataKey`** (replicacao de perfil por chave): o servidor ja agrupa as
  mudancas num batch do Charm e manda uma vez por lote.
- **A tabela de chave fraca do IDService**: existia porque o V2 nao tinha
  gancho de saida; agora tem `PlayerRemoving`.

### Pontas soltas, de proposito

- **`MovementController.Landed`** e um `Signal<number>` com a intensidade do
  tremor de queda. No V2 quem escutava era `SurfaceUIController` e
  `CameraController`, que entram na fase 5. Hoje ninguem escuta.
- **`RigBuilder`** esta completo e sem consumidor: quem o chamava era o
  `ArmsController`, que entra na fase 4.
- **`self.LocalCharacter`/`self.LocalHumanoid`** do V2 nao existem no V3. O
  dono passou a ser o `MovementController` (`self.Character`, `self.Humanoid`,
  `GetMoveDirection`). Snapshot, Hit, FOV e DeathCamera vao bater na mesma
  porta — se virar um `CharacterController` proprio, e daqui que ele sai.

### Dois achados de infra

**O `analyze.ps1` do template nao via pasta de asset.** Ele gerava o sourcemap
sem `--include-non-scripts`, entao `ReplicatedStorage.Assets` simplesmente nao
existia para o type-check (o `PlayerBillboardService` foi o primeiro a bater).
Agora usa mapa proprio (`sourcemap.analyze.json`, para nao correr contra o
watcher do editor) e a flag. O `.vscode/settings.json` ganhou
`includeNonScripts`, que estava comentado, senao o editor discorda do analyze.

**`OnTick` recebe delta em runtime mas nao no tipo.** O Loader chama
`pcall(tick.callback, tick.instance, delta)`, e o tipo registrado e
`callback: (any) -> ()`. Em strict nao da para declarar o segundo parametro, e
quem precisa de delta (a fisica do slide) teve que usar `Heartbeat` direto. O
conserto e no framework: `(any, number) -> ()` em
`src/Modux/shared/Classes/{Component,Controller,Service}.luau`.

## Fase 4 — Weapon, Hit, Snapshot (feito)

| origem | destino |
|---|---|
| `server/Components/Mixin/GunMixin.luau` | `src/Weapon/server/GunRules.luau` (funcoes livres) |
| `server/Components/Weapon/{Shotgun,Peavolver}Component.luau` | `src/Weapon/server/Gun.luau` (**um** componente) |
| `server/Components/Player/EquipmentComponent.luau` | `src/Weapon/server/Equipment.luau` |
| `server/Services/WeaponService.luau` | `src/Weapon/server/WeaponService.luau` |
| `client/Controllers/WeaponController.luau` | `src/Weapon/client/WeaponController.luau` |
| `client/Controllers/ArmsController.luau` | `src/Weapon/client/ArmsController.luau` |
| `client/Controllers/Arms/PoseMachine.luau` | `src/Weapon/client/PoseMachine.luau` |
| `client/Controllers/Arms/AnimationSetLoader.luau` | `src/Weapon/client/AnimationSetLoader.luau` |
| `client/Controllers/HitController.luau` | `src/Hit/client/HitController.luau` |
| `client/Controllers/ProjectileController.luau` | `src/Hit/client/ProjectileController.luau` |
| `server/Services/HitService.luau` | `src/Hit/server/HitService.luau` |
| `client/Controllers/SnapshotController.luau` | `src/Snapshot/client/SnapshotController.luau` |
| `server/Services/SnapshotService.luau` | `src/Snapshot/server/SnapshotService.luau` |

### Um componente para 21 armas

`Equipment` grava `GunName` em atributo na instancia da arma **antes** de criar
o componente; o `Gun` le o atributo no `Setup` e pega o dado com
`GetGun.ByName`. O laco de tiro e `for i = 1, stats.Bullets`, que com
`Bullets = 1` e o Peavolver e com 6 e a Shotgun.

Isso apaga a causa do bug: no V2 a classe da arma era resolvida por
`gunName .. "Component"`, entao 19 das 21 armas — inclusive o `M6Bean` do
loadout default — nao tinham componente e **todo** tiro era rejeitado.

### O que mudou na rede

- **`WeaponKey` + `GetWeapon:request()` -> packet `Loadout`.** Um pacote com o
  loadout inteiro, publicado no `ClientReady`, do mesmo jeito que perfil e
  rodada. Ficou packet e nao set porque municao e informacao privada: set
  replica para todos, e dai o adversario leria quantos tiros faltam na tua arma.
  Qual arma esta na mao, que e publico, ja viaja no snapshot.
- **`DrawLock` virou `DrawEndsAt`.** Era duracao relativa que o cliente somava
  ao timestamp do pacote; agora e instante absoluto em
  `workspace:GetServerTimeNow()`, que da o mesmo numero nos dois lados. De
  bonus, o `ArmsController` usa o que sobra do prazo para esticar ou encolher o
  clipe de saque, entao a animacao termina junto com o lock mesmo se o tick
  atrasar.
- **Snapshot:** `State` virou nome ("Walking", ...) no lugar do ID numerico, e
  `Position`/`LookAt` viraram `Vector3` quantizado em 0,25 stud no lugar de
  `Vector3int16` (1 stud). Para validar headshot com rewind, 1 stud e grosso.
- **O teto de pellets subiu de 8 para 12**, porque a Double Cob solta 12 e o
  codec recusaria o tiro inteiro dela.

### O rateLimit que o Lync 4 nao tem

O V2 passava `rateLimit = { maxPerSecond = 15, burst = 10 }` na definicao do
`Fire`; o orcamento do Lync 4 e de bytes por namespace, nao de chamadas por
packet. Virou token bucket por jogador no `HitService`
(`SpendFireToken`), com enchimento continuo e teto de 10, primeira checagem do
responder, e balde apagado no `PlayerRemoving`.

### Tres bugs do V2 corrigidos

1. **O "discard" nao descartava.** `DiscardWeapon` dava a Shovel, que cai no
   slot 3 por ser corpo a corpo, e a arma vazia continuava no slot 1. Agora
   limpa o slot ativo antes.
2. **`LastShoot` comecava em `GetServerTimeNow()`**, entao a cadencia segurava
   o primeiro tiro depois do spawn. Comeca em 0; quem segura o primeiro tiro e
   o lock de saque, que e o que devia.
3. **O trail nascia no `PrimaryPart`.** Agora sai de
   `ArmsController:GetMuzzlePosition()`, com o corpo como reserva. O pellet
   continua saindo do corpo, que e o que o servidor valida.

### O que estava solto e foi ligado

O `HitController` tinha uma source `IsAiming` propria que ninguem escrevia — a
mira e do `ArmsController`, que binda o botao direito. Ligado. De passagem,
arma branca e arremessavel voltaram a fazer algo (`PlayAttack`, `BeginThrow`,
`ReleaseThrow` no soltar do botao); antes so "nao atiravam".

## Fase 5 — Seed, Zone, DayNight, Audio, Camera (feito)

| origem | destino |
|---|---|
| `client/Controllers/SeedController.luau` | `src/Seed/client/SeedController.luau` |
| `server/Components/SeedComponent.luau` | `src/Seed/server/Seed.luau` (tag `"Seed"`, era `"SeedComponent"`) |
| `server/Components/ZoneComponent.luau` + `shared/Components/PlayerZoneComponent.luau` | `src/Zone/server/Zone.luau` (o mixin foi dobrado dentro) |
| `server/Services/ZoneService.luau` | `src/Zone/server/ZoneService.luau` |
| `server/Services/DayNightService.luau` | `src/DayNight/server/DayNightService.luau` |
| `client/Controllers/MusicController.luau` | `src/Audio/client/MusicController.luau` |
| `client/Controllers/CameraController.luau` | `src/Camera/client/CameraController.luau` |
| `client/Controllers/DeathCameraController.luau` | `src/Camera/client/DeathCameraController.luau` |
| `client/Controllers/FOVController.luau` | `src/Camera/client/FOVController.luau` |
| `client/Controllers/UnlockCameraController.luau` | `src/Camera/client/UnlockCameraController.luau` |
| `shared/Modux/src/Tools/SpringWrapper.luau` | `src/Libs/Spring/init.luau` (chega como `self.Libs.Spring`) |

### O ciclo dia/noite nunca virava

`ToggleCycle` existia e **ninguem chamava**: o `GameService` so chamava
`StartCycle`, que punha o ciclo em "Day" e parava ali, com `CurrentClock`
decrementado por ninguem. Faltava o tick — agora e um `OnTick` de 1 Hz que
desce o contador e alterna quando zera, e o `RoundService` liga o ciclo no
`OnStart`, onde o `GameService` ligava.

**A feature ficou sem rede.** Os tres packets iam para um controller com os
tres callbacks vazios, e `Lighting` e servico do jogo: o Roblox replica
ClockTime e Brightness sozinho. Quando alguma tela precisar do numero do dia,
dai entra um set de uma linha.

### O FOV estava quebrado em dois lugares

1. O `FOVController` lia `IsAiming` **como campo**, e o valor era um objeto do
   Fusion: sempre truthy, entao o desconto de mira valia sempre.
2. Chamava `ApplyFov` em **todo** tick de 60 Hz, criando e destruindo um Tween
   60 vezes por segundo — o tween de 1 s nunca saia do comeco.

Agora o tick compara o par `(Style, Aiming)` e o tween nasce so quando o par
muda. O desconto de mira virou uma transicao visivel, que e o que ele queria
ser.

### A saida de zona tambem era no-op

`OnExit` chamava `ChangePlayerZone(player, self.Instance.Name)` — o mesmo nome
da entrada — e a guarda "mudou de zona?" derrubava a escrita: quem saisse de
todas as zonas ficava com a ultima gravada no perfil para sempre. Agora a saida
limpa o campo, **mas so se** a zona registrada ainda for a que esta saindo
(zonas se sobrepoem, e a ordem entre "entrou em B" e "saiu de A" nao e
garantida).

### Mais correcoes de passagem

- **Semente travada.** A colheita marcava `_harvested = true` **antes** de
  buscar o `Equipment`; sem componente, a semente ficava inerte para sempre.
  Agora so se destroi se a recompensa saiu.
- **A GUI do unlock morria no respawn** (`ResetOnSpawn` no padrao), e o Q
  passava a mexer num TextButton destruido. Virou `ResetOnSpawn = false`.
- **A camera dava um pulo** quando perdia o humanoid, porque o tilt era zerado
  no mesmo quadro; agora volta ao centro pela mesma rampa.
- **`Player:GetMouse()`** (deprecado) virou `UserInputService:GetMouseLocation()`
  + `ViewportPointToRay`: mesma conta, e a mira continua seguindo o cursor
  quando o Q solta o mouse, em vez de cravar no centro.

### O que nao veio

- **`ChangePlayerSafeZone` e `safezonePlayers`**: zero chamadores, e escreviam
  no mesmo campo `CurrentZone` que a zona normal — se fossem chamados um dia,
  os dois disputariam o valor.
- **`RegionComponent`** (ja registrado como descartado) era o segundo consumidor
  do mixin de zona; com um consumidor so, o mixin virou codigo dentro do
  `Zone.luau`.
- **`BLACKLIST_OVERLAP`** do CameraController: montado e nunca lido.
- **O tremor de queda no `SurfaceUIController`**: esse controller entra na fase
  7; hoje so a camera escuta o `Landed`.

### Um numero que parece errado, e ficou como esta

`SeedSettings.COLLECT_TIME_THRESHOLD = 0.4` contra `SEED_GROW_TIME = 2`: o
prompt de colheita libera com a semente ainda crescendo. E dado, nao codigo.

### O unico arquivo nao-strict do projeto

`src/Libs/Spring/init.luau` (468 linhas) e o `SpringWrapper` do Modux V2, uma
fachada estilo TweenService sobre o pacote `spring`. Entrou como esta,
`--!nonstrict`. Vale uma passada de tipagem depois.

## Fase 7 — a UI ligada ao estado, e a conferencia (feito)

| origem | destino |
|---|---|
| `client/Controllers/KillFeedController.luau` | `src/KillFeed/client/KillFeedController.luau` |
| `client/Controllers/SurfaceUIController.luau` | `src/Interface/client/SurfaceUIController.luau` |
| `client/Interface/init.luau` | `src/Interface/client/InterfaceController.luau` |

### Onde a interface encontra o estado

O `InterfaceController` e o unico lugar do cliente que sabe de tela **e** de
estado. Os componentes recebem getters e nao conhecem controller nenhum; os
controllers nao sabem que existe tela.

Tudo nasce dentro de um `Vide.mount`, e isso nao e detalhe de estilo:
`derive`, `effect` e `spring` do Vide exigem escopo reativo. Componente montado
fora de um `mount`/`root` **passa no type-check e quebra em runtime** — o
`WeaponSlot` e o `Crosshair` usam spring.

### A barra de armas deixou de chutar

O V2 desenhava os tres slots com `GetGun:GetByName("Shotgun")` e
`GetGun:GetByName("Peavolver")` **cravados na UI**, porque o pacote de loadout
mandava so a arma ativa — o cliente nao tinha como saber o que havia nos outros
dois slots.

O pacote agora leva `Slots`, um ID de arma por slot (0 = vazio), e o campo
`WeaponID` deixou de existir: a arma ativa e `Slots[ActiveSlot]`, entao nao ha
dois campos para discordar. A UI ganhou `WeaponController:SlotGun(slot)` e
desenha o icone certo de cada slot.

### A fila de kills virou array

No V2 as entradas eram um mapa `{ [id] = entrada }` com `LayoutOrder = -id`
para inverter a ordem na tela. O componente Vide recebe **array**, e a ordem do
array e a ordem na tela: a entrada nova entra na frente e o `LayoutOrder` saiu
do dado. A identidade para remover passou a ser a propria tabela da entrada,
que e o que o `values` do Vide usa para casar item com filho.

### O tremor de queda fechou o circuito

`MovementController.Landed` (criado na fase 3, sem ouvinte) agora tem dois:
`CameraController` (trauma de shake) e `SurfaceUIController` (todos os paineis
tremem). No V2 o MovementController chamava `CreateEffect` em dois paineis pelo
nome, na mao.

### O gerador de folhas, de novo

O `modux generate` reconstroi a raiz de um require copiado para a folha
assumindo que ela e um local de `game:GetService(...)`. Eu tinha escrito
`const Client = StarterPlayer.StarterPlayerScripts.client` e requerido
`Client.Weapon.GunBar`; a folha saiu com `local Client = game:GetService("Client")`,
e como o Manifest agrega as folhas, **o erro contaminou todos os controllers do
lado cliente** — dezenas de "Cannot add property" em arquivos sem nada errado.

Regra: **caminho inteiro em cada require, a partir de um local de servico.**

## Conferencia final

Os 120 arquivos de jogo da origem, classificados:

| | arquivos |
|---|---|
| portados (inclui renomeados e fundidos) | **69** |
| wrappers de elemento que morreram com o Fusion | 19 |
| stories velhas, substituidas por stories de Vide | 6 |
| descartados de proposito (vazio, orfao, vendor, no-op) | 26 |
| **total** | **120** |

As fusoes: `ShotgunComponent` + `PeavolverComponent` -> `Gun.luau`;
`GameService` -> `RoundService`; `PlayerZoneComponent` -> `Zone.luau`. As
renomeacoes: `Guns` -> `GunsData`, `DayCycle` -> `DayCycleSettings`,
`ProgressionBar` -> `Components/ProgressionBar/init`.

No destino: **173 arquivos**, 22 controllers e 22 modulos de servidor no
Manifest, `modux check` up to date, `tools/analyze.ps1` em **0 erros e 0
ciclos**.

Em `--!nonstrict` existem **dois** arquivos, os dois de `src/Libs`: o `Signal`
que veio do template e o `Spring` que veio do Modux V2. Todo o codigo de jogo
esta em strict.

## O que ainda depende de voce

1. **Abrir o `backup/12_07_26.rbxl` no Studio e exportar os assets.** A origem
   nao mapeia asset nenhum em disco: modelos de arma, sementes, sons, musicas,
   billboard e os mapas existem so dentro do place. O `.rogen.json` daqui ja
   declara as pastas (`Assets.Weapons`, `Assets.Seeds`, `Assets.Sounds`,
   `Assets.Musics`); o conteudo e que falta.
2. **Nada rodou no Studio ainda.** O type-check esta limpo, o que garante forma,
   nao comportamento. O primeiro teste vai cobrar: tags (`Gun`, `Equipment`,
   `Vital`, `Movement`, `Zone`, `Seed`, `FFASpawn`, `Farmland`), o handshake
   `Ready` do Lync e o mount da HUD.
3. **`AdminSettings.AdminUserIds`** tem um UserId real e dois negativos de
   reserva vindos do V2. Confirme quem deve ser admin.
4. **`OnTick` sem delta no tipo** (ver fase 3): quem precisa de delta usa
   `Heartbeat`/`RenderStep` direto. Consertar e uma linha em tres arquivos do
   framework, mas `src/Modux` e subtree — o conserto de verdade e na branch
   `framework` do ModuxV3.
5. **Pontas que esperam feature futura**: `PlayShoot`/`PlayAttack`/`BeginThrow`
   ja ligados, mas `GetPoseState` (trava de recarga) segue sem consumidor; o
   `RigBuilder` so e usado pelo viewmodel; `ZoneNotification` nao existe mais.
