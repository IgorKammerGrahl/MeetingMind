# MeetingMind

## Como rodar o projeto localmente

### Backend (Go + Postgres)

```bash
cd backend

# 1. Confirmar que o Postgres local está rodando (serviço do sistema)
systemctl status postgresql --no-pager

# 2. Se não estiver rodando, suba com:
sudo systemctl start postgresql

# 3. Rodar o servidor (porta 8081, pois a 8080 costuma estar ocupada)
PORT=8081 go run ./cmd/server
```

Testar se subiu (em outro terminal):

```bash
curl http://localhost:8081/health
# deve retornar: {"status":"ok"}
```

Rodar em background:

```bash
cd backend
PORT=8081 go run ./cmd/server > /tmp/backend.log 2>&1 &
disown
tail -f /tmp/backend.log   # acompanhar logs
```

Parar:

```bash
pkill -f "go run ./cmd/server"
```

**Observações:**
- `backend/.env` já está configurado com as credenciais do Postgres local.
- Se der `bind: address already in use` na 8081, troque a porta (`PORT=8082 ...`).
- `backend/.env.example` (versionado no git) ainda contém chave/senha reais em vez de placeholders — pendente de limpeza.

### Mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```
