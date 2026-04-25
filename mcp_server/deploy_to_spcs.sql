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

-- =====================================================
-- SPCS Setup Script for Soccer Graph Analytics
-- =====================================================
-- Execute these commands in Snowflake Web UI
--
-- NOTE: A least-privilege deployment role is recommended instead of
-- ACCOUNTADMIN. Uncomment and run the block below to create one:
--
-- USE ROLE ACCOUNTADMIN;
-- CREATE ROLE IF NOT EXISTS ONTOLOGY_DEPLOY_ROLE;
-- GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE ONTOLOGY_DEPLOY_ROLE;
-- GRANT CREATE DATABASE ON ACCOUNT TO ROLE ONTOLOGY_DEPLOY_ROLE;
-- GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ONTOLOGY_DEPLOY_ROLE;
-- GRANT OWNERSHIP ON DATABASE ONTOLOGY_DB TO ROLE ONTOLOGY_DEPLOY_ROLE;
-- GRANT ROLE ONTOLOGY_DEPLOY_ROLE TO USER <your_user>;
--
-- Then use:  USE ROLE ONTOLOGY_DEPLOY_ROLE;

USE ROLE ONTOLOGY_DEPLOY_ROLE;  -- or ACCOUNTADMIN if you have not created the role above
USE WAREHOUSE COMPUTE_WH;
USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- Step 1: Create Image Repository
CREATE OR REPLACE IMAGE REPOSITORY soccer_graph_analytics_repo
  COMMENT = 'Repository for soccer graph analytics service Docker images with NetworkX';

SHOW IMAGE REPOSITORIES;

-- Step 2: Create Compute Pool
DROP COMPUTE POOL IF EXISTS soccer_graph_compute_pool;

CREATE COMPUTE POOL soccer_graph_compute_pool
  MIN_NODES = 1
  MAX_NODES = 3
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  COMMENT = 'Compute pool for soccer graph analytics SPCS service with NetworkX';

-- Wait for compute pool to be ACTIVE before proceeding
SHOW COMPUTE POOLS;

-- Step 3: Create Stage for Service Specification
CREATE OR REPLACE STAGE soccer_graph_service_spec
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for soccer graph analytics service specification';

-- Upload service.yaml to the stage:
-- Option A: Using SnowSQL CLI: PUT file://service.yaml @soccer_graph_service_spec;
-- Option B: Upload manually via Snowflake UI: Data → Databases → ONTOLOGY_DB → SOCCER_KG → Stages → soccer_graph_service_spec

-- Verify upload
LIST @soccer_graph_service_spec;

-- Step 4: Create SPCS Service
DROP SERVICE IF EXISTS soccer_graph_analytics_service;

CREATE SERVICE soccer_graph_analytics_service
  IN COMPUTE POOL soccer_graph_compute_pool
  FROM @"ONTOLOGY_DB"."SOCCER_KG"."SOCCER_GRAPH_SERVICE_SPEC"
  SPECIFICATION_FILE = 'service.yaml'
  MIN_INSTANCES = 1
  MAX_INSTANCES = 2
  COMMENT = 'Snowpark Container Services for advanced soccer graph analytics using NetworkX';

-- Step 5: Verify Deployment
SHOW SERVICES;
SHOW ENDPOINTS IN SERVICE soccer_graph_analytics_service;
SHOW SERVICE CONTAINERS IN SERVICE soccer_graph_analytics_service;

-- View service logs
SELECT SYSTEM$GET_SERVICE_LOGS('soccer_graph_analytics_service', '0', 'mcp-server', 100);

-- View detailed logs (line by line)
SELECT value AS log_entry
FROM TABLE(
    SPLIT_TO_TABLE(
        SYSTEM$GET_SERVICE_LOGS('soccer_graph_analytics_service', '0', 'mcp-server'),
        '\n'
    )
);

-- Service management commands (use as needed)
-- ALTER SERVICE soccer_graph_analytics_service SUSPEND;
-- ALTER SERVICE soccer_graph_analytics_service RESUME;
-- DESCRIBE SERVICE soccer_graph_analytics_service;
