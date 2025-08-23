#!/usr/bin/env python3
"""
Script para consultar e verificar a documentação no Neo4j
"""

import os
from neo4j import GraphDatabase
from tabulate import tabulate

# Configurações do Neo4j
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USERNAME = os.getenv("NEO4J_USERNAME", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")
if not NEO4J_PASSWORD:
    print("Erro: NEO4J_PASSWORD não configurada no ambiente")
    sys.exit(1)
NEO4J_DATABASE = os.getenv("NEO4J_DATABASE", "neo4j")

class Neo4jDocsQuery:
    def __init__(self):
        self.driver = GraphDatabase.driver(
            NEO4J_URI,
            auth=(NEO4J_USERNAME, NEO4J_PASSWORD)
        )
    
    def close(self):
        self.driver.close()
    
    def query_clusters(self):
        """Lista todos os clusters de documentação"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            result = session.run("""
                MATCH (c:documentation:cluster)
                RETURN c.id as id, c.name as name, c.description as description
                ORDER BY c.order
            """)
            
            clusters = []
            for record in result:
                clusters.append([
                    record['id'],
                    record['name'],
                    record['description'][:50] + '...' if len(record['description']) > 50 else record['description']
                ])
            
            print("\n📁 CLUSTERS DE DOCUMENTAÇÃO:")
            print(tabulate(clusters, headers=['ID', 'Nome', 'Descrição'], tablefmt='grid'))
    
    def query_technologies(self):
        """Lista todas as tecnologias"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            result = session.run("""
                MATCH (t:documentation:technology)
                RETURN t.name as name, t.type as type, t.purpose as purpose
                ORDER BY t.name
            """)
            
            techs = []
            for record in result:
                techs.append([
                    record['name'],
                    record['type'],
                    record['purpose']
                ])
            
            print("\n🔧 TECNOLOGIAS:")
            print(tabulate(techs, headers=['Nome', 'Tipo', 'Propósito'], tablefmt='grid'))
    
    def query_prp_example(self):
        """Consulta o exemplo de PRP"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            result = session.run("""
                MATCH (prp:documentation:prp)
                OPTIONAL MATCH (prp)-[:HAS_PHASE]->(ph:documentation:phase)
                RETURN prp, collect(ph) as phases
            """)
            
            print("\n📋 EXEMPLO DE PRP:")
            for record in result:
                prp = record['prp']
                phases = record['phases']
                
                print(f"  Nome: {prp['name']}")
                print(f"  Objetivo: {prp['objective']}")
                print(f"  Justificativa: {prp['justification']}")
                print(f"  Valor para o usuário: {prp['user_value']}")
                
                if phases:
                    print("\n  📈 Fases de Implementação:")
                    for phase in sorted(phases, key=lambda x: x['order']):
                        print(f"    {phase['order']}. {phase['name']}")
    
    def query_relationships(self):
        """Analisa os relacionamentos no grafo"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            result = session.run("""
                MATCH (n:documentation)-[r]->(m:documentation)
                RETURN labels(n)[0] as from_type, type(r) as relationship, labels(m)[0] as to_type, count(*) as count
                ORDER BY count DESC
            """)
            
            rels = []
            for record in result:
                rels.append([
                    record['from_type'],
                    record['relationship'],
                    record['to_type'],
                    record['count']
                ])
            
            print("\n🔗 ANÁLISE DE RELACIONAMENTOS:")
            print(tabulate(rels, headers=['De', 'Relacionamento', 'Para', 'Quantidade'], tablefmt='grid'))
    
    def search_by_keyword(self, keyword):
        """Busca por palavra-chave em todos os nós"""
        with self.driver.session(database=NEO4J_DATABASE) as session:
            result = session.run("""
                MATCH (n:documentation)
                WHERE any(prop in keys(n) WHERE toString(n[prop]) CONTAINS $keyword)
                RETURN labels(n) as labels, n.name as name, 
                       [key in keys(n) WHERE toString(n[key]) CONTAINS $keyword | key] as matching_props
                LIMIT 10
            """, keyword=keyword)
            
            results = []
            for record in result:
                results.append([
                    ', '.join(record['labels']),
                    record['name'] if record['name'] else 'N/A',
                    ', '.join(record['matching_props'])
                ])
            
            if results:
                print(f"\n🔍 RESULTADOS PARA '{keyword}':")
                print(tabulate(results, headers=['Tipo', 'Nome', 'Propriedades'], tablefmt='grid'))
            else:
                print(f"\n❌ Nenhum resultado encontrado para '{keyword}'")
    
    def generate_report(self):
        """Gera relatório completo"""
        print("\n" + "="*60)
        print("📊 RELATÓRIO DA DOCUMENTAÇÃO NO NEO4J")
        print("="*60)
        
        self.query_clusters()
        self.query_technologies()
        self.query_prp_example()
        self.query_relationships()
        
        print("\n" + "="*60)
        print("✅ Relatório concluído!")

if __name__ == "__main__":
    import sys
    
    query = Neo4jDocsQuery()
    
    try:
        if len(sys.argv) > 1:
            # Se passou argumento, faz busca
            keyword = ' '.join(sys.argv[1:])
            query.search_by_keyword(keyword)
        else:
            # Senão, gera relatório completo
            query.generate_report()
    finally:
        query.close()