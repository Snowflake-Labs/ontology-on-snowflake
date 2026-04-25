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
-- LAYER 3: ABSTRACT VIEWS
-- Pre-built abstract views for the ontology layer
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- VW_ONT_PERSON - Abstract Person View
-- Unifies all person types (Player, Coach)
-- =====================================================
CREATE OR REPLACE VIEW VW_ONT_PERSON AS
SELECT 
    NODE_ID AS ID,
    'Player' AS SUBTYPE,
    'V_PLAYER' AS SRC_VIEW
FROM V_PLAYER

UNION ALL

SELECT 
    NODE_ID AS ID,
    'Coach' AS SUBTYPE,
    'V_COACH' AS SRC_VIEW
FROM V_COACH;

COMMENT ON VIEW VW_ONT_PERSON IS 'Abstract view unifying all person types (Player, Coach)';

-- =====================================================
-- VW_ONT_ORGANIZATION - Abstract Organization View
-- Unifies all organization types (Club)
-- =====================================================
CREATE OR REPLACE VIEW VW_ONT_ORGANIZATION AS
SELECT 
    NODE_ID AS ID,
    'Club' AS SUBTYPE,
    'V_CLUB' AS SRC_VIEW
FROM V_CLUB;

COMMENT ON VIEW VW_ONT_ORGANIZATION IS 'Abstract view unifying all organization types (Club)';

-- =====================================================
-- VW_ONT_EVENT - Abstract Event View
-- Unifies all event types (Match)
-- =====================================================
CREATE OR REPLACE VIEW VW_ONT_EVENT AS
SELECT 
    NODE_ID AS ID,
    'Match' AS SUBTYPE,
    'V_MATCH' AS SRC_VIEW
FROM V_MATCH;

COMMENT ON VIEW VW_ONT_EVENT IS 'Abstract view unifying all event types (Match)';

-- =====================================================
-- REL_RESOLVED - Unified Relationship View
-- Combines all concrete relationships with type resolution
-- =====================================================
CREATE OR REPLACE VIEW REL_RESOLVED AS
-- PLAYS_FOR relationships (Player -> Club)
SELECT
    'PLAYS_FOR' AS REL_NAME,
    PLAYER_ID AS SRC_ID,
    'Player' AS SRC_CLASS,
    CLUB_ID AS DST_ID,
    'Club' AS DST_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    OBJECT_CONSTRUCT(
        'CONTRACT_VALUE', CONTRACT_VALUE,
        'JERSEY_NUMBER', JERSEY_NUMBER
    ) AS PROPS,
    1.0 AS WEIGHT
FROM V_PLAYS_FOR

UNION ALL

-- COACHES relationships (Coach -> Club)
SELECT
    'COACHES' AS REL_NAME,
    COACH_ID AS SRC_ID,
    'Coach' AS SRC_CLASS,
    CLUB_ID AS DST_ID,
    'Club' AS DST_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    OBJECT_CONSTRUCT(
        'CONTRACT_VALUE', CONTRACT_VALUE
    ) AS PROPS,
    1.0 AS WEIGHT
FROM V_COACHES

UNION ALL

-- PLAYED_IN relationships (Player -> Match)
SELECT
    'PLAYED_IN' AS REL_NAME,
    PLAYER_ID AS SRC_ID,
    'Player' AS SRC_CLASS,
    MATCH_ID AS DST_ID,
    'Match' AS DST_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    OBJECT_CONSTRUCT(
        'MINUTES_PLAYED', MINUTES_PLAYED,
        'GOALS_SCORED', GOALS_SCORED,
        'ASSISTS', ASSISTS,
        'YELLOW_CARDS', YELLOW_CARDS,
        'RED_CARDS', RED_CARDS
    ) AS PROPS,
    1.0 AS WEIGHT
FROM V_PLAYED_IN

UNION ALL

-- HOME_TEAM relationships (Club -> Match)
SELECT
    'HOME_TEAM' AS REL_NAME,
    CLUB_ID AS SRC_ID,
    'Club' AS SRC_CLASS,
    MATCH_ID AS DST_ID,
    'Match' AS DST_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS,
    1.0 AS WEIGHT
