#!/usr/bin/env python3

# Copyright 2026 Snowflake Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Soccer Knowledge Graph MCP Server
Implements MCP protocol server for graph analytics on soccer knowledge graph
"""

import asyncio
import logging
import sys
import os
from typing import Any, Dict, List, Optional
import json
import networkx as nx
import pandas as pd

# MCP imports - using FastMCP for simpler implementation
from mcp.server.fastmcp import FastMCP

# HTTP server imports for SPCS endpoints
from flask import Flask, request, jsonify
import threading

# Configure logging to stderr (required for MCP STDIO servers)
logging.basicConfig(level=logging.INFO, stream=sys.stderr)
logger = logging.getLogger(__name__)

class SoccerGraphLoader:
    """Loads and caches soccer knowledge graph data from static JSON files"""
    
    def __init__(self):
        self.graph_data = None
        self.player_graph = None
        self.club_graph = None
        self.match_graph = None
    
    def load_from_static_files(self, data_dir='/app/graph_data'):
        """Load graph data from static JSON files"""
        try:
            logger.info(f"Loading graph data from static files in {data_dir}")
            
            # Try multiple possible data directory locations
            possible_dirs = [
                data_dir,  # Default SPCS path
                '/app/graph_data',  # Docker container path
                os.path.join(os.path.dirname(__file__), 'graph_data'),  # Local development path
                'graph_data'  # Current directory
            ]
            
            data_dir_found = None
            for dir_path in possible_dirs:
                if os.path.exists(dir_path):
                    data_dir_found = dir_path
                    logger.info(f"Found graph data directory: {dir_path}")
                    break
            
            if not data_dir_found:
                logger.error(f"Data directory not found in any of: {possible_dirs}")
                return False
            
            # Load all JSON files
            tables = {
                'persons': 'persons.json',
                'clubs': 'clubs.json',
                'matches': 'matches.json',
                'player_contracts': 'player_contracts.json',
                'coach_contracts': 'coach_contracts.json',
                'match_appearances': 'match_appearances.json'
            }
            
            self.graph_data = {}
            
            for table_name, filename in tables.items():
                filepath = os.path.join(data_dir_found, filename)
                if not os.path.exists(filepath):
                    logger.error(f"Data file not found: {filepath}")
                    return False
                
                with open(filepath, 'r') as f:
                    data = json.load(f)
                
                # Convert to DataFrame
                df = pd.DataFrame(data)
                
                # Convert date columns back to datetime
                date_columns = ['DATE_OF_BIRTH', 'START_DATE', 'END_DATE', 'MATCH_DATE', 'CREATED_AT']
                for col in date_columns:
                    if col in df.columns:
                        df[col] = pd.to_datetime(df[col], errors='coerce')
                
                self.graph_data[table_name] = df
                logger.info(f"Loaded {len(df)} rows from {filename}")
            
            logger.info("✅ Successfully loaded all graph data from static files")
            return True
            
        except Exception as e:
            logger.error(f"Failed to load graph data from static files: {e}")
            return False
    
    def build_networks(self):
        """Build NetworkX graphs from loaded data"""
        try:
            # Build player network
            self.player_graph = nx.Graph()
            persons_df = self.graph_data['persons']
            player_contracts_df = self.graph_data['player_contracts']
            match_appearances_df = self.graph_data['match_appearances']
            
            # Add player nodes
            for _, person in persons_df[persons_df['ROLE'] == 'PLAYER'].iterrows():
                self.player_graph.add_node(
                    person['PERSON_ID'],
                    name=person['NAME'],
                    nationality=person['NATIONALITY'],
                    position=person['POSITION']
                )
            
            # Add teammate edges (same club)
            for _, contract in player_contracts_df.iterrows():
                club_id = contract['CLUB_ID']
                player_id = contract['PERSON_ID']
                
                # Find other players in same club
                other_contracts = player_contracts_df[
                    (player_contracts_df['CLUB_ID'] == club_id) & 
                    (player_contracts_df['PERSON_ID'] != player_id)
                ]
                
                for _, other_contract in other_contracts.iterrows():
                    other_player_id = other_contract['PERSON_ID']
                    if not self.player_graph.has_edge(player_id, other_player_id):
                        self.player_graph.add_edge(player_id, other_player_id, 
                                                 relationship='teammate', club_id=club_id)
            
            # Add match co-participation edges
            for _, appearance in match_appearances_df.iterrows():
                match_id = appearance['MATCH_ID']
                player_id = appearance['PERSON_ID']
                
                # Find other players in same match
                other_appearances = match_appearances_df[
                    (match_appearances_df['MATCH_ID'] == match_id) & 
                    (match_appearances_df['PERSON_ID'] != player_id)
                ]
                
                for _, other_appearance in other_appearances.iterrows():
                    other_player_id = other_appearance['PERSON_ID']
                    if not self.player_graph.has_edge(player_id, other_player_id):
                        self.player_graph.add_edge(player_id, other_player_id, 
                                                 relationship='match_co_participation', match_id=match_id)
            
            # Build club network
            self.club_graph = nx.Graph()
            clubs_df = self.graph_data['clubs']
            matches_df = self.graph_data['matches']
            
            # Add club nodes
            for _, club in clubs_df.iterrows():
                self.club_graph.add_node(
                    club['CLUB_ID'],
                    name=club['CLUB_NAME'],
                    country=club['COUNTRY'],
                    founded_year=club['FOUNDED_YEAR']
                )
            
            # Add match edges between clubs
            for _, match in matches_df.iterrows():
                home_club = match['HOME_CLUB_ID']
                away_club = match['AWAY_CLUB_ID']
                if not self.club_graph.has_edge(home_club, away_club):
                    self.club_graph.add_edge(home_club, away_club, 
                                          relationship='match', match_id=match['MATCH_ID'])
            
            # Add transfer edges between clubs
            for _, contract in player_contracts_df.iterrows():
                club_id = contract['CLUB_ID']
                player_id = contract['PERSON_ID']
                
                # Find other clubs this player has been at
                other_contracts = player_contracts_df[
                    (player_contracts_df['PERSON_ID'] == player_id) & 
                    (player_contracts_df['CLUB_ID'] != club_id)
                ]
                
                for _, other_contract in other_contracts.iterrows():
                    other_club_id = other_contract['CLUB_ID']
                    if not self.club_graph.has_edge(club_id, other_club_id):
                        self.club_graph.add_edge(club_id, other_club_id, 
                                               relationship='transfer', player_id=player_id)
            
            logger.info(f"Built player network with {self.player_graph.number_of_nodes()} nodes and {self.player_graph.number_of_edges()} edges")
            logger.info(f"Built club network with {self.club_graph.number_of_nodes()} nodes and {self.club_graph.number_of_edges()} edges")
            
            return True
        except Exception as e:
            logger.error(f"Failed to build networks: {e}")
            return False

# Initialize FastMCP server
mcp = FastMCP("soccer-graph-analytics")

# Constants
SERVICE_NAME = "soccer-graph-analytics"

# Global graph loader instance
graph_loader = SoccerGraphLoader()

# Helper functions
async def ensure_data_loaded():
    """Ensure graph data is loaded before processing"""
    if not graph_loader.graph_data:
        logger.info("Loading graph data from static files...")
        if not graph_loader.load_from_static_files():
            return False
        if not graph_loader.build_networks():
            return False
    return True

def format_centrality_results(results: list, analysis_type: str) -> str:
    """Format centrality analysis results as readable string"""
    formatted = f"Top {len(results)} entities by {analysis_type} centrality:\n\n"
    for i, result in enumerate(results, 1):
        formatted += f"{i}. {result['name']} (Score: {result['centrality_score']:.4f})\n"
    return formatted

def format_community_results(communities: list, graph_type: str) -> str:
    """Format community detection results as readable string"""
    formatted = f"Found {len(communities)} communities in {graph_type} network:\n\n"
    for i, community in enumerate(communities, 1):
        formatted += f"Community {i} ({community['size']} members):\n"
        for member in community['members'][:5]:  # Show first 5 members
            formatted += f"  - {member['name']}\n"
        if community['size'] > 5:
            formatted += f"  ... and {community['size'] - 5} more\n"
        formatted += "\n"
    return formatted
    
# FastMCP Tools - using decorators for automatic tool registration
@mcp.tool()
async def graph_shortest_path(source_id: int, target_id: int, graph_type: str = 'player') -> str:
    """Find shortest path between entities in the soccer knowledge graph.
    
    Args:
        source_id: Source entity ID
        target_id: Target entity ID  
        graph_type: Type of graph to analyze (player or club)
    """
    # Ensure data is loaded
    if not await ensure_data_loaded():
        return "Failed to load graph data from static files."
    
    if graph_type == 'player':
        graph = graph_loader.player_graph
    else:
        graph = graph_loader.club_graph
    
    if not graph:
        return "Graph not available. Please ensure data is loaded."
    
    if not graph.has_node(source_id) or not graph.has_node(target_id):
        return "Invalid source or target ID. Please check the entity IDs."
    
    try:
        path = nx.shortest_path(graph, source_id, target_id)
        path_details = []
        for node_id in path:
            node_data = graph.nodes[node_id]
            path_details.append({
                "id": node_id,
                "name": node_data.get('name', f"Node {node_id}"),
                "type": graph_type
            })
        
        # Format the result as a readable string
        path_names = [node["name"] for node in path_details]
        result = f"Shortest path from {path_names[0]} to {path_names[-1]}:\n"
        result += f"Path: {' -> '.join(path_names)}\n"
        result += f"Distance: {len(path) - 1} steps\n"
        result += f"Graph Type: {graph_type.title()}"
        
        return result
    except nx.NetworkXNoPath:
        return "No path found between the specified entities."

@mcp.tool()
async def graph_centrality_analysis(graph_type: str = 'player', analysis_type: str = 'betweenness', top_n: int = 10) -> str:
    """Analyze centrality measures for entities in the soccer knowledge graph.
    
    Args:
        graph_type: Type of graph to analyze (player or club)
        analysis_type: Type of centrality analysis (betweenness, closeness, degree, eigenvector)
        top_n: Number of top results to return
    """
    # Ensure data is loaded
    if not await ensure_data_loaded():
        return json.dumps({"error": "Failed to load graph data from static files."})
    
    if graph_type == 'player':
        graph = graph_loader.player_graph
    else:
        graph = graph_loader.club_graph
    
    if not graph:
        return json.dumps({"error": "Graph not available"})
    
    try:
        if analysis_type == 'betweenness':
            centrality = nx.betweenness_centrality(graph)
        elif analysis_type == 'closeness':
            centrality = nx.closeness_centrality(graph)
        elif analysis_type == 'degree':
            centrality = nx.degree_centrality(graph)
        elif analysis_type == 'eigenvector':
            centrality = nx.eigenvector_centrality(graph)
        else:
            return json.dumps({"error": "Invalid analysis type"})
        
        # Sort by centrality score
        sorted_centrality = sorted(centrality.items(), key=lambda x: x[1], reverse=True)
        top_results = []
        
        for node_id, score in sorted_centrality[:top_n]:
            node_data = graph.nodes[node_id]
            top_results.append({
                "id": node_id,
                "name": node_data.get('name', f"Node {node_id}"),
                "centrality_score": score,
                "type": graph_type
            })
        
        result = {
            "analysis_type": analysis_type,
            "graph_type": graph_type,
            "top_results": top_results
        }
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"error": f"Centrality analysis failed: {str(e)}"})

@mcp.tool()
async def graph_community_detection(graph_type: str = 'player') -> str:
    """Detect communities in the soccer knowledge graph.
    
    Args:
        graph_type: Type of graph to analyze (player or club)
    """
    # Ensure data is loaded
    if not await ensure_data_loaded():
        return json.dumps({"error": "Failed to load graph data from static files."})
    
    if graph_type == 'player':
        graph = graph_loader.player_graph
    else:
        graph = graph_loader.club_graph
    
    if not graph:
        return json.dumps({"error": "Graph not available"})
    
    try:
        # Use Louvain community detection
        communities = nx.community.louvain_communities(graph)
        community_results = []
        
        for i, community in enumerate(communities):
            community_members = []
            for node_id in community:
                node_data = graph.nodes[node_id]
                community_members.append({
                    "id": node_id,
                    "name": node_data.get('name', f"Node {node_id}"),
                    "type": graph_type
                })
            
            community_results.append({
                "community_id": i,
                "size": len(community),
                "members": community_members
            })
        
        result = {
            "graph_type": graph_type,
            "communities": community_results,
            "total_communities": len(communities)
        }
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"error": f"Community detection failed: {str(e)}"})

@mcp.tool()
async def graph_transfer_network_analysis(club_id: int = None, player_id: int = None, start_date: str = None, end_date: str = None) -> str:
    """Analyze transfer networks in the soccer knowledge graph.
    
    Args:
        club_id: Club ID for analysis
        player_id: Player ID for analysis
        start_date: Start date for analysis (YYYY-MM-DD)
        end_date: End date for analysis (YYYY-MM-DD)
    """
    # Ensure data is loaded
    if not await ensure_data_loaded():
        return json.dumps({"error": "Failed to load graph data from static files."})
    
    if not graph_loader.graph_data:
        return json.dumps({"error": "Graph data not available"})
    
    try:
        player_contracts_df = graph_loader.graph_data['player_contracts']
        persons_df = graph_loader.graph_data['persons']
        clubs_df = graph_loader.graph_data['clubs']
        
        # Filter by date range if provided
        if start_date and end_date:
            start_dt = pd.to_datetime(start_date)
            end_dt = pd.to_datetime(end_date)
            # Convert START_DATE column to datetime if it's not already
            player_contracts_df['START_DATE'] = pd.to_datetime(player_contracts_df['START_DATE'])
            player_contracts_df = player_contracts_df[
                (player_contracts_df['START_DATE'] >= start_dt) & 
                (player_contracts_df['START_DATE'] <= end_dt)
            ]
        
        # Analyze transfers for specific club
        if club_id:
            club_contracts = player_contracts_df[player_contracts_df['CLUB_ID'] == club_id]
            transfers = []
            
            for _, contract in club_contracts.iterrows():
                person_id = contract['PERSON_ID']
                person_data = persons_df[persons_df['PERSON_ID'] == person_id]
                if not person_data.empty:
                    transfers.append({
                        "player_id": person_id,
                        "player_name": person_data.iloc[0]['NAME'],
                        "start_date": str(contract['START_DATE']) if pd.notna(contract['START_DATE']) else None,
                        "end_date": str(contract['END_DATE']) if pd.notna(contract['END_DATE']) else None,
                        "contract_value": float(contract['CONTRACT_VALUE']) if pd.notna(contract['CONTRACT_VALUE']) else 0.0
                    })
            
            result = {
                "club_id": club_id,
                "transfers": transfers,
                "total_transfers": len(transfers)
            }
            return json.dumps(result)
        
        # Analyze transfers for specific player
        elif player_id:
            player_contracts = player_contracts_df[player_contracts_df['PERSON_ID'] == player_id]
            transfer_history = []
            
            for _, contract in player_contracts.iterrows():
                club_id = contract['CLUB_ID']
                club_data = clubs_df[clubs_df['CLUB_ID'] == club_id]
                if not club_data.empty:
                    transfer_history.append({
                        "club_id": club_id,
                        "club_name": club_data.iloc[0]['CLUB_NAME'],
                        "start_date": str(contract['START_DATE']) if pd.notna(contract['START_DATE']) else None,
                        "end_date": str(contract['END_DATE']) if pd.notna(contract['END_DATE']) else None,
                        "contract_value": float(contract['CONTRACT_VALUE']) if pd.notna(contract['CONTRACT_VALUE']) else 0.0
                    })
            
            result = {
                "player_id": player_id,
                "transfer_history": transfer_history,
                "total_clubs": len(transfer_history)
            }
            return json.dumps(result)
        
        else:
            return json.dumps({"error": "Either club_id or player_id must be provided"})
            
    except Exception as e:
        return json.dumps({"error": f"Transfer network analysis failed: {str(e)}"})

@mcp.tool()
async def graph_temporal_analysis(time_range: str, analysis_type: str = 'evolution') -> str:
    """Perform temporal analysis on the soccer knowledge graph.
    
    Args:
        time_range: Time range for analysis
        analysis_type: Type of temporal analysis (evolution, trends, patterns)
    """
    # Ensure data is loaded
    if not await ensure_data_loaded():
        return json.dumps({"error": "Failed to load graph data from static files."})
    
    if not graph_loader.graph_data:
        return json.dumps({"error": "Graph data not available"})
    
    try:
        if analysis_type == 'evolution':
            # Analyze network evolution over time
            player_contracts_df = graph_loader.graph_data['player_contracts']
            
            # Group by year to see evolution
            player_contracts_df['YEAR'] = pd.to_datetime(player_contracts_df['START_DATE']).dt.year
            yearly_stats = player_contracts_df.groupby('YEAR').agg({
                'PERSON_ID': 'nunique',
                'CLUB_ID': 'nunique',
                'CONTRACT_VALUE': 'sum'
            }).reset_index()
            
            evolution_data = []
            for _, row in yearly_stats.iterrows():
                evolution_data.append({
                    "year": int(row['YEAR']),
                    "unique_players": int(row['PERSON_ID']),
                    "unique_clubs": int(row['CLUB_ID']),
                    "total_contract_value": float(row['CONTRACT_VALUE']) if pd.notna(row['CONTRACT_VALUE']) else 0
                })
            
            result = {
                "analysis_type": "evolution",
                "time_range": time_range,
                "evolution_data": evolution_data
            }
            return json.dumps(result)
        
        elif analysis_type == 'trends':
            # Analyze transfer trends
            player_contracts_df = graph_loader.graph_data['player_contracts']
            clubs_df = graph_loader.graph_data['clubs']
            
            # Top clubs by number of transfers
            club_transfers = player_contracts_df.groupby('CLUB_ID').size().reset_index(name='transfer_count')
            club_transfers = club_transfers.merge(clubs_df[['CLUB_ID', 'CLUB_NAME']], on='CLUB_ID')
            top_clubs = club_transfers.nlargest(10, 'transfer_count')
            
            trends_data = []
            for _, row in top_clubs.iterrows():
                trends_data.append({
                    "club_id": int(row['CLUB_ID']),
                    "club_name": row['CLUB_NAME'],
                    "transfer_count": int(row['transfer_count'])
                })
            
            result = {
                "analysis_type": "trends",
                "time_range": time_range,
                "trends_data": trends_data
            }
            return json.dumps(result)
        
        else:
            return json.dumps({"error": "Invalid analysis type"})
            
    except Exception as e:
        return json.dumps({"error": f"Temporal analysis failed: {str(e)}"})
    
# HTTP endpoints for SPCS stored procedures
flask_app = Flask(__name__)

@flask_app.route('/shortest-path', methods=['POST'])
def shortest_path_endpoint():
    """HTTP endpoint for shortest path analysis (Snowflake Service Function format)"""
    try:
        payload = request.get_json() or {}
        
        # Service Functions send: {"data": [[row_number, source_id, target_id, graph_type]]}
        # Process the first row (Service Functions can send batches)
        row = payload['data'][0]
        
        # Extract arguments by position
        row_number = row[0]  # Snowflake row index
        source_id = row[1]   # First argument
        target_id = row[2]   # Second argument
        graph_type = row[3]  # Third argument
        
        # Call the graph analytics logic
        result = asyncio.run(graph_shortest_path(int(source_id), int(target_id), str(graph_type)))
        
        # Service Functions expect: {"data": [[row_number, result]]}
        response_data = {
            "data": [
                [row_number, result]
            ]
        }
        return jsonify(response_data)
        
    except (KeyError, IndexError) as e:
        # Malformed request
        return jsonify({"error": "Invalid request format", "details": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@flask_app.route('/community-detect', methods=['POST'])
def community_detection_endpoint():
    """HTTP endpoint for community detection (Snowflake Service Function format)"""
    try:
        payload = request.get_json() or {}
        
        # Service Functions send: {"data": [[row_number, graph_type]]}
        row = payload['data'][0]
        
        row_number = row[0]
        graph_type = row[1]
        
        # Call the graph analytics logic
        result = asyncio.run(graph_community_detection(str(graph_type)))
        
        # Return in Service Function format
        response_data = {
            "data": [
                [row_number, result]
            ]
        }
        return jsonify(response_data)
        
    except (KeyError, IndexError) as e:
        return jsonify({"error": "Invalid request format", "details": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@flask_app.route('/centrality', methods=['POST'])
def centrality_endpoint():
    """HTTP endpoint for centrality analysis (Snowflake Service Function format)"""
    try:
        payload = request.get_json() or {}
        
        # Service Functions send: {"data": [[row_number, graph_type, analysis_type, top_n]]}
        row = payload['data'][0]
        
        row_number = row[0]
        graph_type = row[1]
        analysis_type = row[2]
        top_n = row[3]
        
        # Call the graph analytics logic
        result = asyncio.run(graph_centrality_analysis(str(graph_type), str(analysis_type), int(top_n)))
        
        # Return in Service Function format
        response_data = {
            "data": [
                [row_number, result]
            ]
        }
        return jsonify(response_data)
        
    except (KeyError, IndexError) as e:
        return jsonify({"error": "Invalid request format", "details": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@flask_app.route('/transfer-network', methods=['POST'])
def transfer_network_endpoint():
    """HTTP endpoint for transfer network analysis (Snowflake Service Function format)"""
    try:
        payload = request.get_json() or {}
        
        # Service Functions send: {"data": [[row_number, club_id, player_id, start_date, end_date]]}
        row = payload['data'][0]
        
        row_number = row[0]
        club_id = row[1] if row[1] not in [None, 0] else None
        player_id = row[2] if row[2] not in [None, 0] else None
        start_date = row[3]
        end_date = row[4]
        
        # Call the graph analytics logic
        result = asyncio.run(graph_transfer_network_analysis(
            int(club_id) if club_id is not None else None,
            int(player_id) if player_id is not None else None,
            str(start_date) if start_date else None,
            str(end_date) if end_date else None
        ))
        
        # Return in Service Function format
        response_data = {
            "data": [
                [row_number, result]
            ]
        }
        return jsonify(response_data)
        
    except (KeyError, IndexError) as e:
        return jsonify({"error": "Invalid request format", "details": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@flask_app.route('/temporal-analysis', methods=['POST'])
def temporal_analysis_endpoint():
    """HTTP endpoint for temporal graph analysis (Snowflake Service Function format)"""
    try:
        payload = request.get_json() or {}
        
        # Service Functions send: {"data": [[row_number, time_range, analysis_type]]}
        row = payload['data'][0]
        
        row_number = row[0]
        time_range = row[1]
        analysis_type = row[2]
        
        # Call the graph analytics logic
        result = asyncio.run(graph_temporal_analysis(str(time_range), str(analysis_type)))
        
        # Return in Service Function format
        response_data = {
            "data": [
                [row_number, result]
            ]
        }
        return jsonify(response_data)
        
    except (KeyError, IndexError) as e:
        return jsonify({"error": "Invalid request format", "details": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@flask_app.route('/health', methods=['GET', 'POST'])
def health_endpoint():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "soccer-mcp-server"})

def run_http_server(host='0.0.0.0', port=5000):
    """Run HTTP server for SPCS endpoints"""
    flask_app.run(host=host, port=port, debug=False)

async def preload_graph_data():
    """Preload graph data at startup from static JSON files"""
    try:
        logger.info("Starting graph data preloading from static files...")
        
        # Load from static files (try multiple possible locations)
        if not graph_loader.load_from_static_files():
            return False
        
        # Build networks
        if not graph_loader.build_networks():
            return False
        
        logger.info("✅ Graph data preloaded successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to preload graph data: {e}")
        return False
    
# Main entry point for MCP server
def main():
    """Main entry point for the MCP server"""
    # Check if we should run HTTP server (for SPCS) or STDIO (for MCP)
    transport_mode = os.getenv('MCP_TRANSPORT', 'stdio')
    
    # Check if we should preload graph data
    should_preload = os.getenv('PRELOAD_ON_STARTUP', 'false').lower() == 'true'
    
    if should_preload:
        logger.info("Preloading graph data at startup...")
        try:
            if asyncio.run(preload_graph_data()):
                logger.info("✅ Graph data preloaded successfully")
            else:
                logger.warning("⚠️  Failed to preload graph data. Data will be loaded on first request.")
        except Exception as e:
            logger.warning(f"⚠️  Could not preload graph data: {e}. Data will be loaded on first request.")
    
    if transport_mode == 'http':
        # Run HTTP server for SPCS service functions
        logger.info("Starting HTTP server for SPCS endpoints on 0.0.0.0:5000")
        run_http_server()
    else:
        # Run STDIO server for MCP protocol using FastMCP
        logger.info("Starting STDIO server for MCP protocol")
        # Run the FastMCP server with STDIO transport
        mcp.run(transport='stdio')

if __name__ == "__main__":
    main()
