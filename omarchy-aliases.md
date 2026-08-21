# Aliases do Omarchy — referência para comparação

Fonte: [`basecamp/omarchy` → `default/bash/aliases`](https://github.com/basecamp/omarchy/blob/master/default/bash/aliases)
Coletado em 2026-08-21. Arquivo de referência — marque o que quiser adotar.

Legenda da coluna **Dep**: ✅ já instalado aqui · ⬜ falta instalar · 📦 não está no apt do trixie

---

## Diretórios

| ? | Alias | Expansão | Dep |
|---|---|---|---|
| [ ] | `..` | `cd ..` | ✅ |
| [ ] | `...` | `cd ../..` | ✅ |
| [ ] | `....` | `cd ../../..` | ✅ |

Puro bash, zero dependência. O de retorno mais imediato da lista inteira.

## Listagem — `eza`

| ? | Alias | Expansão | Dep |
|---|---|---|---|
| [ ] | `ls` | `eza -lh --group-directories-first --icons=auto` | ⬜ `eza` |
| [ ] | `lsa` | `ls -a` | ⬜ `eza` |
| [ ] | `lt` | `eza --tree --level=2 --long --icons --git` | ⬜ `eza` |
| [ ] | `lta` | `lt -a` | ⬜ `eza` |

Note que ele **sobrescreve o `ls`** — sempre em formato longo. É uma mudança de hábito considerável; se incomodar, use `l` em vez de `ls`.
Os `--icons` exigem uma Nerd Font no terminal, senão aparecem quadradinhos.

O bloco original é guardado por `if command -v eza`, então o alias só existe se o binário existir. Vale copiar esse cuidado.

## fzf + bat

| ? | Alias | Expansão | Dep |
|---|---|---|---|
| [ ] | `ff` | `fzf --preview 'bat --style=numbers --color=always {}'` | ⬜ `fzf` `bat` |
| [ ] | `eff` | `$EDITOR "$(ff)"` — busca fuzzy e abre no editor | ⬜ `fzf` `bat` |

No Omarchy há ainda uma variante de `ff` para o terminal kitty que faz preview de **imagem** via `kitty icat`. Como você usa GNOME Console/Alacritty, ignore essa parte.

## Git

| ? | Alias | Expansão | Dep |
|---|---|---|---|
| [ ] | `g` | `git` | ✅ |
| [ ] | `gcm` | `git commit -m` | ✅ |
| [ ] | `gcam` | `git commit -a -m` | ✅ |
| [ ] | `gcad` | `git commit -a --amend` | ✅ |

Conjunto deliberadamente pequeno — DHH não usa os mega-pacotes tipo oh-my-zsh.

## Ferramentas

| ? | Alias | Expansão | Dep |
|---|---|---|---|
| [ ] | `d` | `docker` | ✅ |
| [ ] | `r` | `rails` | ⬜ |
| [ ] | `t` | `tmux attach \|\| tmux new -s Work` | ⬜ `tmux` |
| [ ] | `mup` | `MISE_MINIMUM_RELEASE_AGE=0 mise up` | ✅ `mise` |
| [ ] | `c` | `opencode` | 📦 |
| [ ] | `cx` | limpa a tela e roda `claude --permission-mode bypassPermissions` | 📦 |
| [ ] | `cy` | `codex -s danger-full-access -a never` | 📦 |
| [ ] | `ic` / `ix` / `icx` | atalhos `tdl` (ferramenta interna deles) | 📦 |

`mup` existe porque o mise segura releases muito novas por padrão; a env var zera essa espera e força a atualização.
`cx` e `cy` desligam as confirmações dos agentes de IA — conveniente, mas é exatamente a proteção que evita que um agente rode algo destrutivo sem perguntar. Adote com consciência.

## Funções (estão no mesmo arquivo)

| ? | Nome | O que faz | Dep |
|---|---|---|---|
| [ ] | `zd` | wrapper de `cd` com `zoxide`: caminho normal se a pasta existe, senão salta pelo histórico. Fica como `alias cd=zd` | ⬜ `zoxide` |
| [ ] | `n` | `nvim .` sem argumento, `nvim "$@"` com argumento | ⬜ `neovim` |
| [ ] | `open` | `xdg-open "$@"` em background, sem poluir o terminal | ✅ |
| [ ] | `sff` | escolhe um arquivo por fuzzy (mais recentes primeiro) e manda por `scp` | ⬜ `fzf` |

O `zd` é o mais transformador da lista e o de maior risco: ele **substitui o `cd`**. Se um script seu depender de comportamento exato de `cd`, teste antes.

---

## O que você já tem hoje

Do seu `~/.bash_aliases`:

```bash
alias dcu="docker compose up"      # o Omarchy não tem equivalente — só d='docker'
alias dcd="docker compose down"
alias dce="docker compose exec"
alias dcr="docker compose run"
alias lanip="hostname -I | awk '{print $1}'"
alias tt='kgx --tab --working-directory=$PWD'
```

Não há conflito de nome com nada do Omarchy. Seus `dc*` são mais específicos que o `d` genérico deles — dá pra ter os dois.

Atenção a uma divergência: o `3_docker.sh` do repo instala esses aliases com `sudo docker compose`, enquanto o que está na sua máquina não tem `sudo` (você está no grupo `docker`). O script está desatualizado em relação ao seu shell real.

## Instalando as dependências no Debian 13

Quase tudo está no repositório oficial do trixie:

```bash
sudo apt install -y eza bat fd-find fzf zoxide starship du-dust tealdeer \
                    btop lazygit plocate fastfetch tmux neovim gh
```

Três pegadinhas do Debian:

- **`bat` vira `batcat`** e **`fd` vira `fdfind`** (conflito de nome com outros pacotes). Os aliases do Omarchy chamam `bat` e `fd` direto, então precisam de shims:
  ```bash
  mkdir -p ~/.local/bin
  ln -s /usr/bin/batcat ~/.local/bin/bat
  ln -s /usr/bin/fdfind ~/.local/bin/fd
  ```
- **`tldr` não existe** no trixie; o equivalente é `tealdeer`, que instala o comando `tldr`.
- **`lazydocker` não está no apt** — pegue via release do GitHub ou pelo próprio mise.
