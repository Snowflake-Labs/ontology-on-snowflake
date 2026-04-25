-- Copyright 2026 Snowflake Inc.
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- ===============================================================
-- Service Functions for Cortex Agent Custom Tools
-- ===============================================================
-- Service Functions directly call SPCS endpoints with:
-- ✅ No Network Rules or External Access Integration needed
-- ✅ Automatic security and authentication
-- ✅ Direct internal communication
-- ===============================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- ===============================================================
-- STEP 1: Verify SPCS Service is Running
-- ===============================================================

SHOW SERVICES LIKE 'SOCCER_GRAPH_ANALYTICS_SERVICE';
SHOW ENDPOINTS IN SERVICE SOCCER_GRAPH_ANALYTICS_SERVICE;

-- ===============================================================
-- STEP 2: Create Service Functions (Cortex Agent Custom Tools)
-- ===============================================================

-- Tool 1: Shortest Path Analysis
CREATE OR REPLACE FUNCTION shortest_path_tool(
    source_id INTEGER,
    target_id INTEGER,
    graph_type STRING
)
RETURNS STRING
SERVICE = SOCCER_GRAPH_ANALYTICS_SERVICE
ENDPOINT = 'graph-api'
MAX_BATCH_ROWS = 1
AS '/shortest-path';

-- Tool 2: Centrality Analysis
CREATE OR REPLACE FUNCTION centrality_tool(
    graph_type STRING,
    analysis_type STRING,
    top_n INTEGER
)
RETURNS STRING
SERVICE = SOCCER_GRAPH_ANALYTICS_SERVICE
ENDPOINT = 'graph-api'
MAX_BATCH_ROWS = 1
AS '/centrality';

-- Tool 3: Community Detection
CREATE OR REPLACE FUNCTION community_detection_tool(
    graph_type STRING
)
RETURNS STRING
SERVICE = SOCCER_GRAPH_ANALYTICS_SERVICE
ENDPOINT = 'graph-api'
MAX_BATCH_ROWS = 1
AS '/community-detect';

-- Tool 4: Transfer Network Analysis
CREATE OR REPLACE FUNCTION transfer_analysis_tool(
    club_id INTEGER,
    player_id INTEGER,
    start_date STRING,
    end_date STRING
)
RETURNS STRING
SERVICE = SOCCER_GRAPH_ANALYTICS_SERVICE
ENDPOINT = 'graph-api'
MAX_BATCH_ROWS = 1
AS '/transfer-network';

-- Tool 5: Temporal Analysis
CREATE OR REPLACE FUNCTION temporal_analysis_tool(
    time_range STRING,
    analysis_type STRING
)
RETURNS STRING
SERVICE = SOCCER_GRAPH_ANALYTICS_SERVICE
ENDPOINT = 'graph-api'
MAX_BATCH_ROWS = 1
AS '/temporal-analysis';

-- ===============================================================
-- STEP 3: Grant Usage Permissions
-- ===============================================================

GRANT USAGE ON FUNCTION shortest_path_tool(INTEGER, INTEGER, STRING) TO ROLE PUBLIC;
GRANT USAGE ON FUNCTION centrality_tool(STRING, STRING, INTEGER) TO ROLE PUBLIC;
GRANT USAGE ON FUNCTION community_detection_tool(STRING) TO ROLE PUBLIC;
GRANT USAGE ON FUNCTION transfer_analysis_tool(INTEGER, INTEGER, STRING, STRING) TO ROLE PUBLIC;
GRANT USAGE ON FUNCTION temporal_analysis_tool(STRING, STRING) TO ROLE PUBLIC;

-- ===============================================================
-- STEP 4: Test Service Functions
-- ===============================================================

-- Test 1: Shortest Path
SELECT shortest_path_tool(1, 5, 'player') AS result;

-- Test 2: Centrality Analysis
SELECT centrality_tool('player', 'betweenness', 5) AS result;

-- Test 3: Community Detection
SELECT community_detection_tool('player') AS result;

-- Test 4: Transfer Analysis
SELECT transfer_analysis_tool(1, 0, '2024-01-01', '2025-12-31') AS result;

-- Test 5: Temporal Analysis
SELECT temporal_analysis_tool('2024-2025', 'evolution') AS result;

