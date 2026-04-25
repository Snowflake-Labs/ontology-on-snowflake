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
-- SEED DATA: ONTOLOGY METADATA
-- Populates the ontology metadata tables
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- ONTOLOGY REGISTRY
-- =====================================================
INSERT INTO ONT_ONTOLOGY (ONTOLOGY_NAME, VERSION, DESCRIPTION, DEFAULT_SCHEMA, CREATED_BY, IS_ACTIVE)
VALUES ('SOCCER_V1', '1.0.0', 'Soccer Knowledge Graph Ontology', 'SOCCER_KG', 'SYSTEM', TRUE);

-- =====================================================
-- SHARED PROPERTIES
-- Reusable property definitions across classes
-- =====================================================
INSERT INTO ONT_SHARED_PROPERTY (SHARED_PROP_NAME, BASE_TYPE, DESCRIPTION, DEFAULT_FORMAT) VALUES
('identity', 'STRING', 'Unique identifier for any entity', NULL),
('temporal_start', 'DATE', 'Start date for time-bounded entities', 'YYYY-MM-DD'),
('temporal_end', 'DATE', 'End date for time-bounded entities', 'YYYY-MM-DD'),
('name', 'STRING', 'Display name', NULL),
('nationality', 'STRING', 'Country of nationality', NULL),
('currency_value', 'NUMBER', 'Monetary value in USD', '#,##0.00');

-- =====================================================
-- ABSTRACT CLASSES
-- =====================================================
INSERT INTO ONT_CLASS (CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT, DESCRIPTION, ONTOLOGY_NAME, TYPE_CLASS, STATUS) VALUES
('Thing', NULL, TRUE, 'Root class for all entities', 'SOCCER_V1', 'ABSTRACT', 'ACTIVE'),
('Person', 'Thing', TRUE, 'Any human individual', 'SOCCER_V1', 'ABSTRACT', 'ACTIVE'),
('Organization', 'Thing', TRUE, 'Any organizational entity', 'SOCCER_V1', 'ABSTRACT', 'ACTIVE'),
('Event', 'Thing', TRUE, 'Any temporal occurrence', 'SOCCER_V1', 'ABSTRACT', 'ACTIVE');

-- =====================================================
-- CONCRETE CLASSES
-- =====================================================
INSERT INTO ONT_CLASS (CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT, DESCRIPTION, ONTOLOGY_NAME, TYPE_CLASS, STATUS) VALUES
('Player', 'Person', FALSE, 'Professional soccer player', 'SOCCER_V1', 'OPERATIONAL', 'ACTIVE'),
('Coach', 'Person', FALSE, 'Professional soccer coach', 'SOCCER_V1', 'OPERATIONAL', 'ACTIVE'),
('Club', 'Organization', FALSE, 'Professional soccer club', 'SOCCER_V1', 'OPERATIONAL', 'ACTIVE'),
('Match', 'Event', FALSE, 'Soccer match event', 'SOCCER_V1', 'OPERATIONAL', 'ACTIVE');

-- =====================================================
-- CLASS PROPERTIES
-- =====================================================
-- Person properties
INSERT INTO ONT_PROPERTY (CLASS_NAME, PROP_NAME, DATA_TYPE, SHARED_PROP_NAME, IS_REQUIRED, IS_INDEXED, DESCRIPTION) VALUES
('Person', 'name', 'STRING', 'name', TRUE, TRUE, 'Full name of the person'),
('Person', 'nationality', 'STRING', 'nationality', FALSE, TRUE, 'Country of nationality');

-- Player properties
INSERT INTO ONT_PROPERTY (CLASS_NAME, PROP_NAME, DATA_TYPE, SHARED_PROP_NAME, IS_REQUIRED, IS_INDEXED, DESCRIPTION) VALUES
('Player', 'position', 'STRING', NULL, FALSE, TRUE, 'Playing position'),
('Player', 'birthdate', 'DATE', NULL, FALSE, FALSE, 'Date of birth'),
('Player', 'market_value', 'NUMBER', 'currency_value', FALSE, FALSE, 'Current market value');

-- Coach properties
INSERT INTO ONT_PROPERTY (CLASS_NAME, PROP_NAME, DATA_TYPE, SHARED_PROP_NAME, IS_REQUIRED, IS_INDEXED, DESCRIPTION) VALUES
('Coach', 'license_level', 'STRING', NULL, FALSE, FALSE, 'Coaching license level');

