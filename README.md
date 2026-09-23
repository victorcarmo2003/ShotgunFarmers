# ModuxTemplate

Ponto de partida para projetos em Roblox com o [Modux V3](https://github.com/victorcarmo2003/ModuxV3):
o framework, a rede já ligada e cinco sistemas base funcionando.

O framework vive em `src/Modux` e é cópia da branch `framework` do repositório do
Modux. Nada do que está aqui é exemplo descartável — é o que roda.

---

## Setup

```sh
rokit install
wally install
wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/
rogen build
modux generate
rojo serve
```

**`wally-package-types` não é opcional.** O shim que o Wally escreve em
`Packages/X.lua` é `return require(_Index[...])`, e `export type` não atravessa
um require assim: os valores resolvem, os tipos não. Sem esse passo,
`Vide.Source` e `Charm.Atom` viram `Unknown type` e o projeto não compila.
Rode de novo depois de cada `wally install`.

`rogen build` vem antes de `modux generate`: o `default.project.json` é gerado a
partir das pastas, e fora de ordem o gerador resolve caminho por um arquivo
velho.

---

## Estrutura

O rogen é feature-based, e o Modux já carrega a espécie na declaração
(`Modux.Service(...)`). Uma pasta `Services/` repetiria o que o arquivo já diz;
a pasta guarda a **feature**, e cada uma traz o seu `server/` e `client/`:

```
src/Net/       server/NetService        client/NetController
src/Player/    server/PlayerService
src/Profile/   server/ProfileService    client/ProfileController
src/Vital/     server/VitalService      client/VitalController
               server/Vital  (componente)
src/Round/     server/RoundService      client/RoundController
src/Input/                              client/InputController
src/Interface/                          client/ (componentes Vide e stories)

src/Modux/     framework (gerado + invariante, ver src/Modux/README.md)
src/Shared/    Types utilitarios (Occlude, Struct, Union) e tablejs
src/Libs/      injetadas em self.Libs: Signal, Promise, FSM, Charm, Net
```

O caminho vira o lugar no DataModel: `src/Vital/server/` chega como
`ServerScriptService.server.Vital`. Feature nova é uma pasta nova, com as duas
metades juntas — e apagar a feature é apagar a pasta.

Um módulo é uma pasta com `init.luau`, nunca um arquivo solto: o gerador escreve
o `Type.luau` ao lado do módulo, e dois módulos na mesma pasta colidiriam nesse
nome.

---

## Rede

As definições ficam em `src/Libs/Net/init.luau`, um `Lync.define` só, requerido
pelos dois lados. Adicionar tráfego é adicionar uma entrada ali.

```lua
Vitals = Lync.replicate(Lync.struct({
	Health = Lync.int(0, 100),
	Armor = Lync.int(0, 100),
	Stamina = Lync.int(0, 100),
})),
```

Do lado do código, `self.Libs.Net.Vitals:update(...)` já vem tipado pelo schema.

**O schema é validado em runtime, dentro de `Lync.start()`.** `analyze.ps1`
passando não diz nada sobre ele: um `keyBy` inválido compila e só estoura no
Studio, levando junto tudo que depende do start.

### Set ou packet

| | |
|---|---|
| **set** (`replicate`) | estado que vários clientes veem. Manda só o campo que mudou, junta escritas do mesmo flush, e **entrega o estado atual a quem chega depois**. |
| **packet** (`packet`) | evento, ou dado privado de um jogador só. Não guarda nada: se ninguém estava escutando, se perde. |

`keyBy` particiona a audiência e aceita **só campo finito** — `bool`, `int`,
`quant`, `angle` ou `enum`. Não serve para "cada um vê o seu": um `str` com o
UserId é recusado no start, e um `int` com o range de UserId seria uma grade
absurda. Set é para time, sala, região.

Por isso `Vitals` é set (todos veem) e `Profile` é packet direcionado
(`fireClient(player, ...)`), privado por construção — não por uma alocação de
chave que um bug poderia errar.

### Para quem o servidor manda

`Lync.all` inclui cliente que ainda não completou o handshake interno do Lync,
e o frame enviado a ele é descartado com um aviso:

```
a frame arrived before this client was told it could send one
```

Por isso o `NetService` mantém um `Lync.group()` alimentado pelo `Ready`, e o
`GameService` transmite para esse grupo. Quem mandou `Ready` necessariamente
completou o handshake do transporte — senão o pacote não teria chegado —, então
o handshake da aplicação implica o do Lync de graça.

Na volta, `BindToClose` desarma antes de `Lync.close()`, e quem transmite
checa `NetService:IsRunning()`. Sem isso o servidor erra no desligamento: os
ticks correm mais um frame, mexem no estado, e o `effect` tenta disparar num
Lync que ja soltou os remotes.

### Um aviso que nao e teu, e como calamos ele

Todo cliente que entra produzia uma vez:

```
a frame arrived before this client was told it could send one
```

E uma corrida dentro do Lync. O servidor responde o handshake e semeia o
backlog dos sets no mesmo instante, por remotes diferentes, e o Roblox nao
garante ordem entre remotes — se o dado chega primeiro, o cliente ainda tem
`link.sending = false` e descarta o frame. O Lync se recupera sozinho: ao
admitir o cliente ele reenvia os records. Custo real: um frame descartado por
join, e `Log.warn`, nunca `Log.error` — nada quebra.

`src/Net/Log.luau` desconecta o `Lync.console` e instala um listener que deixa
passar tudo menos `drop.unready`. E a saida que a propria lib documenta: *a
caller who formats records themselves disconnects it and attaches their own*.

Silenciar **so esse codigo** e o ponto. `link.sending` e escrito uma unica vez
na vida de uma sessao (`= true`, nunca volta), entao `drop.unready` so pode
acontecer na janela de handshake — depois dela e impossivel por construcao, e
nao ha estado acionavel se escondendo.

Os vizinhos dele ficam audiveis de proposito. `drop.mismatch` significa
servidor e cliente com schemas diferentes, `drop.validate` e uma mensagem
recusada, `drop.bounds` e frame corrompido. Para acrescentar um codigo a lista,
edite `SILENCED` — e pense duas vezes.

### O handshake Ready

Como packet não guarda estado, o servidor não pode replicar o perfil quando
quiser: o cliente demora **segundos** a mais para bootar, e o pacote enviado
antes disso simplesmente some.

`NetController` dispara `Ready` no `OnStart`; `NetService` escuta e expõe o
signal `ClientReady` mais o `IsReady(player)`. `ProfileService:Replicate`
verifica `IsReady` e desiste se o cliente ainda não chegou, e replica de novo
quando o `ClientReady` chega. Os dois caminhos existem porque a ordem entre
"perfil carregou" e "cliente pronto" não é garantida.

Set não precisa disso: quem chega depois recebe o estado atual num `onAdded`.

### start, flush e close

`NetService` e `NetController` existem só para isso, e o lugar deles no ciclo de
vida não é arbitrário:

| | |
|---|---|
| `Priority = 1000` | roda o **primeiro** `OnStart`, quando todos os `OnInit` já registraram seus responders e antes de qualquer módulo disparar |
| `OnTick(..., 60, -1000)` | roda o **último** tick do frame, depois de todo mundo ter escrito |

Isso decorre de como o Loader funciona: ele completa todos os `OnInit` antes de
começar os `OnStart`, e ordena as duas fases por prioridade decrescente.

Daí saem duas regras:

- **Responder de rede só em Service ou Controller, dentro de `OnInit`.**
  `Lync.start()` tranca as definições, e registrar depois disso lança.
- **Componente não registra responder.** Componente tagueado sobe depois do
  `start`, e um responder é único por definição — um por instância seria errado
  de qualquer forma. Componente dispara e lê à vontade.
- **Varredura de quem já está no servidor vai no `OnStart`, não no `OnInit`.**
  `PlayerService` faz isso: varrendo no `OnInit`, os serviços de prioridade
  menor ainda não tinham conectado seus handlers e perderiam quem já estava lá,
  e o `Vitals:add` do componente rodaria antes do `Lync.start()`.

---

## O que vem pronto

| | |
|---|---|
| `PlayerService` | entrada e saída de jogador e de personagem em Signals, tratando quem já estava no servidor |
| `ProfileService` | ProfileStore + campos reativos: `profile.Coins(100)` escreve, `profile.Coins()` lê |
| `VitalService` + `Vital` | Health/Armor/Stamina por jogador, dano com absorção por armadura, regen de stamina a 4 Hz, morte e respawn |
| `InputController` | `ContextActionService` com contexto (Gameplay/Menu), binds desktop e mobile |
| `RoundService` | ciclo de rodada em `atom` do Charm, com `batch` e `effect` replicando |
| `Counter` | componente Vide com story do UI Labs, para provar o caminho de UI |

O throttle manual de replicação que a versão anterior deste template carregava
não existe mais: um set do Lync manda só o campo que mudou, junta escritas
dentro do mesmo flush e tem orçamento por cliente.

---

## Estado reativo

### O perfil é reativo

`Get` devolve um campo por atom, não uma tabela plana:

```lua
const profile = self.Dependencies.ProfileService:Get(player)
profile.Coins(100)                     -- escreve
print(profile.Coins())                 -- le, tipado como number
profile.Level(profile.Level() + 1)
```

Escrever num campo persiste e replica sozinho: um `effect` por jogador lê todos
os atoms, copia para `session.Data` (que é o que o ProfileStore salva) e dispara
a replicação. Não existe "lembrar de salvar".

O tipo é **derivado do Template**, não escrito à mão. `Atomic.Table<Data>` em
`src/Shared/Types/Atomic.luau` mapeia cada campo `K: V` para
`K: (() -> V) & ((V) -> V)`. Campo novo em `Template.luau` vira atom tipado sem
tocar em mais nada — e `profile.Coins("texto")` não compila.

Para mexer em vários campos de uma vez, `Update(player, patch)` envolve tudo num
`batch`, senão cada escrita dispara o effect e manda um pacote.

### Charm no servidor, Vide no client

**Charm no servidor, Vide no client.** São dois sistemas de reatividade que não
se enxergam: um `atom` mudando não re-renderiza Vide. Não há ponte aqui, e é
proposital — o client recebe do Lync e escreve em `source`.

```lua
-- server
self.Status = self.Libs.Charm.atom("Waiting") :: Charm.Atom<Status>

-- client
self.Health = Vide.source(100) :: Vide.Source<number>
```

Para usar Charm no client também, nada precisa mudar: ele já está em
`self.Libs` dos dois lados.

---

## A armadilha do `self.Libs`

Toda pasta em `src/Libs` entra em `self.Libs` automaticamente, com o tipo saindo
de `typeof(require(...))`. Mas **nem toda lib pode entrar**.

Lync e Vide estão fora de propósito. O tipo dos dois contém type function que
não reduz — `Codec<T>` no Lync, `index<Instances, Name>` no `Vide.create` — e
uma dessas dentro dos extras impede o `SelfOf.Build` de reduzir. O resultado é
brutal e enganoso:

```
Cannot add property 'Setup' to table 'setmetatable<Build<Public, {...}>, ...>'
```

Esse erro aparece em **todos** os módulos do projeto, em métodos que não têm
nada de errado, e nunca menciona a lib que o causou. Uma lib ruim derruba a
tipagem inteira.

Por isso os dois são requeridos direto onde se usa:

```lua
local Lync = require(ReplicatedStorage.Packages.Lync)
local Vide = require(ReplicatedStorage.Packages.Vide)
```

`src/Libs/Net` continua em `self.Libs` e funciona: `Lync.define(...)` devolve as
definições com os tipos já aplicados a codecs concretos, então nada fica
pendente.

O que está fora é o **módulo inteiro**, não cada tipo dele. `Lync.Group` e
`Lync.Recipient` são tipos simples e atravessam o `Build` sem problema — o
`NetService` guarda um `Lync.Group` e o `GameService` recebe um
`Lync.Recipient`, os dois no Manifest, com o projeto em zero erro. O que não
passa é `Codec<T>`, `Packet<T>` e companhia.

**Se depois de adicionar uma lib o projeto inteiro passar a acusar
`Cannot add property`, o suspeito é a lib que você acabou de adicionar.** Tire
de `src/Libs`, requeira direto, e rode `tools/analyze.ps1` de novo.

---

## Verificando

```sh
modux check          # falha se algo esta desatualizado (CI)
tools/analyze.ps1    # roda o motor do editor sobre o projeto inteiro
```

`analyze.ps1` passando não prova que os tipos existem — prova que nada errou.
Para saber se o `self` está mesmo tipado, escreva um acesso que **deveria**
falhar (`self.Dependencies.ServicoQueNaoDeclarei`) e confirme que ele falha.

### `LuauSolverV2` é obrigatório

Sem a flag não existe type function, `self` fica sem tipo e o autocomplete
devolve zero item — sem erro e sem aviso. O `.vscode/settings.json` já liga.

---

## Atualizando o framework

```sh
git clone -b framework https://github.com/victorcarmo2003/ModuxV3 /tmp/modux
```

E copie por cima de `src/Modux`, menos os quatro arquivos gerados
(`*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`), que o
`modux generate` reescreve. Os dois `Bootstrap` são seus.
