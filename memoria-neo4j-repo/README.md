# 🧠 Memória Neo4j Repository

Central de gerenciamento de memórias do Neo4j para o sistema Terminal.

## 📁 Estrutura

```
memoria-neo4j-repo/
├── scripts/               # Scripts de gerenciamento
│   ├── backup-neo4j.sh              # Backup local simples
│   ├── backup-neo4j-github.sh       # Backup com sync GitHub
│   ├── restore-neo4j-github.sh      # Restore do GitHub
│   ├── restart.sh                   # Reiniciar serviços
│   └── setup-neo4j-backup-submodule.sh  # Configurar submódulo
├── backups/              # Backups locais (ignorado no git)
├── neo4j-memory-backups/ # Submódulo GitHub com backups
│   ├── daily/           # Backups diários
│   ├── weekly/          # Backups semanais
│   ├── monthly/         # Backups mensais
│   └── snapshots/       # Snapshots manuais
└── docs/                # Documentação
```

## 🚀 Quick Start

### 1. Configuração Inicial

```bash
cd memoria-neo4j-repo
./setup-neo4j-backup-submodule.sh
```

### 2. Fazer Backup Manual

```bash
# Backup local simples
./backup-neo4j.sh

# Backup com sync para GitHub
./backup-neo4j-github.sh

# Backup snapshot (importante)
./backup-neo4j-github.sh manual
```

### 3. Restaurar Backup

```bash
# Restaurar último backup
./restore-neo4j-github.sh

# Restaurar backup específico
./restore-neo4j-github.sh 2025-08-23

# Restaurar de tipo específico
./restore-neo4j-github.sh 2025-08-23 weekly
```

## 🔄 Backups Automáticos

### Configurar Cron

```bash
# Adicionar ao crontab
crontab -e

# Adicionar estas linhas:
0 2 * * * cd /home/codable/terminal/memoria-neo4j-repo && ./backup-neo4j-github.sh daily
0 3 * * 0 cd /home/codable/terminal/memoria-neo4j-repo && ./backup-neo4j-github.sh weekly
0 4 1 * * cd /home/codable/terminal/memoria-neo4j-repo && ./backup-neo4j-github.sh monthly
```

## 🔐 Segurança

### Trocar Senha do Neo4j

**IMPORTANTE**: Ao trocar a senha, faça backup primeiro!

```bash
# 1. Fazer backup ANTES de trocar senha
./backup-neo4j-github.sh snapshot_before_password_change

# 2. Atualizar senha no .env
vim /home/codable/terminal/.env
# NEO4J_PASSWORD=NovaSenhaAqui

# 3. Parar e limpar Neo4j
docker compose down
docker volume rm terminal_neo4j_data

# 4. Reiniciar com nova senha
docker compose up -d

# 5. Restaurar dados
./restore-neo4j-github.sh
```

## 📊 Formato dos Backups

### memories.json
```json
{
  "nodes": [
    {
      "id": 1,
      "labels": ["Memory"],
      "properties": {
        "name": "Example",
        "created_at": "2025-08-23"
      }
    }
  ],
  "relationships": [
    {
      "id": 1,
      "type": "RELATES_TO",
      "startNode": 1,
      "endNode": 2,
      "properties": {}
    }
  ],
  "timestamp": "2025-08-23T10:00:00",
  "stats": {
    "nodeCount": 100,
    "relationshipCount": 50
  }
}
```

## 🛠️ Scripts Disponíveis

### backup-neo4j.sh
- Backup local simples
- Salva em `./backups/`
- Útil para testes rápidos

### backup-neo4j-github.sh
- Backup com versionamento Git
- Sync automático com GitHub
- Limpeza automática de backups antigos
- Tipos: daily, weekly, monthly, manual

### restore-neo4j-github.sh
- Restaura de qualquer backup
- Busca automática por data
- Confirmação antes de sobrescrever

### restart.sh
- Reinicia containers Docker
- Útil após mudanças de configuração

### setup-neo4j-backup-submodule.sh
- Configura submódulo GitHub
- Cria estrutura de diretórios
- Prepara scripts automáticos

## 📈 Monitoramento

### Verificar Status

```bash
# Ver últimos backups
ls -la neo4j-memory-backups/daily/

# Contar memórias no banco
docker exec terminal-neo4j cypher-shell \
  -u neo4j -p "$NEO4J_PASSWORD" \
  "MATCH (n) RETURN count(n)"

# Ver espaço usado
du -sh neo4j-memory-backups/
```

### Logs

```bash
# Ver logs do Neo4j
docker logs terminal-neo4j --tail 50

# Ver histórico de backups
cd neo4j-memory-backups && git log --oneline
```

## 🆘 Troubleshooting

### Erro de Autenticação

```bash
# Verificar senha no .env
cat /home/codable/terminal/.env | grep NEO4J_PASSWORD

# Verificar senha no container
docker exec terminal-api env | grep NEO4J_PASSWORD
```

### Backup Vazio

```bash
# Verificar se Neo4j está rodando
docker ps | grep neo4j

# Testar conexão
docker exec terminal-neo4j cypher-shell \
  -u neo4j -p "$NEO4J_PASSWORD" \
  "RETURN 1"
```

### Restore Falhou

```bash
# Verificar se arquivo existe
ls -la neo4j-memory-backups/*/2025-08-23*

# Tentar restore manual
docker exec terminal-neo4j cypher-shell \
  -u neo4j -p "$NEO4J_PASSWORD" \
  -f /path/to/backup.cypher
```

## 📝 Notas Importantes

1. **SEMPRE** fazer backup antes de:
   - Trocar senha
   - Atualizar Neo4j
   - Fazer mudanças grandes

2. **Submódulo GitHub**:
   - Mantém histórico completo
   - Permite rollback fácil
   - Sincronização entre máquinas

3. **Retenção de Backups**:
   - Daily: 7 dias
   - Weekly: 4 semanas
   - Monthly: 12 meses
   - Snapshots: Permanente

## 🔗 Links Úteis

- [Neo4j Documentation](https://neo4j.com/docs/)
- [Cypher Query Language](https://neo4j.com/docs/cypher-manual/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 📄 Licença

Parte do projeto Terminal System.