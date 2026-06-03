# Idle Monster March

Jogo *idle / clicker / auto-battler* em **Godot 4.6** (renderizador GL Compatibility, alvo PC / Mobile / Web, orientacao retrato).

Este repositorio contem o **esqueleto de arquitetura** (v1 de codigo). Ele ainda nao tem gameplay visual — a meta desta etapa e a fundacao tecnica que sustenta o resto: conteudo data-driven, um nucleo de combate **calculavel** (que viabiliza o progresso offline), o pipeline de atributos e o sistema de save.

As regras de design seguem o documento **"GDD v2 — Refinamento & Especificacao Tecnica"**.

## Como rodar

1. Abra a pasta do projeto no **Godot 4.6**.
2. Rode o projeto (F5). A cena `scenes/main.tscn` carrega o save (ou cria um estado de demonstracao) e imprime um relatorio no painel **Output**, alem de mostrar um resumo na tela.

> Os scripts foram escritos e revisados com cuidado, mas ainda nao foram executados dentro do editor — ao abrir no Godot, confira o painel Output por eventuais avisos.

## Estrutura

```
data/                  Conteudo editavel (JSON) — fonte da verdade do jogo
  monsters.json          fichas dos monstros
  enemies.json           tipos de inimigo
  talents.json           talentos roguelike
scripts/
  core/                Logica pura, sem estado
    game_enums.gd        valores validos (elementos, raridades, papeis, tipos)
    formulas.gd          TODA a matematica do GDD v2 (XP, fases, DEF, prestigio, pipeline de stats)
    numbers.gd           formatacao de numeros grandes (K, M, B, aa...)
    battle_simulator.gd  modelo calculavel de combate/economia (base do offline)
  data/                Classes de dados
    monster_data.gd      ficha (imutavel) do monstro
    enemy_data.gd        ficha do inimigo
    talent_data.gd       ficha do talento
    monster_instance.gd  estado de jogo do monstro (nivel/estrelas/xp) + stats finais
  autoload/            Singletons (registrados no project.godot)
    content_db.gd        ContentDB  - carrega os JSON no startup
    game_state.gd        GameState  - estado central + serializacao
    save_manager.gd      SaveManager - save/load + ganhos offline (cap 12h)
  main.gd              bootstrap de demonstracao
scenes/
  main.tscn            cena inicial
```

## Principios de arquitetura

- **Data-driven:** monstros, inimigos e talentos sao JSON. Adicionar conteudo = editar um arquivo, sem mexer em codigo. (Pode-se migrar para Resources `.tres` depois, se quiser integracao com o editor.)
- **Combate calculavel:** `BattleSimulator` calcula DPS, tempo-de-abate e ouro/segundo por matematica, sem depender da renderizacao. E isso que permite calcular o progresso offline com a mesma formula do jogo ativo.
- **Pipeline unico de stats:** `Formulas.compute_stat()` aplica a ordem de operacoes do v2 (base+crescimento -> tier -> estrela -> bucket % -> fixos -> caps). Todo talento/sinergia deve passar por aqui.
- **Numeros grandes:** hoje em `float`/double (aguenta ate ~fase 5000). Para progressao infinita de verdade, o caminho e trocar o storage por um BigNumber; a formatacao ja esta pronta.

## Proximos passos

- [ ] Planilha/simulador de balanceamento (poder do jogador vs curva inimiga) — pendencia critica do v2 (secao 10).
- [ ] Sinergias de elemento e de adjacencia (entram no bucket % do pipeline).
- [ ] Sistema de gacha + Pity (0/100) e fragmentos/estrelas.
- [ ] Maquina de estados do combate: Marcha <-> Combate, Boss/Enrage, Farm Mode.
- [ ] Camada visual: side-scroller, parallax, clique, Fever Mode, Goblin do Tesouro.
- [ ] UI de tela dividida (Acao em cima / Gestao em abas embaixo).
