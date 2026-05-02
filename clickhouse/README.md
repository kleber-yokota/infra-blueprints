# ClickHouse

Servidor ClickHouse com storage integration para Garage S3.

## Estrutura de Arquivos

```
clickhouse/
├── docker-compose.yml      # Configuração Docker
├── configs/
│   ├── config.yaml         # Configuração do servidor
│   └── users.yaml          # Usuários, perfis e senhas
├── data/                   # Dados persistentes (não comitar)
├── .env                    # Variáveis de ambiente (não comitar)
└── .env.example            # Exemplo de variáveis
```

## Configuração do Servidor - `configs/config.yaml`

Arquivo YAML nativo (formato suportado desde ClickHouse 22.9).

| Campo | Descrição | Valor padrão |
|-------|-----------|-------------|
| `logger.level` | Nível de log: trace, debug, warning, error | `warning` |
| `http_port` | Porta para acesso HTTP/REST | `8123` |
| `tcp_port` | Porta para acesso nativo (clickhouse-client) | `9000` |
| `listen_host` | Interface de escuta | `0.0.0.0` |
| `path` | Diretório de dados | `/var/lib/clickhouse/` |
| `user_directories.users_xml.path` | Onde ler usuários | `users.d/users.yaml` |
| `user_directories.local_directory.path` | Armazenamento de acesso local | `/var/lib/clickhouse/access/` |

## Usuários e Perfis - `configs/users.yaml`

Define usuários e perfis que são mesclados automaticamente pelo ClickHouse.

### Perfis

| Perfil | Comportamento |
|--------|--------------|
| `default` | Acesso total (max 10GB memória, log de queries) |
| `readonly` | Apenas leitura (readonly=1) |

### Usuários

| Usuário | Profile | Acesso |
|---------|---------|--------|
| `default` | default | Login sem senha |
| `ch_admin` | default | Admin (acesso total) |
| `superset_user` | readonly | Apenas SELECT |

As senhas vêm das variáveis de ambiente via `@from_env` — nenhuma senha está no repositório.

### Opções de senha

**Senha via variável de ambiente** (recomendado):
```yaml
users:
  meu_usuario:
    password:
      - '@from_env': CLICKHOUSE_PASSWORD
```
Coloque em `.env`: `CLICKHOUSE_PASSWORD=minha_senha`

**Senha em texto simples** (uso local):
```yaml
users:
  meu_usuario:
    password: minha_senha
```

**Senha com SHA256 hash**:
```yaml
users:
  meu_usuario:
    password_sha256_hex: $(echo -n 'minha_senha' | sha256sum | awk '{print $1}')
```

### Como adicionar/alterar usuário

```yaml
# Adicionar novo usuário com senha via env
users:
  novo_usuario:
    profile: default
    networks:
      ip: "::/0"
    password:
      - '@from_env': NOVO_USUARIO_PASSWORD

# Alterar senha — mude em .env
CLICKHOUSE_PASSWORD=nova_senha
```

Reinicie após alterar `.env`:
```bash
docker compose -f clickhouse/docker-compose.yml restart
```

## Variáveis de Ambiente - `.env`

```bash
CLICKHOUSE_PASSWORD=clickhouse_secure_2026
CLICKHOUSE_SUPERSET_PASSWORD=superset_secure_2026
GARAGE_S3_ACCESS_KEY=minioadmin
GARAGE_S3_SECRET_KEY=minioadmin
```

Copie `.env.example` para `.env`:

```bash
cp .env.example .env
```

### Variáveis disponíveis

| Variável | Uso | Obrigatória |
|----------|-----|-------------|
| `CLICKHOUSE_PASSWORD` | Senha do `ch_admin` | Sim |
| `CLICKHOUSE_SUPERSET_PASSWORD` | Senha do `superset_user` | Sim |
| `GARAGE_S3_ACCESS_KEY` | Chave de acesso Garage S3 | Sim |
| `GARAGE_S3_SECRET_KEY` | Chave secreta Garage S3 | Sim |

### Por que precisa das chaves S3?

O ClickHouse usa `GARAGE_S3_ACCESS_KEY` e `GARAGE_S3_SECRET_KEY` para acessar dados remotos via a `s3()` table function. Sem essas chaves, não é possível ler arquivos do Garage S3 diretamente nas queries.

## Storage - Garage S3

Para consultar dados do Garage S3:

```sql
SELECT *
FROM s3(
  'https://{bucket}.s3.garage:3600/path/*.parquet',
  '${GARAGE_S3_ACCESS_KEY}',
  '${GARAGE_S3_SECRET_KEY}',
  'Parquet'
)
```

## docker-compose.yml

O `docker-compose.yml` monta os arquivos de configuração dentro do container:

| Mount | Descrição |
|-------|-----------|
| `./data:/var/lib/clickhouse` | Dados persistentes do banco |
| `./data/access:/var/lib/clickhouse/access` | Acesso e políticas |
| `./configs/config.yaml:/etc/clickhouse-server/config.yaml` | Config do servidor |
| `./configs/users.yaml:/etc/clickhouse-server/users.d/users.yaml` | Usuários e perfis |

## Comandos

```bash
# Subir
docker compose -f clickhouse/docker-compose.yml up -d

# Parar
docker compose -f clickhouse/docker-compose.yml down

# Ver logs
docker compose -f clickhouse/docker-compose.yml logs -f

# Query via CLI (senha vem de .env)
docker exec -it clickhouse_db clickhouse-client \
  --user ch_admin \
  --password "$CLICKHOUSE_PASSWORD" \
  --database clickhouse_warehouse \
  --query "SELECT 1"

# Query interativa
source .env && docker exec -it clickhouse_db clickhouse-client \
  --user ch_admin \
  --password "$CLICKHOUSE_PASSWORD"
```

## Ports

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| `8123` | HTTP | API REST, queries via curl |
| `9000` | TCP | Protocolo nativo (clickhouse-client) |
