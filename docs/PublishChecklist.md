# Checklist de publicação — build de teste

## Antes de publicar (Studio)

1. **Salvar o place** — vários assets foram criados direto no Studio e só existem depois de salvos:
   - `ServerStorage.Maps.Practice` e `ServerStorage.Lighting.Practice`
   - `ReplicatedStorage.Assets.Weapons`: `Shovel`, `Hoe`, `StrawborryArrow`, attachments `Muzzle`
   - `ReplicatedStorage.Assets.Sounds` (31 sons) e `ReplicatedStorage.Assets.VFX`
2. **Rojo conectado e sincronizado** antes do Publish (o código vem do Rojo).
3. **Armas no mapa (FFA/TDM)** — todos nascem só com a Hoe. As armas surgem como sementes pelo `WeaponSpawnService`:
   - Usa partes com a tag `WeaponSpawn`; se não houver, usa as partes com a tag `Farmland` do mapa.
   - Se o mapa não tiver nenhuma das duas, aparece no Output: `[WeaponSpawnService] mapa sem partes ...` e ninguém consegue arma.
   - Ajustes em `src/Weapon/server/WeaponSpawnService.luau`: `MAX_ACTIVE` (8), `SPAWN_INTERVAL` (6s), `INITIAL_BURST` (5).
4. **Admins** — `src/Admin/shared/AdminSettings.luau`. Adicionar o UserId do chefe se ele for usar comandos.
5. Atributos `ForceRole/ForceMode/ForceMap` no `workspace` só valem no Studio; podem ficar.

## Game Settings (site / Studio)

- Security: **Enable Studio Access to API Services** (só para testar DataStore/MemoryStore no Studio).
- O fluxo Router → Lobby privado → Match usa `ReserveServer` + `TeleportAsync` no mesmo place; não precisa de outro place.
- Pelo menos 1 servidor público ativo funciona como Router (manda cada jogador para o lobby dele).

## O que está pronto para testar

- Lobby completo (topbar/bottombar, seleção de modo, carreira, opções, leaderstats, convites de amigos).
- Matchmaking: Quick Play, FFA, TDM, **Practice** (rodada infinita, munição/granadas infinitas, painel na tecla B).
- Armas com balística (tempo de voo + queda leve), VFX/SFX, chance de semente por arma, descarte ao zerar munição.
- Granadas estilo CS (esquerdo curto, direito longo, os dois médio) com animações de pino/arremesso.
- Melee padrão (Hoe) com acerto atrasado 0.25s.
- Crosshair configurável com presets (Options > CROSSHAIR).

## Ainda não implementado (botões existem, sem efeito)

- Salas privadas (Etapa 7), Quests (9), Cosmetics (10), Shop (11) — só fazem `print` no Output.
- Ícones das armas (`ImageID` vazio na maioria) — barra de armas e painel de treino sem imagem.
- Sem modelo: Chilli Thrower, Gromato Launcher, Double Cob (desativada).
- Animações pendentes: melee própria (Hoe usa as da pá), arremesso médio, descarte de arma (`Discard`).
- Granadas não surgem no mapa (só armas de fogo com `SeedModel`).
