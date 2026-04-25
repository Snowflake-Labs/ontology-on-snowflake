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
-- DATA LOADING SCRIPT
-- Loads sample data from JSON files into KG_NODE and KG_EDGE tables
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- Create stage for loading data files
-- =====================================================
CREATE OR REPLACE STAGE SOCCER_DATA_STAGE
    FILE_FORMAT = (TYPE = 'JSON');

-- Upload the JSON files to the stage using:
-- PUT file:///path/to/clubs.json @SOCCER_DATA_STAGE;
-- PUT file:///path/to/persons.json @SOCCER_DATA_STAGE;
-- PUT file:///path/to/player_contracts.json @SOCCER_DATA_STAGE;
-- PUT file:///path/to/coach_contracts.json @SOCCER_DATA_STAGE;
-- PUT file:///path/to/matches.json @SOCCER_DATA_STAGE;
-- PUT file:///path/to/match_appearances.json @SOCCER_DATA_STAGE;

-- =====================================================
-- Load Clubs into KG_NODE
-- =====================================================
COPY INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS, TS_INGESTED)
FROM (
    SELECT 
        $1:CLUB_ID::STRING,
        'CLUB',
        $1:CLUB_NAME::STRING,
        OBJECT_CONSTRUCT(
            'league', $1:LEAGUE::STRING,
            'country', $1:COUNTRY::STRING,
            'stadium', $1:STADIUM::STRING,
            'founded_year', $1:FOUNDED_YEAR::INTEGER
        ),
        TRY_TO_TIMESTAMP($1:CREATED_AT::STRING)
    FROM @SOCCER_DATA_STAGE/clubs.json
);

-- =====================================================
-- Load Persons (Players and Coaches) into KG_NODE
-- =====================================================
COPY INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS, TS_INGESTED)
FROM (
    SELECT 
        $1:PERSON_ID::STRING,
        UPPER($1:ROLE::STRING),  -- PLAYER or COACH
        $1:NAME::STRING,
        CASE 
            WHEN UPPER($1:ROLE::STRING) = 'PLAYER' THEN
                OBJECT_CONSTRUCT(
                    'position', $1:POSITION::STRING,
                    'nationality', $1:NATIONALITY::STRING,
                    'birthdate', $1:DATE_OF_BIRTH::DATE
                )
            ELSE
                OBJECT_CONSTRUCT(
                    'nationality', $1:NATIONALITY::STRING,
                    'license_level', 'UEFA Pro'
                )
        END,
        TRY_TO_TIMESTAMP($1:CREATED_AT::STRING)
    FROM @SOCCER_DATA_STAGE/persons.json
);

-- =====================================================
-- Load Matches into KG_NODE
-- =====================================================
COPY INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS, TS_INGESTED)
FROM (
    SELECT 
        $1:MATCH_ID::STRING,
        'MATCH',
        $1:MATCH_NAME::STRING,
        OBJECT_CONSTRUCT(
            'event_date', $1:EVENT_DATE::DATE,
            'venue', $1:VENUE::STRING,
            'competition', $1:COMPETITION::STRING,
            'score_home', $1:SCORE_HOME::INTEGER,
            'score_away', $1:SCORE_AWAY::INTEGER,
            'home_team_id', $1:HOME_TEAM_ID::STRING,
            'away_team_id', $1:AWAY_TEAM_ID::STRING
        ),
        TRY_TO_TIMESTAMP($1:CREATED_AT::STRING)
    FROM @SOCCER_DATA_STAGE/matches.json
);

