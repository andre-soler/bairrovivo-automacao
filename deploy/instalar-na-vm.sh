#!/usr/bin/env bash
# Instala a automação BairroVivo (n8n) na VM de produção do MVP.
# Rodar NA VM, com sudo:   sudo bash instalar-na-vm.sh
# Pode ser executado de novo: ele atualiza o repositório e não duplica nada.
set -euo pipefail

REPO_URL="https://github.com/andre-soler/bairrovivo-automacao.git"
DIR="/opt/bairrovivo-automacao"
MVP_ENV="/opt/bairrovivo/.env"          # criado pelo cloud-init do MVP (segredos de produção)
REDE_MVP="bairrovivo_backend"
DB_CONTAINER="bairrovivo-db-1"
N8N_CONTAINER="bairrovivo-n8n"
CRED_ID="EfMzb9gFgmZMMPCA"              # mesmo ID usado nos workflows exportados
COMPOSE="docker compose -f $DIR/deploy/docker-compose.prod.yml --env-file $DIR/deploy/.env"

passo() { echo; echo "==> $*"; }
erro()  { echo "ERRO: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || erro "rode com sudo"

passo "1/7 Conferindo o MVP"
docker network inspect "$REDE_MVP" >/dev/null 2>&1 || erro "rede $REDE_MVP não existe. O MVP está no ar?"
[ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" = "true" ] || erro "container $DB_CONTAINER não está rodando"
[ -r "$MVP_ENV" ] || erro "não encontrei $MVP_ENV"
PG_USER=$(grep -E '^POSTGRES_USER=' "$MVP_ENV" | cut -d= -f2-)
PG_DB=$(grep -E '^POSTGRES_DB=' "$MVP_ENV" | cut -d= -f2-)
PG_PASS=$(grep -E '^POSTGRES_PASSWORD=' "$MVP_ENV" | cut -d= -f2-)
[ -n "$PG_PASS" ] || erro "POSTGRES_PASSWORD vazio em $MVP_ENV"
echo "MVP ok (banco $PG_DB, usuário $PG_USER)"

passo "2/7 Baixando ou atualizando o repositório da automação"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only -q
else
  git clone -q "$REPO_URL" "$DIR"
fi

passo "3/7 Criando deploy/.env (só na primeira vez)"
if [ ! -f "$DIR/deploy/.env" ]; then
  umask 077
  echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)" > "$DIR/deploy/.env"
  echo "criado com chave nova (permissão 600)"
else
  echo "já existe, mantido (trocar a chave invalidaria as credenciais salvas no n8n)"
fi

passo "4/7 Criando as tabelas da automação no banco de produção"
docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -q -U "$PG_USER" -d "$PG_DB" < "$DIR/sql/001_tabelas_automacao.sql"
echo "tabelas ok (o script usa IF NOT EXISTS)"

passo "5/7 Subindo o n8n"
$COMPOSE pull -q
$COMPOSE up -d
for i in $(seq 1 30); do
  curl -fsS http://127.0.0.1:5678/healthz >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS http://127.0.0.1:5678/healthz >/dev/null || erro "n8n não respondeu em 60 s: $COMPOSE logs n8n"
# O healthz responde antes do n8n terminar as migrations do banco interno.
# Rodar comandos da CLI nesse meio-tempo causa disputa ("duplicate column").
echo "aguardando o n8n terminar de inicializar..."
for i in $(seq 1 60); do
  docker logs "$N8N_CONTAINER" 2>&1 | grep -q "Editor is now accessible" && break
  sleep 2
done
docker logs "$N8N_CONTAINER" 2>&1 | grep -q "Editor is now accessible" || erro "n8n não terminou de iniciar em 2 min: docker logs $N8N_CONTAINER"
echo "n8n no ar em 127.0.0.1:5678 (só dentro da VM)"

MARCA="$DIR/deploy/.instalado"
if [ -f "$MARCA" ]; then
  passo "6-7/7 Credencial e workflows já foram importados antes. Nada a fazer."
else
  passo "6/7 Criando a credencial Postgres (mesmo ID dos workflows)"
  TMP=$(mktemp)
  chmod 600 "$TMP"
  cat > "$TMP" <<JSON
[{"id":"$CRED_ID","name":"Postgres account","type":"postgres",
  "data":{"host":"db","database":"$PG_DB","user":"$PG_USER","password":"$PG_PASS",
          "port":5432,"ssl":"disable","maxConnections":100,"allowUnauthorizedCerts":false,"sshTunnel":false}}]
JSON
  docker cp "$TMP" "$N8N_CONTAINER":/tmp/cred.json
  rm -f "$TMP"
  # o n8n roda como "node" dentro do container; o arquivo chegou como root (600)
  docker exec -u root "$N8N_CONTAINER" chown node:node /tmp/cred.json
  docker exec "$N8N_CONTAINER" n8n import:credentials --input=/tmp/cred.json
  docker exec -u root "$N8N_CONTAINER" rm -f /tmp/cred.json

  passo "7/7 Importando os 3 workflows"
  docker exec "$N8N_CONTAINER" n8n import:workflow --separate --input=/home/node/workflows/
  touch "$MARCA"
fi

cat <<FIM

============================================================
Instalação concluída. Falta só publicar os workflows:

1) No SEU computador, abra o túnel SSH:
     ssh -L 5678:localhost:5678 azureuser@<IP-DA-VM>
2) Acesse http://localhost:5678 e crie a conta de dono
3) Publique nesta ordem: 02 - Mock IA, 01 - Triagem principal, 03 - Reprocessador
============================================================
FIM
