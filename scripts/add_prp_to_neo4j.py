#!/usr/bin/env python3
"""
Script para adicionar informações do PRP (Product Requirement Prompt) ao Neo4j
"""

import os
from datetime import datetime
from neo4j import GraphDatabase
import json

# Configurações do Neo4j
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USERNAME = os.getenv("NEO4J_USERNAME", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")
if not NEO4J_PASSWORD:
    print("Erro: NEO4J_PASSWORD não configurada no ambiente")
    sys.exit(1)
NEO4J_DATABASE = os.getenv("NEO4J_DATABASE", "neo4j")

class PRPNeo4jManager:
    def __init__(self):
        self.driver = GraphDatabase.driver(
            NEO4J_URI, 
            auth=(NEO4J_USERNAME, NEO4J_PASSWORD)
        )
    
    def close(self):
        self.driver.close()
    
    def clear_existing_prp(self, tx):
        """Remove dados PRP existentes para evitar duplicatas"""
        query = """
        MATCH (n:project {name: 'PRP Terminal Enhancement'})
        DETACH DELETE n
        """
        tx.run(query)
    
    def create_prp_nodes(self, tx):
        """Cria os nós principais do PRP"""
        
        # Criar nó do projeto PRP
        project_query = """
        CREATE (p:project {
            name: 'PRP Terminal Enhancement',
            description: 'Melhoria do Sistema de Acesso Remoto ao Terminal',
            status: 'active',
            created_at: datetime(),
            methodology: 'PRP',
            objetivo: 'Aprimorar o sistema de acesso remoto ao terminal para garantir confiabilidade, segurança e experiência de usuário superior'
        })
        RETURN p
        """
        result = tx.run(project_query)
        project = result.single()['p']
        
        # Criar nós das fases de implementação
        phases = [
            {
                "name": "Fase 1 - Reconexão Automática",
                "description": "Implementar reconexão automática com heartbeat",
                "status": "pending",
                "order": 1,
                "tasks": [
                    "Criar enhanced_websocket.py",
                    "Adicionar heartbeat/ping-pong", 
                    "Implementar lógica de reconexão com backoff exponencial"
                ]
            },
            {
                "name": "Fase 2 - Autenticação",
                "description": "Adicionar sistema de autenticação para terminal",
                "status": "pending",
                "order": 2,
                "tasks": [
                    "Criar sistema de tokens para terminal",
                    "Validar tokens em cada conexão",
                    "Implementar TTL e renovação"
                ]
            },
            {
                "name": "Fase 3 - Histórico Persistente",
                "description": "Implementar histórico de comandos persistente",
                "status": "pending",
                "order": 3,
                "tasks": [
                    "Criar modelo de banco de dados",
                    "Salvar cada comando executado",
                    "Implementar endpoint para recuperar histórico"
                ]
            },
            {
                "name": "Fase 4 - Interface de Status",
                "description": "Criar interface visual de status",
                "status": "pending",
                "order": 4,
                "tasks": [
                    "Adicionar mensagens de status estruturadas",
                    "Implementar indicadores visuais",
                    "Criar dashboard de monitoramento"
                ]
            }
        ]
        
        for phase in phases:
            phase_query = """
            CREATE (ph:phase {
                name: $name,
                description: $description,
                status: $status,
                order: $order,
                tasks: $tasks,
                created_at: datetime()
            })
            RETURN ph
            """
            phase_result = tx.run(phase_query, **phase)
            
            # Conectar fase ao projeto
            connect_query = """
            MATCH (p:project {name: 'PRP Terminal Enhancement'})
            MATCH (ph:phase {name: $phase_name})
            CREATE (p)-[:HAS_PHASE {order: $order}]->(ph)
            """
            tx.run(connect_query, phase_name=phase['name'], order=phase['order'])
        
        # Criar nós dos componentes técnicos
        components = [
            {
                "name": "EnhancedTerminalWebSocket",
                "type": "class",
                "file": "/home/codable/terminal/apps/api/app/claudable_terminal/enhanced_websocket.py",
                "description": "WebSocket melhorado com reconexão automática e heartbeat"
            },
            {
                "name": "TerminalAuth",
                "type": "class",
                "file": "/home/codable/terminal/apps/api/app/core/auth/terminal_auth.py",
                "description": "Autenticação para acesso remoto ao terminal"
            },
            {
                "name": "TerminalHistory",
                "type": "model",
                "file": "/home/codable/terminal/apps/api/app/models/terminal_history.py",
                "description": "Modelo de banco de dados para histórico de comandos"
            },
            {
                "name": "WebSocketManager",
                "type": "class",
                "file": "/home/codable/terminal/apps/api/app/core/websocket/manager.py",
                "description": "Gerenciador de conexões WebSocket existente"
            }
        ]
        
        for component in components:
            comp_query = """
            CREATE (c:component {
                name: $name,
                type: $type,
                file: $file,
                description: $description,
                created_at: datetime()
            })
            RETURN c
            """
            comp_result = tx.run(comp_query, **component)
            
            # Conectar componente ao projeto
            connect_comp_query = """
            MATCH (p:project {name: 'PRP Terminal Enhancement'})
            MATCH (c:component {name: $comp_name})
            CREATE (p)-[:USES_COMPONENT]->(c)
            """
            tx.run(connect_comp_query, comp_name=component['name'])
        
        # Criar nós de métricas de sucesso
        metrics = [
            {"name": "Tempo de Reconexão", "target": "< 2 segundos", "type": "performance"},
            {"name": "Taxa de Sucesso de Reconexão", "target": "> 95%", "type": "reliability"},
            {"name": "Latência de Comando", "target": "< 50ms", "type": "performance"},
            {"name": "Uptime do Serviço", "target": "> 99.9%", "type": "availability"},
            {"name": "Perda de Histórico", "target": "Zero", "type": "data_integrity"}
        ]
        
        for metric in metrics:
            metric_query = """
            CREATE (m:metric {
                name: $name,
                target: $target,
                type: $type,
                created_at: datetime()
            })
            RETURN m
            """
            metric_result = tx.run(metric_query, **metric)
            
            # Conectar métrica ao projeto
            connect_metric_query = """
            MATCH (p:project {name: 'PRP Terminal Enhancement'})
            MATCH (m:metric {name: $metric_name})
            CREATE (p)-[:HAS_METRIC]->(m)
            """
            tx.run(connect_metric_query, metric_name=metric['name'])
        
        # Criar nós de tecnologias utilizadas
        technologies = [
            {"name": "FastAPI", "type": "framework", "purpose": "WebSocket support"},
            {"name": "SQLAlchemy", "type": "orm", "purpose": "Persistência de dados"},
            {"name": "JWT", "type": "authentication", "purpose": "Tokens de autenticação"},
            {"name": "asyncio", "type": "library", "purpose": "Operações assíncronas"},
            {"name": "Docker", "type": "containerization", "purpose": "Sandboxing e isolamento"}
        ]
        
        for tech in technologies:
            tech_query = """
            CREATE (t:technology {
                name: $name,
                type: $type,
                purpose: $purpose,
                created_at: datetime()
            })
            RETURN t
            """
            tech_result = tx.run(tech_query, **tech)
            
            # Conectar tecnologia ao projeto
            connect_tech_query = """
            MATCH (p:project {name: 'PRP Terminal Enhancement'})
            MATCH (t:technology {name: $tech_name})
            CREATE (p)-[:USES_TECHNOLOGY]->(t)
            """
            tx.run(connect_tech_query, tech_name=tech['name'])
        
        # Criar nós de riscos identificados
        risks = [
            {
                "name": "Segurança - Execução de comandos",
                "severity": "high",
                "mitigation": "Implementar whitelist de comandos e sandboxing via Docker"
            },
            {
                "name": "Performance - Múltiplas conexões",
                "severity": "medium",
                "mitigation": "Pool de conexões e rate limiting por usuário"
            },
            {
                "name": "Estabilidade - Reconexões frequentes",
                "severity": "medium",
                "mitigation": "Backoff exponencial e circuit breaker pattern"
            }
        ]
        
        for risk in risks:
            risk_query = """
            CREATE (r:risk {
                name: $name,
                severity: $severity,
                mitigation: $mitigation,
                created_at: datetime()
            })
            RETURN r
            """
            risk_result = tx.run(risk_query, **risk)
            
            # Conectar risco ao projeto
            connect_risk_query = """
            MATCH (p:project {name: 'PRP Terminal Enhancement'})
            MATCH (r:risk {name: $risk_name})
            CREATE (p)-[:HAS_RISK]->(r)
            """
            tx.run(connect_risk_query, risk_name=risk['name'])
        
        print("✅ Nós do PRP criados com sucesso!")
        return project
    
    def create_relationships(self, tx):
        """Cria relacionamentos entre os nós do PRP"""
        
        # Relacionar fases sequencialmente
        phase_sequence_query = """
        MATCH (ph1:phase), (ph2:phase)
        WHERE ph1.order = ph2.order - 1
        CREATE (ph1)-[:PRECEDES]->(ph2)
        """
        tx.run(phase_sequence_query)
        
        # Relacionar componentes com fases específicas
        component_phase_relationships = [
            ("EnhancedTerminalWebSocket", "Fase 1 - Reconexão Automática"),
            ("TerminalAuth", "Fase 2 - Autenticação"),
            ("TerminalHistory", "Fase 3 - Histórico Persistente"),
            ("WebSocketManager", "Fase 1 - Reconexão Automática")
        ]
        
        for comp_name, phase_name in component_phase_relationships:
            rel_query = """
            MATCH (c:component {name: $comp_name})
            MATCH (ph:phase {name: $phase_name})
            CREATE (ph)-[:IMPLEMENTS_COMPONENT]->(c)
            """
            tx.run(rel_query, comp_name=comp_name, phase_name=phase_name)
        
        # Relacionar tecnologias com componentes
        tech_comp_relationships = [
            ("FastAPI", "EnhancedTerminalWebSocket"),
            ("JWT", "TerminalAuth"),
            ("SQLAlchemy", "TerminalHistory"),
            ("asyncio", "EnhancedTerminalWebSocket"),
            ("Docker", "TerminalAuth")
        ]
        
        for tech_name, comp_name in tech_comp_relationships:
            rel_query = """
            MATCH (t:technology {name: $tech_name})
            MATCH (c:component {name: $comp_name})
            CREATE (c)-[:USES]->(t)
            """
            tx.run(rel_query, tech_name=tech_name, comp_name=comp_name)
        
        # Relacionar riscos com fases
        risk_phase_relationships = [
            ("Segurança - Execução de comandos", "Fase 2 - Autenticação"),
            ("Performance - Múltiplas conexões", "Fase 1 - Reconexão Automática"),
            ("Estabilidade - Reconexões frequentes", "Fase 1 - Reconexão Automática")
        ]
        
        for risk_name, phase_name in risk_phase_relationships:
            rel_query = """
            MATCH (r:risk {name: $risk_name})
            MATCH (ph:phase {name: $phase_name})
            CREATE (ph)-[:ADDRESSES_RISK]->(r)
            """
            tx.run(rel_query, risk_name=risk_name, phase_name=phase_name)
        
        print("✅ Relacionamentos do PRP criados com sucesso!")
    
    def add_prp_to_neo4j(self):
        """Adiciona todas as informações do PRP ao Neo4j"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            # Limpar dados existentes
            session.execute_write(self.clear_existing_prp)
            
            # Criar nós
            session.execute_write(self.create_prp_nodes)
            
            # Criar relacionamentos
            session.execute_write(self.create_relationships)
            
            # Verificar o que foi criado
            result = session.run("""
                MATCH (p:project {name: 'PRP Terminal Enhancement'})
                OPTIONAL MATCH (p)-[r]-(connected)
                RETURN count(distinct connected) as connected_nodes
            """)
            
            record = result.single()
            print(f"\n📊 Estatísticas do grafo criado:")
            print(f"   - Nós conectados ao projeto: {record['connected_nodes']}")
            
            # Mostrar estrutura do grafo
            result = session.run("""
                MATCH (p:project {name: 'PRP Terminal Enhancement'})
                OPTIONAL MATCH (p)-[:HAS_PHASE]->(ph:phase)
                OPTIONAL MATCH (p)-[:USES_COMPONENT]->(c:component)
                OPTIONAL MATCH (p)-[:USES_TECHNOLOGY]->(t:technology)
                OPTIONAL MATCH (p)-[:HAS_METRIC]->(m:metric)
                OPTIONAL MATCH (p)-[:HAS_RISK]->(r:risk)
                RETURN 
                    count(distinct ph) as phases,
                    count(distinct c) as components,
                    count(distinct t) as technologies,
                    count(distinct m) as metrics,
                    count(distinct r) as risks
            """)
            
            record = result.single()
            print(f"   - Fases: {record['phases']}")
            print(f"   - Componentes: {record['components']}")
            print(f"   - Tecnologias: {record['technologies']}")
            print(f"   - Métricas: {record['metrics']}")
            print(f"   - Riscos: {record['risks']}")

def main():
    print("🚀 Iniciando adição do PRP ao Neo4j...")
    print(f"   URI: {NEO4J_URI}")
    print(f"   Database: {NEO4J_DATABASE}")
    
    manager = PRPNeo4jManager()
    
    try:
        manager.add_prp_to_neo4j()
        print("\n✅ PRP adicionado com sucesso ao Neo4j!")
        print("\n📌 Para visualizar o grafo:")
        print("   1. Acesse http://localhost:7474")
        print("   2. Execute: MATCH (p:project {name: 'PRP Terminal Enhancement'})-[r]-(n) RETURN p, r, n")
    except Exception as e:
        print(f"\n❌ Erro ao adicionar PRP ao Neo4j: {e}")
    finally:
        manager.close()

if __name__ == "__main__":
    main()