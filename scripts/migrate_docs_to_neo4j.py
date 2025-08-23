#!/usr/bin/env python3
"""
Script para migrar documentação PRP para o Neo4j
Baseado na metodologia PRP - 100% de contexto no projeto
"""

import os
import sys
from datetime import datetime
from neo4j import GraphDatabase
import json
from pathlib import Path

# Configurações do Neo4j
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USERNAME = os.getenv("NEO4J_USERNAME", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")
if not NEO4J_PASSWORD:
    print("Erro: NEO4J_PASSWORD não configurada no ambiente")
    sys.exit(1)
NEO4J_DATABASE = os.getenv("NEO4J_DATABASE", "neo4j")

class DocsToNeo4jMigrator:
    def __init__(self):
        try:
            self.driver = GraphDatabase.driver(
                NEO4J_URI, 
                auth=(NEO4J_USERNAME, NEO4J_PASSWORD)
            )
            print(f"✅ Conectado ao Neo4j: {NEO4J_URI}")
        except Exception as e:
            print(f"❌ Erro ao conectar ao Neo4j: {e}")
            sys.exit(1)
    
    def close(self):
        self.driver.close()
    
    def clear_existing_docs(self):
        """Remove documentação existente para evitar duplicatas"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            result = session.run("""
                MATCH (n:documentation)
                DETACH DELETE n
                RETURN count(n) as deleted
            """)
            deleted = result.single()['deleted']
            print(f"🗑️  Removidos {deleted} nós de documentação existentes")
    
    def create_documentation_structure(self):
        """Cria a estrutura base da documentação no Neo4j"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            # Criar nó raiz da documentação
            session.run("""
                CREATE (root:documentation:root {
                    name: 'PRP Documentation System',
                    description: 'Sistema de documentação baseado em PRP com 100% de contexto no Neo4j',
                    created_at: datetime(),
                    methodology: 'PRP',
                    version: '1.0.0'
                })
            """)
            print("✅ Criado nó raiz da documentação")
            
            # Estrutura de clusters da documentação
            clusters = [
                {
                    "id": "01",
                    "name": "Getting Started",
                    "description": "Guias de início rápido e configuração inicial",
                    "order": 1
                },
                {
                    "id": "02", 
                    "name": "Agent Architecture",
                    "description": "Arquitetura dos agentes e componentes do sistema",
                    "order": 2
                },
                {
                    "id": "03",
                    "name": "MCP Integration", 
                    "description": "Integração com MCP (Model Context Protocol)",
                    "order": 3
                },
                {
                    "id": "04",
                    "name": "PRP System",
                    "description": "Sistema de Product Requirement Prompts",
                    "order": 4
                },
                {
                    "id": "05",
                    "name": "Delegation Strategy",
                    "description": "Estratégia de delegação 100% MCP",
                    "order": 5
                },
                {
                    "id": "06",
                    "name": "Cleanup & Maintenance",
                    "description": "Limpeza e manutenção do sistema",
                    "order": 6
                },
                {
                    "id": "07",
                    "name": "Examples",
                    "description": "Exemplos práticos de uso",
                    "order": 7
                },
                {
                    "id": "08",
                    "name": "Reference",
                    "description": "Referência técnica e APIs",
                    "order": 8
                }
            ]
            
            for cluster in clusters:
                session.run("""
                    CREATE (c:documentation:cluster {
                        id: $id,
                        name: $name,
                        description: $description,
                        order: $order,
                        created_at: datetime()
                    })
                """, **cluster)
                
                # Conectar cluster ao root
                session.run("""
                    MATCH (root:documentation:root)
                    MATCH (c:documentation:cluster {id: $id})
                    CREATE (root)-[:HAS_CLUSTER {order: $order}]->(c)
                """, id=cluster['id'], order=cluster['order'])
            
            print(f"✅ Criados {len(clusters)} clusters de documentação")
    
    def add_prp_content(self):
        """Adiciona o conteúdo do PRP exemplo ao Neo4j"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            # Criar nó do PRP de exemplo
            prp_content = {
                "name": "Remote Terminal Enhancement PRP",
                "objective": "Aprimorar o sistema de acesso remoto ao terminal",
                "justification": "Sistema atual tem conexões WebSocket básicas sem reconexão automática",
                "user_value": "Acesso confiável ao terminal de qualquer lugar via navegador"
            }
            
            session.run("""
                CREATE (prp:documentation:prp {
                    name: $name,
                    objective: $objective,
                    justification: $justification,
                    user_value: $user_value,
                    created_at: datetime(),
                    type: 'example'
                })
            """, **prp_content)
            
            # Conectar ao cluster de exemplos
            session.run("""
                MATCH (c:documentation:cluster {id: '07'})
                MATCH (prp:documentation:prp {name: 'Remote Terminal Enhancement PRP'})
                CREATE (c)-[:CONTAINS_EXAMPLE]->(prp)
            """)
            
            # Adicionar fases de implementação
            phases = [
                {"name": "Reconexão Automática", "order": 1},
                {"name": "Autenticação", "order": 2},
                {"name": "Histórico Persistente", "order": 3},
                {"name": "Interface de Status", "order": 4}
            ]
            
            for phase in phases:
                session.run("""
                    CREATE (ph:documentation:phase {
                        name: $name,
                        order: $order,
                        created_at: datetime()
                    })
                """, **phase)
                
                session.run("""
                    MATCH (prp:documentation:prp {name: 'Remote Terminal Enhancement PRP'})
                    MATCH (ph:documentation:phase {name: $name})
                    CREATE (prp)-[:HAS_PHASE {order: $order}]->(ph)
                """, name=phase['name'], order=phase['order'])
            
            print("✅ Adicionado conteúdo do PRP exemplo")
    
    def add_standardization_docs(self):
        """Adiciona documentação de padronização"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            # Criar nó de padronização
            session.run("""
                CREATE (std:documentation:standard {
                    name: 'Documentation Standardization',
                    description: 'Padronização da documentação entre agentes',
                    benefits: ['Consistência arquitetural', 'Fácil navegação', 'Manutenção simplificada'],
                    created_at: datetime()
                })
            """)
            
            # Conectar ao cluster de arquitetura
            session.run("""
                MATCH (c:documentation:cluster {id: '02'})
                MATCH (std:documentation:standard {name: 'Documentation Standardization'})
                CREATE (c)-[:DEFINES_STANDARD]->(std)
            """)
            
            # Adicionar regras de sincronização
            rules = [
                {"type": "structure", "rule": "Mesmo número de clusters (8)"},
                {"type": "naming", "rule": "Prefixos numéricos (01-, 02-, etc.)"},
                {"type": "content", "rule": "Documentação específica do agente"}
            ]
            
            for rule in rules:
                session.run("""
                    CREATE (r:documentation:rule {
                        type: $type,
                        rule: $rule,
                        created_at: datetime()
                    })
                """, **rule)
                
                session.run("""
                    MATCH (std:documentation:standard {name: 'Documentation Standardization'})
                    MATCH (r:documentation:rule {rule: $rule})
                    CREATE (std)-[:HAS_RULE]->(r)
                """, rule=rule['rule'])
            
            print("✅ Adicionada documentação de padronização")
    
    def add_technologies(self):
        """Adiciona tecnologias utilizadas"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            technologies = [
                {"name": "Neo4j", "type": "database", "purpose": "Graph database para armazenamento"},
                {"name": "MCP", "type": "protocol", "purpose": "Model Context Protocol"},
                {"name": "FastAPI", "type": "framework", "purpose": "WebSocket support"},
                {"name": "Docker", "type": "containerization", "purpose": "Isolamento e deployment"}
            ]
            
            for tech in technologies:
                session.run("""
                    CREATE (t:documentation:technology {
                        name: $name,
                        type: $type,
                        purpose: $purpose,
                        created_at: datetime()
                    })
                """, **tech)
                
                # Conectar ao cluster de referência
                session.run("""
                    MATCH (c:documentation:cluster {id: '08'})
                    MATCH (t:documentation:technology {name: $name})
                    CREATE (c)-[:USES_TECHNOLOGY]->(t)
                """, name=tech['name'])
            
            print(f"✅ Adicionadas {len(technologies)} tecnologias")
    
    def create_relationships(self):
        """Cria relacionamentos entre os elementos da documentação"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            # Relacionar MCP com estratégia de delegação
            session.run("""
                MATCH (mcp:documentation:cluster {id: '03'})
                MATCH (delegation:documentation:cluster {id: '05'})
                CREATE (mcp)-[:ENABLES]->(delegation)
            """)
            
            # Relacionar PRP system com exemplos
            session.run("""
                MATCH (prp:documentation:cluster {id: '04'})
                MATCH (examples:documentation:cluster {id: '07'})
                CREATE (prp)-[:HAS_EXAMPLES_IN]->(examples)
            """)
            
            print("✅ Criados relacionamentos entre elementos")
    
    def generate_summary(self):
        """Gera resumo da migração"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            result = session.run("""
                MATCH (n:documentation)
                RETURN 
                    count(n) as total_nodes,
                    count(DISTINCT CASE WHEN 'cluster' IN labels(n) THEN n END) as clusters,
                    count(DISTINCT CASE WHEN 'prp' IN labels(n) THEN n END) as prps,
                    count(DISTINCT CASE WHEN 'technology' IN labels(n) THEN n END) as technologies,
                    count(DISTINCT CASE WHEN 'phase' IN labels(n) THEN n END) as phases,
                    count(DISTINCT CASE WHEN 'rule' IN labels(n) THEN n END) as rules
            """)
            
            stats = result.single()
            
            print("\n" + "="*50)
            print("📊 RESUMO DA MIGRAÇÃO")
            print("="*50)
            print(f"📦 Total de nós criados: {stats['total_nodes']}")
            print(f"📁 Clusters: {stats['clusters']}")
            print(f"📋 PRPs: {stats['prps']}")
            print(f"🔧 Tecnologias: {stats['technologies']}")
            print(f"📈 Fases: {stats['phases']}")
            print(f"📏 Regras: {stats['rules']}")
            print("="*50)
            
            # Verificar relacionamentos
            rel_result = session.run("""
                MATCH ()-[r]->()
                WHERE type(r) IN ['HAS_CLUSTER', 'CONTAINS_EXAMPLE', 'HAS_PHASE', 
                                  'DEFINES_STANDARD', 'HAS_RULE', 'USES_TECHNOLOGY', 
                                  'ENABLES', 'HAS_EXAMPLES_IN']
                RETURN type(r) as relationship, count(r) as count
                ORDER BY count DESC
            """)
            
            print("\n🔗 RELACIONAMENTOS CRIADOS:")
            for record in rel_result:
                print(f"  - {record['relationship']}: {record['count']}")
            print("="*50)
    
    def migrate(self):
        """Executa a migração completa"""
        try:
            print("\n🚀 Iniciando migração da documentação para Neo4j...")
            print(f"📍 Conectando a: {NEO4J_URI}")
            print(f"📁 Database: {NEO4J_DATABASE}")
            print("-"*50)
            
            # Limpar dados existentes
            self.clear_existing_docs()
            
            # Criar estrutura
            self.create_documentation_structure()
            
            # Adicionar conteúdo
            self.add_prp_content()
            self.add_standardization_docs()
            self.add_technologies()
            
            # Criar relacionamentos
            self.create_relationships()
            
            # Gerar resumo
            self.generate_summary()
            
            print("\n✅ Migração concluída com sucesso!")
            print("💡 Use o Neo4j Browser para visualizar o grafo em: http://localhost:7474")
            
        except Exception as e:
            print(f"\n❌ Erro durante a migração: {e}")
            raise
        finally:
            self.close()

if __name__ == "__main__":
    migrator = DocsToNeo4jMigrator()
    migrator.migrate()