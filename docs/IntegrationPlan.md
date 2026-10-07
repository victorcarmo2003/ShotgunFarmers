# Plano de integração das telas

Ordem pensada para executar **uma etapa por vez**. Cada etapa diz o que integra, o que muda, como testar e as perguntas que precisam de resposta antes de começar.

| # | Etapa | Telas | Testável no Studio? |
|---|---|---|---|
| 1 | Saneamento | — | Sim |
| 2 | Stats de partida, times e Leaderstats | Leaderstats | Sim (`ForceRole=Match`, 2 clientes) |
| 3 | Options in-game | Options | Sim |
| 4 | Matchmaking + registro de partidas | GameSelection (modos) | Parcial (teleport só publicado) |
| 5 | ONLINE global | Topbar | Sim (API Services) |
| 6 | Squad/party + InviteCircle | Lobby (slots, INVITE) | Parcial |
| 7 | Salas privadas | GameSelection (Join/Create Room) | Publicado |
| 8 | Progressão | Career | Sim |
| 9 | Quests | Quests | Sim |
| 10 | Cosmetics | Cosmetics | Sim |
| 11 | Shop | Shop | Sim (produto de teste) |

Dependências: 1 → tudo · 2 → 8, 9 · 4 → 5, 6, 7 · 8 → 9 · 10 → 11.

---

## Achados que afetam o plano

1. **Kill duplicada.** `Hit/server/HitService.luau:80` retorna `not vital:TakeDamage()`, e `Vital:TakeDamage` retorna `false` quando o alvo já está morto. Tiro em alvo morto (durante os 3s de respawn) conta como kill de novo e gera outra entrada no KillFeed.
2. **Nada conta K/D/A hoje.** Kill só vira `KillFeed.Kill`; death não guarda o killer; não existe assist nem times (ninguém atribui time, sem friendly-fire, spawn sempre FFA).
3. **Profile replica tudo a cada mudança** (`ProfileService` → `Replicate`). Campo novo = 4 edições (Template, Replicate, `Profile/shared/Net`, `ProfileController`). Regra: dados grandes (quests, inventário, stats de carreira) persistem no Template mas replicam por pacote próprio da feature.
4. **UserId passa de 2³²** — em pacotes usar `Lync.f64()`.
5. **Todo `Net.luau` novo precisa entrar em `Libs/Net/init.luau`**, senão o client trava no boot.
6. **`InviteCircle.luau`** usa `Activate` em vez de `Activated`.
7. **ONLINE fixo em 100** no `LobbyScreen` (o `props.PlayersOnline()` está comentado).
8. **Mais de 5 no lobby** → slot aleatório sobreposto; o slot só é dado no spawn.
9. **Teclas livres:** `Tab` (placar) e `M` (Options). Em uso: Q, C, R, 1–3, Mouse1, F2. `InputController.Context` existe mas não é consultado.
10. **Sensibilidade não existe no código**; FOV é constante; `MusicController` não lê o volume do Profile.
11. **`GameModes.Chicken.AllowJoinInProgress = false`**, contrariando a decisão de modos casuais entrarem em andamento.
12. **Teleport não roda no Studio** e MemoryStore exige API Services — o back-end precisa de uma camada `TeleportGateway` com fallback de Studio.

---

## Etapa 1 — Saneamento

- `HitService:DealDamage`: checar `vital.Alive` antes do dano.
- `InviteCircle`: `Activated` + `--!strict`.

**Aceite:** atirar no alvo morto não gera segunda kill no KillFeed.

## Etapa 2 — Stats de partida, times e Leaderstats

**Nova feature `src/Stats`:**
- `TeamService` (server): atribui Red/Blue balanceado em modos com time (`player:SetAttribute("Team")`); `SpawnService` passa a usar `GetTeamSpawnCFrame`; filtro de friendly-fire.
- `MatchStatsService` (server): K/D/A/Headshots/Score/Damage por jogador e placar por time; assist = dano recente de quem não matou; reset ao voltar a Starting; signals `Killed`, `Died`, `MatchStarted`, `MatchEnded` (base da progressão e quests).
- `VitalService`: signal `Died`. `HitService`: chama `RecordDamage`/`RecordKill`.
- `Stats/shared/Net.luau`: `Rows` (replicate por UserId: K, D, A, Score, Ping, Team) e `Totals` (Red/Blue). Ping via `GetNetworkPing` a 1 Hz.
- `LeaderstatsController` (client): monta `LeaderstatsUI`; **segurar Tab** mostra; abre sozinho em Intermission/Vote; desliga a PlayerList padrão do Roblox.

**Aceite (2 clientes):** kill/death/assist contam; Tab mostra e esconde; TDM com times balanceados, spawn do time e sem fogo amigo; stats zeram na nova rodada.

**Perguntas:** pontos por kill/assist/headshot/vitória? Janela e dano mínimo do assist? Botão no mobile? Atingir o ScoreLimit encerra a partida (hoje só o timer encerra)?

## Etapa 3 — Options in-game

- Profile: `Settings` (id → número) e `Keybinds` (ação → KeyCode). Volumes usam `MusicVolume`/`SoundVolume` que já existem.
- `Options/shared/Net.luau`: `SetSetting`, `SetKeybind` (servidor valida faixas de um `OptionsCatalog`).
- `OptionsService` (server) grava no Profile; `OptionsController` (client) monta `OptionsUI`, abre com **M**, troca o `InputController` para contexto "Menu" (bloqueia binds de gameplay) e destrava o mouse.
- Aplicar: FOV no `FOVController`, sensibilidade (código novo), volumes no `MusicController`, rebind via `InputController:Rebind`.
- Ajustes de UI pendentes: slider arrastável; Toggle Crouch como ON/OFF em vez de slider.

**Aceite:** M abre/fecha e bloqueia tiro; FOV muda na hora e persiste; rebind do Reload funciona e persiste.

**Perguntas:** abre também no lobby (qual botão)? WASD/Jump/Run são do PlayerModule — esconder ou implementar rebind? Sensibilidade via `UserGameSettings` ou multiplicador próprio? Quais idiomas? Botão "voltar ao lobby"?

## Etapa 4 — Matchmaking e registro de partidas (GameSelection)

**Nova feature `src/Matchmaking`:**
- `TeleportGateway`: `Reserve()` / `Teleport()`; no Studio só loga.
- `MatchRegistryService`: HashMap `MatchConfig` (chave = `PrivateServerId`, fonte da verdade da partida) + SortedMap `MatchRegistry` (jogadores, vagas reservadas, fase; heartbeat de 15s, TTL 45s). Implementa o `FetchConfig` real do `ServerRoleService`.
- `MatchmakingService` (lobby): valida líder e vagas; QuickPlay/FFA/TDM procuram partida com vaga (reserva atômica com `UpdateAsync`), senão reservam servidor novo com mapa aleatório do modo; Practice sempre reservado e privado. No servidor da partida: devolve ao lobby quem não pode entrar.
- `Matchmaking/shared/Net.luau`: `Play` (query), `Status`, `Cancel`, `ReturnToLobby`.
- `MatchmakingController` (client) + `LobbyController.SelectMode` chama `Play`; estado "Procurando…" na GameSelection.
- Max Players do place ≥ 20.

