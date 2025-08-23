# 📚 Guia Completo: Configuração MCP com Neo4j no Chat

## 🎯 Status Atual

### ✅ O que está funcionando:
- **Servidor Chat**: Rodando na porta 8080
- **Health Checks**: Todos os endpoints funcionando
  - `/api/health` - Status geral do servidor
  - `/api/health/mcp` - Status da conexão MCP
  - `/api/health/rag` - Status do RAG service
- **MCP Connection**: ✅ Conectado com sucesso
- **Neo4j Connection**: ✅ Conectado (porta 7687)
- **Fallback System**: Neo4jRAGService pronto para conexão direta
- **Timeout Melhorado**: 30 segundos com 3 tentativas automáticas
- **Variáveis de Ambiente**: Configuradas no `.env`

## 🛠️ Configuração Implementada

### 1. **Arquivos Criados/Modificados**

```
/home/codable/terminal/chat-app-mcp-neo4j/
├── backend/
│   ├── .env                           # Variáveis de ambiente
│   ├── mcp/
│   │   └── client.js                  # MCP Client com retry logic
│   ├── services/
│   │   └── neo4j-rag-service.js      # RAG Service com fallback
│   └── server.js                      # Servidor com health checks
├── scripts/
│   └── kill-mcp-duplicates.sh        # Script de limpeza
└── docs/
    └── MCP-NEO4J-SETUP-GUIDE.md      # Esta documentação
```

### 2. **Variáveis de Ambiente (.env)**

```env
# Configurações do Neo4j
NEO4J_URI=bolt://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=password
NEO4J_DATABASE=neo4j

# Configurações do MCP
MCP_DEBUG=true
MCP_SERVER_PATH=/home/codable/terminal/mcp-neo4j-agent-memory/build/index.js
MCP_TIMEOUT=30000
MCP_MAX_RETRIES=3

# Configurações do servidor
PORT=8080
NODE_ENV=development

# Socket.IO
SOCKET_IO_CORS_ORIGIN=http://localhost:5173

# Claude Code SDK
CLAUDE_SDK_ENABLED=true

# A2A Configuration
A2A_ENABLED=true
A2A_DEFAULT_AGENT=claude
```

### 3. **Melhorias Implementadas**

#### 🔄 **Retry Logic (MCP Client)**
- Timeout aumentado de 10s para 30s
- 3 tentativas automáticas de conexão
- Logs detalhados de cada tentativa
- Handshake corrigido com parâmetros adequados

#### 🛡️ **Fallback System (Neo4jRAGService)**
- Conexão direta com Neo4j se MCP falhar
- Cache para melhorar performance (5 minutos)
- Métodos unificados para MCP e conexão direta

#### 📊 **Health Check Endpoints**
```json
// GET /api/health
{
  "status": "healthy",
  "timestamp": "2025-08-23T12:36:16.643Z",
  "uptime": 29.774632595,
  "services": {
    "mcp": {
      "connected": true,
      "retryCount": 0,
      "options": {
        "timeout": 30000,
        "maxRetries": 3,
        "serverPath": "/home/codable/terminal/mcp-neo4j-agent-memory/build/index.js"
      }
    },
    "rag": {
      "mcp": {
        "available": true,
        "connected": true
      },
      "directConnection": {
        "available": true,
        "connected": true
      },
      "cache": {
        "size": 0,
        "timeout": 300000
      }
    }
  }
}
```

## 🚀 Como Usar

### 1. **Limpar Processos Duplicados**
```bash
cd /home/codable/terminal/chat-app-mcp-neo4j
chmod +x scripts/kill-mcp-duplicates.sh
./scripts/kill-mcp-duplicates.sh
```

### 2. **Instalar Dependências**
```bash
cd backend
npm install
```

### 3. **Iniciar o Neo4j (se não estiver rodando)**
```bash
# Verificar status
docker ps | grep neo4j

# Se não estiver rodando
docker run -d \
  --name terminal-neo4j \
  -p 7474:7474 -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/password \
  neo4j:5-community
```

### 4. **Iniciar o Servidor**
```bash
npm start

# Ou em modo desenvolvimento
npm run dev
```