-- Club properties
INSERT INTO ONT_PROPERTY (CLASS_NAME, PROP_NAME, DATA_TYPE, SHARED_PROP_NAME, IS_REQUIRED, IS_INDEXED, DESCRIPTION) VALUES
('Club', 'name', 'STRING', 'name', TRUE, TRUE, 'Official club name'),
('Club', 'country', 'STRING', 'nationality', FALSE, TRUE, 'Country of registration'),
('Club', 'league', 'STRING', NULL, FALSE, TRUE, 'Current league competition'),
('Club', 'stadium', 'STRING', NULL, FALSE, FALSE, 'Home stadium name'),
('Club', 'founded_year', 'INTEGER', NULL, FALSE, FALSE, 'Year the club was founded');

-- Match properties
INSERT INTO ONT_PROPERTY (CLASS_NAME, PROP_NAME, DATA_TYPE, SHARED_PROP_NAME, IS_REQUIRED, IS_INDEXED, DESCRIPTION) VALUES
('Match', 'name', 'STRING', 'name', FALSE, FALSE, 'Match description'),
('Match', 'event_date', 'DATE', 'temporal_start', TRUE, TRUE, 'Date of the match'),
('Match', 'venue', 'STRING', NULL, FALSE, FALSE, 'Match venue'),
('Match', 'competition', 'STRING', NULL, FALSE, TRUE, 'Competition name'),
('Match', 'score_home', 'INTEGER', NULL, FALSE, FALSE, 'Home team score'),
('Match', 'score_away', 'INTEGER', NULL, FALSE, FALSE, 'Away team score');

-- =====================================================
-- RELATIONSHIP DEFINITIONS
-- =====================================================
INSERT INTO ONT_RELATION_DEF (REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, ONTOLOGY_NAME, STATUS, RENDER_HINT) VALUES
-- Abstract relationships
('works_for', 'Person', 'Organization', 'N:1', FALSE, 'employs', 'Person works for an organization', 'SOCCER_V1', 'ACTIVE', 'directed'),
('participates_in', 'Person', 'Event', 'N:N', FALSE, 'has_participant', 'Person participates in an event', 'SOCCER_V1', 'ACTIVE', 'directed'),
('affiliated_with', 'Organization', 'Event', 'N:N', FALSE, 'involves', 'Organization is affiliated with an event', 'SOCCER_V1', 'ACTIVE', 'directed'),

-- Concrete relationships
('PLAYS_FOR', 'Player', 'Club', 'N:1', FALSE, 'HAS_PLAYER', 'Player plays for a club', 'SOCCER_V1', 'ACTIVE', 'directed'),
('COACHES', 'Coach', 'Club', 'N:1', FALSE, 'HAS_COACH', 'Coach coaches a club', 'SOCCER_V1', 'ACTIVE', 'directed'),
('PLAYED_IN', 'Player', 'Match', 'N:N', FALSE, 'HAS_PLAYER', 'Player played in a match', 'SOCCER_V1', 'ACTIVE', 'directed'),
('HOME_TEAM', 'Club', 'Match', '1:N', FALSE, 'HOSTED_BY', 'Club plays as home team', 'SOCCER_V1', 'ACTIVE', 'directed'),
('AWAY_TEAM', 'Club', 'Match', '1:N', FALSE, 'VISITED_BY', 'Club plays as away team', 'SOCCER_V1', 'ACTIVE', 'directed');

-- =====================================================
-- CLASS MAPPINGS (Abstract -> Concrete)
-- =====================================================
INSERT INTO ONT_CLASS_MAP (CLASS_NAME, CONCRETE_VIEW, ID_COL, SUBTYPE_VALUE) VALUES
('Player', 'V_PLAYER', 'NODE_ID', 'Player'),
('Coach', 'V_COACH', 'NODE_ID', 'Coach'),
('Club', 'V_CLUB', 'NODE_ID', 'Club'),
('Match', 'V_MATCH', 'NODE_ID', 'Match'),
('Person', 'V_PLAYER', 'NODE_ID', 'Player'),
('Person', 'V_COACH', 'NODE_ID', 'Coach'),
('Organization', 'V_CLUB', 'NODE_ID', 'Club'),
('Event', 'V_MATCH', 'NODE_ID', 'Match');

