# mri_Qfarm - Advanced Farming System

O `mri_Qfarm` é um sistema de farm modular e altamente configurável para FiveM, focado em facilidade de uso via interface gráfica (NUI) e profundidade de recursos para administradores e desenvolvedores.

## 🚀 Funcionalidades Principais

- **Criador In-Game (GUI)**: Gerencie todos os seus farms diretamente no jogo com o comando `/managefarms`.
- **Múltiplos Modos de Operação**:
    - **Rotas (Route)**: O jogador segue uma sequência de pontos (ordenada ou aleatória).
    - **AFK**: O jogador coleta continuamente em um local fixo.
    - **Início Automático (No-Start)**: O farm é ativado assim que o jogador entra na zona, sem necessidade de interação manual para iniciar o turno.
- **Sistema de Alerta Policial**:
    - Chance configurável por farm ou por item.
    - Tipos de alerta variados (`drugsell`, `susactivity`, `houserobbery`, `storerobbery`).
- **Itens Extra**: Possibilidade de configurar itens secundários que podem ser ganhos durante a coleta.
- **Requisitos de Itens e Ferramentas**:
    - Exija que o jogador porte um item para coletar.
    - Suporte a **perda de durabilidade** de ferramentas (ex: picareta).
- **Restrição por Organização/Gangue**:
    - Limite o acesso a cargos específicos (Jobs ou Gangs).
    - Defina um grau (grade) mínimo para acesso.
- **Locales Dinâmicos**: Suporte total a JSON aninhado para traduções organizadas.
- **Importação/Exportação**: Clone farms entre servidores ou compartilhe configurações facilmente via JSON.
- **Integração Nativa**: Otimizado para `qbx_core`, `ox_inventory`, `ox_lib` e `ox_target`.

## 📋 Requisitos

- [qbx_core](https://github.com/Qbox-Project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)

## 🔧 Instalação

1.  Certifique-se de ter todos os requisitos instalados e iniciados.
2.  Clone ou baixe este repositório para sua pasta `resources`.
3.  Adicione `ensure mri_Qfarm` ao seu `server.cfg`.
4.  Reinicie seu servidor.

## ⚙️ Configuração Central (`shared/config.lua`)

```lua
return {
    ImageURL = "https://cfx-nui-ox_inventory/web/images", -- URL base para imagens do inventário
    Inventory = "ox_inventory",
    PermissionNeeded = "admin", -- Permissão ACE necessária para abrir o menu
    Debug = false,
    Interaction = "target", -- Opções: target, marker, zone
    ShowMarker = true,      -- Exibir marcadores visuais nos pontos
    ShowBlips = true,       -- Exibir blips no mapa
    ShowOSD = true,         -- Exibir informações na tela durante o farm
    UseEmoteMenu = true,    -- Usar comandos de animação (e c, e anim) em vez de animDict direto
}
```

## 🎮 Como Usar (Administrador)

### Criando um Farm do Zero

1.  Acesse o Menu pelo F10 ou use o comando `/managefarms` no chat (requer permissões de admin).
2.  Clique em **Criar Farm** e dê um nome.
3.  **Configurações do Farm**:
    - Defina se é um farm AFK ou No-Start.
    - Configure as Organizações que podem acessar (deixe vazio para público).
    - Configure o Alerta Policial Global para este farm.
    - Defina a localização de início (entrada do trabalho).
4.  **Adicionando Itens**:
    - Vá em **Rotas de Farm** -> **Adicionar Item**.
    - Escolha o item principal da rota.
    - Configure tempo de coleta, animação e requisitos de ferramenta.
    - Clique em **Gerenciar Pontos** para adicionar as coordenadas no mapa (basta ficar no local e clicar em Adicionar Ponto).
5.  **Salvar**: Lembre-se de clicar em **Salvar** para gravar as alterações no banco de dados.

### Importando Exemplos

Você pode importar modelos prontos para agilizar o processo. Veja os modelos disponíveis no arquivo [example_farms.md](file:///C:/Users/ggfto/.gemini/antigravity/brain/d5fb0613-68fb-4af9-8f1e-7573d4efc060/example_farms.md).

## 🌍 Tradução (Locales)

Este script suporta JSON aninhado para melhor organização. Os arquivos estão localizados em `locales/`.

- Para adicionar um novo idioma, crie um arquivo `.json` com o código do idioma (ex: `es.json`) seguindo a estrutura do `pt-br.json`.

## 🛠️ Suporte e Créditos

Desenvolvido por **MRI Qbox Brasil**.
Este recurso é parte do ecossistema de scripts avançados da MRI.

---

> [!TIP]
> Use o modo `NextTask` com `randomRoute = true` para evitar que jogadores usem macros decorando a ordem dos pontos.