-- ===============================================================
-- STEP 5: Add Service Functions as Custom Tools to Cortex Agent
-- ===============================================================
-- Navigate to: Snowsight → AI & ML → Agents → [Your Agent] → Edit → Tools → Custom tools → Add
-- 
-- For each Service Function below, configure in Cortex Agent UI:

Tool 1: Shortest Path
---------------------
• Name: shortest_path
• Resource type: Function
• Custom tool identifier: ONTOLOGY_DB.SOCCER_KG.SHORTEST_PATH_TOOL
• Parameters:
  - source_id (INTEGER, required): "The ID of the source player or club"
  - target_id (INTEGER, required): "The ID of the target player or club"
  - graph_type (STRING, required): "Type of graph: 'player' or 'club'"
• Warehouse: COMPUTE_WH
• Description: "Use this tool to find the shortest path between two players or clubs in the soccer network. Specify source_id, target_id, and graph_type ('player' or 'club')."

Tool 2: Centrality Analysis
---------------------------
• Name: centrality_analysis
• Resource type: Function
• Custom tool identifier: ONTOLOGY_DB.SOCCER_KG.CENTRALITY_TOOL
• Parameters:
  - graph_type (STRING, required): "Type of graph: 'player' or 'club'"
  - analysis_type (STRING, required): "Centrality type: 'betweenness', 'degree', 'eigenvector', 'closeness'"
  - top_n (INTEGER, required): "Number of top results to return"
• Warehouse: COMPUTE_WH
• Description: "Use this tool to find the most influential players or clubs using centrality analysis. Specify graph_type, analysis_type (betweenness/degree/eigenvector/closeness), and top_n."

Tool 3: Community Detection
---------------------------
• Name: community_detection
• Resource type: Function
• Custom tool identifier: ONTOLOGY_DB.SOCCER_KG.COMMUNITY_DETECTION_TOOL
• Parameters:
  - graph_type (STRING, required): "Type of graph: 'player' or 'club'"
• Warehouse: COMPUTE_WH
• Description: "Use this tool to detect communities or groups in the player or club network. Specify graph_type ('player' or 'club')."

Tool 4: Transfer Analysis
-------------------------
• Name: transfer_analysis
• Resource type: Function
• Custom tool identifier: ONTOLOGY_DB.SOCCER_KG.TRANSFER_ANALYSIS_TOOL
• Parameters:
  - club_id (INTEGER, optional): "Club ID to analyze transfers for. Use 0 if not filtering by club."
  - player_id (INTEGER, optional): "Player ID to analyze transfers for. Use 0 if not filtering by player."
  - start_date (STRING, required): "Start date in YYYY-MM-DD format"
  - end_date (STRING, required): "End date in YYYY-MM-DD format"
• Warehouse: COMPUTE_WH
• Description: "Use this tool to analyze transfer history for a specific player or club within a date range. Provide club_id OR player_id (use 0 for unused parameter), start_date, and end_date."

Tool 5: Temporal Analysis
-------------------------
• Name: temporal_analysis
• Resource type: Function
• Custom tool identifier: ONTOLOGY_DB.SOCCER_KG.TEMPORAL_ANALYSIS_TOOL
• Parameters:
  - time_range (STRING, required): "Time range for analysis (e.g., '2024-2025')"
  - analysis_type (STRING, required): "Type of analysis: 'evolution' or 'trends'"
• Warehouse: COMPUTE_WH
• Description: "Use this tool to analyze how the player or club network has evolved over time. Specify time_range and analysis_type."

-- ===============================================================
-- STEP 6: Test Cortex Agent with Natural Language Queries
-- ===============================================================
-- Example questions to test your agent:
-- • "Find the shortest path between player 1 and player 5"
-- • "Who are the top 5 most influential players based on betweenness centrality?"
-- • "What communities exist in the player network?"
-- • "Show me the transfer history for club 1 from 2024 to 2025"
-- • "How has the player network evolved from 2024 to 2025?"

-- ===============================================================
-- Troubleshooting
-- ===============================================================
-- Service not responding:
--   SHOW SERVICES;
--   SHOW SERVICE CONTAINERS IN SERVICE SOCCER_GRAPH_ANALYTICS_SERVICE;
--   SELECT SYSTEM$GET_SERVICE_LOGS('SOCCER_GRAPH_ANALYTICS_SERVICE', '0', 'mcp-server', 100);
--
-- Verify endpoints:
--   SHOW ENDPOINTS IN SERVICE SOCCER_GRAPH_ANALYTICS_SERVICE;

