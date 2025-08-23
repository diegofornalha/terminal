# DIRETRIZES DO PROJETO TERMINAL 

garanta que toda a documentação do neo4j esteja em pt br

sempre que for criar algum arquivo não é pra gerar ele na raiz do projeto e sim na sua devida pasta 

investigue e leia cada arquivo pra entender ao tentar resolver um problema vc precisa ter contexto 100%, vai no detalhe e não se preoculpe em terminar logo, garanta que vai fazer exatamente o que eu te pedi.           

## 🧠 REGRA PRINCIPAL: Neo4j é a Fonte da Verdade
SEMPRE consulte o Neo4j antes de qualquer ação para ter contexto completo.

## 📋 REGRAS FUNDAMENTAIS

### 1. Metodologia PRP (Preserve, Retrieve, Process)
- **PRESERVE**: Salvar TUDO no Neo4j antes de remover/modificar
- **RETRIEVE**: Sempre buscar contexto existente primeiro
- **PROCESS**: Processar mantendo 100% do contexto do projeto

### 2. Documentação APENAS no Neo4j
- **PROIBIDO** criar arquivos .md (exceto este CLAUDE.md)
- Toda documentação → Nós com label `Documentation`
- Todo conhecimento → Preservado no grafo

### 3. Zero Duplicação no Neo4j
```cypher
// Antes de adicionar, sempre:
MATCH (existing:Label {name: $name}) 
DELETE existing
CREATE (new:Label {name: $name, updated_at: datetime()})
```

### 4. Scripts .sh são Temporários
- Criar → Executar → Salvar no Neo4j → Deletar arquivo
- Preservar como `ScriptExecution` com código completo

### 5. Backup Obrigatório
- Antes de apagar QUALQUER coisa → Garantir que está no Neo4j
- Sistema de backup ZIP em `/memoria-neo4j-repo/`
- Comando: `./backup-manager.sh`

## 🔍 CONSULTAS ESSENCIAIS

```cypher
// Buscar antes de criar
MATCH (n) WHERE n.name CONTAINS $keyword RETURN n

// Ver todas as regras
MATCH (r:ProjectRules)-[:HAS_RULE]->(rule) RETURN rule

// Recuperar scripts removidos
MATCH (s:RemovedScript) RETURN s.name, s.useful_code

// Ver documentação
MATCH (d:Documentation) RETURN d.name, d.content
```

## ⚡ WORKFLOW CORRETO

1. **Consultar Neo4j** → Contexto
2. **Verificar duplicação** → Evitar redundância  
3. **Executar ação** → Fazer o necessário
4. **Preservar conhecimento** → Salvar no Neo4j
5. **Limpar temporários** → Remover .sh e .md

## 🚫 NUNCA FAZER

- ❌ Criar .md sem ser o CLAUDE.md
- ❌ Apagar sem salvar no Neo4j primeiro
- ❌ Duplicar informação no grafo
- ❌ Manter scripts .sh após uso
- ❌ Ignorar contexto existente

## ✅ SEMPRE FAZER

- ✔️ Consultar Neo4j PRIMEIRO
- ✔️ Preservar antes de deletar
- ✔️ Atualizar ao invés de duplicar
- ✔️ Documentar no grafo
- ✔️ Fazer backup regularmente

---
**Responder sempre em PT-BR**
**Este é o ÚNICO .md permitido no projeto**