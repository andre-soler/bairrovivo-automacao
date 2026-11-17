# Automação em produção (VM Azure do MVP)

A automação roda **na mesma VM do MVP**, porque o banco de produção não tem porta pública (e deve continuar assim). O n8n entra na rede interna do MVP e enxerga o banco pelo nome `db`, sem abrir nenhuma porta nova.

```
VM Azure (NSG: 80 público, 22 só do admin)
├── projeto "bairrovivo" (repositório do Victor, deploy por cron a cada 1 min)
│   ├── app  (FastAPI, porta 80)
│   └── db   (PostgreSQL, sem porta)
└── projeto "bairrovivo-automacao" (este repositório)
    └── n8n  (127.0.0.1:5678, acesso só por túnel SSH)
          └── entra na rede bairrovivo_backend → fala com "db"
```

## Por que um projeto Compose separado

O deploy do MVP roda `docker compose up -d --remove-orphans` a cada minuto no projeto `bairrovivo`. Se o n8n fosse adicionado ao compose do MVP, seria removido como órfão. Com um projeto próprio, os dois deploys não se atrapalham, e **nenhum arquivo do repositório do MVP precisa mudar**.

## O que precisa existir

- A VM do MVP no ar (`terraform apply` do repositório `bairrovivo-secure`)
- Acesso SSH à VM: só o IP do `admin_cidr` passa no NSG

## Instalação (uma vez só)

Quem tem o SSH da VM roda:

```bash
ssh azureuser@<IP-DA-VM>
curl -fsSL https://raw.githubusercontent.com/andre-soler/bairrovivo-automacao/main/deploy/instalar-na-vm.sh -o instalar-na-vm.sh
less instalar-na-vm.sh          # leia antes de rodar
sudo bash instalar-na-vm.sh
```

O script:

1. Confere se o MVP está no ar (rede `bairrovivo_backend` e container `bairrovivo-db-1`)
2. Clona este repositório em `/opt/bairrovivo-automacao`
3. Gera `deploy/.env` com uma `N8N_ENCRYPTION_KEY` aleatória (permissão 600, fora do Git)
4. Cria as tabelas `automacao_*` no banco de produção (`IF NOT EXISTS`, não mexe em nada do MVP)
5. Sobe o n8n
6. Cria a credencial `Postgres account` lendo a senha de `/opt/bairrovivo/.env`, que **já existe na VM**: nenhuma senha passa pelo Git, pelo chat ou pelo terminal de ninguém
7. Importa os 3 workflows

## Publicar os workflows

No seu computador, abra o túnel e acesse o painel:

```bash
ssh -L 5678:localhost:5678 azureuser@<IP-DA-VM>
```

Abra http://localhost:5678 (a conexão passa criptografada pelo SSH), crie a conta de dono e publique, nesta ordem:

1. **02 - Mock IA**
2. **01 - Triagem principal**
3. **03 - Reprocessador**

A partir daí, toda ocorrência registrada na URL pública do MVP é processada em até 1 minuto.

## Teste rápido em produção

```bash
curl -X POST http://<IP-DA-VM>/api/ocorrencias \
  -H "Content-Type: application/json" \
  -d '{"titulo":"Entulho jogado na esquina","descricao":"Muito lixo e entulho","categoria":"descarte","latitude":-23.6,"longitude":-46.625,"alias":"teste"}'
```

Em até 1 minuto ela aparece como "Em análise" no site. Na VM:

```bash
docker exec bairrovivo-db-1 psql -U bairrovivo -d bairrovivo -c "SELECT ocorrencia_id, etapa, resultado FROM automacao_log ORDER BY id DESC LIMIT 5;"
```

## Atualizar depois de uma mudança nos workflows

Rodar o script de novo atualiza o repositório e o n8n, mas **não reimporta** os workflows (para não duplicar). Para trazer uma versão nova de um workflow, importe pelo painel (**⋯ → Import → From File**) ou:

```bash
docker exec bairrovivo-n8n n8n import:workflow --input=/home/node/workflows/01-triagem-principal.json
```

## Operação

| Ação | Comando (na VM) |
|---|---|
| Ver logs do n8n | `docker logs -f bairrovivo-n8n` |
| Parar a automação | `docker compose -f /opt/bairrovivo-automacao/deploy/docker-compose.prod.yml --env-file /opt/bairrovivo-automacao/deploy/.env stop` |
| Backup dos workflows | `docker exec bairrovivo-n8n n8n export:workflow --all --separate --output=/home/node/.n8n/backup/` |

Os dados da automação (log, fila, notificações) ficam no mesmo PostgreSQL do MVP e entram no `pg_dump` que o MVP já documenta.

## Limites conhecidos

- Se a VM for destruída (`terraform destroy`), a automação vai junto. Depois de um novo `terraform apply`, basta rodar o script de novo.
- O IP público pode mudar quando a VM é recriada.
- O webhook de entrada (`/webhook/nova-ocorrencia`) só é acessível de dentro da VM. Se o backend for chamá-lo, ele usa `http://bairrovivo-n8n:5678/webhook/nova-ocorrencia` pela rede interna, e o webhook deve ganhar autenticação por token antes disso.
