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
-- INFERENCE AND CONSTRAINT PROCEDURES
-- Stored procedures for ontology inference and data quality
-- =====================================================
--
-- SECURITY WARNING: The procedures in this file (SP_INFER_TRANSITIVE,
-- SP_INFER_INVERSE, SP_CHECK_CARDINALITY_SINGLE, SP_CHECK_REFERENTIAL)
-- use Python f-string interpolation to construct SQL from their input
-- parameters. This is safe when callers are trusted administrators, but
-- if you expose these procedures to untrusted users, the string parameters
-- (e.g., TARGET_REL, RULE_ID, REL, CHECK_NAME) could be exploited for
-- SQL injection. In that case, add strict input validation or refactor
-- to use parameterized queries.
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- SP_INFER_TRANSITIVE
-- Computes transitive closure for a relationship
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_INFER_TRANSITIVE(TARGET_REL STRING, RULE_ID STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'infer_transitive'
AS
$$
def infer_transitive(session, target_rel, rule_id):
    """
    Computes transitive closure for a relationship type.
    If A->B and B->C via the same relationship, infers A->C.
    """
    
    # Clear previous inferences for this rule
    session.sql(f"""
        DELETE FROM REL_EDGE_INFERRED 
        WHERE RULE_ID = '{rule_id}'
    """).collect()
    
    # Compute transitive closure
    infer_sql = f"""
        INSERT INTO REL_EDGE_INFERRED (REL_NAME, SRC_ID, DST_ID, INFERENCE_KIND, RULE_ID, WEIGHT)
        WITH RECURSIVE transitive(src, dst, depth) AS (
            -- Base case: direct edges
            SELECT SRC_ID, DST_ID, 1
            FROM KG_EDGE
            WHERE EDGE_TYPE = '{target_rel}'
            UNION ALL
            -- Recursive case: extend paths
            SELECT t.src, e.DST_ID, t.depth + 1
            FROM transitive t
            JOIN KG_EDGE e ON t.dst = e.SRC_ID AND e.EDGE_TYPE = '{target_rel}'
            WHERE t.depth < 5
            AND t.src != e.DST_ID  -- prevent cycles
        )
        SELECT DISTINCT
            '{target_rel}' AS REL_NAME,
            src AS SRC_ID,
            dst AS DST_ID,
            'TRANSITIVE' AS INFERENCE_KIND,
            '{rule_id}' AS RULE_ID,
            1.0 / depth AS WEIGHT
        FROM transitive
        WHERE (src, dst) NOT IN (
            SELECT SRC_ID, DST_ID FROM KG_EDGE WHERE EDGE_TYPE = '{target_rel}'
        )
    """
    
    result = session.sql(infer_sql).collect()
    
    # Count inferred edges
    count_sql = f"""
        SELECT COUNT(*) as cnt FROM REL_EDGE_INFERRED WHERE RULE_ID = '{rule_id}'
    """
    count = session.sql(count_sql).collect()[0]['CNT']
    
    return f"Inferred {count} transitive edges for {target_rel}"
$$;

-- =====================================================
-- SP_INFER_INVERSE
-- Creates inverse relationships (e.g., HAS_PLAYER from PLAYS_FOR)
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_INFER_INVERSE(RULE_ID STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'infer_inverse'
AS
$$
def infer_inverse(session, rule_id):
    """
    Creates inverse relationships based on ONT_RELATION_DEF.INVERSE_REL_NAME.
    If PLAYS_FOR has inverse HAS_PLAYER, creates HAS_PLAYER edges.
    """
    
    # Clear previous inferences for this rule
    session.sql(f"""
        DELETE FROM REL_EDGE_INFERRED 
        WHERE RULE_ID = '{rule_id}'
    """).collect()
    
    # Get relationships with defined inverses
    rels_sql = """
        SELECT REL_NAME, INVERSE_REL_NAME
        FROM ONT_RELATION_DEF
        WHERE INVERSE_REL_NAME IS NOT NULL
        AND STATUS = 'ACTIVE'
    """
    
    rels = session.sql(rels_sql).collect()
    
    total_inferred = 0
    
    for rel in rels:
        rel_name = rel['REL_NAME']
        inverse_name = rel['INVERSE_REL_NAME']
        
        # Insert inverse edges
        infer_sql = f"""
            INSERT INTO REL_EDGE_INFERRED (REL_NAME, SRC_ID, DST_ID, INFERENCE_KIND, RULE_ID, WEIGHT, EFFECTIVE_START, EFFECTIVE_END)
            SELECT 
                '{inverse_name}' AS REL_NAME,
                DST_ID AS SRC_ID,
                SRC_ID AS DST_ID,
                'INVERSE' AS INFERENCE_KIND,
                '{rule_id}' AS RULE_ID,
                WEIGHT,
                EFFECTIVE_START,
                EFFECTIVE_END
            FROM KG_EDGE
            WHERE EDGE_TYPE = '{rel_name}'
        """
        
        session.sql(infer_sql).collect()
        
        # Count inferred
        count_sql = f"""
            SELECT COUNT(*) as cnt FROM REL_EDGE_INFERRED 
            WHERE RULE_ID = '{rule_id}' AND REL_NAME = '{inverse_name}'
        """
        count = session.sql(count_sql).collect()[0]['CNT']
        total_inferred += count
    
    return f"Inferred {total_inferred} inverse edges"
$$;

-- =====================================================
-- SP_RUN_ONTOLOGY_INFERENCE
-- Master procedure to run all enabled inference rules
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_RUN_ONTOLOGY_INFERENCE()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_inference'
AS
$$
def run_inference(session):
    """
    Runs all enabled inference rules in the correct order.
    """
    results = []
    
    # Get enabled rules
    rules_sql = """
        SELECT RULE_ID, RULE_KIND, TARGET_REL, SOURCE_REL_1, SOURCE_REL_2, INVERSE_OF
        FROM ONT_RULE
        WHERE IS_ENABLED = TRUE
        ORDER BY 
            CASE RULE_KIND 
                WHEN 'INVERSE' THEN 1 
                WHEN 'TRANSITIVE' THEN 2 
                WHEN 'PROPERTY_CHAIN' THEN 3 
            END
    """
    
    rules = session.sql(rules_sql).collect()
    
    for rule in rules:
        rule_id = rule['RULE_ID']
        rule_kind = rule['RULE_KIND']
        
        try:
            if rule_kind == 'INVERSE':
                result = session.call('SP_INFER_INVERSE', rule_id)
                results.append(f"{rule_id}: {result}")
                
            elif rule_kind == 'TRANSITIVE':
                target_rel = rule['TARGET_REL']
                result = session.call('SP_INFER_TRANSITIVE', target_rel, rule_id)
                results.append(f"{rule_id}: {result}")
                
        except Exception as e:
            results.append(f"{rule_id}: ERROR - {str(e)}")
    
    return "\\n".join(results)
$$;

-- =====================================================
-- SP_CHECK_CARDINALITY_SINGLE
-- Checks cardinality constraints (e.g., 1:1 relationships)
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_CHECK_CARDINALITY_SINGLE(REL STRING, CHECK_NAME STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'check_cardinality'
AS
$$
def check_cardinality(session, rel, check_name):
    """
    Checks that a relationship has at most one edge per source node.
    Records violations in ONT_CONSTRAINT_VIOLATION.
    """
    
    check_sql = f"""
        INSERT INTO ONT_CONSTRAINT_VIOLATION (CHECK_NAME, SCOPE, REL_OR_CLASS, SRC_ID, DETAILS)
        SELECT 
            '{check_name}' AS CHECK_NAME,
            'RELATION' AS SCOPE,
            '{rel}' AS REL_OR_CLASS,
            SRC_ID,
            'Multiple edges from same source: ' || COUNT(*) || ' edges'
        FROM KG_EDGE
        WHERE EDGE_TYPE = '{rel}'
        AND (EFFECTIVE_END IS NULL OR EFFECTIVE_END >= CURRENT_DATE())
        GROUP BY SRC_ID
        HAVING COUNT(*) > 1
    """
    
    session.sql(check_sql).collect()
    
    count_sql = f"""
        SELECT COUNT(*) as cnt FROM ONT_CONSTRAINT_VIOLATION 
        WHERE CHECK_NAME = '{check_name}'
    """
    count = session.sql(count_sql).collect()[0]['CNT']
    
    return f"Found {count} cardinality violations for {rel}"
$$;

-- =====================================================
-- SP_CHECK_REFERENTIAL
-- Checks referential integrity (edges reference valid nodes)
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_CHECK_REFERENTIAL(REL STRING, CHECK_NAME STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'check_referential'
AS
$$
def check_referential(session, rel, check_name):
    """
    Checks that all edge endpoints reference existing nodes.
    Records violations in ONT_CONSTRAINT_VIOLATION.
    """
    
    # Check source references
    check_src_sql = f"""
        INSERT INTO ONT_CONSTRAINT_VIOLATION (CHECK_NAME, SCOPE, REL_OR_CLASS, SRC_ID, DETAILS)
        SELECT 
            '{check_name}' AS CHECK_NAME,
            'RELATION' AS SCOPE,
            '{rel}' AS REL_OR_CLASS,
            e.SRC_ID,
            'Source node not found'
        FROM KG_EDGE e
        LEFT JOIN KG_NODE n ON e.SRC_ID = n.NODE_ID
        WHERE e.EDGE_TYPE = '{rel}'
        AND n.NODE_ID IS NULL
    """
    
    session.sql(check_src_sql).collect()
    
    # Check destination references
    check_dst_sql = f"""
        INSERT INTO ONT_CONSTRAINT_VIOLATION (CHECK_NAME, SCOPE, REL_OR_CLASS, DST_ID, DETAILS)
        SELECT 
            '{check_name}' AS CHECK_NAME,
            'RELATION' AS SCOPE,
            '{rel}' AS REL_OR_CLASS,
            e.DST_ID,
            'Destination node not found'
        FROM KG_EDGE e
        LEFT JOIN KG_NODE n ON e.DST_ID = n.NODE_ID
        WHERE e.EDGE_TYPE = '{rel}'
        AND n.NODE_ID IS NULL
    """
    
    session.sql(check_dst_sql).collect()
    
    count_sql = f"""
        SELECT COUNT(*) as cnt FROM ONT_CONSTRAINT_VIOLATION 
        WHERE CHECK_NAME = '{check_name}'
    """
    count = session.sql(count_sql).collect()[0]['CNT']
    
    return f"Found {count} referential integrity violations for {rel}"
$$;

COMMENT ON PROCEDURE SP_INFER_TRANSITIVE(STRING, STRING) IS 'Computes transitive closure for a relationship type';
COMMENT ON PROCEDURE SP_INFER_INVERSE(STRING) IS 'Creates inverse relationships based on ontology definitions';
COMMENT ON PROCEDURE SP_RUN_ONTOLOGY_INFERENCE() IS 'Master procedure to run all enabled inference rules';
COMMENT ON PROCEDURE SP_CHECK_CARDINALITY_SINGLE(STRING, STRING) IS 'Checks cardinality constraints for relationships';
COMMENT ON PROCEDURE SP_CHECK_REFERENTIAL(STRING, STRING) IS 'Checks referential integrity for edges';