-- =====================================================
-- Load Player Contracts as PLAYS_FOR edges
-- =====================================================
COPY INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, PROPS, EFFECTIVE_START, EFFECTIVE_END, TS_INGESTED)
FROM (
    SELECT 
        $1:CONTRACT_ID::STRING,
        $1:PERSON_ID::STRING,
        $1:CLUB_ID::STRING,
        'PLAYS_FOR',
        OBJECT_CONSTRUCT(
            'jersey_number', $1:JERSEY_NUMBER::INTEGER,
            'contract_value', $1:CONTRACT_VALUE::NUMBER
        ),
        TRY_TO_DATE($1:START_DATE::STRING),
        TRY_TO_DATE($1:END_DATE::STRING),
        TRY_TO_TIMESTAMP($1:CREATED_AT::STRING)
    FROM @SOCCER_DATA_STAGE/player_contracts.json
);

-- =====================================================
-- Load Coach Contracts as COACHES edges
-- =====================================================
COPY INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, PROPS, EFFECTIVE_START, EFFECTIVE_END, TS_INGESTED)
FROM (
    SELECT 
        $1:CONTRACT_ID::STRING,
        $1:PERSON_ID::STRING,
        $1:CLUB_ID::STRING,
        'COACHES',
        OBJECT_CONSTRUCT(
            'contract_value', $1:CONTRACT_VALUE::NUMBER
        ),
        TRY_TO_DATE($1:START_DATE::STRING),
        TRY_TO_DATE($1:END_DATE::STRING),
        TRY_TO_TIMESTAMP($1:CREATED_AT::STRING)
    FROM @SOCCER_DATA_STAGE/coach_contracts.json
);

-- =====================================================
-- Load Match Appearances as PLAYED_IN edges
-- =====================================================
COPY INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, PROPS, TS_INGESTED)
FROM (
    SELECT 
        $1:APPEARANCE_ID::STRING,
        $1:PERSON_ID::STRING,
        $1:MATCH_ID::STRING,
        'PLAYED_IN',
        OBJECT_CONSTRUCT(
            'minutes_played', $1:MINUTES_PLAYED::INTEGER,
            'goals_scored', $1:GOALS_SCORED::INTEGER,
            'assists', $1:ASSISTS::INTEGER,
            'yellow_cards', $1:YELLOW_CARDS::INTEGER,
            'red_cards', $1:RED_CARDS::INTEGER
        ),
        TRY_TO_TIMESTAMP($1:CREATED_AT::STRING)
    FROM @SOCCER_DATA_STAGE/match_appearances.json
);

-- =====================================================
-- Load Home Team relationships from matches
-- =====================================================
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, PROPS, EFFECTIVE_START)
SELECT 
    'HT_' || NODE_ID AS EDGE_ID,
    PROPS:home_team_id::STRING AS SRC_ID,
    NODE_ID AS DST_ID,
    'HOME_TEAM' AS EDGE_TYPE,
    NULL AS PROPS,
    PROPS:event_date::DATE AS EFFECTIVE_START
FROM KG_NODE
WHERE NODE_TYPE = 'MATCH'
AND PROPS:home_team_id IS NOT NULL;

-- =====================================================
-- Load Away Team relationships from matches
-- =====================================================
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, PROPS, EFFECTIVE_START)
SELECT 
    'AT_' || NODE_ID AS EDGE_ID,
    PROPS:away_team_id::STRING AS SRC_ID,
    NODE_ID AS DST_ID,
    'AWAY_TEAM' AS EDGE_TYPE,
    NULL AS PROPS,
    PROPS:event_date::DATE AS EFFECTIVE_START
FROM KG_NODE
WHERE NODE_TYPE = 'MATCH'
AND PROPS:away_team_id IS NOT NULL;

-- =====================================================
-- Note: Primary keys and clustering are defined in 01_physical_layer.sql
-- =====================================================

-- =====================================================
-- Verify data loading
-- =====================================================
SELECT 'Nodes by Type' AS metric, NODE_TYPE, COUNT(*) AS count
FROM KG_NODE
GROUP BY NODE_TYPE
ORDER BY NODE_TYPE;

SELECT 'Edges by Type' AS metric, EDGE_TYPE, COUNT(*) AS count
FROM KG_EDGE
GROUP BY EDGE_TYPE
ORDER BY EDGE_TYPE;