**Aceite (publicado):** FFA teleporta para servidor reservado com o mapa certo; segundo jogador cai na mesma partida; lotada cria outra; falha mostra erro.

**Perguntas:** QuickPlay sorteia o modo ou prioriza o mais cheio? Chicken entra em andamento? Practice é solo, com bots, ou com o squad? Como volta ao lobby (fim de partida automático)? Rotação de mapas?

### Etapa 4 — implementado

- `src/Matchmaking`: `MatchmakingSettings`, `Net` (`Play` query, `Status`, `Cancel`, `ReturnToLobby`), `TeleportGateway` (Studio só loga; retry 1x em erro e em `TeleportInitFailed`), `MatchRegistryService` (HashMap `ServerConfig` + SortedMap `MatchRegistry`, heartbeat 15s, reserva atômica por `Pending` com expiração, `FetchConfig` real, limpeza no `BindToClose`), `RouterService`, `MatchmakingService`, `MatchmakingController`.
- Papel **Router** (servidor público): reserva lobby privado por jogador e teleporta; convite via `LaunchData {Lobby}` e `TeleportData.ReturnLobby` levam ao lobby existente (se tiver vaga). Router não carrega ambiente nem spawna; GameState fica `Loading`.
- Lobby: squad implícito = todos do servidor; líder = `Owner` da config (ou o primeiro). Só o líder dá Play; vai todo mundo junto com `TeleportData.ReturnLobby`. QuickPlay = partida casual mais cheia com vaga, senão cria FFA. Practice = servidor novo privado. Estado `SEARCHING...`/`JOINING...` no cabeçalho da GameSelection; fechar a tela durante a busca cancela.
- Partida: admissão (privada fora do squad, lotada, modo sem entrada em andamento) devolve ao lobby; botão **LEAVE MATCH** nas Options; gancho ranked (volta todos no Intermission).
- Lobby config com TTL 15 min renovado pelo lobby e pelos servidores de partida dos jogadores que vieram dele.
- `GameModes`: Chicken entra em andamento; novo modo `Practice` (máx. 5) em todos os mapas.

**Pendências:** rotação de mapa entre rodadas (mapa fixo por servidor — trocar exige respawn na troca, limpar componentes taggeados do mapa e reiniciar DayCycle); UI de votação; bots no Practice; party/slots reais (Etapa 6); ranked; Max Players do place ≥ 20 (configurar no site); teste publicado.

## Etapa 5 — ONLINE global

- `OnlineService`: todo servidor grava `{Count}` num SortedMap `Online` a cada 20s (TTL 45s); o lobby soma e envia `Lobby.Online`.
- `LobbyScreen`: trocar o `100` fixo por `props.PlayersOnline()`.

**Aceite:** o número sobe com mais clientes e cai em até ~45s quando um servidor fecha.

**Perguntas:** conta servidores de partida também? Atraso de ~30s é ok?

## Etapa 6 — Squad/party e InviteCircle

- `PartyService` (lobby): parties em memória (máx. 5); convite pelo `SocialService` leva `LaunchData` com o líder; líder no slot 1, membros 2–5 via `SpawnService.SlotProvider` + novo `MoveToSlot`; saída do líder promove o próximo.
- `Party/shared/Net.luau`: `State`, `Invite`, `Invited`, `Respond`, `Leave`, `Kick`.
- `PartyController`: InviteCircles como `BillboardGui` no PlayerGui adornados em `CharacterPositions` 2–5; vazio = convidar, ocupado = avatar/nome.
- Matchmaking passa a teleportar o squad junto e o `TeamService` põe o squad no mesmo time.

**Aceite:** A convida B, B aparece no slot 2; o líder dá Play e os dois vão juntos.

**Perguntas:** limitar o lobby público a 1 squad ou esconder os outros jogadores localmente? Party persiste ao voltar da partida? Convite só para amigos? Líder pode expulsar?

### Etapa 6 — implementado

- Squad = lobby: a chave do squad é o `PrivateServerId` do lobby do líder (a mesma do `ReturnLobby`). Registro no HashMap `Squads` (`Leader`, `Members[{Id, Name, Status Lobby|Idle, Joined}]`, `Job`, TTL 15 min renovado pelo lobby a cada 20s e pelas partidas a cada 60s). Máx. 5, contando idle.
- `src/Party`: `PresenceService` (HashMap `Presence` por UserId → `{Job, Role, Squad}`, heartbeat 20s, TTL 60s, marca `Gone` ao sair; tópico MessagingService `Party_<JobId>` por servidor), `SquadStore` (UpdateAsync atômico, add/remove membro, avisa o lobby do squad), `SquadService` (sincroniza o squad do lobby, slots 1–5 via `SpawnService.SlotProvider`/`ArrangeSlots`, promove líder, remove ausente sem presença após ~60s, chave de retorno na partida), `InviteService` (lista de amigos, convite, resposta, entrada no squad).
- Lista de amigos: o cliente filtra `GetFriendsOnlineAsync` (mesmo `PlaceId`, ou em jogo sem PlaceId) e manda até 20 candidatos; o servidor confirma amizade (`GetFriendsAsync`, cache 60s) e a Presence. Lista vazia → `PromptGameInvite` com `LaunchData` (fallback antigo).
- Aceitar no lobby → sai do squad atual e teleporta para o lobby do líder. Aceitar na partida → entra como `Idle`; LEAVE MATCH / fim ranked usam a chave do squad novo (`SquadService:GetReturnKey`).
- `MatchmakingService`: líder vem do squad; Play bloqueado com "Waiting for squad members" se algum membro não está no lobby; leva só os membros presentes.
- UI: `FriendsScreen`, `InvitePopup` (30s, ACCEPT/DECLINE, teclas Y/N para funcionar com o mouse travado na partida), `InviteCircle` como BillboardGui nos slots 2–5 (vazio = "+", ausente = foto + IDLE/IN MATCH/JOINING). Avisos via `ShowError(msg, "SQUAD")`.
- No Studio tudo é local (sem MemoryStore/MessagingService); convites só funcionam publicado.

**Pendências:** sair do squad / expulsar (sem UI); convidar quem está no mesmo servidor de partida não existe (só do lobby); convites que chegam antes do `SubscribeAsync` do servidor novo se perdem; o fallback do convite Roblox (LaunchData) não foi depurado.

