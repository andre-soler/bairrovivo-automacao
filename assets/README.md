# Evidências visuais

Prints reais das execuções da automação (17/11/2026). Todos os dados são fictícios.

## Cenário 1: registro normal (sucesso)
| Arquivo | O que mostra |
|---|---|
| `cenario1-registro-normal-execucao.png` | Execução disparada pelo agendamento, caminho completo verde até Encaminhar e Notificar |
| `cenario1-e-fora-da-area-log.png` | Banco: ocorrência 48 com as 4 etapas `ok` (e a 47, rejeitada, ao lado) |

## Decisão: fora da área piloto
| Arquivo | O que mostra |
|---|---|
| `decisao-fora-da-area-execucao.png` | Execução terminando em Registrar inválida |
| `decisao-log.png` | Log com os três caminhos de decisão: `invalida`, `ok` e `duplicata` |

## Cenário 2: duplicidade
| Arquivo | O que mostra |
|---|---|
| `cenario2-duplicidade-execucao.png` | Execução com Duplicata? → true → Registrar duplicata, seguindo para classificação |
| `cenario2-duplicidade-log.png` | Ocorrência 49: duplicata da 48 a 6,8 m, IA com 92%, encaminhada para revisão |

## Cenário 3: falha e recuperação
| Arquivo | O que mostra |
|---|---|
| `cenario3-falha-execucao-erro.png` | IA fora do ar: Classificar (IA) → Error → Enviar para fila (4,3 s, 3 tentativas) |
| `cenario3-falha-fila-pendente.png` | `automacao_falhas`: status `pendente` com o erro 404 |
| `cenario3-reprocessador-execucao.png` | Reprocessador todo verde: reclassifica, encaminha, notifica e marca como reprocessada |
| `cenario3-falha-reprocessada.png` | `automacao_falhas`: status `reprocessada` após 7 tentativas |

## Produção (VM do MVP)
| Arquivo | O que mostra |
|---|---|
| `producao-site.png` | Site público com a ocorrência "Buraco na rua" em "Em análise" |
| `producao-execucao.png` | Execução de produção de 17/11/2026 16:00:03, caminho completo verde |
| `producao-log.png` | `automacao_log` de produção: as 4 etapas da ocorrência em ~1 s |
