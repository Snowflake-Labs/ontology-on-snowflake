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
-- LAYER 2: ONTOLOGY METADATA LAYER
-- Metadata tables that define the ontology structure
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- ONTOLOGY REGISTRY
-- =====================================================
CREATE OR REPLACE TABLE ONT_ONTOLOGY (
    ONTOLOGY_NAME STRING PRIMARY KEY,
    DESCRIPTION STRING,
    VERSION STRING,
    DEFAULT_SCHEMA STRING,
    CREATED_BY STRING,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    IS_ACTIVE BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE ONT_ONTOLOGY IS 'Registry of ontologies with versioning';

-- =====================================================
-- OBJECT TYPE SOURCE MAPPINGS
-- =====================================================
CREATE OR REPLACE TABLE ONT_OBJECT_SOURCE (
    ONTOLOGY_NAME STRING,
    OBJ_TYPE STRING,            -- e.g. 'Player', 'Club'
    SOURCE_TABLE STRING,        -- e.g. 'KG_NODE'
    FILTER_SQL STRING,          -- e.g. 'NODE_TYPE = ''PLAYER'''
    MAPPING VARIANT,            -- JSON mapping of source columns to properties
    PRIMARY KEY (ONTOLOGY_NAME, OBJ_TYPE, SOURCE_TABLE)
);

COMMENT ON TABLE ONT_OBJECT_SOURCE IS 'Maps object types to their source tables with column mappings';

CREATE OR REPLACE TABLE ONT_LINK_SOURCE (
    ONTOLOGY_NAME STRING,
    LINK_TYPE STRING,           -- e.g. 'PLAYS_FOR', 'COACHES'
    SOURCE_TABLE STRING,        -- e.g. 'KG_EDGE'
    FILTER_SQL STRING,          -- e.g. 'EDGE_TYPE = ''PLAYS_FOR'''
    MAPPING VARIANT,            -- JSON mapping of source columns to properties
    PRIMARY KEY (ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE)
);

COMMENT ON TABLE ONT_LINK_SOURCE IS 'Maps link types to their source tables with column mappings';

-- =====================================================
-- CLASS DEFINITIONS (Object Types)
-- =====================================================
CREATE OR REPLACE TABLE ONT_CLASS (
    CLASS_NAME STRING PRIMARY KEY,
    PARENT_CLASS_NAME STRING,
    IS_ABSTRACT BOOLEAN DEFAULT FALSE,
    DESCRIPTION STRING,
    ONTOLOGY_NAME STRING,
    TYPE_CLASS STRING,          -- 'ANALYTICAL' | 'OPERATIONAL'
    STATUS STRING DEFAULT 'ACTIVE',
    TS_CREATED TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE ONT_CLASS IS 'Object type definitions with class hierarchy';

-- =====================================================
-- RELATIONSHIP DEFINITIONS (Link Types)
-- =====================================================
CREATE OR REPLACE TABLE ONT_RELATION_DEF (
    REL_NAME STRING PRIMARY KEY,
    DOMAIN_CLASS STRING,        -- source class
    RANGE_CLASS STRING,         -- target class
    CARDINALITY STRING,         -- N:1 | 1:N | N:N | 1:1
    IS_HIERARCHICAL BOOLEAN DEFAULT FALSE,
    INVERSE_REL_NAME STRING,
    DESCRIPTION STRING,
    ONTOLOGY_NAME STRING,
    STATUS STRING DEFAULT 'ACTIVE',
    RENDER_HINT STRING          -- 'directed' | 'undirected' | 'hierarchical'
);

COMMENT ON TABLE ONT_RELATION_DEF IS 'Link type definitions with cardinality and constraints';

-- =====================================================
-- PROPERTY DEFINITIONS
-- =====================================================
CREATE OR REPLACE TABLE ONT_SHARED_PROPERTY (
    SHARED_PROP_NAME STRING PRIMARY KEY,   -- e.g. 'name', 'country'
    BASE_TYPE STRING,                      -- 'STRING','NUMBER', etc.
    DESCRIPTION STRING,
    DEFAULT_FORMAT STRING
);

COMMENT ON TABLE ONT_SHARED_PROPERTY IS 'Shared properties reusable across object types';

CREATE OR REPLACE TABLE ONT_PROPERTY (
    CLASS_NAME STRING,
    PROP_NAME STRING,
    DATA_TYPE STRING,                      -- 'STRING','NUMBER','DATE', etc.
    SHARED_PROP_NAME STRING,               -- FK to shared property
    IS_REQUIRED BOOLEAN DEFAULT FALSE,
    IS_INDEXED BOOLEAN DEFAULT FALSE,
    DESCRIPTION STRING,
    PRIMARY KEY (CLASS_NAME, PROP_NAME)
);

COMMENT ON TABLE ONT_PROPERTY IS 'Properties for each object type';

CREATE OR REPLACE TABLE ONT_DERIVED_PROPERTY (
    CLASS_NAME STRING,
    PROP_NAME STRING,
    DEFINITION_KIND STRING,                -- 'SQL','FUNCTION'
    SQL_EXPR STRING,                       -- if definition_kind = 'SQL'
    FUNCTION_NAME STRING,                  -- if definition_kind = 'FUNCTION'
    DESCRIPTION STRING,
    PRIMARY KEY (CLASS_NAME, PROP_NAME)
);

COMMENT ON TABLE ONT_DERIVED_PROPERTY IS 'Computed/derived properties with their definitions';

-- =====================================================
-- INFERENCE RULES
-- =====================================================
CREATE OR REPLACE TABLE ONT_RULE (
    RULE_ID STRING PRIMARY KEY,
    RULE_KIND STRING,                      -- TRANSITIVE | PROPERTY_CHAIN | INVERSE
    TARGET_REL STRING,                     -- relationship to infer
    SOURCE_REL_1 STRING,
    SOURCE_REL_2 STRING,                   -- for property chain
    INVERSE_OF STRING,                     -- for inverse rules
    DESCRIPTION STRING,
    IS_ENABLED BOOLEAN DEFAULT TRUE,
    TS_CREATED TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE ONT_RULE IS 'Inference rules for deriving new relationships';

-- =====================================================
-- DATA QUALITY CONSTRAINTS
-- =====================================================
CREATE OR REPLACE TABLE ONT_CONSTRAINT_VIOLATION (
    VIOLATION_ID STRING DEFAULT UUID_STRING(),
    CHECK_NAME STRING,
    SCOPE STRING,                          -- RELATION | CLASS | GLOBAL
    REL_OR_CLASS STRING,
    SRC_ID STRING,
    DST_ID STRING,
    DETAILS STRING,
    OBSERVED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (VIOLATION_ID)
);

COMMENT ON TABLE ONT_CONSTRAINT_VIOLATION IS 'Log of data quality constraint violations';

-- =====================================================
-- ACTIONS (Operations)
-- =====================================================
CREATE OR REPLACE TABLE ACT_TYPE (
    ACTION_TYPE_ID STRING PRIMARY KEY,
    ACTION_NAME STRING NOT NULL,
    DESCRIPTION STRING,
    ONTOLOGY_NAME STRING,
    TARGET_CLASS STRING,                   -- object type this action applies to
    HANDLER_PROC STRING,                   -- stored procedure reference
    IS_ENABLED BOOLEAN DEFAULT TRUE,
    TS_CREATED TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE ACT_TYPE IS 'Action type definitions - operations that can be performed on objects';

CREATE OR REPLACE TABLE ACT_DEF (
    ACTION_TYPE_ID STRING,
    PARAM_NAME STRING,
    PARAM_TYPE STRING,                     -- 'STRING' | 'NUMBER' | 'DATE' | 'BOOLEAN'
    IS_REQUIRED BOOLEAN DEFAULT FALSE,
    DESCRIPTION STRING,
    PRIMARY KEY (ACTION_TYPE_ID, PARAM_NAME)
);

COMMENT ON TABLE ACT_DEF IS 'Action parameter definitions';

CREATE OR REPLACE TABLE ACT_INVOCATION (
    INVOCATION_ID STRING PRIMARY KEY,
    ACTION_TYPE_ID STRING NOT NULL,
    TARGET_OBJECT_ID STRING,
    PARAMS VARIANT,
    STATUS STRING,                         -- 'PENDING' | 'SUCCESS' | 'FAILED'
    RESULT_MSG STRING,
    INVOKED_BY STRING,
    INVOKED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    COMPLETED_AT TIMESTAMP_NTZ
);

COMMENT ON TABLE ACT_INVOCATION IS 'Log of action invocations';

-- =====================================================
-- CLASS AND RELATIONSHIP MAPPINGS
-- =====================================================
CREATE OR REPLACE TABLE ONT_CLASS_MAP (
    CLASS_NAME STRING,
    CONCRETE_VIEW STRING,
    ID_COL STRING DEFAULT 'NODE_ID',
    SUBTYPE_VALUE STRING,       -- The subtype value for this mapping (e.g., 'Player')
    PRIMARY KEY (CLASS_NAME, CONCRETE_VIEW)
);

COMMENT ON TABLE ONT_CLASS_MAP IS 'Maps abstract classes to concrete views for view generation';

CREATE OR REPLACE TABLE ONT_REL_MAP (
    REL_NAME STRING,
    CONCRETE_VIEW STRING,
    SRC_COL STRING,
    DST_COL STRING,
    PROPS_COL STRING DEFAULT 'PROPS',
    VIA_REL_VALUE STRING,       -- The concrete relationship type (e.g., 'PLAYS_FOR')
    PRIMARY KEY (REL_NAME, CONCRETE_VIEW)
);

COMMENT ON TABLE ONT_REL_MAP IS 'Maps abstract relationships to concrete views';

-- =====================================================
-- INTERFACES (Polymorphism)
-- =====================================================
CREATE OR REPLACE TABLE ONT_INTERFACE (
    INTERFACE_NAME STRING PRIMARY KEY,     -- e.g. 'PERSON', 'COMPETITION_MEMBER'
    DESCRIPTION STRING
);

COMMENT ON TABLE ONT_INTERFACE IS 'Interface definitions for polymorphism';

CREATE OR REPLACE TABLE ONT_INTERFACE_PROPERTY (
    INTERFACE_NAME STRING,
    PROP_NAME STRING,
    SHARED_PROP_NAME STRING,
    PRIMARY KEY (INTERFACE_NAME, PROP_NAME)
);

COMMENT ON TABLE ONT_INTERFACE_PROPERTY IS 'Properties required by each interface';

CREATE OR REPLACE TABLE ONT_INTERFACE_IMPL (
    INTERFACE_NAME STRING,
    CLASS_NAME STRING,
    PRIMARY KEY (INTERFACE_NAME, CLASS_NAME)
);

COMMENT ON TABLE ONT_INTERFACE_IMPL IS 'Maps which classes implement which interfaces';

-- =====================================================
-- FUNCTION CATALOG
-- =====================================================
CREATE OR REPLACE TABLE ONT_FUNCTION (
    FUNCTION_NAME STRING,                  -- logical name in ontology
    VERSION STRING,
    LANGUAGE STRING,                       -- 'SQL','PYTHON','JS','EXTERNAL'
    SNOWFLAKE_REF STRING,                  -- actual Snowflake function reference
    DESCRIPTION STRING,
    INPUT_SCHEMA VARIANT,
    OUTPUT_SCHEMA VARIANT,
    ONTOLOGY_NAME STRING,
    PRIMARY KEY (ONTOLOGY_NAME, FUNCTION_NAME, VERSION)
);

COMMENT ON TABLE ONT_FUNCTION IS 'Ontology function catalog - versioned code artifacts';

CREATE OR REPLACE TABLE ONT_FUNCTION_BINDING (
    ONTOLOGY_NAME STRING,
    FUNCTION_NAME STRING,
    VERSION STRING,
    BOUND_TO_KIND STRING,                  -- 'OBJECT_TYPE','LINK_TYPE','ACTION_TYPE'
    BOUND_TO_NAME STRING
);

COMMENT ON TABLE ONT_FUNCTION_BINDING IS 'Binds functions to object types, link types, or action types';

-- =====================================================
-- OBJECT VIEWS (UI Configuration / Governance)
-- =====================================================
CREATE OR REPLACE TABLE OBJ_VIEW_DEF (
    OBJ_TYPE STRING,                       -- Object type, e.g. 'Player'
    VIEW_NAME STRING,                      -- logical view name, e.g. 'V_PLAYER'
    CREATED_BY STRING,                     -- creator of the view definition
    DESCRIPTION STRING,                    -- description of the view
    DISPLAY_COLS VARIANT,                  -- array of columns to display
    VERSION STRING DEFAULT '1.0',
    STATUS STRING DEFAULT 'ACTIVE',
    TS_CREATED TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (OBJ_TYPE, VIEW_NAME)
);

COMMENT ON TABLE OBJ_VIEW_DEF IS 'Object view definitions for UI presentation and governance';

CREATE OR REPLACE TABLE OBJ_VIEW_FIELD (
    OBJ_TYPE STRING,
    VIEW_NAME STRING,
    VERSION STRING DEFAULT '1.0',
    FIELD_ORDER NUMBER,
    PROP_NAME STRING,
    RENDER_HINT STRING,                    -- 'badge' | 'link' | 'date' | 'number'
    PRIMARY KEY (OBJ_TYPE, VIEW_NAME, VERSION, PROP_NAME)
);

COMMENT ON TABLE OBJ_VIEW_FIELD IS 'Field configuration for object views';

-- =====================================================
-- PERMISSIONS AND ROLES
-- =====================================================
CREATE OR REPLACE TABLE ONT_ROLE (
    ONTOLOGY_NAME STRING,
    ONT_ROLE_NAME STRING,
    DESCRIPTION STRING,
    PRIMARY KEY (ONTOLOGY_NAME, ONT_ROLE_NAME)
);

COMMENT ON TABLE ONT_ROLE IS 'Ontology-specific roles for access control';

CREATE OR REPLACE TABLE ONT_ROLE_BINDING (
    ONTOLOGY_NAME STRING,
    ONT_ROLE_NAME STRING,
    SNOWFLAKE_ROLE STRING,
    PRIMARY KEY (ONTOLOGY_NAME, ONT_ROLE_NAME, SNOWFLAKE_ROLE)
);

COMMENT ON TABLE ONT_ROLE_BINDING IS 'Maps ontology roles to Snowflake roles';

CREATE OR REPLACE TABLE ONT_PERMISSION (
    ONTOLOGY_NAME STRING,
    SUBJECT_KIND STRING,                   -- 'OBJECT_TYPE','LINK_TYPE','ACTION_TYPE'
    SUBJECT_NAME STRING,
    ONT_ROLE_NAME STRING,
    PRIVILEGE STRING,                      -- 'READ','WRITE','EXECUTE','ADMIN'
    PRIMARY KEY (ONTOLOGY_NAME, SUBJECT_KIND, SUBJECT_NAME, ONT_ROLE_NAME, PRIVILEGE)
);

COMMENT ON TABLE ONT_PERMISSION IS 'Granular permissions for object types, link types, and actions';

-- =====================================================
-- INFERRED EDGES
-- =====================================================
CREATE OR REPLACE TABLE REL_EDGE_INFERRED (
    REL_NAME STRING NOT NULL,
    SRC_ID STRING NOT NULL,
    DST_ID STRING NOT NULL,
    INFERENCE_KIND STRING,                 -- 'TRANSITIVE','INVERSE','PROPERTY_CHAIN'
    RULE_ID STRING,
    WEIGHT FLOAT DEFAULT 1.0,
    EFFECTIVE_START DATE,
    EFFECTIVE_END DATE,
    COMPUTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (REL_NAME, SRC_ID, DST_ID, RULE_ID)
);

COMMENT ON TABLE REL_EDGE_INFERRED IS 'Inferred relationships generated by inference rules';

-- =====================================================
-- NOTE: ONT_CLASS_CLOSURE and REL_RESOLVED views are
-- defined in 07_abstract_views.sql with richer schemas
-- =====================================================