**Testar publicado (A, B, C amigos entre si):**
1. A e B em lobbies próprios: A → INVITE → lista mostra B (LOBBY) → INVITE vira SENT → B recebe popup → ACCEPT → B cai no lobby de A, no slot 2. Play de A leva os dois.
2. C numa partida: A convida C (IN MATCH) → C aceita → no lobby de A aparece o slot com foto + IDLE; Play de A dá "Waiting for squad members". C usa LEAVE MATCH → cai no lobby de A; Play libera.
3. Recusa: B recusa → A vê "declined" e o botão volta a INVITE. Expiração: não responder 30s → popup some, A vê "did not answer".
4. Cheio: com 5 no squad (contando idle), INVITE → "Your squad is full"; aceitar convite de squad cheio → "This squad is full".
5. Líder sai do jogo → o próximo membro presente vira líder (Play só para ele).

## Etapa 7 — Salas privadas (Join/Create Room)

- `RoomService`: código de 5 caracteres num HashMap `RoomCodes` (TTL renovado pelo servidor da sala); Create reserva servidor privado (fora do QuickPlay); Join com rate limit.
- `Rooms/shared/Net.luau`: `Create`, `Join` (queries).
- UI nova: `RoomDialog` (TextBox do código, seleção de modo/mapa, código gerado).

**Aceite (publicado):** A cria, B entra pelo código; código errado avisa; sala não aparece no QuickPlay.

**Perguntas:** quem pode criar sala? Opções (modo, mapa, TeamSize, tamanho)? Poderes do host? Tempo de vida da sala?

## Etapa 8 — Progressão (Career)

- Profile: `Xp`, `Level`, `Career = { Kills, Deaths, Assists, Headshots, Matches, QuestsDone, Damage }` (replicado por `Career/shared/Net.luau`, não pelo `Profile.Data`).
- `CareerService`: ouve os eventos da etapa 2 e soma no Profile na hora; XP por evento; curva em `Career/shared/Progression.luau`; `Wins` no fim da partida; anti-farm.
- `CareerController` alimenta Career e Leaderstats (Level/XP).

**Aceite:** números sobem e persistem após rejoin; perfis antigos recebem os campos novos sem erro.

**Perguntas:** curva de XP e nível máximo? XP por evento? O que é vitória no FFA e no TDM? Rótulos finais dos 10 stats (hoje há "ETC")?

## Etapa 9 — Quests

- Profile: `Quests = { Day, Progress, Claimed }`, reset diário por dia UTC.
- `Quests/shared/QuestCatalog.luau`: `{ Id, Title, Event, Goal, Reward }` (até 8 ativas).
- `QuestService`: progresso pelos eventos da etapa 2/8; `Claim` valida e paga Gems (idempotente).
- `Quests/shared/Net.luau`: `State`, `Claim`.

**Aceite:** "matar 5" avança, REDEEM paga uma vez só, virar o dia renova.

**Perguntas:** diárias, semanais ou fixas? Quantas ativas? Lista inicial e recompensas? Contam no Practice?

## Etapa 10 — Cosmetics

- Profile: `Owned`, `Equipped` (categoria → id), `RedeemedCodes`.
- `Cosmetics/shared/CosmeticCatalog.luau` e `Codes.luau`.
- `CosmeticService`: valida posse, aplica no `CharacterAdded` (respeitando `CharacterService:Sanitize` e o `RigBuilder` do viewmodel); resgate de código.
- `CosmeticsController`: seções reais por aba, prévia local, `Equip` no DONE; `Humanoid:MoveTo` para a posição 6 (seu gancho).

**Aceite:** equipar aparece no lobby e na partida e persiste; item não possuído é rejeitado; código vale uma vez.

**Perguntas:** quais são as 7 abas? Itens padrão e origem de cada item? Aparece na primeira pessoa? Códigos fixos ou dinâmicos? Skins de arma entram aqui?

## Etapa 11 — Shop

- Profile: `PurchaseIds` (idempotência do `ProcessReceipt`); usa `Owned`, `Gems`, `GemsSpent`, `RobuxSpent`.
- `ShopCatalog`: `ProductId`/`GamepassId`/`GrantsCosmeticId`; remover os itens de exemplo.
- `ShopService`: compra com moedas (preço só no servidor) e `ProcessReceipt` único que só confirma após salvar.
- `ShopController`: prompt de Robux, compra com moedas, estado "Possuído".

**Aceite:** comprar com moedas debita e concede; saldo insuficiente rejeita; recibo repetido não duplica.

**Perguntas:** "moedas" = Gems? Itens, preços e IDs reais de DevProducts/Gamepasses? Pacotes de Gems por Robux? Rotação/estoque?

**Etapa 8 — implementado:**
- `Career/shared`: `Progression` (XP do nível n = round(100 × 1.15^(n-1)); `Apply` com overflow multi-nível; teto técnico de 1000 níveis), `CareerSettings` (XP: kill 10, headshot +5, assist 5, partida 25; anti-farm 3 kills/60s por par), `Net` (`Data` servidor→cliente, também no `Libs/Net`).
- `CareerService` (server): soma no Profile via `ProfileService:Update` (Level, Xp, Career e Wins num batch só) a cada `Killed`/`Died`; dano acumulado em buffer e gravado a cada 1 s; `MatchEnded` dá Matches+1, 25 XP e Wins. Só no role Match e fora do Practice. Vitória: TDM = time de maior placar (empate não conta); FFA = top 3 por score (empates no 3º entram; score 0 não vence).
- `MatchStatsService`: novo signal `Damaged(attacker, victim, amount)`.
- `CareerController` (client): `Level`, `Xp`, `XpMax`, `Stats` (WINS, KILLS, ASSISTS, HEADSHOTS, QUESTS, MATCHS, DEATHS, K/D, DAMAGE, LEVEL); usado por `LobbyController` e `LeaderstatsController`.
- Profile: `Xp`, `Level`, `Career` no Template (Reconcile preenche perfis antigos); `Wins` no `Profile/shared/Net` subiu para 4294967295.

---

## Decisões registradas (2026-10-01)

- **Score:** kill 1; kill por headshot 1.5 no total; assist 0.5 (só quem não matou; qualquer dano entra nos pendentes, limpos ao voltar a 100% de vida); vitória não pontua. Partida termina só pelo timer.
- **Lobby privado:** servidor público vira **roteador** — reserva um servidor só do jogador (`ReserveServer`) e teleporta. Convites levam no `LaunchData` a chave do lobby de quem convidou. Redirecionamento dentro do place principal (sem place de entrada separado, por ora).
- **QuickPlay:** partida casual mais cheia com vaga para o squad; sem nenhuma, cria nova.
- **Practice:** servidor privado do squad; bots (adicionar/remover) ficam para depois.
- **Fim de partida:** casual → nova rodada no mesmo servidor; ranked → todos voltam ao lobby.
- **Chicken:** entra em andamento (como FFA/TDM).
- **Mapas:** votação na fase Vote; até ter UI, sorteio automático.
- **Party:** continua junta ao voltar da partida. Saída da partida é individual.
- **Progressão:** curva exponencial `100 × 1.15^n`; XP kill 10, headshot +5, assist 5, partida completa 25.
- **Vitória (Wins):** FFA top 3; TDM todos do time com maior placar; empate não conta.