FROM V_HOME_TEAM

UNION ALL

-- AWAY_TEAM relationships (Club -> Match)
SELECT
    'AWAY_TEAM' AS REL_NAME,
    CLUB_ID AS SRC_ID,
    'Club' AS SRC_CLASS,
    MATCH_ID AS DST_ID,
    'Match' AS DST_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS,
    1.0 AS WEIGHT
FROM V_AWAY_TEAM;

COMMENT ON VIEW REL_RESOLVED IS 'Unified view of all relationships with resolved type information';

-- =====================================================
-- VW_ONT_WORKS_FOR - Abstract "works for" relationship
-- Unifies PLAYS_FOR and COACHES relationships
-- =====================================================
CREATE OR REPLACE VIEW VW_ONT_WORKS_FOR AS
SELECT
    'PLAYS_FOR' AS VIA_REL,
    SRC_ID AS SUBJECT_ID,
    'Player' AS SUBJECT_CLASS,
    DST_ID AS OBJECT_ID,
    'Club' AS OBJECT_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS,
    WEIGHT
FROM REL_RESOLVED
WHERE REL_NAME = 'PLAYS_FOR'

UNION ALL

SELECT
    'COACHES' AS VIA_REL,
    SRC_ID AS SUBJECT_ID,
    'Coach' AS SUBJECT_CLASS,
    DST_ID AS OBJECT_ID,
    'Club' AS OBJECT_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS,
    WEIGHT
FROM REL_RESOLVED
WHERE REL_NAME = 'COACHES';

COMMENT ON VIEW VW_ONT_WORKS_FOR IS 'Abstract relationship unifying PLAYS_FOR and COACHES (Person -> Organization)';

-- =====================================================
-- VW_ONT_PARTICIPATES_IN - Abstract "participates in" relationship
-- Unifies PLAYED_IN relationships
-- =====================================================
CREATE OR REPLACE VIEW VW_ONT_PARTICIPATES_IN AS
SELECT
    'PLAYED_IN' AS VIA_REL,
    SRC_ID AS SUBJECT_ID,
    'Player' AS SUBJECT_CLASS,
    DST_ID AS OBJECT_ID,
    'Match' AS OBJECT_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS,
    WEIGHT
FROM REL_RESOLVED
WHERE REL_NAME = 'PLAYED_IN';

COMMENT ON VIEW VW_ONT_PARTICIPATES_IN IS 'Abstract relationship for participation (Person -> Event)';

-- =====================================================
-- VW_ONT_AFFILIATED_WITH - Abstract "affiliated with" relationship
-- Unifies HOME_TEAM and AWAY_TEAM relationships
-- =====================================================
CREATE OR REPLACE VIEW VW_ONT_AFFILIATED_WITH AS
SELECT
    'HOME_TEAM' AS VIA_REL,
    SRC_ID AS SUBJECT_ID,
    'Club' AS SUBJECT_CLASS,
    DST_ID AS OBJECT_ID,
    'Match' AS OBJECT_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS,
    WEIGHT
FROM REL_RESOLVED
WHERE REL_NAME = 'HOME_TEAM'

UNION ALL

SELECT
    'AWAY_TEAM' AS VIA_REL,
    SRC_ID AS SUBJECT_ID,
    'Club' AS SUBJECT_CLASS,
    DST_ID AS OBJECT_ID,
    'Match' AS OBJECT_CLASS,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS,
    WEIGHT
FROM REL_RESOLVED
WHERE REL_NAME = 'AWAY_TEAM';

COMMENT ON VIEW VW_ONT_AFFILIATED_WITH IS 'Abstract relationship for affiliation (Organization -> Event)';

