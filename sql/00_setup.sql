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
-- ONTOLOGY ON SNOWFLAKE - SETUP SCRIPT
-- Creates database and schema for the soccer knowledge graph
-- =====================================================

-- Create database
CREATE OR REPLACE DATABASE ONTOLOGY_DB;
USE DATABASE ONTOLOGY_DB;

-- Create schema
CREATE OR REPLACE SCHEMA SOCCER_KG;
USE SCHEMA SOCCER_KG;

-- Grant basic permissions (adjust as needed)
-- GRANT USAGE ON DATABASE ONTOLOGY_DB TO ROLE PUBLIC;
-- GRANT USAGE ON SCHEMA ONTOLOGY_DB.SOCCER_KG TO ROLE PUBLIC;

COMMENT ON DATABASE ONTOLOGY_DB IS 'Ontology on Snowflake - Soccer Knowledge Graph Demo';
COMMENT ON SCHEMA SOCCER_KG IS 'Soccer knowledge graph with ontology metadata layer';