-- =====================================================
-- RELATIONSHIP MAPPINGS (Abstract -> Concrete)
-- =====================================================
INSERT INTO ONT_REL_MAP (REL_NAME, CONCRETE_VIEW, SRC_COL, DST_COL, PROPS_COL, VIA_REL_VALUE) VALUES
('PLAYS_FOR', 'V_PLAYS_FOR', 'PLAYER_ID', 'CLUB_ID', 'PROPS', 'PLAYS_FOR'),
('COACHES', 'V_COACHES', 'COACH_ID', 'CLUB_ID', 'PROPS', 'COACHES'),
('PLAYED_IN', 'V_PLAYED_IN', 'PLAYER_ID', 'MATCH_ID', 'PROPS', 'PLAYED_IN'),
('HOME_TEAM', 'V_HOME_TEAM', 'CLUB_ID', 'MATCH_ID', 'PROPS', 'HOME_TEAM'),
('AWAY_TEAM', 'V_AWAY_TEAM', 'CLUB_ID', 'MATCH_ID', 'PROPS', 'AWAY_TEAM'),
('works_for', 'V_PLAYS_FOR', 'PLAYER_ID', 'CLUB_ID', 'PROPS', 'PLAYS_FOR'),
('works_for', 'V_COACHES', 'COACH_ID', 'CLUB_ID', 'PROPS', 'COACHES'),
('participates_in', 'V_PLAYED_IN', 'PLAYER_ID', 'MATCH_ID', 'PROPS', 'PLAYED_IN'),
('affiliated_with', 'V_HOME_TEAM', 'CLUB_ID', 'MATCH_ID', 'PROPS', 'HOME_TEAM'),
('affiliated_with', 'V_AWAY_TEAM', 'CLUB_ID', 'MATCH_ID', 'PROPS', 'AWAY_TEAM');

-- =====================================================
-- INTERFACES
-- =====================================================
INSERT INTO ONT_INTERFACE (INTERFACE_NAME, DESCRIPTION) VALUES
('Named', 'Entities that have a name property'),
('Temporal', 'Entities with temporal validity'),
('Locatable', 'Entities with location information');

INSERT INTO ONT_INTERFACE_PROPERTY (INTERFACE_NAME, PROP_NAME, SHARED_PROP_NAME) VALUES
('Named', 'name', 'name'),
('Temporal', 'effective_start', 'temporal_start'),
('Temporal', 'effective_end', 'temporal_end'),
('Locatable', 'country', 'nationality');

INSERT INTO ONT_INTERFACE_IMPL (INTERFACE_NAME, CLASS_NAME) VALUES
('Named', 'Person'),
('Named', 'Organization'),
('Named', 'Event'),
('Temporal', 'Match'),
('Locatable', 'Person'),
('Locatable', 'Organization');

-- =====================================================
-- INFERENCE RULES
-- =====================================================
INSERT INTO ONT_RULE (RULE_ID, RULE_KIND, TARGET_REL, SOURCE_REL_1, SOURCE_REL_2, INVERSE_OF, IS_ENABLED, DESCRIPTION) VALUES
('RULE_INV_001', 'INVERSE', 'HAS_PLAYER', NULL, NULL, 'PLAYS_FOR', TRUE, 'Infer HAS_PLAYER from PLAYS_FOR'),
('RULE_INV_002', 'INVERSE', 'HAS_COACH', NULL, NULL, 'COACHES', TRUE, 'Infer HAS_COACH from COACHES'),
('RULE_INV_003', 'INVERSE', 'employs', NULL, NULL, 'works_for', TRUE, 'Infer employs from works_for');

-- =====================================================
-- ACTION TYPES
-- =====================================================
INSERT INTO ACT_TYPE (ACTION_TYPE_ID, ACTION_NAME, DESCRIPTION, ONTOLOGY_NAME, TARGET_CLASS, HANDLER_PROC, IS_ENABLED) VALUES
('ACT_TRANSFER', 'Transfer Player', 'Transfer a player to a new club', 'SOCCER_V1', 'Player', 'SP_TRANSFER_PLAYER', TRUE),
('ACT_HIRE_COACH', 'Hire Coach', 'Hire a coach for a club', 'SOCCER_V1', 'Coach', 'SP_HIRE_COACH', TRUE),
('ACT_RECORD_MATCH', 'Record Match', 'Record a match result', 'SOCCER_V1', 'Match', 'SP_RECORD_MATCH', TRUE);