---

## Revisão de fluxo (lobby/matchmaking/squad) — pendências a corrigir

Sem BLOCKER no caminho principal. Status após a rodada de correções (2026-10-01):

- **H1 — corrigido.** Membro de `Squads` de partida privada é admitido mesmo após Starting (`MatchmakingService:AdmissionProblem`). Partida privada segura o Starting até o primeiro jogador entrar, com teto `MatchSettings.PrivateStartHold` = 60s (`RoundService:ShouldHold`). É a opção menos invasiva: um guard no tick, sem novos sinais nem acoplamento entre serviços.
- **H2 — corrigido.** Cada servidor grava a própria contagem (SortedMap `Online`, TTL 45s). Só o agregador eleito (lock `OnlineAggregatorLock` no HashMap `OnlineMeta` via UpdateAsync, TTL 60s, renovado a cada 30s) faz o GetRangeAsync e grava `OnlineTotal`. Os lobbies leem só essa chave a cada 30s. Mantém fallback local e só envia ao cliente quando muda. O lock é solto no BindToClose.
- **H3 — corrigido.** O FetchConfig do boot faz 5 tentativas com backoff de 1.25s até 10s. Servidor reservado sem config válida (nil, erro ou inválida) vira **Router** (ReturnLobby se permitido, senão lobby novo). `Cleanup` não apaga mais a config da partida: só remove do `MatchRegistry`, e a config expira pelo TTL.
- **M1 — corrigido.** `SubscribeAsync` com retry e backoff exponencial (2s até 60s). A escrita de presença só começa depois da assinatura.
- **M2 — corrigido.** O Router só honra ReturnLobby/LaunchData para quem é membro do `Squads[key]`, é Owner do lobby ou tem token de convite (`SquadTokens`, TTL 120s, gravado no Accept). `compose` só adiciona presentes que são membros, Owner ou têm token; os demais são realocados para um lobby próprio. Na partida, ReturnLobby só vale com `SourcePlaceId == PlaceId` e se o jogador for membro do squad (checado no store). O fallback `PromptGameInvite`/LaunchData não grava token, então quem entra por ele vai para um lobby próprio.
- **M3 — corrigido.** Nomes vêm das páginas do GetFriendsAsync (cache 60s). Cooldown de 10s, cache de presence por UserId de 10s e teto de 60 leituras por jogador por minuto (`InviteService:Spend`).
- **M4 — corrigido.** No Studio, `MatchRegistryService` faz curto-circuito via `TeleportGateway:IsSimulated()` (FindLobby, CreateLobby, SetConfig, UpdateConfig, ListMatches, Reserve/Release, RegisterMatch). OnlineService usa só a contagem local. Logs de simulação viraram `print`.
- **M5 — corrigido.** A busca (`Search`) fica ativa até o líder sair do servidor, até o teleporte do líder falhar ou até o timeout de segurança de 45s. Play é rejeitado se algum membro estiver Traveling.
- **M6 — corrigido.** Teleporta exatamente os userIds reservados que ainda estão presentes.
- **M7 — corrigido.** A poda conta o tempo desde o primeiro miss (60s). Erro de leitura da presença não conta como ausência.
- **M8 — corrigido.** ProfileService espera `ServerRoleService:OnReady` e não carrega perfil no papel Router.
- **M9 — corrigido.** O lobby grava `Players=0` no BindToClose. O Router checa capacidade pelo registro `Squads` (contando Idle).
- **L1 — corrigido.** Trava por jogador (`Joining`) antes do AddMember.
- **L2 — corrigido.** RefreshConfigs usa UpdateAsync, preserva `Squads` e atualiza o Raw local.
- **L3 — corrigido.** A renovação da config do lobby ficou só no `SquadService:Renew`.
- **L4 — corrigido.** `TeleportInitFailed` libera a vaga do jogador. A busca é por squad e só reage a falhas de quem está nela.
- **L5 — corrigido.** OnSessionEnd não dá Kick se o jogador está em teleporte pelo gateway (`TeleportGateway:IsTeleporting`).
- **L6 — parcial.** A escrita de presença usa UpdateAsync e aborta se o jogador já saiu do servidor. Ainda há corrida entre servidores por relógio.
- **L7 — corrigido.** Quem não é membro recebe estado de squad vazio, e a presença só marca o squad para membros.
- **L8 — pendente.** Sair/expulsar precisa de UI. Idle longo continua bloqueando Play (comportamento da decisão atual).

**Testar publicado:** convite em lobby e em partida (token + membership); Practice com 2–5 membros chegando com atraso; fechar e reabrir partida pelo mesmo access code (deve rotear); ONLINE com vários lobbies (só um agregador; conferir cota do MemoryStore); Play duplo durante teleporte; jogador entrando com TeleportData forjado (deve ir para lobby próprio); profile não carregado no Router (sem sessão dupla).

## Granadas — implementado

Arremessáveis com autoridade no servidor e simulação própria por passo fixo (1/60 s) compartilhada entre servidor e cliente (`src/Weapon/shared/ThrowSim.luau`). Fonte única de balanceamento: `src/Weapon/shared/Throwables.luau` (pavio, raio, dano, física, efeito). Quantidade por vida e intervalo vêm do `GunsData` (`Amount = 2`, `FireRate = 1`) e reaproveitam munição/`GunRules.CanShoot`/`Equipment:ResetAmmo` (recarrega ao renascer; a GunBar mostra a contagem).

| Granada | Disparo | Raio | Dano (centro → borda) | Efeito |
|---|---|---|---|---|
| Grenade | pavio 3 s, quica | 12 | 100 → 30 | só explosão |
| Pinapple | pavio 2,5 s, quica | 15 | 90 → 20 | 4 estilhaços radiais (raycast 22 studs, 15 cada) |
| Onionnade | pavio 2 s, quica | 14 | 15 | gás 6 s (raio 12): 5/s + cegueira no cliente (4 s após sair) |
| Lemonade | pavio 2 s, quica | 12 | 20 | ácido 6 s (raio 10): 8/s + WalkSpeed ×0,6 |
| Moolotov | contato (máx. 5 s) | 10 | 10 | fogo 6 s (raio 9): 12/s + queimadura 4/s por 3 s após sair |
| Bananarang | contato (máx. 4 s) | 10 | 80 → 20 | voo plano (gravidade ×0,05) curvando à esquerda (1,3 rad/s) |