-- =====================================================
-- ONT_CLASS_CLOSURE - Recursive closure of class hierarchy
-- For finding all subtypes of an abstract class
-- =====================================================
CREATE OR REPLACE VIEW ONT_CLASS_CLOSURE AS
WITH RECURSIVE class_tree(ancestor, descendant, depth) AS (
    -- Base case: each class is its own ancestor at depth 0
    SELECT CLASS_NAME, CLASS_NAME, 0
    FROM ONT_CLASS
    
    UNION ALL
    
    -- Recursive case: follow parent relationships
    SELECT ct.ancestor, c.CLASS_NAME, ct.depth + 1
    FROM class_tree ct
    JOIN ONT_CLASS c ON c.PARENT_CLASS_NAME = ct.descendant
    WHERE ct.depth < 10
)
SELECT DISTINCT ancestor AS ANCESTOR_CLASS, descendant AS DESCENDANT_CLASS, depth AS DEPTH
FROM class_tree
ORDER BY ancestor, depth, descendant;

COMMENT ON VIEW ONT_CLASS_CLOSURE IS 'Transitive closure of class hierarchy for polymorphic queries';

-- =====================================================
-- ACTIVE_PLAYERS - Players with current contracts
-- =====================================================
CREATE OR REPLACE VIEW ACTIVE_PLAYERS AS
SELECT 
    p.NODE_ID,
    p.NAME,
    p.POSITION,
    p.NATIONALITY,
    p.BIRTHDATE,
    c.NAME AS CLUB_NAME,
    pf.CONTRACT_VALUE,
    pf.JERSEY_NUMBER
FROM V_PLAYER p
JOIN V_PLAYS_FOR pf ON p.NODE_ID = pf.PLAYER_ID
JOIN V_CLUB c ON pf.CLUB_ID = c.NODE_ID
WHERE pf.EFFECTIVE_END IS NULL 
   OR pf.EFFECTIVE_END >= CURRENT_DATE();

COMMENT ON VIEW ACTIVE_PLAYERS IS 'Players with currently active contracts';

-- =====================================================
-- ACTIVE_COACHES - Coaches with current contracts
-- =====================================================
CREATE OR REPLACE VIEW ACTIVE_COACHES AS
SELECT 
    co.NODE_ID,
    co.NAME,
    co.NATIONALITY,
    co.LICENSE_LEVEL,
    c.NAME AS CLUB_NAME,
    ch.CONTRACT_VALUE
FROM V_COACH co
JOIN V_COACHES ch ON co.NODE_ID = ch.COACH_ID
JOIN V_CLUB c ON ch.CLUB_ID = c.NODE_ID
WHERE ch.EFFECTIVE_END IS NULL 
   OR ch.EFFECTIVE_END >= CURRENT_DATE();

COMMENT ON VIEW ACTIVE_COACHES IS 'Coaches with currently active contracts';

-- =====================================================
-- MATCH_RESULTS - Enriched match view with team names
-- =====================================================
CREATE OR REPLACE VIEW MATCH_RESULTS AS
SELECT 
    m.NODE_ID AS MATCH_ID,
    m.NAME AS MATCH_NAME,
    m.EVENT_DATE,
    m.COMPETITION,
    m.VENUE,
    home.NAME AS HOME_TEAM,
    away.NAME AS AWAY_TEAM,
    m.SCORE_HOME,
    m.SCORE_AWAY,
    CASE 
        WHEN m.SCORE_HOME > m.SCORE_AWAY THEN 'HOME_WIN'
        WHEN m.SCORE_HOME < m.SCORE_AWAY THEN 'AWAY_WIN'
        ELSE 'DRAW'
    END AS RESULT
FROM V_MATCH m
LEFT JOIN V_HOME_TEAM ht ON m.NODE_ID = ht.MATCH_ID
LEFT JOIN V_CLUB home ON ht.CLUB_ID = home.NODE_ID
LEFT JOIN V_AWAY_TEAM at ON m.NODE_ID = at.MATCH_ID
LEFT JOIN V_CLUB away ON at.CLUB_ID = away.NODE_ID;

COMMENT ON VIEW MATCH_RESULTS IS 'Enriched match results with home and away team names';
