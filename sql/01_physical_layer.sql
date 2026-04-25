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
-- LAYER 1: PHYSICAL STORAGE LAYER
-- Universal node-and-edge model for the knowledge graph
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- KG_NODE: Entity storage table
-- Stores all entities (players, coaches, clubs, matches)
-- with flexible VARIANT properties
-- =====================================================
CREATE OR REPLACE TABLE KG_NODE (
    NODE_ID      STRING          NOT NULL,        -- stable global id
    NODE_TYPE    STRING          NOT NULL,        -- e.g., PLAYER | COACH | CLUB | MATCH
    NAME         STRING,                          -- common name attribute
    PROPS        VARIANT,                         -- type-specific JSON properties
    TS_INGESTED  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_KG_NODE PRIMARY KEY (NODE_ID)
)
CLUSTER BY (NODE_TYPE);

COMMENT ON TABLE KG_NODE IS 'All entities (players, coaches, clubs, matches).';

-- =====================================================
-- KG_EDGE: Relationship storage table
-- Stores all relationships between entities with
-- temporal validity (effective start/end dates)
-- =====================================================
CREATE OR REPLACE TABLE KG_EDGE (
    EDGE_ID          STRING          NOT NULL,      -- can be a hash of (src, dst, type, start)
    SRC_ID           STRING          NOT NULL,
    DST_ID           STRING          NOT NULL,
    EDGE_TYPE        STRING          NOT NULL,      -- e.g., PLAYS_FOR | COACHES | PLAYED_IN
    WEIGHT           FLOAT           DEFAULT 1.0,   -- relationship weight for graph algorithms
    PROPS            VARIANT,                       -- e.g., jersey_number, contract_value
    EFFECTIVE_START  DATE,                          -- temporal validity start
    EFFECTIVE_END    DATE,                          -- temporal validity end (NULL = current)
    TS_INGESTED      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_KG_EDGE PRIMARY KEY (EDGE_ID)
)
CLUSTER BY (EDGE_TYPE, SRC_ID, DST_ID);

COMMENT ON TABLE KG_EDGE IS 'All relationships between nodes; time-bounded where relevant.';