Regras: linha de visão do centro ao HumanoidRootPart ou Head (parede bloqueia), falloff linear, aliados imunes em modo de times, lançador toma 50%, kill conta em placar/XP/KillFeed (`isHeadshot = false`, `GunName` = granada). Rede: `Weapon.Throw` (cliente → servidor), `ThrowSpawn`/`ThrowDetonate`/`ThrowClear` (servidor → todos). Zonas/queimaduras/projéteis são limpos quando o estado sai de `Combat`.

Pendências:
- Sons de explosão: ganchos `Assets.Sounds.<Granada>Explosion` (GrenadeExplosion, PinappleExplosion, OnionnadeExplosion, LemonadeExplosion, MolotovExplosion, BananaExplosion) — sem asset ainda.
- `Assets.Weapons.Grenade` não existe (projétil usa esfera procedural).
- VFX em `ReplicatedStorage.Assets.VFX` criados no Studio (place precisa ser salvo); sem eles o cliente usa fallback procedural.
- Viewmodel continua mostrando a granada com 0 unidades; arremesso dispara no início da animação `Throw` (sem marker de soltura).
- Teste em Play pendente (Rojo estava desconectado na implementação).

## Armas — implementado

Fonte única: `src/Weapon/shared/GunsData.luau` (novos campos `HeadshotMultiplier`, `Range`, `FireMode` = `Hitscan | Projectile | Cone | Melee | Throw`, `Disabled`). Sem recarga: `Amount` é munição total; `DiscardWhenEmpty` mantido (Carrocket, Strawborry). Todas as armas são hold-to-fire (segurar atira na cadência `FireRate`).

| Arma | Modo | Dano | Balas | FireRate (s) | Amount | Spread | HS× | Range | Knockback |
|---|---|---|---|---|---|---|---|---|---|
| Shotgun | hitscan | 15 | 6 | 0.5 | 12 | 4 | 1.5 | 60 | 80 |
| Peavolver | hitscan | 35 | 1 | 0.25 | 12 | 1 | 2.0 | 250 | 30 |
| Uzichinni | hitscan | 9 | 1 | 0.06 | 60 | 2.5 | 1.5 | 150 | 4 (era 10) |
| M6Bean | hitscan | 14 | 1 | 0.1 | 45 | 1.5 | 1.75 | 400 | 5 (era 15) |
| WatermeLMG | hitscan | 16 | 1 | 0.09 | 100 | 2.5 | 1.5 | 350 | 4 (era 10) |
| Sniperagus | hitscan | 75 | 1 | 1.2 | 5 | 0.2 | 2.0 | 1000 | 40 |
| Snipine | hitscan | 50 | 1 | 0.6 | 8 | 0.4 | 2.0 | 800 | 40 |
| Strawborry | hitscan | 60 | 1 | 0.9 | 10 | 0.5 | 2.0 | 500 | 25 |
| Raygun | hitscan | 22 | 1 | 0.2 | 25 | 0.8 | 1.5 | 400 | 30 |
| Carrocket | projétil reto (vel. 160, gravidade 0, contato) | 100 → 30, raio 8 | 1 | 3 | 4 | — | — | 500 (pavio 3,1 s) | 60 |
| Gromato Launcher | projétil em arco (vel. 110, lift 10, gravidade ×0,35, contato) | 70 → 20, raio 7 | 1 | 1.2 | 6 | — | — | 300 (pavio 2,7 s) | 50 |
| Chilli Thrower | cone (meio-ângulo 15°) | 6/tick + queimadura 4/s por 3 s | — | 0.08 | 150 | — | — | 18 | 2 (era 20) |
| Hoe | corpo a corpo (spherecast) | 45 | — | 0.6 | ∞ | — | 1.0 | 6 | 0 |
| Shovel | corpo a corpo (spherecast) | 55 | — | 0.8 | ∞ | — | 1.0 | 6 | 0 |
| Double Cob | desativada (`Disabled`, sem modelo) | — | — | — | — | — | — | — | — |

Regras:
- Hitscan: raycast limitado ao `Range` no cliente e no servidor (`HitService:ResolvePellet` recebe o alcance da arma). Dano integral até 60% do Range, cai linearmente até 50% no Range (`GetGun.RangeFalloff`, distância ao alvo rebobinado). Headshot multiplica por `HeadshotMultiplier`. Dano final arredondado (mínimo 1).
- Cadência no servidor: validada pelo `TimeStamp` do cliente (já limitado a −1 s/+0,25 s do relógio do servidor), não pela hora de chegada do pacote — jitter de rede não rejeita tiros legítimos. Tolerância de 15% (`FIRE_RATE_TOLERANCE = 0.85`). Token bucket subiu para 20 tiros/s (rajada 12).
- Projéteis (Carrocket/Gromato): reutilizam `ThrowSim`/`ThrowableService` (definições em `Throwables.luau`, `FaceVelocity`/`ProjectileModel`). Cliente envia `Weapon.Throw`; servidor valida munição/cadência, toca o som e aplica recuo. Dano em área com linha de visão, falloff, aliados imunes, autodano 50%, kill no placar/XP/KillFeed com o nome da arma. Explosão em Farmland planta a semente da arma.
- Chilli: servidor varre jogadores no cone (posição rebobinada, tolerância de corpo 2 studs, linha de visão), 6 por tick e acende/renova a queimadura do Moolotov (`HitService.Burned` → `ThrowableService:Ignite`; o relógio do tick é preservado ao renovar).
- Melee: spherecast (raio 1,5) de 6 studs no cliente; servidor confirma com hitbox 3,5. Não consome munição.
- Plantio por tiro limitado a 1 tentativa a cada 0,45 s por arma (evita inundar de sementes com armas automáticas); a Shotgun continua plantando por chumbo.
- `Equipment:AddAmmo` limitado a 255 (limite do pacote `Loadout`).

Sons (`ReplicatedStorage.Assets.Sounds`, mapa em `src/Weapon/shared/WeaponSounds.luau`; som ausente = silêncio + 1 warn por nome):
- Disparo (servidor, no modelo da arma, pool de 3 instâncias reaproveitadas por arma): `ShotgunShoot`, `Revolver`, `AutoPistol`, `M4`, `WatermelonMG`, `Sniper1`, `Sniper2`, `Bow`, `Laser`, `Bazooka` (Carrocket e Gromato). Chilli sem som.
- Impacto (cliente do atirador, posicional): `Hit1`..`Hit9` no jogador (após o servidor confirmar), `HitWall1`..`HitWall9` em parede/cenário (1 por tiro). Máximo de 16 sons posicionais simultâneos.
- Explosão de Carrocket/Gromato: `GrenadeExplosion` (reaproveita o da granada).
- Fim de partida: `MatchEnd` para todos ao passar de Match → Intermission; resultado pessoal (`Victory`/`Defeat`/`Draw`) 1,5 s depois. O resultado vem de `CareerService:Winners()` (FFA top 3 / TDM time vencedor; empate = sem vencedores) via atributo `MatchOutcome` no Player (limpo no início da partida seguinte). Usado atributo em vez de pacote novo porque qualquer pacote extra no `Libs.Net` estoura o limite de complexidade do typecheck em `CareerService`.

