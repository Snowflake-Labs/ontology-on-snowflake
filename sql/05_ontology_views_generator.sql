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
-- LAYER 3: ONTOLOGY VIEWS GENERATOR
-- Stored procedure to auto-generate abstract views from metadata
-- =====================================================
--
-- SECURITY WARNING: SP_GENERATE_ONTOLOGY_VIEWS uses dynamic SQL built from
-- values in the ONT_CLASS_MAP and ONT_REL_MAP metadata tables. This is safe
-- when metadata is managed by trusted administrators, but if you extend the
-- access model to allow untrusted callers to write to those metadata tables,
-- the dynamic SQL could be exploited for SQL/DDL injection. In that case,
-- add strict input validation or use parameterized queries.
-- =====================================================

USE DATABASE ONTOLOGY_DB;
USE SCHEMA SOCCER_KG;

-- =====================================================
-- SP_GENERATE_ONTOLOGY_VIEWS
-- Generates abstract views from ONT_CLASS_MAP metadata
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_GENERATE_ONTOLOGY_VIEWS()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'generate_views'
AS
$$
def generate_views(session):
    """
    Generates abstract ontology views by reading metadata from ONT_CLASS and ONT_CLASS_MAP tables.
    For each abstract class, creates a UNION ALL view combining all concrete implementations.
    """
    import json
    
    results = []
    
    # Get abstract classes and their mappings
    abstract_classes_sql = """
        SELECT DISTINCT c.CLASS_NAME, c.PARENT_CLASS_NAME, c.DESCRIPTION
        FROM ONT_CLASS c
        WHERE c.IS_ABSTRACT = TRUE
        AND c.ONTOLOGY_NAME = 'SOCCER_V1'
        ORDER BY c.CLASS_NAME
    """
    
    abstract_classes = session.sql(abstract_classes_sql).collect()
    
    for ac in abstract_classes:
        class_name = ac['CLASS_NAME']
        
        # Get concrete implementations for this abstract class
        mappings_sql = f"""
            SELECT cm.CONCRETE_VIEW, cm.ID_COL, c.CLASS_NAME as SUBTYPE
            FROM ONT_CLASS_MAP cm
            JOIN ONT_CLASS c ON cm.CLASS_NAME = c.CLASS_NAME
            WHERE c.PARENT_CLASS_NAME = '{class_name}'
            OR c.CLASS_NAME = '{class_name}'
            ORDER BY c.CLASS_NAME
        """
        
        mappings = session.sql(mappings_sql).collect()
        
        if len(mappings) == 0:
            results.append(f"SKIP: {class_name} - no concrete mappings")
            continue
        
        # Build UNION ALL query
        union_parts = []
        for m in mappings:
            concrete_view = m['CONCRETE_VIEW']
            id_col = m['ID_COL']
            subtype = m['SUBTYPE']
            
            part = f"""
                SELECT 
                    {id_col} AS ID,
                    '{subtype}' AS SUBTYPE,
                    '{concrete_view}' AS SRC_VIEW
                FROM {concrete_view}
            """
            union_parts.append(part.strip())
        
        if len(union_parts) > 0:
            view_ddl = f"""
                CREATE OR REPLACE VIEW VW_ONT_{class_name.upper()} AS
                {' UNION ALL '.join(union_parts)}
            """
            
            # Execute the CREATE VIEW statement
            session.sql(view_ddl).collect()
            
            results.append(f"OK: VW_ONT_{class_name.upper()} created with {len(union_parts)} sources")
    
    # Now generate abstract relationship views
    abstract_rels_sql = """
        SELECT DISTINCT r.REL_NAME, r.DOMAIN_CLASS, r.RANGE_CLASS, r.DESCRIPTION
        FROM ONT_RELATION_DEF r
        JOIN ONT_CLASS dc ON r.DOMAIN_CLASS = dc.CLASS_NAME
        WHERE dc.IS_ABSTRACT = TRUE
        AND r.ONTOLOGY_NAME = 'SOCCER_V1'
        ORDER BY r.REL_NAME
    """
    
    abstract_rels = session.sql(abstract_rels_sql).collect()
    
    for ar in abstract_rels:
        rel_name = ar['REL_NAME']
        
        # Get concrete implementations for this abstract relationship
        rel_mappings_sql = f"""
            SELECT rm.CONCRETE_VIEW, rm.SRC_COL, rm.DST_COL, rm.PROPS_COL,
                   r.REL_NAME as VIA_REL
            FROM ONT_REL_MAP rm
            JOIN ONT_RELATION_DEF r ON rm.REL_NAME = r.REL_NAME
            WHERE r.REL_NAME IN (
                SELECT r2.REL_NAME FROM ONT_RELATION_DEF r2
                JOIN ONT_CLASS c ON r2.DOMAIN_CLASS = c.CLASS_NAME
                WHERE c.PARENT_CLASS_NAME IN (
                    SELECT DOMAIN_CLASS FROM ONT_RELATION_DEF WHERE REL_NAME = '{rel_name}'
                )
                OR r2.REL_NAME = '{rel_name}'
            )
            ORDER BY r.REL_NAME
        """
        
        rel_mappings = session.sql(rel_mappings_sql).collect()
        
        if len(rel_mappings) == 0:
            results.append(f"SKIP: {rel_name} - no concrete mappings")
            continue
        
        # Build UNION ALL query for relationships
        rel_union_parts = []
        for rm in rel_mappings:
            concrete_view = rm['CONCRETE_VIEW']
            src_col = rm['SRC_COL']
            dst_col = rm['DST_COL']
            props_col = rm['PROPS_COL'] or 'NULL'
            via_rel = rm['VIA_REL']
            
            # Determine subject and object classes from the concrete view name
            subject_class = 'Player' if 'PLAYS_FOR' in concrete_view else ('Coach' if 'COACHES' in concrete_view else 'Club')
            object_class = 'Club' if 'CLUB' in dst_col.upper() else ('Match' if 'MATCH' in dst_col.upper() else 'Organization')
            
            rel_part = f"""
                SELECT 
                    {src_col} AS SUBJECT_ID,
                    '{subject_class}' AS SUBJECT_CLASS,
                    {dst_col} AS OBJECT_ID,
                    '{object_class}' AS OBJECT_CLASS,
                    '{via_rel}' AS VIA_REL,
                    '{concrete_view}' AS SRC_VIEW,
                    {props_col} AS PROPS,
                    EFFECTIVE_START,
                    EFFECTIVE_END,
                    WEIGHT
                FROM {concrete_view}
            """
            rel_union_parts.append(rel_part.strip())
        
        if len(rel_union_parts) > 0:
            rel_view_ddl = f"""
                CREATE OR REPLACE VIEW VW_ONT_{rel_name.upper()} AS
                {' UNION ALL '.join(rel_union_parts)}
            """
            
            # Execute the CREATE VIEW statement
            session.sql(rel_view_ddl).collect()
            
            results.append(f"OK: VW_ONT_{rel_name.upper()} created with {len(rel_union_parts)} sources")
    
    return "\\n".join(results)
$$;

COMMENT ON PROCEDURE SP_GENERATE_ONTOLOGY_VIEWS() IS 'Generates abstract ontology views from metadata';
