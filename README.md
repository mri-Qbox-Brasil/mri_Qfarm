# 🌾 mri_Qfarm

> **Sistema modular de rotas de coleta para Qbox/qbx_core**
> Gerencie rotas de coleta in-game com pontos configuráveis, menus administrativos, itens por ponto, alertas policiais opcionais, durabilidade de ferramenta, ganho de estresse e restrições por job/gangue.

[![FiveM](https://img.shields.io/badge/FiveM-Resource-orange)](https://fivem.net/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![ox_lib](https://img.shields.io/badge/UI-ox_lib-blue)](https://github.com/overextended/ox_lib)
[![ox_inventory](https://img.shields.io/badge/Inventory-ox_inventory-green)](https://github.com/overextended/ox_inventory)

---

## Visão geral

O recurso não implementa uma “fazenda” no sentido literal. O fluxo real é de **rotas de coleta**: o administrador cria uma rota, define um ou mais itens, configura os pontos de coleta e os jogadores interagem com esses pontos conforme as permissões do grupo e o modo configurado.

## O que o recurso faz

- Cria e edita rotas de coleta pelo menu administrativo.
- Salva as rotas no banco em `mri_qfarm`.
- Carrega as rotas automaticamente para todos os jogadores.
- Permite três formas de execução no cliente:
  - rota com pontos sequenciais;
  - coleta AFK no mesmo local;
  - rota sem ponto de início explícito.
- Permite restringir acesso por job, gangue e grade.
- Permite configurar item de coleta, quantidade mínima/máxima, tempo de coleta, animação, item exigido para coletar, durabilidade e itens extras.
- Permite exigir veículo para coletar e, quando houver veículo configurado na rota, também validar o último veículo usado quando o jogador estiver a pé.
- A seleção de veículo no criador usa a lista de veículos cadastrados no `qbx_core`.
- Pode disparar alerta policial global por rota ou específico por item.
- Suporta interação por `ox_target`, zonas ou markers, conforme `Config.Interaction`.

## Dependências

- `qbx_core`
- `ox_lib`
- `ox_inventory`
- `ox_target` se `Config.Interaction = "target"`
- `oxmysql`

## Instalação

1. Coloque o recurso na pasta de resources.
2. Garanta que as dependências estejam iniciadas antes do `mri_Qfarm`.
3. Execute o SQL de [database.sql](database.sql).
4. Adicione `ensure mri_Qfarm` no `server.cfg`.

O recurso cria e carrega a tabela automaticamente ao iniciar, mas o arquivo SQL deve existir no banco antes do uso normal.

## Configuração

Arquivo: [shared/config.lua](shared/config.lua)

```lua
return {
    ImageURL = "https://cfx-nui-ox_inventory/web/images",
    Inventory = "ox_inventory",
    PermissionNeeded = "admin",
    Debug = true,
    Interaction = "target", -- target, marker, zone
    ShowMarker = true,
    ShowBlips = true,
    ShowOSD = true,
    UseEmoteMenu = true,
    IconAnimation = "fade",
    FarmBoxWidth = 1,
    FarmBoxLength = 1,
    FarmBoxHeight = 1,
}
```

Pontos importantes:

- `PermissionNeeded` controla a permissão ACE do menu administrativo.
- `Interaction` define o tipo de interação usado na rota.
- `ShowMarker` e `ShowBlips` controlam a exibição visual dos pontos.
- `UseEmoteMenu` define se a animação usa comando de emote ou animação nativa.

## Como funciona

### Fluxo administrativo

1. O admin abre o menu com `/managefarms`.
2. O menu permite criar, listar, duplicar, importar, exportar, salvar e excluir rotas.
3. Cada rota recebe nome, grupos permitidos, grade mínima e configuração de início.
4. Em cada item/rota, o admin define:
   - item coletado;
   - quantidade mínima e máxima;
   - tempo de coleta;
   - animação;
   - item necessário para coletar;
   - perda de durabilidade desse item;
   - ganho de estresse;
   - chance/tipo de alerta policial;
   - pontos de coleta;
   - itens extras.

### Fluxo do jogador

1. O jogador entra na área da rota.
2. O recurso valida veículo, permissão de job/gangue, item obrigatório e durabilidade.
3. O ponto de coleta é exibido via target, zone ou marker, conforme a configuração.
4. Ao coletar, o sistema aplica progressão, animação, degradação da ferramenta, estresse e recompensa do item.
5. Se a rota ou o item tiver alerta policial ativo, os policiais em serviço são notificados por evento client-side.

## Comando administrativo

| Comando | Permissão | Descrição |
|---------|-----------|-----------|
| `/managefarms` | `group.admin` ou ACE definido em `PermissionNeeded` | Abre o menu de gerenciamento das rotas |

Observação: o comando só é registrado quando `mri_Qbox` não está iniciado, porque nesse caso o acesso ao menu é feito por integração do próprio Qbox.

## Estrutura de dados

As rotas ficam persistidas na tabela `mri_qfarm` com:

- `farmId`
- `farmName`
- `farmConfig`
- `farmGroup`

## Integrações reais do código

- `qbx_core` para jobs, gangs, notificações e dados do jogador.
- `ox_inventory` para itens, durabilidade e checagem de capacidade.
- `qbx_core` para a lista de veículos exibida no criador.
- `ox_target`, `lib.zones` ou markers para interação.
- `ox_lib` para menus, notificações, progress bar, dialogs e callbacks.

## Tipos de rota e opções

- Rota com pontos: sequência de pontos de coleta, com suporte a ordem fixa ou aleatória.
- Rota AFK: coleta no mesmo local, com execução contínua.
- Rota sem início explícito: entrada simplificada sem necessidade de uma área inicial configurada.

Todos esses modos usam a mesma validação compartilhada do cliente para veículo, on-foot e último veículo configurado.

## Eventos e callbacks mais importantes

### Cliente

- `mri_Qfarm:client:LoadFarms` recarrega as rotas após alterações.
- `mri_Qfarm:client:PoliceAlert` recebe o alerta policial.

### Servidor

- `mri_Qfarm:server:getRewardItem` entrega o item da coleta.
- `mri_Qfarm:server:SaveFarm` cria ou atualiza uma rota.
- `mri_Qfarm:server:DeleteFarm` remove uma rota.
- `mri_Qfarm:server:DuplicateFarm` duplica uma rota.
- `mri_Qfarm:server:UseItem` reduz durabilidade do item de coleta.
- `mri_Qfarm:server:GainStress` aplica estresse ao jogador.

## Exemplo de rota

```lua
Config = Config or {}

local farm = {
    name = "Rota de coleta de ervas",
    config = {
        start = {
            location = vec3(123.4, 456.7, 78.9)
        },
        items = {
            weed_leaf = {
                customName = "Coleta de folhas",
                min = 1,
                max = 3,
                collectTime = 7000,
                collectItem = {
                    name = "sickle",
                    durability = 5
                },
                points = {
                    vec3(120.0, 450.0, 78.9),
                    vec3(122.0, 452.0, 78.9)
                },
                randomRoute = false,
                unlimited = false
            }
        },
        policeAlert = {
            enabled = true,
            chance = 30,
            type = "drugsell"
        }
    },
    group = {
        name = {"police"},
        grade = 0
    }
}
```

## Problemas comuns

- A rota não aparece: confira se o jogador pertence ao job/gang permitido e se as rotas foram carregadas do banco.
- O item não é entregue: confira se o inventário tem espaço e se o item existe no `ox_inventory`.
- A ferramenta não perde durabilidade: verifique se a rota definiu `collectItem` com nome e durabilidade.
- O alerta policial não dispara: confira `policeAlert.enabled`, a chance configurada e se há policiais on-duty.
- A coleta não funciona no estado certo: confira se `requireVehicle` está coerente com o fato de o jogador estar dentro de um veículo ou a pé.
- Se a rota tiver `vehicle` configurado, o jogador a pé precisa ter saído do veículo correspondente mais recentemente.

## Observação importante

Se você for documentar o recurso para outros administradores, prefira os termos **rota de coleta**, **ponto de coleta** e **rota** em vez de “fazenda”. Isso reflete melhor o que o script realmente faz.
