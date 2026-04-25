<!--
Copyright 2026 Snowflake Inc.
SPDX-License-Identifier: Apache-2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Deploying MCP Server to Snowflake SPCS

## 🎯 Architecture Overview

Your MCP server is deployed as a custom SPCS container service:

```
┌─────────────────────────────────────────────────┐
│  Snowflake SPCS (Container Services)            │
│  ┌───────────────────────────────────────────┐  │
│  │  Docker Container                         │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │  soccer_mcp_server.py               │  │  │
│  │  │  - FastMCP framework                │  │  │
│  │  │  - NetworkX graph analytics         │  │  │
│  │  │  - HTTP endpoints (port 5000)       │  │  │
│  │  │  - 5 custom tools                   │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
         ↕ HTTP
┌─────────────────────────────────────────────────┐
│  Cortex Agent (SQL UDFs or External Functions)  │
└─────────────────────────────────────────────────┘
```

**✅ This is what `deploy_spcs.sh` does!**

---

## ✅ **Your Setup: Custom MCP Server via SPCS**

Your `deploy_spcs.sh` is correctly designed to deploy your custom MCP server as an SPCS container. The MCP server uses **static JSON files** from the `graph_data/` directory - no Snowflake database connection or authentication required for graph data.

### **Prerequisites**

Before deploying, ensure you have:
- ✅ Docker installed and running
- ✅ Access to Snowflake account (replace `XXXXXX` in config files with your account identifier, e.g., `abc12345.us-east-1`)
- ✅ Snowflake role with SPCS permissions: `ONTOLOGY_DEPLOY_ROLE` (recommended) or `ACCOUNTADMIN` (see `deploy_to_spcs.sql` for role setup)
- ✅ Virtual warehouse: `COMPUTE_WH`
- ✅ Database: `ONTOLOGY_DB` and schema: `SOCCER_KG`
- ✅ `graph_data/` directory with JSON files (included in repo)

---

## 🚀 **Step-by-Step SPCS Deployment**

### **Step 1: Setup Snowflake Infrastructure**

Execute `deploy_to_spcs.sql` in Snowflake to create:
- Image repository: `soccer_graph_analytics_repo`
- Compute pool: `soccer_graph_compute_pool`
- Stage: `soccer_graph_service_spec`

**📄 File:** `deploy_to_spcs.sql` (lines 6-28)

### **Step 2: Login to Snowflake Docker Registry**

Before pushing Docker images, authenticate with the Snowflake Container Registry. You have two authentication options:

#### **Option A: Username and Password (Interactive)**

```bash
docker login <your-account-id>.registry.snowflakecomputing.com
# Replace <your-account-id> with your actual Snowflake account identifier (e.g., abc12345.us-east-1)
# When prompted:
#   Username: Your Snowflake username
#   Password: Your Snowflake password
```

#### **Option B: Personal Access Token (PAT) - Recommended for Automation**

