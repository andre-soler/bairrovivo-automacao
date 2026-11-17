# Logs

Amostras do `automacao_log`, a tabela de auditoria da automação. **Nenhuma contém dados pessoais**: só IDs, etapas, resultados, detalhes técnicos e horários.

| Arquivo | O que mostra |
|---|---|
| [`producao-automacao_log.txt`](producao-automacao_log.txt) | Uma ocorrência real de produção percorrendo as 4 etapas em ~1 s |
| [`local-cenarios-decisao.txt`](local-cenarios-decisao.txt) | Os cenários de decisão: inválida, sem duplicata e duplicata |

Para gerar uma amostra nova:

```bash
docker compose exec db psql -U bairrovivo -d bairrovivo -c "SELECT ocorrencia_id, etapa, resultado, tentativas, criado_em FROM automacao_log ORDER BY id;"
```
