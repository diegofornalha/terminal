# DIRETRIZES DO PROJETO TERMINAL 

garanta que toda a documentação do neo4j esteja em pt br

sempre que for criar algum arquivo não é pra gerar ele na raiz do projeto e sim na sua devida pasta 

investigue e leia cada arquivo pra entender ao tentar resolver um problema vc precisa ter contexto 100%, vai no detalhe e não se preoculpe em terminar logo, garanta que vai fazer exatamente o que eu te pedi.           

## 🧠 REGRA PRINCIPAL: Neo4j é a Fonte da Verdade
SEMPRE consulte o Neo4j antes de qualquer ação para ter contexto completo.

## 🎯 MATRIZ DE DECISÃO DO ORCHESTRATOR

### Detecção Automática de Padrões → Ativação de Sub-Agentes
| **Padrão Detectado** | **Sub-Agente Ativado** | **Trigger** |
|---------------------|------------------------|-------------|
| "complexo demais", "muitas camadas", "abstração" | 🔧 `layer-simplifier` | >2 intermediários detectados |
| "limpar neo4j", "muitos nós", "complexidade" | 🧹 `neo4j-cleaner` | >100 nós no grafo |
| "vale a pena?", "muito trabalho", "pouco retorno" | 💰 `roi-guardian` | ROI < 10% |
| "tutorial", "documentação", "explicar" | 🥷 `mcp-shadow-agent` | Sempre ativo silenciosamente |
| "monitorar", "automático", "contínuo" | 🤖 `mcp-autonomous-agent` | Modo autônomo |

### Fluxo de Interceptação
1. **UserPromptSubmit Hook** → Intercepta TODOS os prompts
2. **Orchestrator Master** → Analisa e decide
3. **Consulta Neo4j** → Busca contexto relevante
4. **Aplica CLAUDE.md** → Segue diretrizes
5. **Ativa Sub-Agentes** → Conforme padrões detectados

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

## 🎯 PRINCÍPIO DO EQUILÍBRIO (SABER QUANDO PARAR)

### Reconhecer o Ponto de Saturação Produtiva
**FUNDAMENTAL**: Saber identificar quando o sistema está suficientemente bom e parar antes de complicar desnecessariamente.

#### Sinais de que é hora de PARAR:
- ✅ Funcionalidade principal implementada e funcionando
- ✅ Sistema estável e operacional
- ✅ Benefício marginal < Complexidade adicional
- ✅ Risco de "overengineering" presente

#### Filosofia:
> "A perfeição não é quando não há mais nada para adicionar, mas quando não há mais nada para remover." - Antoine de Saint-Exupéry

### Diretrizes Práticas:
1. **95% é melhor que 100% complexo** - Um sistema 95% completo e simples é melhor que 100% completo e impossível de manter
2. **KISS (Keep It Simple, Stupid)** - Simplicidade sempre vence complexidade desnecessária
3. **ROI decrescente** - Quando o retorno sobre investimento de tempo/esforço diminui drasticamente, PARE
4. **Manutenibilidade > Perfeição** - Código simples que outros entendem > código "perfeito" que só você entende

### Aplicação:
- Avaliar constantemente: "Isso REALMENTE adiciona valor?"
- Preferir iterações futuras vs perfeição imediata
- Documentar o que foi feito e PARAR quando estiver BOM O SUFICIENTE

---
**Responder sempre em PT-BR**
**Este é o ÚNICO .md permitido no projeto**