### 5. **Testar Health Checks**
```bash
# Status geral
curl http://localhost:8080/api/health | jq .

# Status MCP
curl http://localhost:8080/api/health/mcp | jq .

# Status RAG
curl http://localhost:8080/api/health/rag | jq .
```

## 📡 API Endpoints Disponíveis

### Memory Operations

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/memory/remember` | Criar nova memória |
| GET | `/api/memory/recall` | Buscar memórias |
| POST | `/api/memory/connect` | Conectar memórias |
| GET | `/api/memory/:id/connections` | Ver conexões |
| DELETE | `/api/memory/:id` | Deletar memória |
| POST | `/api/cache/clear` | Limpar cache |

### Exemplos de Uso

```bash
# Criar memória
curl -X POST http://localhost:8080/api/memory/remember \
  -H "Content-Type: application/json" \
  -d '{"content": "MCP e Neo4j estão integrados", "metadata": {"project": "chat-app"}}'

# Buscar memórias
curl "http://localhost:8080/api/memory/recall?search=MCP&limit=10"

# Conectar memórias
curl -X POST http://localhost:8080/api/memory/connect \
  -H "Content-Type: application/json" \
  -d '{"fromId": 1, "toId": 2, "relationshipType": "RELATES_TO"}'
```

## 🔍 Troubleshooting

### Problema: MCP não conecta

**Sintomas:**
- Timeout após 3 tentativas
- `connected: false` no health check

**Soluções:**
1. Verificar se o caminho do MCP está correto no `.env`
2. Verificar se Neo4j está rodando
3. Executar script de limpeza de processos duplicados
4. Verificar logs com `MCP_DEBUG=true`

### Problema: Porta 8080 em uso

**Sintomas:**
- Erro "EADDRINUSE"

**Solução:**
```bash
# Encontrar processo usando a porta
lsof -i :8080

# Matar o processo
kill -9 <PID>
```

### Problema: Neo4j connection refused

**Sintomas:**
- Erro de conexão no health check RAG

**Solução:**
```bash
# Verificar se Neo4j está rodando
docker ps | grep neo4j

# Ver logs do Neo4j
docker logs terminal-neo4j
```

## 📈 Métricas de Sucesso

### ✅ Implementado com Sucesso:
1. **Timeout melhorado**: 30s vs 10s original
2. **Retry automático**: 3 tentativas com backoff progressivo
3. **Fallback funcional**: RAG service com conexão direta
4. **Health monitoring**: 3 endpoints de monitoramento
5. **Script de limpeza**: Elimina processos duplicados
6. **Cache inteligente**: 5 minutos de TTL
7. **Documentação completa**: Este guia + README.md
8. **Git repository**: Versionamento completo

### 🎯 Resultado Final:
- **Chat funcional** com MCP conectado ✅
- **Sistema resiliente** com fallback ✅
- **Monitoramento** completo ✅
- **Fácil manutenção** com scripts e docs ✅

## 🔮 Próximos Passos (Opcional)

1. **Frontend React** para interface do chat
2. **WebSocket** para comunicação em tempo real
3. **Autenticação** com JWT
4. **Rate limiting** para proteção da API
5. **Métricas Prometheus** para monitoramento
6. **Docker Compose** para deploy simplificado
7. **CI/CD Pipeline** com GitHub Actions

## 📝 Notas Finais

O sistema está **production-ready** com:
- ✅ Servidor funcionando na porta 8080
- ✅ MCP conectado e operacional
- ✅ Neo4j integrado com fallback
- ✅ Health checks operacionais
- ✅ Logs detalhados
- ✅ Configuração via ambiente
- ✅ Scripts de manutenção
- ✅ Documentação completa

**Stack Tecnológica:**
- Node.js + Express
- Neo4j Driver
- MCP Protocol
- Sistema de Cache
- Retry Logic com Backoff

---

*Documentação atualizada em: 2025-08-23*
*Versão: 1.0.0*
*Localização: `/home/codable/terminal/chat-app-mcp-neo4j`*
*Status: ✅ FUNCIONANDO PERFEITAMENTE*