# Exemplos de Configuração de Farm (mri_Qfarm)

Estes exemplos demonstram o potencial máximo do sistema. Para usar, abra o menu de gerenciamento de farms, clique em **Importar**, dê um nome ao farm e cole o código JSON correspondente abaixo.

---

### 1. Tráfico de Cocaína (Extremo)
Este exemplo demonstra:
- Restrição para organizações específica (Ballas e Vagos).
- Alerta policial configurado como venda de drogas (`drugsell`) com 80% de chance.
- Rota infinita e aleatória.
- Ganho de estresse ao coletar.
- Item extra (`baggy`) coletado junto com o principal.

```json
{
  "config": {
    "items": {
      "coke_pure": {
        "min": 1,
        "max": 2,
        "collectTime": 5000,
        "randomRoute": true,
        "unlimited": true,
        "gainStress": { "min": 2, "max": 5 },
        "extraItems": {
          "empty_baggy": { "min": 1, "max": 1 }
        },
        "animation": {
            "dict": "anim@amb@business@meth@meth_smash_weight_check@",
            "anim": "base",
            "inSpeed": 8.0,
            "outSpeed": -8.0,
            "duration": 5000,
            "flag": 49,
            "rate": 0,
            "x": 0.0,
            "y": 0.0,
            "z": 0.0
        },
        "points": [
          { "x": 198.4, "y": -2356.1, "z": 6.1 },
          { "x": 205.2, "y": -2360.5, "z": 6.1 },
          { "x": 215.8, "y": -2365.1, "z": 6.1 }
        ]
      }
    },
    "policeAlert": {
      "enabled": true,
      "chance": 80,
      "type": "drugsell"
    },
    "start": {
      "location": { "x": 190.1, "y": -2345.5, "z": 6.1 }
    }
  },
  "group": {
    "name": ["ballas", "vagos"],
    "grade": "2"
  }
}
```

---

### 2. Mineração Profissional (Público)
Este exemplo demonstra:
- Acesso público (sem organizações).
- Requisito de ferramenta (`pickaxe`) com perda de durabilidade.
- Múltiplos itens extras com chances variadas.
- Rota sequencial (não aleatória).

```json
{
  "config": {
    "items": {
      "iron_ore": {
        "min": 2,
        "max": 5,
        "collectTime": 8000,
        "randomRoute": false,
        "unlimited": false,
        "collectItem": {
          "name": "pickaxe",
          "durability": 5
        },
        "extraItems": {
          "gold_nugget": { "min": 0, "max": 1 },
          "stone": { "min": 1, "max": 1 }
        },
        "animation": {
            "dict": "amb@world_human_hammering@male@base",
            "anim": "base",
            "inSpeed": 8.0,
            "outSpeed": -8.0,
            "duration": 8000,
            "flag": 49,
            "rate": 0,
            "x": 0.0,
            "y": 0.0,
            "z": 0.0
        },
        "points": [
          { "x": 2950.1, "y": 2795.5, "z": 40.5 },
          { "x": 2960.5, "y": 2805.2, "z": 41.2 },
          { "x": 2970.2, "y": 2815.8, "z": 42.1 }
        ]
      }
    },
    "policeAlert": { "enabled": false },
    "start": {
      "location": { "x": 2940.5, "y": 2785.1, "z": 39.8 }
    }
  },
  "group": { "name": [], "grade": "0" }
}
```

---

### 3. Hacker (AFK + No-Start)
Este exemplo demonstra:
- Modo AFK (coleta contínua no mesmo lugar).
- Início Automático (`nostart`): O player só precisa entrar na zona para o menu aparecer/trabalho começar.
- Alerta por atividade suspeita (`susactivity`).
- Requerimento de item (`laptop`) mas sem perda de durabilidade.

```json
{
  "config": {
    "afk": true,
    "nostart": true,
    "items": {
      "encrypted_data": {
        "min": 1,
        "max": 3,
        "collectTime": 15000,
        "collectItem": {
          "name": "laptop",
          "durability": 0
        },
        "animation": {
            "dict": "amb@prop_human_atm@male@base",
            "anim": "base",
            "inSpeed": 8.0,
            "outSpeed": -8.0,
            "duration": 15000,
            "flag": 49,
            "rate": 0,
            "x": 0.0,
            "y": 0.0,
            "z": 0.0
        }
      }
    },
    "policeAlert": {
      "enabled": true,
      "chance": 15,
      "type": "susactivity"
    },
    "start": {
      "location": { "x": 127.3, "y": -640.8, "z": 44.2 }
    }
  },
  "group": { "name": [], "grade": "0" }
}
```

> [!NOTE]
> Lembre-se de verificar se os nomes dos itens (`coke_pure`, `pickaxe`, `iron_ore`, etc.) existem no seu inventário (`ox_inventory`). Se não existirem, o sistema mostrará um aviso de "Item Inválido".