**Step 1: Generate a PAT in Snowflake:**
1. Log into Snowsight
2. Click on your username → **My Profile**
3. Go to **Password & Authentication**
4. Under **Personal Access Tokens**, click **Generate Token**
5. Copy the token (you'll only see it once!)

**Step 2: Authenticate with Docker using PAT:**

```bash
# Interactive method (will prompt for password)
docker login <your-account-id>.registry.snowflakecomputing.com -u <your-username>
# When prompted for password, paste your PAT token

# Or, non-interactive method (for scripts/automation)
echo "<your-PAT-token>" | docker login <your-account-id>.registry.snowflakecomputing.com -u <your-username> --password-stdin
```

**Note:** Use your actual Snowflake username, not the literal string "USER". The PAT serves as your password.

**Why use PAT?**
- ✅ More secure (can be revoked without changing your password)
- ✅ Better for automation and CI/CD pipelines
- ✅ Can have limited scope and expiration
- ✅ No multi-factor authentication prompts

### **Step 3: Build and Push Docker Image**

```bash
chmod +x deploy_spcs.sh
./deploy_spcs.sh
```

This builds the Docker image (linux/amd64), tags it, and pushes to Snowflake registry.

### **Step 4: Upload Service Specification**

Upload `service.yaml` to Snowflake stage `soccer_graph_service_spec`:
- **Via Snowflake UI:** Data → Databases → ONTOLOGY_DB → SOCCER_KG → Stages → soccer_graph_service_spec → Upload Files
- **Via SnowSQL:** `PUT file://service.yaml @soccer_graph_service_spec AUTO_COMPRESS=FALSE;`

### **Step 5: Create SPCS Service**

Execute service creation commands from `deploy_to_spcs.sql`:

**📄 File:** `deploy_to_spcs.sql` (lines 42-56)

Wait 2-3 minutes for service status to change: `PENDING` → `STARTING` → `READY`

### **Step 6: Verify Deployment**

Check service status and logs:
```sql
SHOW SERVICES;
SHOW SERVICE CONTAINERS IN SERVICE soccer_graph_analytics_service;
```

**📄 File:** `deploy_to_spcs.sql` (lines 54-68) for complete verification commands

### **Step 7: Create Service Functions**

Execute all commands from `spcs_service_functions.sql`:
- Create 5 Service Functions (Steps 2-3)
- Test functions (Step 4)
- Configure Cortex Agent (Step 5)

**📄 File:** `spcs_service_functions.sql` (complete workflow)

---

## 🔧 **Service Architecture**

**Key Configuration (`service.yaml`):**
- HTTP mode for SPCS (`MCP_TRANSPORT=http`)
- Graph data preloaded from static JSON files (`graph_data/`)
- Health check endpoint at `/health`
- Internal-only access (`public: false`)
- No Snowflake database connection or authentication required

---

## 🎯 **Integration with Cortex Agent**

Add all 5 Service Functions as custom tools in Cortex Agent:

**Snowsight:** AI & ML → Agents → [Your Agent] → Edit → Tools → Custom tools → Add

**📄 File:** `spcs_service_functions.sql` (Step 5) for complete configuration details for each tool

---

## 🔍 **Troubleshooting**

**Common Issues:**

1. **Docker Push Failed:** Re-login to Snowflake registry
2. **Service Status = FAILED:** Check logs and verify linux/amd64 platform
3. **Health Check Failing:** Verify endpoints and container status
4. **Compute Pool Issues:** Check pool status and resume if needed

**View Logs:**
```sql
SELECT SYSTEM$GET_SERVICE_LOGS('soccer_graph_analytics_service', '0', 'mcp-server', 100);
```

**📄 File:** `deploy_to_spcs.sql` (lines 58-68) for monitoring commands

---

## ✅ **Deployment Checklist**

1. [ ] Snowflake infrastructure created (Step 1)
2. [ ] Docker image built and pushed (Steps 2-3)
3. [ ] Service specification uploaded (Step 4)
4. [ ] SPCS service created and status = `READY` (Step 5)
5. [ ] Service logs show successful graph data loading (Step 6)
6. [ ] Service Functions created and tested (Step 7)
7. [ ] Service Functions added to Cortex Agent
8. [ ] Natural language queries working

---

## 📚 **Reference Files**

- **`deploy_to_spcs.sql`** - Complete Snowflake setup and SPCS deployment
- **`spcs_service_functions.sql`** - Service Functions and Cortex Agent integration
- **`deploy_spcs.sh`** - Docker build and push automation
- **`service.yaml`** - SPCS service specification

---

## 🎉 **What You've Built**

A production-ready MCP server on SPCS that:
- Uses static JSON files (no database connection needed)
- Provides 5 NetworkX graph analytics tools
- Integrates with Cortex Agent for natural language queries
- Scales automatically with MIN/MAX instances

**You're ready to deploy!** 🚀⚽

## License

Copyright (c) Snowflake Inc. All rights reserved.

Licensed under the Apache 2.0 license.
