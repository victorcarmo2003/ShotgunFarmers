# Modux — framework

Esta pasta é o framework inteiro e não depende de nada fora dela. A branch
`framework` do repositório tem exatamente este conteúdo na raiz, então dá para
puxá-la direto para dentro de um projeto:

```sh
git clone -b framework https://github.com/victorcarmo2003/ModuxV3 src/Modux
```

O primeiro comando depois do clone é `modux generate`. Sem ele o Manifest ainda
é o do repositório de origem, e o editor reclama de módulo que não existe aqui.

## O que é gerado e o que não é

Quatro arquivos desta pasta são saída do gerador e são reescritos a cada
`modux generate`. Editar é perder na próxima geração.

```
client/Manifest/init.luau    server/Manifest/init.luau
client/Modules.luau          server/Modules.luau
shared/Libs.luau
```

`shared/Libs.luau` sai de uma varredura de `src/Libs` do projeto que consome o
framework — não de nada que esteja aqui dentro. Projeto sem `src/Libs` gera
`Api = {}` e `self.Libs` fica vazio, sem quebrar.

Todo o resto é invariante: `shared/Classes`, `shared/ComponentManager`,
`shared/Core.luau`, `shared/Loader.luau`, `shared/Types` (Pick e SelfOf),
`client/init.luau`, `server/init.luau` e os dois `Types.luau` de lado.

Os dois `Bootstrap` são a exceção: são teus. Ficam aqui porque precisam de um
ponto de partida, e é neles que `Modux.Configure`/`Modux.Start` recebem as
settings.

## Atualizando

Do lado do repositório, cada mudança em `src/Modux` volta para a branch com:

```sh
git subtree split --prefix=src/Modux -b framework
git push -f origin framework
```

Do lado do projeto que consome, é um `git pull` dentro de `src/Modux`.
