# Testes da automação

Os testes cobrem os três tipos pedidos (**sucesso**, **decisão** e **falha**). Todos usam dados fictícios e rodam no ambiente local (`docker compose up -d`, com os 3 workflows publicados).

Os comandos são para PowerShell. A ocorrência é criada pela própria API do MVP, o mesmo caminho do formulário do site.

## Resumo

| # | Tipo | Cenário | Resultado esperado | Resultado obtido |
|---|---|---|---|---|
| 1 | Sucesso | Ocorrência válida e isolada | "Em análise" + notificação | ✅ Aprovado (local e produção) |
| 2 | Decisão | Ocorrência fora da área piloto | "Não procedente" com motivos | ✅ Aprovado |
| 3 | Decisão | Ocorrência duplicada (mesma categoria a poucos metros) | Marcada como duplicata, encaminhada para revisão | ✅ Aprovado (6,6 m da original) |
| 4 | Falha | API de IA fora do ar | Fila de falhas → reprocessada | ✅ Aprovado |

---

## 1. Sucesso: registro normal

```powershell
$c = @{ titulo="Entulho jogado na esquina"; descricao="Muito lixo e entulho acumulado"; categoria="descarte"; latitude=-23.6000; longitude=-46.6250; alias="Joao" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/api/ocorrencias" -Body $c -ContentType "application/json; charset=utf-8"
```

**Esperado em até 1 minuto:**
- Site: a ocorrência aparece como **"Em análise"**
- n8n (01 - Triagem principal → Executions): Duplicata? → *false*, Classificar (IA) → *Success*, Encaminhar e Notificar verdes
- Log: `duplicidade ok` → `classificar ok` → `encaminhar ok` → `notificar ok`
- `automacao_notificacoes`: mensagem para "Joao"

## 2. Decisão: ocorrência fora da área piloto

```powershell
$c = @{ titulo="Teste fora da area"; descricao="Ponto em outra cidade"; categoria="buraco"; latitude=-22.9000; longitude=-43.2000; alias="teste" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/api/ocorrencias" -Body $c -ContentType "application/json; charset=utf-8"
```

**Esperado:** Válida? → *false* → Registrar inválida. Status **"não procedente"**. No log: `validar | invalida | {"motivos": ["latitude fora da area piloto", "longitude fora da area piloto"]}`.

## 3. Decisão: duplicidade

Crie uma ocorrência e, depois, outra da **mesma categoria** a poucos metros dela:

```powershell
$a = @{ titulo="Buraco no meio da rua"; descricao="Buraco grande no asfalto"; categoria="buraco"; latitude=-23.58948; longitude=-46.63396; alias="Ana" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/api/ocorrencias" -Body $a -ContentType "application/json; charset=utf-8"
# espere 1 minuto para a primeira ser processada
$b = @{ titulo="Buraco perto do terminal"; descricao="Teste de duplicidade"; categoria="buraco"; latitude=-23.58950; longitude=-46.63390; alias="Bia" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/api/ocorrencias" -Body $b -ContentType "application/json; charset=utf-8"
```

**Esperado para a segunda:** Duplicata? → *true* → Registrar duplicata. No log: `duplicidade | duplicata | {"dup_id": <id da primeira>, "distancia_m": ~6.6, "raio_m": 50}` e `encaminhar | revisao`. A ocorrência **não é apagada**.

## 4. Falha: IA fora do ar e recuperação

1. No n8n, abra **02 - Mock IA** e clique em **Unpublish**.
2. Crie uma ocorrência (comando do teste 1, com outro título).
3. **Esperado:** Classificar (IA) tenta 3 vezes e sai pela saída *Error* → Enviar para fila. Em `automacao_falhas`: status **`pendente`**.
4. Publique o **02 - Mock IA** de novo.
5. Em até 5 minutos (ou rodando o **03 - Reprocessador** manualmente): a ocorrência é concluída e a falha fica **`reprocessada`**.

## Consultas de verificação

```powershell
docker compose exec db psql -U bairrovivo -d bairrovivo -c "SELECT ocorrencia_id, etapa, resultado, tentativas FROM automacao_log ORDER BY id;"
docker compose exec db psql -U bairrovivo -d bairrovivo -c "SELECT id, titulo, status FROM ocorrencias WHERE origem = 'cidadao' ORDER BY id;"
docker compose exec db psql -U bairrovivo -d bairrovivo -c "SELECT ocorrencia_id, mensagem FROM automacao_notificacoes;"
docker compose exec db psql -U bairrovivo -d bairrovivo -c "SELECT id, ocorrencia_id, status, tentativas, erro FROM automacao_falhas;"
```

As evidências visuais (prints das execuções e do site) estão em [`../assets/`](../assets/).