Pendências:
- Sons faltando no place (conferido no Studio): `AutoPistol`, `M4`, `WatermelonMG`, `Hit8`, `Hit9`, `HitWall8`, `HitWall9`, `Victory`, `GrenadeExplosion`. `RevolverShoot`/`SniperShoot` antigos não são mais usados.
- Modelos de projétil `Assets.Weapons.CarrocketMissile` e `Assets.Weapons.GromatoShell` não existem (fallback procedural). VFX de chama do Chilli é procedural (bolas neon que atravessam paredes visualmente).
- Som de disparo continua tocando pelo servidor (o atirador ouve com a latência do ping).
- Double Cob desativada até ter modelo.
- Teste em Play pendente (Studio em uso para importar áudio); funções puras (falloff, cadência, melee sem munição, Double Cob) testadas no servidor.

## VFX — implementado

Fonte: `ServerStorage.VFXCARTOON` (original intocado). Cada pasta de `Diaparo/<arma>` é um conjunto por arma: `Disparo`/`Diaparo` (Part 1×1×1 = muzzle flash), `Impact`/modelo com o nome da arma (Part plana 2,3×0×2,3 = impacto na superfície, eixo Y = normal) e `PistolShot` (Part 7,8 de comprimento com Beam = tracer; no strawborry é Trail = flecha). `Pistola` e `RayGun` só têm o impacto. Por isso o mapa final usa o impacto próprio de cada arma na parede/cenário e o `ImpactDust` como impacto genérico.

Copiado para `ReplicatedStorage.Assets.VFX` (Parts ancoradas, invisíveis, sem colisão/query, CFrame identidade, attachments aninhados achatados, emissores desligados com atributo `EmitCount`):

| Asset | Origem |
|---|---|
| `Muzzle_Default` / `Muzzle_Uzichinni` | Diaparo/Uzichinni/Disparo |
| `Muzzle_M6Bean` | Diaparo/m6bean/Disparo |
| `Muzzle_WatermeLMG` | Diaparo/ThompsonMelancia/ThompsonDisparo |
| `Muzzle_Shotgun` | ThompsonDisparo com EmitCount ×1,6 e tamanho ×1,3 |
| `Muzzle_Snipine` / `Muzzle_Sniperagus` | Diaparo/sniperpinha/Diaparo, Diaparo/sniperbeterraba/Diaparo |
| `Muzzle_Launcher` | Diaparo/carrotbazooka/Diaparo |
| `Impact_Peavolver` / `Impact_Raygun` / `Impact_Uzichinni` / `Impact_M6Bean` / `Impact_WatermeLMG` / `Impact_Snipine` / `Impact_Sniperagus` / `Impact_Strawborry` | modelos de impacto de cada pasta do Diaparo |
| `ImpactWall` | VisualEffects/ImpactDust + Flash do VisualEffects/Impact (linhas giradas para sair na normal) |
| `ImpactPlayer` | HitObjetos + penas do Pena (attachment `Feathers`) |
| `ImpactPlayerHeadshot` | o mesmo com EmitCount ×2 e tamanho ×1,4 |
| `Tracer_Bullet` | VFXCARTOON/Pistola/PistolShot (Beam verde) |
| `Tracer_Sniper` | Diaparo/sniperpinha PistolShot (Beam largo) |
| `Tracer_Arrow` | Diaparo/strawborry PistolShot (Trail) |
| `Explosion_Carrocket` / `Trail_Carrocket` | Diaparo/carrotbazooka/Explosion e /Trail (Trail com emissores contínuos) |
| `Flame_Chilli` | Fire, Fire2, Sperc1 e Smoke do `MolotovFire`, reconfigurados para jato frontal (Front, 34–44 studs/s, 0,3–0,42 s ≈ alcance 18) |
| `ScreenFire` | VisualEffects/FireScreen (atributo `Loop` nos emissores contínuos) |
| `ScreenHit` | PipocaScreenEff (EmitCount 10) |
| `ScreenHeal` | Heal |
| `HealBody` | VisualEffects/R6 Torso/Effect (o R6 é o efeito de cura no corpo) |

Mapa por arma (`src/Weapon/shared/WeaponVFX.luau`):

| Arma | Muzzle | Tracer | Impacto parede |
|---|---|---|---|
| Shotgun | Muzzle_Shotgun | bullet_trail | ImpactWall |
| Peavolver | Muzzle_Default | Tracer_Bullet | Impact_Peavolver |
| Uzichinni | Muzzle_Uzichinni | Tracer_Bullet | Impact_Uzichinni |
| M6Bean | Muzzle_M6Bean | Tracer_Bullet | Impact_M6Bean |
| WatermeLMG | Muzzle_WatermeLMG | Tracer_Bullet | Impact_WatermeLMG |
| Snipine | Muzzle_Snipine | Tracer_Sniper | Impact_Snipine |
| Sniperagus | Muzzle_Sniperagus | Tracer_Sniper | Impact_Sniperagus |
| Strawborry | — (arco) | Tracer_Arrow | Impact_Strawborry |
| Raygun | Muzzle_Default | bullet_trail | Impact_Raygun |
| Carrocket | Muzzle_Launcher | Trail_Carrocket no foguete | Explosion_Carrocket |
| Gromato Launcher | Muzzle_Launcher | — | GrenadeExplosion (mantido) |
| Chilli Thrower | Flame_Chilli (fallback: bolas procedurais) | — | — |
| Hoe/Shovel | — | — | ImpactWall |

Eventos: acerto em jogador = `ImpactPlayer` (cabeça = `ImpactPlayerHeadshot`), alinhado à normal; `ScreenFire` enquanto o jogador local tem o atributo `Burning` (Moolotov/Chilli); `ScreenHit` + `SurfaceUIController:ShakeAll(0.35)` quando Health+Armor cai ≥ 30 numa atualização; `HealBody` (todos os jogadores próximos) + `ScreenHeal` (local) quando a vida volta a 100 vinda de 1–99.

