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
-- LAYER 3: RELATIONSHIP VIEWS (Convenience Views)
-- Type-specific views over KG_EDGE for easier querying
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- V_PLAYS_FOR: Player-to-Club relationships
-- =====================================================
CREATE OR REPLACE VIEW V_PLAYS_FOR AS
SELECT
    SRC_ID                AS PLAYER_ID,
    DST_ID                AS CLUB_ID,
    EDGE_TYPE,
    PROPS,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS:jersey_number::INTEGER      AS JERSEY_NUMBER,
    PROPS:contract_value::DECIMAL(15,2) AS CONTRACT_VALUE
FROM KG_EDGE
WHERE EDGE_TYPE = 'PLAYS_FOR';

COMMENT ON VIEW V_PLAYS_FOR IS 'Player-to-Club contract relationships with extracted properties';

-- =====================================================
-- V_COACHES: Coach-to-Club relationships
-- =====================================================
CREATE OR REPLACE VIEW V_COACHES AS
SELECT
    SRC_ID                AS COACH_ID,
    DST_ID                AS CLUB_ID,
    EDGE_TYPE,
    PROPS,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS:contract_value::DECIMAL(15,2) AS CONTRACT_VALUE
FROM KG_EDGE
WHERE EDGE_TYPE = 'COACHES';

COMMENT ON VIEW V_COACHES IS 'Coach-to-Club contract relationships with extracted properties';

-- =====================================================
-- V_PLAYED_IN: Player-to-Match relationships (appearances)
-- =====================================================
CREATE OR REPLACE VIEW V_PLAYED_IN AS
SELECT
    SRC_ID                AS PLAYER_ID,
    DST_ID                AS MATCH_ID,
    EDGE_TYPE,
    PROPS,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS:minutes_played::INTEGER  AS MINUTES_PLAYED,
    PROPS:goals_scored::INTEGER    AS GOALS_SCORED,
    PROPS:assists::INTEGER         AS ASSISTS,
    PROPS:yellow_cards::INTEGER    AS YELLOW_CARDS,
    PROPS:red_cards::INTEGER       AS RED_CARDS
FROM KG_EDGE
WHERE EDGE_TYPE = 'PLAYED_IN';

COMMENT ON VIEW V_PLAYED_IN IS 'Player match appearances with performance statistics';

-- =====================================================
-- V_HOME_TEAM: Club-to-Match relationships (home team)
-- =====================================================
CREATE OR REPLACE VIEW V_HOME_TEAM AS
SELECT
    SRC_ID                AS CLUB_ID,
    DST_ID                AS MATCH_ID,
    EDGE_TYPE,
    PROPS,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END
FROM KG_EDGE
WHERE EDGE_TYPE = 'HOME_TEAM';

COMMENT ON VIEW V_HOME_TEAM IS 'Club-to-Match relationship for home team designation';

-- =====================================================
-- V_AWAY_TEAM: Club-to-Match relationships (away team)
-- =====================================================
CREATE OR REPLACE VIEW V_AWAY_TEAM AS
SELECT
    SRC_ID                AS CLUB_ID,
    DST_ID                AS MATCH_ID,
    EDGE_TYPE,
    PROPS,
    WEIGHT,
    EFFECTIVE_START,
    EFFECTIVE_END
FROM KG_EDGE
WHERE EDGE_TYPE = 'AWAY_TEAM';

COMMENT ON VIEW V_AWAY_TEAM IS 'Club-to-Match relationship for away team designation';

-- =====================================================
-- NOTE: ACTIVE_PLAYERS, ACTIVE_COACHES, and MATCH_RESULTS
-- views are defined in 07_abstract_views.sql with richer schemas
-- =====================================================
