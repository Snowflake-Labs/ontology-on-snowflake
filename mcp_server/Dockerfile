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

FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel
RUN pip install -r requirements.txt

# Copy application code
COPY soccer_mcp_server.py .

# Copy key files for authentication (if using key pair auth)
# COPY rsa_key.p8 .
# COPY rsa_key.pub .

# Copy static graph data (required - for graph analytics)
COPY graph_data/ /app/graph_data/

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV MCP_TRANSPORT=http

# Run the MCP server
CMD ["python", "soccer_mcp_server.py"]