Código:
- `src/Weapon/shared/WeaponVFX.luau`: mapa, nomes, `Template`, `EmitCount`, `Muzzle`/`MuzzleCFrame` (attachment `Muzzle` se existir, senão a ponta da bounding box no eixo mais alinhado ao "para frente"; cache fraco por modelo).
- `src/Weapon/client/VFXController.luau`: pool de impactos (10 por template, round-robin com `:Emit`), muzzle montado uma vez por modelo de arma (viewmodel com ZOffset +1,5 e LightInfluence 0), orçamento de 14 bursts por frame, máx. 3 impactos por disparo, culling de 350 studs para eventos remotos, telas presas à câmera (Part do tamanho do viewport a 2,5 studs), trail do Carrocket solto e apagado (Debris 1,5 s) na detonação.
- `ProjectileController:Shoot(start, end, tracer?)`: tracers por template com pool (máx. 48 cada; Trail limpo antes de reposicionar). `bullet_trail` mantém o linger de 3 s.
- Rede: novo `Hit.Shot` (servidor → todos menos o atirador, unreliable: ShooterID, GunID, Origin, Direction), enviado em `HitService:ProcessFire` para hitscan/cone aceitos. O cliente remoto refaz os raios com o spread da arma a partir de `Origin` e desenha muzzle no modelo de terceira pessoa (`Equipment.Visual`, filho do personagem com o nome da arma), tracers e impactos. Lançadores usam o `ThrowSpawn` existente para o muzzle remoto. O pacote é tipado como `any` no `Net.luau` porque tipado ele estoura "Code is too complex" no `CareerService`.
- Queimadura: `ThrowableService:SyncBurning()` mantém o atributo `Burning` no Player enquanto ele está em `Burns`.

Muzzle preso ao cano (task-vfx-muzzle-002):
- Attachment `Muzzle` (LookVector = direção do tiro) criado na peça do cano de Shotgun (`Canos`), Peavolver, Uzichinni, M6Bean, WatermeLMG, Sniperagus, Snipine, Strawborry, Raygun e Carrocket em `Assets.Weapons` (ponta medida pelos vértices da malha via EditableMesh; Shotgun pela bounding box de `Canos`). Gromato Launcher e Chilli Thrower não têm modelo. O `Muzzle` antigo da Shotgun (filho do Model, sem efeito) foi mantido; `WeaponVFX.MuzzleAttachment` só aceita attachment com pai BasePart.
- Disparos (locais e remotos) entram numa fila e são desenhados em `BindToRenderStep` `Camera + 3`, depois da câmera (`Camera + 1`) e do `ArmsController_Follow` (`Camera + 2`): flash, origem do tracer e chama usam a posição do `Muzzle` no frame renderizado. Raycast lógico continua da câmera/HumanoidRootPart.
- Emissores do flash com `LockedToPart` (seguem o recuo/animação); chama do Chilli continua solta. Telas (`ScreenFire` etc.) passaram para o mesmo bind.
- Sem viewmodel, o tiro local usa o modelo de 3ª pessoa do próprio personagem.

Pendências/sugestões não implementadas:
- `RarityEffect` (4 variações de estrelas/flare): não há sistema de raridade; sugestão: usar na colheita/semente pronta ou em drops.
- `Bubble` (tela) e `VisualEffects/Bubble`: sem uso claro; sugestão: gás da Onionnade/ácido da Lemonade na tela.
- `ThompsonMelancia`/`peaVolver` (Models soltos) e `RIG_ARMAS`: são rigs/modelos de arma, não efeitos.
- Os efeitos de granada já existentes (`GrenadeExplosion` etc.) têm attachments aninhados (Attachment dentro de Attachment), que o Roblox não posiciona; vale achatar como foi feito nos novos.
- Corpo pegando fogo nos outros jogadores (atributo `Burning` já replica) não tem efeito ainda.
- Tiros remotos usam spread aleatório próprio (não as direções exatas do atirador); hitscan remoto de jogadores longe (> 350 studs) não aparece.
- Place precisa ser salvo para persistir os assets novos em `Assets.VFX`.

## Polimento — implementado

- Blur + FOV em menus: `Camera/client/MenuEffectsController` agrega fontes (`Leaderstats`, `Options`, `RobloxMenu` via `GuiService.MenuOpened/MenuClosed`) com `Open/Close(source)`; `BlurEffect` Size 12 em tween de 0,2 s (também no lobby). `FOVController` é o único que escreve `FieldOfView`: soma boost de +6 graus (tween 0,2 s) quando há menu aberto, só com `FirstPerson`.
- Preview de trajetória: `ThrowableController:StepPreview` (por frame no Heartbeat) segurando botão direito com arremessável (`PoseKind Throwable`) ou lançador (`FireMode Projectile`) equipado. Usa `ThrowSim.new/LaunchVelocity/Step` com a mesma origem (`ThrowOrigin`) e direção (`camera.LookVector`) do `Throw/Launch`. Pool fixo de 90 esferas neon e um disco marcador com o raio da explosão, reparentados (nada criado/destruído por frame); some ao soltar, arremessar, entrar em Menu ou sair de Combat.

## Practice — implementado

- Server: `src/Practice/server/PracticeService.luau`. So responde quando `ServerRoleService` esta em Match com `Mode == "Practice"`. Pacotes (namespace proprio `Practice`, requerido direto por service e controller, fora do agregador `Libs.Net` porque la ele deixava o `ThrowableService` "Code is too complex"): `Equip {Gun = ID}`, `SetInfinite {Ammo, Grenades}`, `Refill`, `Respawn`. Rate limit 20/s por jogador, respawn com cooldown de 1s.
- Catalogo: `src/Practice/shared/PracticeCatalog.luau` — todas as armas do GunsData exceto `Disabled`, por categoria (WEAPONS slot 1, GRENADES slot 2, MELEE slot 3). O slot vem do `PoseKind`; o servidor valida ID + slot.
- Equipment: nova API `SlotFor(gunName)` e `SetSlot(gunName, focus)` (`Grant` = `SetSlot(..., true)`); `Refill()` = `ResetAmmo` + `Publish`. `ConsumeAmmo` nao decrementa quando o Player tem `InfiniteAmmo` (armas/melee/launchers) ou `InfiniteGrenades` (PoseKind Throwable) — atributos setados so pelo servidor.
- Escolhas ficam na sessao (`PracticeService.Choices`) e sao reaplicadas no `CharacterAdded` (ex.: Carrocket descartado vira Shovel e volta no respawn).
- Client: `PracticeController` + `PracticeScreen` (+ story/storybook "Practice"). Tecla B (keybind `Practice` registrado no `OptionsCatalog`, rebindavel), so abre em Practice e com o contexto livre; abre em contexto Menu, `UnlockCameraController:SetMenu` e `MenuEffectsController:Open("Practice")`. Mostra o equipado por slot, toggles, REFILL, RESPAWN, CLOSE.
- Pendente: adicionar `"Practice"` ao tipo `Source` do `MenuEffectsController` (hoje passado com cast); ImageID das armas que estao vazias (card mostra as iniciais).

