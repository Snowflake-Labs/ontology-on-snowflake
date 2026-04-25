#!/bin/bash

# Copyright 2026 Snowflake Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Deploy MCP Server to Snowflake SPCS
# Build, push, and deploy the MCP server to Snowflake Container Services

set -e

echo "🚀 SPCS Deployment for MCP Server"
echo "=================================="
echo ""

# Configuration
SNOWFLAKE_ACCOUNT="XXXXXX"  # Replace with your Snowflake account identifier
REGISTRY_URL="$SNOWFLAKE_ACCOUNT.registry.snowflakecomputing.com"
IMAGE_REPO="ontology_db/soccer_kg/soccer_graph_analytics_repo"
IMAGE_NAME="soccer_mcp_server"
FULL_IMAGE="$REGISTRY_URL/$IMAGE_REPO/$IMAGE_NAME:latest"

# Step 1: Build Docker Image
echo "📋 Step 1: Building Docker Image"
echo "Building with linux/amd64 platform (required for SPCS)..."
docker build --platform linux/amd64 -f Dockerfile -t soccer-mcp-server:latest .

if [ $? -eq 0 ]; then
    echo "✅ Docker image built successfully"
else
    echo "❌ Docker build failed"
    exit 1
fi

echo ""
echo "📋 Step 2: Tag Image for Snowflake Registry"
echo "Tagging image: $FULL_IMAGE"
docker tag soccer-mcp-server:latest $FULL_IMAGE

if [ $? -eq 0 ]; then
    echo "✅ Image tagged successfully"
else
    echo "❌ Image tagging failed"
    exit 1
fi

echo ""
echo "📋 Step 3: Push Image to Snowflake Registry"
echo "Pushing to: $REGISTRY_URL"
echo ""
echo "Note: You must be logged in to Snowflake Docker registry"
echo "If not logged in, run: docker login $REGISTRY_URL"
echo ""

docker push $FULL_IMAGE

if [ $? -eq 0 ]; then
    echo "✅ Image pushed successfully"
else
    echo "❌ Image push failed"
    echo ""
    echo "Troubleshooting:"
    echo "1. Ensure you're logged in: docker login $REGISTRY_URL"
    echo "2. Check image repository exists in Snowflake"
    echo "3. Verify permissions for the repository"
    exit 1
fi

echo ""
echo "📋 Step 4: Prepare SPCS Deployment Files"
echo "Creating SQL deployment script..."

cat > deploy_to_spcs.sql << EOF
-- MCP Server SPCS Deployment Script
-- Execute these commands in Snowflake Web UI

-- 1. Create stage for service specification (if not exists)
CREATE STAGE IF NOT EXISTS SOCCER_GRAPH_SERVICE_SPEC;

-- 2. Upload service.yaml to the stage
-- Note: You must upload service.yaml manually through Snowflake Web UI
-- Navigate to: Data → Databases → ONTOLOGY_DB → SOCCER_KG → Stages → SOCCER_GRAPH_SERVICE_SPEC
-- Click "Upload Files" and select service.yaml

-- 3. Create or replace the SPCS service
CREATE OR REPLACE SERVICE soccer_mcp_server
  IN COMPUTE POOL GRAPH_ANALYTICS_POOL
  FROM SPECIFICATION '@"ONTOLOGY_DB"."SOCCER_KG"."SOCCER_GRAPH_SERVICE_SPEC"/service.yaml';

-- 4. Grant usage permissions
GRANT USAGE ON SERVICE soccer_mcp_server TO PUBLIC;

-- 5. Verify service status (wait a few minutes for startup)
SHOW SERVICES;

-- 6. Check service containers
SHOW SERVICE CONTAINERS IN SERVICE soccer_mcp_server;

-- 7. View service logs (for troubleshooting)
SELECT SYSTEM\$GET_SERVICE_LOGS('soccer_mcp_server', 'mcp-server', 0);

-- 8. Get service URL (once service is running)
SELECT SYSTEM\$GET_SERVICE_URL('soccer_mcp_server', 'graph-api');
EOF

echo "✅ SQL deployment script created: deploy_to_spcs.sql"

echo ""
echo "🎉 SPCS Deployment Preparation Complete!"
echo "========================================"
echo ""
echo "✅ Docker image built (linux/amd64)"
echo "✅ Image tagged for Snowflake registry"
echo "✅ Image pushed to: $FULL_IMAGE"
echo "✅ SQL deployment script created"
echo ""
echo "📋 Manual Deployment Steps:"
echo ""
echo "1. Open Snowflake Web UI"
echo "2. Navigate to: Worksheets"
echo "3. Upload service.yaml to stage:"
echo "   - Go to: Data → Databases → ONTOLOGY_DB → SOCCER_KG → Stages"
echo "   - Create stage: SOCCER_GRAPH_SERVICE_SPEC (if not exists)"
echo "   - Upload: service.yaml"
echo ""
echo "4. Execute SQL commands from: deploy_to_spcs.sql"
echo "   - Copy and paste into a worksheet"
echo "   - Execute step by step"
echo "   - Wait 2-3 minutes for service to start"
echo ""
echo "5. Verify deployment:"
echo "   - Check service status: SHOW SERVICES;"
echo "   - View logs if needed: SELECT SYSTEM\$GET_SERVICE_LOGS(...);"
echo ""
echo "📄 Deployment Files Created:"
echo "  - deploy_to_spcs.sql (SQL commands)"
echo "  - service.yaml (SPCS service specification)"
echo "  - graph_data/ (Static JSON files - included in Docker image)"
echo ""
echo "📚 Documentation:"
echo "  - README.md (Quick start guide)"
echo "  - MCP_SERVER_README.md (Detailed guide)"
echo "  - QUICKSTART.md (5-minute setup)"
echo ""
echo "🔧 Troubleshooting:"
echo ""
echo "If service fails to start:"
echo "1. Check logs: SELECT SYSTEM\$GET_SERVICE_LOGS('soccer_mcp_server', 'mcp-server', 0);"
echo "2. Verify compute pool exists: SHOW COMPUTE POOLS;"
echo "3. Check image repository: SHOW IMAGE REPOSITORIES;"
echo "4. Verify service spec is uploaded: LIST @SOCCER_GRAPH_SERVICE_SPEC;"
echo ""
echo "🚀 Ready for SPCS deployment!"

