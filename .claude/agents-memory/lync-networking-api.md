# Lync v2.3.3 — Networking API Reference

## Core API

### Lifecycle
- `Lync.start()` — Inicializa transport (server ou client auto-detectado)
- `Lync.configure(options)` — Antes do start. Options: `channelMaxSize`, `validationDepth`, `poolSize`, `bandwidthLimit`, `globalRateLimit`, `stats`
- `Lync.flushRate(hz)` — Frequência de flush (1-60, default 60)
- `Lync.flush()` — Flush manual dos pacotes pendentes
- `Lync.isStarted()` — Boolean
- `Lync.reset()` — Restaura estado (testing/hot-reload)

### Packet
```luau
Lync.packet<T>(name: string, codec: Codec<T>, options?: PacketOptions): Packet<T>
```

**PacketOptions:**
- `unreliable: boolean?` — UDP-like, sem resend
- `timestamp: ("frame" | "offset" | "full")?` — Modo de timestamp
- `rateLimit: RateLimitConfig?`
- `validate: ValidateFn?` — `(data, player) -> (bool, string?)`
- `maxPayloadBytes: number?`

**Métodos do Packet:**
- `packet:send(data, target?)` — Server: target obrigatório (Player | {Player} | Lync.all | Lync.except(...))
- `packet:on(fn: (data, sender?, timestamp?) -> ())` — Listener, retorna Connection com :disconnect()
- `packet:once(fn)` — Auto-disconnect após primeiro fire
- `packet:wait()` — Yield até próximo pacote, retorna (data, sender?, timestamp?)
- `packet:name()` — Nome do pacote
- `packet:stats()` — { bytesSent, bytesReceived, fires, recvFires, drops }

### Query (Request-Response)
```luau
Lync.query<Req, Resp>(name, requestCodec, responseCodec, options?: QueryOptions): Query<Req, Resp>
```
- `query:handle(fn: (request, player?) -> Resp?)` — Registra handler server-side
- `query:request(data, target?) -> Resp?` — Envia request, yield até response ou timeout
- Options: `timeout: number?` (default 5s), `rateLimit`, `validate`

### Targeting
- `Lync.all` — Broadcast para todos
- `Lync.except(...: Player | Group)` — Todos exceto especificados
- `Lync.group(name): Group` — Grupo de players com :add(), :remove(), :has(), :count(), :destroy()

### Middleware
- `Lync.onSend(fn: (data, packetName, player) -> data?)` — Modifica/dropa outbound
- `Lync.onReceive(fn: (data, packetName, player) -> data?)` — Modifica inbound
- `Lync.onDrop(fn: (reason, packetName, value, player) -> ())` — Log de drops

## Timestamps — Detalhes

### `"frame"` — 1 byte
- Counter incremental 0-255, wraps
- Atualiza por flush (não por pacote)
- Uso: detectar pacotes duplicados/dropados em sequência

### `"offset"` — 2 bytes
- Milissegundos dentro de janela de 65.535s
- `round((os.clock() % 65.535) * 1000)`
- Uso: medição de latência sub-segundo

### `"full"` — 8 bytes
- `os.clock()` completo (f64, seconds desde game start)
- Precisão de microsegundos
- Uso: timing absoluto, cálculo de latência

**Importante:** Todos os modos atualizam no flush, não por pacote individual. 10 pacotes no mesmo frame = mesmo timestamp.

## Reliable vs Unreliable

**Reliable (default):** RemoteEvent, XOR delta compression, dedup cross-player
**Unreliable:** BindableEvent, sem delta, encode separado por player
- **NÃO** pode usar delta codecs com unreliable (desync se pacote dropar)

## Codecs disponíveis
- **Primitivos:** int, zint, bool, f16, f32, f64, string
- **Datatypes:** vec2, vec3, vec3int16, cframe, color3, udim, udim2, rect, ray, region3, inst, buff
- **Compostos:** struct, array, map, tuple, optional, tagged, enum, bitfield
- **Delta:** deltaInt, deltaFloat, deltaVec3, deltaCFrame, deltaStruct, deltaArray, deltaMap

## Stats
- `Lync.stats.player(player): PlayerStats?` — { bytesSent, bytesReceived }
- `Lync.stats.reset()` — Zera contadores
- `Lync.debug.registrations()` — Lista pacotes/queries registrados
- `Lync.debug.pending()` — Queries em aberto

## Uso atual no projeto (Network/init.luau)
```luau
PlayerSnapshot = Network.packet("PlayerSnapshot", Network.struct({
    Position = Network.vec3int16,
    LookAt = Network.vec3int16,
}), {unreliable = true})
```
Sem timestamp configurado atualmente.