## Ajustes de throw/arco/bananarang — implementado
- Preview de trajetória aparece com botão direito OU segurando o arremesso (Armed); não some mais em cooldown/Throwing.
- Throw packet manda `Target` (ponto da mira); ThrowSpawn manda `Curve`. `ThrowSim.Aim` calcula velocidade + taxa de curva.
- Bananarang: arco circular (`CurveAngle` 24°, `MaxRange` 140) que termina no centro da mira; bojo lateral cresce com a distância.
- Strawborry virou `Projectile` com gravidade (flecha `StrawborryArrow` em Assets.Weapons, dano direto `Direct` com headshot, trail `Tracer_Arrow`, impacto `Impact_Strawborry`).
- Armas sem `ArmWeld`/`BodyWeld` (Shotgun) ganham Motor6D em runtime; peças sem junta recebem WeldConstraint; tudo desancorado.

## Polimento de animações/granadas — implementado
- PoseMachine: `Hold` sempre tocando como base (sem cair na pose zerada); fade por transição (`TRANSITION_FADE`); avanço automático `Length - fade` antes do fim (crossfade); `Throwing` vai para `Drawing` (granada nova sobe).
- Release do throw em 35% do track `Throw` (`THROW_RELEASE_FRACTION`); granada some da mão no release (`SetWeaponHidden`) e volta no Draw.
- Preview e projétil local saem do RootPart da granada / muzzle e convergem para a trajetória real em 0.3s.
- Arremesso sem mirar usa `Throwables.HIP_POWER` (0.65); mirando = força total. Packet `Throw.Aimed`.
- Granadas: GravityScale 0.8, Bounciness 0.4, Friction 0.85, ROLL_IMPACT 8. Bananarang: GravityScale 0.1, `Drop` 0.04.
- Sementes: `SeedChance` por arma em GunsData (0.3 base), rolado por disparo em `GunRules.RollSeed`.

## Preload — implementado
- `Weapon/client/PreloadController` (Priority 990): no OnStart faz `ContentProvider:PreloadAsync` em todas as animações de `PlayerAnimations` + `Assets.Weapons` (prioridade), depois `Assets.VFX`, `Assets.Sounds`, `Assets.Seeds` e ImageIDs das armas. Loga tempo no Output.

## Balística das balas — implementado
- `Weapon/shared/Ballistics`: `BulletSpeed`/`BulletDrop` por arma em GunsData (padrão 1000 / 0.05); `Cast` marcha a parábola em até 16 segmentos.
- Cliente: impacto, som de parede, som de hit e hitmarker esperam o tempo de voo; tracer usa a velocidade da arma; tiros remotos idem.
- Servidor: valida no disparo (rewind no TimeStamp do tiro) e aplica dano/kill após `Distance / BulletSpeed` (`HitService:ApplyHit`).

## Granadas estilo CS — implementado
- Esquerdo = curto (0.5), direito = longo (1.0), os dois = médio (0.75) (`Throwables.THROW_POWERS`). Qualquer botão já puxa o pino; soltar arremessa; soltar um com os dois segurados = médio.
- Sem cancelamento: só trocando de arma. Segurar botão durante o saque arma quando pronto.
- Botão direito em granada não dá zoom (`ArmsController.AimHeld` vs `IsAiming`). Packet `Throw.Mode` (1-3). Bananarang: alcance máximo escala com a força.

## Practice infinito, transição de granada, melee — implementado
- Practice: RoundService entra direto em `Match` e não conta tempo; HUD mostra "Treino"; PracticeService liga InfiniteAmmo/InfiniteGrenades por padrão. Career já ignorava Practice.
- Granada: soltar um dos dois botões só troca o modo; soltar os dois em até `SPLIT_RELEASE_WINDOW` (0.15s) = médio.
- Melee: `Assets.Weapons.Shovel` (rig VFXCARTOON.RIG_ARMAS.shovel) e `Assets.Weapons.Hoe` (mesh Farm Pack, usa AnimationSet Shovel); `HitDelay` 0.25 por arma em GunsData.

## Poses de granada por modo — implementado
- Novos papéis: `PinIdle` (VM_PinOut_Idle), `AimIn` (VM_Aim_In), `AimOut` (VM_Aim_out), `ThrowShort` (VM_Shoot / RIG_Holding_Shoot) para Bananarang, Lemonade, Moolotov, Onionnade, Pinapple.
- Fluxo: Hold > Unpinning > PinIdle (esquerdo) <> AimingIn/AimingOut <> Aim (direito/ambos). Curto = ThrowingShort (release 75%), longo/médio = Throwing (release 35%).
- Médio usa a pose de mira longa até existir animação própria.

## Correções — granada genérica removida, release curto
- Removida `Grenade` (GunsData, Throwables, GetGun, PlayerAnimations). Removido campo sem uso `BulletType`/`AmmoType` (tipo GunData estava estourando "Code is too complex").
- Release só esconde a granada se a pose ainda estiver em Throwing/ThrowingShort; `Hold` e `Drawing` sempre mostram a granada.

## Arma padrão e descarte — implementado
- Loadout padrão: Hoe no slot 3, equipada no spawn e em todo respawn (Practice reaplica as escolhas depois).
- Munição zerada (sem infinito): `Equipment:ScheduleDiscard` remove a arma após `DISCARD_SECONDS` (0.5) e volta para a melee; cliente recebe `Weapon.Discarded` e arremessa uma cópia física da arma (`ArmsController:TossWeapon`).
- Granada sem munição fica escondida (não reaparece no Draw/Hold).
- Papel de animação `Discard` (opcional por AnimationSet) toca quando a munição zera; falta o ID.

## Crosshair configurável — implementado
- Aba CROSSHAIR em Options: seletor de seção (GENERAL / INNER LINES / OUTER LINES) + preview ao vivo. 20 ajustes salvos em `Settings` do perfil (`OptionsCatalog.CrosshairSliders/CrosshairChoices`, Step arredondado no servidor).
- `Weapon/client/Crosshair`: `Crosshair.new(props)` + `Crosshair.Resolve(get)`; linhas internas/externas (comprimento, espessura, offset, opacidade), ponto central, contorno, 6 cores.
- Erro de movimento (spring em IsMoving, 8px) e erro de disparo (bloom: +0.35 por tiro, recupera 2.5/s, 14px) por conjunto de linhas. `HitController.Fired` alimenta o bloom.

## Presets de crosshair e spawn de armas — implementado
- Seção PRESETS na aba CROSSHAIR: DEFAULT, CLASSIC, DOT ONLY, DYNAMIC, TINY, SPRAY, PLUS (`OptionsCatalog.CrosshairPresets`; aplica defaults + overrides). Limite do OptionsService subiu para 60/s.
- `WeaponSpawnService`: em partidas (não Practice) com Combat, mantém até 8 sementes de armas de fogo em partes `WeaponSpawn` (ou `Farmland`), 5 no início e +1 a cada 6s. `GunRules.PlantAt` agora retorna a semente.
- Checklist de publicação em `docs/PublishChecklist.md`.