INSERT INTO ACT_DEF (ACTION_TYPE_ID, PARAM_NAME, PARAM_TYPE, IS_REQUIRED, DESCRIPTION) VALUES
('ACT_TRANSFER', 'player_id', 'STRING', TRUE, 'ID of the player to transfer'),
('ACT_TRANSFER', 'from_club_id', 'STRING', TRUE, 'ID of the source club'),
('ACT_TRANSFER', 'to_club_id', 'STRING', TRUE, 'ID of the destination club'),
('ACT_TRANSFER', 'transfer_fee', 'NUMBER', FALSE, 'Transfer fee amount'),
('ACT_TRANSFER', 'contract_value', 'NUMBER', FALSE, 'New contract value'),
('ACT_HIRE_COACH', 'coach_id', 'STRING', TRUE, 'ID of the coach'),
('ACT_HIRE_COACH', 'club_id', 'STRING', TRUE, 'ID of the club'),
('ACT_HIRE_COACH', 'contract_value', 'NUMBER', FALSE, 'Contract value');

-- =====================================================
-- FUNCTIONS
-- =====================================================
INSERT INTO ONT_FUNCTION (ONTOLOGY_NAME, FUNCTION_NAME, VERSION, LANGUAGE, SNOWFLAKE_REF, DESCRIPTION, INPUT_SCHEMA, OUTPUT_SCHEMA) VALUES
('SOCCER_V1', 'calculate_age', '1.0', 'SQL', 'FN_CALCULATE_AGE', 'Calculate age from birthdate', 
 PARSE_JSON('{"birthdate": "DATE"}'), 
 PARSE_JSON('{"age": "INTEGER"}')),
('SOCCER_V1', 'graph_shortest_path', '1.0', 'PYTHON', 'SP_GRAPH_SHORTEST_PATH', 'Find shortest path between two nodes',
 PARSE_JSON('{"source_id": "STRING", "target_id": "STRING", "rel_types": "ARRAY"}'),
 PARSE_JSON('{"path": "ARRAY", "length": "INTEGER"}')),
('SOCCER_V1', 'graph_centrality', '1.0', 'PYTHON', 'SP_GRAPH_CENTRALITY', 'Calculate centrality metrics for nodes',
 PARSE_JSON('{"centrality_type": "STRING", "node_type": "STRING"}'),
 PARSE_JSON('{"results": "ARRAY"}'));

INSERT INTO ONT_FUNCTION_BINDING (ONTOLOGY_NAME, FUNCTION_NAME, VERSION, BOUND_TO_KIND, BOUND_TO_NAME) VALUES
('SOCCER_V1', 'calculate_age', '1.0', 'OBJECT_TYPE', 'Player'),
('SOCCER_V1', 'graph_shortest_path', '1.0', 'LINK_TYPE', 'works_for'),
('SOCCER_V1', 'graph_centrality', '1.0', 'OBJECT_TYPE', 'Player');

-- =====================================================
-- ROLES AND PERMISSIONS
-- =====================================================
INSERT INTO ONT_ROLE (ONTOLOGY_NAME, ONT_ROLE_NAME, DESCRIPTION) VALUES
('SOCCER_V1', 'viewer', 'Read-only access to all entities'),
('SOCCER_V1', 'analyst', 'Read access plus analytics functions'),
('SOCCER_V1', 'editor', 'Read and write access to entities'),
('SOCCER_V1', 'admin', 'Full administrative access');

INSERT INTO ONT_PERMISSION (ONTOLOGY_NAME, SUBJECT_KIND, SUBJECT_NAME, ONT_ROLE_NAME, PRIVILEGE) VALUES
-- Viewer permissions
('SOCCER_V1', 'OBJECT_TYPE', 'Player', 'viewer', 'READ'),
('SOCCER_V1', 'OBJECT_TYPE', 'Coach', 'viewer', 'READ'),
('SOCCER_V1', 'OBJECT_TYPE', 'Club', 'viewer', 'READ'),
('SOCCER_V1', 'OBJECT_TYPE', 'Match', 'viewer', 'READ'),
('SOCCER_V1', 'LINK_TYPE', 'works_for', 'viewer', 'READ'),

-- Analyst permissions (inherits viewer)
('SOCCER_V1', 'OBJECT_TYPE', 'Player', 'analyst', 'READ'),
('SOCCER_V1', 'OBJECT_TYPE', 'Coach', 'analyst', 'READ'),
('SOCCER_V1', 'OBJECT_TYPE', 'Club', 'analyst', 'READ'),
('SOCCER_V1', 'OBJECT_TYPE', 'Match', 'analyst', 'READ'),
('SOCCER_V1', 'ACTION_TYPE', 'graph_shortest_path', 'analyst', 'EXECUTE'),
('SOCCER_V1', 'ACTION_TYPE', 'graph_centrality', 'analyst', 'EXECUTE'),

