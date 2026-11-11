# Conectando o repo ao Roblox Studio com Rojo

O [Rojo](https://rojo.space) sincroniza os arquivos `.luau` deste repo com o
Roblox Studio em tempo real. Você edita no VS Code/Cursor, salva, e o código
aparece no Studio na hora.

## O que já está configurado

| Arquivo | Para que serve |
|---|---|
| `rokit.toml` | Fixa a versão do Rojo (7.6.1) para todo mundo usar a mesma |
| `default.project.json` | Place do **Game** (o que você usa no dia a dia) |
| `lobby.project.json` | Place do **Lobby** (start place em produção) |
| `.vscode/extensions.json` | Sugere as extensões Rojo e Luau LSP no VS Code/Cursor |

Como as pastas viram serviços no Studio:

```
src/ReplicatedStorage/Shared             → ReplicatedStorage.Shared
src/ServerScriptService                  → ServerScriptService
src/StarterPlayer/StarterPlayerScripts   → StarterPlayer.StarterPlayerScripts
```

Sufixos importam: `*.server.luau` vira `Script`, `*.client.luau` vira
`LocalScript`, e `*.luau` sem sufixo vira `ModuleScript`.

## Instalação (uma vez só)

1. **Rokit** (gerenciador de ferramentas):
   - macOS/Linux: `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
   - Windows (PowerShell): `Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression`
   - Feche e abra o terminal depois.
2. **Rojo** (na pasta do repo):
   ```sh
   rokit install
   rojo --version   # deve mostrar 7.6.1
   ```
3. **Plugin do Rojo no Studio** (escolha um jeito):
   - Pelo terminal, com o Studio fechado: `rojo plugin install`
   - Ou pela [página do plugin](https://create.roblox.com/store/asset/13916111004/Rojo-7)
     → *Get* → no Studio, aba **Plugins** → **Manage Plugins**.

   Use a mesma versão maior (7.x) no plugin e no CLI, senão a conexão recusa.

## Uso diário

1. Na pasta do repo:
   ```sh
   rojo serve                       # Game
   # ou
   rojo serve lobby.project.json    # Lobby
   ```
   Deixe esse terminal aberto. Ele mostra `Rojo server listening on port 34872`.
2. No Roblox Studio, abra um **Baseplate** vazio (ou o seu place do Game).
3. Aba **Plugins** → **Rojo** → **Connect** (endereço `localhost`, porta `34872`).
4. Confirme a sincronização. Os scripts aparecem nos serviços acima.
5. Edite os arquivos no editor e salve. O Studio atualiza sozinho.
6. Aperte **Play** para testar.

> ⚠️ O Rojo é a fonte da verdade para as pastas sincronizadas. Scripts criados
> direto no Studio dentro de `ServerScriptService`, `StarterPlayerScripts` ou
> `ReplicatedStorage.Shared` são **apagados** na próxima sincronização. Crie
> sempre os arquivos em `src/`. O `Workspace` não é gerenciado (mapas, modelos
> e terreno feitos no Studio ficam intactos), e salve o place no Studio
> normalmente para guardar o mapa.

## Gerar um arquivo de place sem o Studio aberto

```sh
rojo build -o MowIt.rbxl                    # Game
rojo build lobby.project.json -o Lobby.rbxl # Lobby
```

Arquivos `.rbxl` ficam fora do git (estão no `.gitignore`).

## Autocomplete no editor (opcional)

Com a extensão **Luau LSP** instalada, rode:

```sh
rojo sourcemap --watch -o sourcemap.json
```

Isso faz o `require(Shared.Config.Tools)` ter autocomplete e checagem de tipos.

## Problemas comuns

| Sintoma | Solução |
|---|---|
| `rojo: command not found` | Reabra o terminal depois de instalar o Rokit e rode `rokit install` de novo |
| Plugin não conecta | Confira se o `rojo serve` está rodando e se a porta é `34872`. Na primeira conexão o Studio pede permissão de rede para o plugin: aceite |
| "Version mismatch" | Atualize o plugin para a mesma versão maior do CLI (7.x) |
| Script sumiu do Studio | Ele foi criado no Studio, não em `src/`. Recrie como arquivo |
