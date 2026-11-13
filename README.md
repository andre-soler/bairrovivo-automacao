\# BairroVivo — Automação (RPA)



Automação da triagem de ocorrências do \*\*BairroVivo\*\*, a plataforma de zeladoria urbana do grupo na FIAP Global Solution 2026.2. Este repositório é a entrega da disciplina de \*\*RPA / Automação\*\*.



> ⚠️ \*\*Dados 100% fictícios.\*\* O MVP sobe com ocorrências sintéticas. Não há fotos nem dados pessoais reais.



| Item | Link |

|---|---|

| MVP (disciplina de DevOps) | https://github.com/victorasfur/bairrovivo-secure |

| Este repositório | https://github.com/andre-soler/bairrovivo-automacao |



\---



\## O que a automação faz



Toda ocorrência nova registrada no BairroVivo passa por um fluxo no \*\*n8n\*\*:



1\. \*\*Validar:\*\* campos obrigatórios, categoria e coordenadas

2\. \*\*Duplicidade:\*\* busca ocorrências da mesma categoria num raio próximo (Haversine em SQL)

3\. \*\*Classificar:\*\* sugestão de categoria pela IA (mock até a API existir)

4\. \*\*Visão computacional:\*\* opcional, só quando houver foto

5\. \*\*Encaminhar:\*\* muda o status para `em\_analise` e cria a tarefa de revisão

6\. \*\*Notificar:\*\* registra a notificação para o cidadão (mock)

7\. \*\*Registrar log:\*\* etapa, resultado, duração, tentativas e erro



Se um nó falhar depois das tentativas de retry, a ocorrência vai para uma \*\*fila de falhas\*\*, e um \*\*reprocessador\*\* agendado tenta de novo.



\*\*Uma possível duplicata nunca é apagada:\*\* ela segue marcada para revisão do operador.



\## Arquitetura adaptável



A automação funciona hoje com o MVP como ele está e recebe as peças das outras disciplinas sem refazer o fluxo:



| Peça | Hoje | Quando chegar |

|---|---|---|

| Entrada de ocorrências | Polling no banco a cada 1 min | Webhook do backend |

| Classificação por IA | Mock | Preencher `IA\_URL` |

| Visão computacional | Etapa pulada (MVP sem fotos) | Preencher `CV\_URL` |

| Notificação | Tabela de notificações (mock) | Canal real |



O diagrama completo está em \[`docs/`](docs/).



\## Stack



| Componente | Tecnologia |

|---|---|

| Orquestração | n8n (Docker) |

| Banco | PostgreSQL 16, o mesmo do MVP |

| MVP | Imagem `ghcr.io/victorasfur/bairrovivo-secure` (FastAPI) |

| Execução | Docker Compose |



\## Como rodar



Pré-requisito: \*\*Docker Desktop\*\* aberto, com o engine rodando.



```bash

git clone https://github.com/andre-soler/bairrovivo-automacao.git

cd bairrovivo-automacao

cp .env.example .env        # no PowerShell: Copy-Item .env.example .env

\# edite o .env: defina POSTGRES\_PASSWORD e N8N\_ENCRYPTION\_KEY

docker compose up -d

docker compose ps

```



| Serviço | Endereço |

|---|---|

| MVP BairroVivo | http://localhost:8000 |

| n8n | http://localhost:5678 |



Para parar sem perder dados: `docker compose down`. O `docker compose down -v` apaga os volumes, inclusive os workflows do n8n.



\### Primeira configuração do n8n



1\. Crie a conta de dono em http://localhost:5678

2\. Crie uma credencial \*\*Postgres\*\* com:

&#x20;  - Host `db`, porta `5432`

&#x20;  - Banco e usuário iguais aos do `.env`

&#x20;  - SSL desabilitado (o tráfego não sai da rede interna do Docker)

3\. Importe os workflows da pasta \[`workflows/`](workflows/)



\## Segurança



\- \*\*Sem segredos no repositório:\*\* o `.env` fica fora do Git (`.gitignore`); só o `.env.example` é versionado.

\- \*\*Portas só locais:\*\* MVP e n8n escutam em `127.0.0.1`; o banco não publica porta nenhuma.

\- \*\*Credenciais criptografadas\*\* no n8n com `N8N\_ENCRYPTION\_KEY`.

\- \*\*Container do n8n\*\* com `no-new-privileges`.

\- \*\*Tabelas próprias:\*\* a automação grava em `automacao\_\*` e só altera o `status` das ocorrências.



\## Estrutura



```

.

├── docker-compose.yml   # db + app (MVP) + n8n

├── .env.example         # variáveis sem segredos

├── sql/                 # criação das tabelas da automação

├── workflows/           # workflows do n8n exportados em JSON

└── docs/                # diagrama e evidências

```



\## Andamento



\- \[x] Fase 1: ambiente local (MVP + n8n + conexão com o banco)

\- \[ ] Fase 2: tabelas da automação

\- \[ ] Fase 3: esqueleto adaptável (entradas, normalização, configuração)

\- \[ ] Fase 4: validação e duplicidade

\- \[ ] Fase 5: classificação, encaminhamento e notificação

\- \[ ] Fase 6: tratamento de falhas (retry, fila e reprocessador)

\- \[ ] Fase 7: peças reais das outras disciplinas

\- \[ ] Fase 8: evidências e demonstração



\## Demonstração



1\. \*\*Registro normal:\*\* a ocorrência percorre o fluxo inteiro e aparece no log.

2\. \*\*Duplicidade provável:\*\* uma ocorrência igual a poucos metros é marcada para revisão.

3\. \*\*Falha recuperada:\*\* com o mock da IA desligado, a ocorrência vai para a fila; religando, ela é reprocessada.



\## Limitações



\- O MVP não tem upload de fotos, então a visão computacional fica desativada até existir.

\- IA e notificações usam mocks até as outras disciplinas entregarem as APIs.

\- A entrada é por polling (até 1 min de atraso) porque o backend ainda não dispara webhook.



\## Grupo



André Solér · Fabrizio Maia Apparicio · Rodrigo Paixão · Victor Miguel Gouveia Asfur · Vitor Shimizu Farias de Campos