-- Editor permissions
('SOCCER_V1', 'OBJECT_TYPE', 'Player', 'editor', 'WRITE'),
('SOCCER_V1', 'OBJECT_TYPE', 'Coach', 'editor', 'WRITE'),
('SOCCER_V1', 'OBJECT_TYPE', 'Club', 'editor', 'WRITE'),
('SOCCER_V1', 'OBJECT_TYPE', 'Match', 'editor', 'WRITE'),
('SOCCER_V1', 'ACTION_TYPE', 'ACT_TRANSFER', 'editor', 'EXECUTE'),
('SOCCER_V1', 'ACTION_TYPE', 'ACT_HIRE_COACH', 'editor', 'EXECUTE'),
('SOCCER_V1', 'ACTION_TYPE', 'ACT_RECORD_MATCH', 'editor', 'EXECUTE'),

-- Admin permissions
('SOCCER_V1', 'OBJECT_TYPE', 'Player', 'admin', 'ADMIN'),
('SOCCER_V1', 'OBJECT_TYPE', 'Coach', 'admin', 'ADMIN'),
('SOCCER_V1', 'OBJECT_TYPE', 'Club', 'admin', 'ADMIN'),
('SOCCER_V1', 'OBJECT_TYPE', 'Match', 'admin', 'ADMIN');

-- =====================================================
-- OBJECT VIEW DEFINITIONS (for governance)
-- =====================================================
INSERT INTO OBJ_VIEW_DEF (OBJ_TYPE, VIEW_NAME, CREATED_BY, DESCRIPTION, DISPLAY_COLS) VALUES
('Player', 'V_PLAYER', 'SYSTEM', 'Standard player view', ARRAY_CONSTRUCT('NAME', 'POSITION', 'NATIONALITY')),
('Coach', 'V_COACH', 'SYSTEM', 'Standard coach view', ARRAY_CONSTRUCT('NAME', 'NATIONALITY', 'LICENSE_LEVEL')),
('Club', 'V_CLUB', 'SYSTEM', 'Standard club view', ARRAY_CONSTRUCT('NAME', 'COUNTRY', 'LEAGUE')),
('Match', 'V_MATCH', 'SYSTEM', 'Standard match view', ARRAY_CONSTRUCT('NAME', 'EVENT_DATE', 'COMPETITION'));

-- =====================================================
-- OBJECT SOURCE MAPPINGS
-- =====================================================
INSERT INTO ONT_OBJECT_SOURCE (ONTOLOGY_NAME, OBJ_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING) VALUES
('SOCCER_V1', 'Player', 'KG_NODE', 'NODE_TYPE = ''PLAYER''', 
 PARSE_JSON('{"NODE_ID": "id", "PROPS:NAME": "name", "PROPS:POSITION": "position"}')),
('SOCCER_V1', 'Coach', 'KG_NODE', 'NODE_TYPE = ''COACH''',
 PARSE_JSON('{"NODE_ID": "id", "PROPS:NAME": "name", "PROPS:LICENSE_LEVEL": "license_level"}')),
('SOCCER_V1', 'Club', 'KG_NODE', 'NODE_TYPE = ''CLUB''',
 PARSE_JSON('{"NODE_ID": "id", "PROPS:CLUB_NAME": "name", "PROPS:COUNTRY": "country"}')),
('SOCCER_V1', 'Match', 'KG_NODE', 'NODE_TYPE = ''MATCH''',
 PARSE_JSON('{"NODE_ID": "id", "PROPS:MATCH_NAME": "name", "PROPS:EVENT_DATE": "event_date"}'));

-- =====================================================
-- LINK SOURCE MAPPINGS
-- =====================================================
INSERT INTO ONT_LINK_SOURCE (ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING) VALUES
('SOCCER_V1', 'PLAYS_FOR', 'KG_EDGE', 'EDGE_TYPE = ''PLAYS_FOR''',
 PARSE_JSON('{"SRC_ID": "player_id", "DST_ID": "club_id", "EFFECTIVE_START": "start_date"}')),
('SOCCER_V1', 'COACHES', 'KG_EDGE', 'EDGE_TYPE = ''COACHES''',
 PARSE_JSON('{"SRC_ID": "coach_id", "DST_ID": "club_id", "EFFECTIVE_START": "start_date"}')),
('SOCCER_V1', 'PLAYED_IN', 'KG_EDGE', 'EDGE_TYPE = ''PLAYED_IN''',
 PARSE_JSON('{"SRC_ID": "player_id", "DST_ID": "match_id", "PROPS:GOALS_SCORED": "goals"}'));

COMMIT;
