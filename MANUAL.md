# MANUAL - mri_Qfarm

## Objetivo do recurso

O `mri_Qfarm` organiza **rotas de coleta**, não fazendas no sentido literal. O administrador define uma rota com um ou mais itens, pontos de coleta, regras de acesso e opções de recompensa. O jogador entra na área configurada e coleta os itens conforme o modo da rota.

## Fluxo real de uso

### 1. Carregamento

- O servidor lê as rotas do banco na tabela `mri_qfarm` ao iniciar o resource.
- As rotas são publicadas em `GlobalState.Farms`.
- O cliente recarrega as rotas quando recebe `mri_Qfarm:client:LoadFarms`.

### 2. Gerenciamento administrativo

- O menu administrativo abre com `/managefarms`.
- Se `mri_Qbox` estiver ativo, o menu pode ser acessado pela integração do próprio Qbox.
- O administrador pode criar, editar, duplicar, importar, exportar, salvar e excluir rotas.

### 3. Execução pelo jogador

- O jogador precisa estar dentro da área configurada da rota.
- O recurso verifica job, gangue, grade, veículo, item obrigatório e durabilidade do item de coleta.
- Se a rota exigir veículo, o jogador precisa estar dentro de um veículo; se a exigência estiver desligada, precisa estar a pé.
- Se a rota tiver um veículo configurado, o jogador a pé precisa ter saído mais recentemente desse modelo para coletar.
- Os modos AFK, rota com pontos e sem início explícito usam a mesma validação compartilhada no cliente.
- A coleta usa `ox_target`, zona ou marker, dependendo de `Config.Interaction`.
- A coleta entrega itens, pode aplicar stress, gastar durabilidade e disparar alerta policial.

## Configurações importantes

Arquivo: [shared/config.lua](shared/config.lua)

| Opção | Efeito |
|-------|--------|
| `PermissionNeeded` | Permissão ACE usada no menu administrativo. |
| `Interaction` | Define se a interação será `target`, `marker` ou `zone`. |
| `ShowMarker` | Exibe ou oculta marcadores. |
| `ShowBlips` | Exibe ou oculta blips. |
| `ShowOSD` | Exibe texto de orientação na tela. |
| `UseEmoteMenu` | Usa comando de emote ou animação nativa. |
| `Debug` | Mostra logs de debug. |

## Veículo obrigatório

Algumas rotas podem exigir um veículo específico.

- O campo fica no nível da rota, não do item.
- O valor deve ser o nome do modelo do veículo, como usado no `GetHashKey`.
- Se o campo estiver vazio, a rota continua sendo coletada apenas fora de veículos.

## Estrutura de uma rota

Uma rota contém, em linhas gerais:

- `name`: nome exibido no menu.
- `config.start.location`: ponto inicial da rota.
- `config.items`: itens coletáveis da rota.
- `config.policeAlert`: alerta policial global da rota.
- `group.name` e `group.grade`: restrição por job ou gangue.

Cada item da rota pode ter:

- `min` e `max`: quantidade entregue.
- `collectTime`: tempo de coleta.
- `collectItem`: item exigido e sua durabilidade.
- `gainStress`: ganho de stress.
- `points`: pontos de coleta.
- `randomRoute`: ordem aleatória dos pontos.
- `unlimited`: rota infinita.
- `animation`: animação usada na coleta.
- `extraItems`: itens extras opcionais.
- `policeAlert`: alerta policial específico do item.

## Comportamento por modo

### Rota com pontos

- O jogador coleta em sequência ou em ordem aleatória, dependendo da configuração.
- O sistema cria a interação no ponto atual e avança para o próximo após a coleta.
- Se `unlimited` estiver desativado, a rota termina ao atingir o último ponto.

### AFK

- O jogador coleta no mesmo local, com progressão contínua.
- O fluxo é mantido enquanto a ação estiver ativa.

### Sem início explícito

- A rota pode operar sem exigir uma etapa manual de início, desde que a configuração da rota suporte isso.

## Alertas policiais

- O alerta pode ser ativado globalmente na rota ou individualmente por item.
- A chance é avaliada no momento da coleta.
- Quando acionado, o sistema notifica policiais em serviço por evento client-side.
- O tipo de alerta é configurável e aceita: `drugsell`, `susactivity`, `houserobbery` e `storerobbery`.

## Eventos e callbacks relevantes

### Cliente

- `mri_Qfarm:client:LoadFarms` recarrega as rotas.
- `mri_Qfarm:client:PoliceAlert` recebe o alerta policial.

### Servidor

- `mri_Qfarm:server:getRewardItem` entrega o item coletado.
- `mri_Qfarm:server:SaveFarm` cria ou atualiza a rota.
- `mri_Qfarm:server:DeleteFarm` remove a rota.
- `mri_Qfarm:server:DuplicateFarm` duplica a rota.
- `mri_Qfarm:server:UseItem` reduz a durabilidade do item.
- `mri_Qfarm:server:GainStress` aumenta o stress do jogador.

## Problemas comuns

- A rota não aparece: verifique se ela está salva no banco e se o jogador tem acesso ao grupo permitido.
- O jogador não consegue coletar: verifique se ele está no veículo ou a pé conforme `requireVehicle` e se o último veículo usado confere quando houver `vehicle` configurado.
- O ponto não aparece: confira `Config.Interaction`, `ShowMarker` e `ShowBlips`.
- O alerta policial não dispara: confira a chance configurada e se há policiais on-duty.
- A durabilidade não muda: confirme se o item da rota possui `collectItem.name` e `collectItem.durability`.

## Termos recomendados na documentação

- Use **rota de coleta**.
- Use **ponto de coleta**.
- Use **rota**.
- Evite tratar o recurso como uma fazenda literal, porque isso não descreve bem o comportamento real.
