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
-- LAYER 3: ENTITY VIEWS (Convenience Views)
-- Type-specific views over KG_NODE for easier querying
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- V_PLAYER: View of all players
-- =====================================================
CREATE OR REPLACE VIEW V_PLAYER AS
SELECT
    NODE_ID,
    NAME,
    PROPS:position::STRING      AS POSITION,
    PROPS:nationality::STRING   AS NATIONALITY,
    PROPS:birthdate::DATE       AS BIRTHDATE,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'PLAYER';

COMMENT ON VIEW V_PLAYER IS 'Convenience view for Player entities with extracted properties';

-- =====================================================
-- V_COACH: View of all coaches
-- =====================================================
CREATE OR REPLACE VIEW V_COACH AS
SELECT
    NODE_ID,
    NAME,
    PROPS:nationality::STRING   AS NATIONALITY,
    PROPS:license_level::STRING AS LICENSE_LEVEL,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'COACH';

COMMENT ON VIEW V_COACH IS 'Convenience view for Coach entities with extracted properties';

-- =====================================================
-- V_CLUB: View of all clubs
-- =====================================================
CREATE OR REPLACE VIEW V_CLUB AS
SELECT
    NODE_ID,
    NAME,
    PROPS:league::STRING        AS LEAGUE,
    PROPS:country::STRING       AS COUNTRY,
    PROPS:stadium::STRING       AS STADIUM,
    PROPS:founded_year::INTEGER AS FOUNDED_YEAR,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'CLUB';

COMMENT ON VIEW V_CLUB IS 'Convenience view for Club entities with extracted properties';

-- =====================================================
-- V_MATCH: View of all matches
-- =====================================================
CREATE OR REPLACE VIEW V_MATCH AS
SELECT
    NODE_ID,
    NAME,
    PROPS:event_date::DATE      AS EVENT_DATE,
    PROPS:venue::STRING         AS VENUE,
    PROPS:competition::STRING   AS COMPETITION,
    PROPS:score_home::INTEGER   AS SCORE_HOME,
    PROPS:score_away::INTEGER   AS SCORE_AWAY,
    PROPS
FROM KG_NODE
WHERE NODE_TYPE = 'MATCH';

COMMENT ON VIEW V_MATCH IS 'Convenience view for Match entities with extracted properties';
