#!/bin/bash

# Automation pipeline for updating infrastructure diagrams
# Can be called from cron or CI/CD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use environment variable or default to user home
BASE_PATH="${DRAWIO_BASE_PATH:-$HOME}"
OUTPUT_DIR="${BASE_PATH}/projects/drawio/output"
NGINX_DIR="${BASE_PATH}/projects/data/nginx-main"
DIAGRAMS_NGINX_DIR="${BASE_PATH}/projects/data/diagrams-nginx"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Infrastructure Diagram Update Pipeline ===${NC}"
echo ""

# Generate new diagram
echo -e "${YELLOW}Generating new diagram from current infrastructure...${NC}"
cd "$SCRIPT_DIR"
# Export the base path for the Python script
export DRAWIO_BASE_PATH="${BASE_PATH}"
python3 generate_infrastructure_diagram.py

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Diagram generated successfully${NC}"
    
    # Copy to web servers
    echo -e "${YELLOW}Deploying to web servers...${NC}"
    
    # Copy from output directory to web servers
    cp "${OUTPUT_DIR}/infrastructure_latest.drawio" "$NGINX_DIR/infrastructure.drawio"
    echo -e "${GREEN}✅ Deployed to nginx.ai-servicers.com${NC}"
    
    # Copy to diagrams nginx (ensure directory exists)
    mkdir -p "$DIAGRAMS_NGINX_DIR"
    cp "${OUTPUT_DIR}/infrastructure_latest.drawio" "$DIAGRAMS_NGINX_DIR/infrastructure.drawio"
    echo -e "${GREEN}✅ Deployed to diagrams.nginx.ai-servicers.com${NC}"
    
    # Clean up old versions in history (keep only last 10)
    if [ -d "${OUTPUT_DIR}/history" ]; then
        ls -t "${OUTPUT_DIR}/history"/*.drawio 2>/dev/null | tail -n +11 | xargs -r rm
    fi
    
    echo ""
    echo -e "${GREEN}=== Update Complete ===${NC}"
    echo -e "${BLUE}Access your diagram at:${NC}"
    echo -e "  • https://nginx.ai-servicers.com/infrastructure.drawio"
    echo -e "  • https://diagrams.nginx.ai-servicers.com/infrastructure.drawio"
    echo ""
    echo -e "${BLUE}To edit:${NC}"
    echo -e "  1. Open Draw.io: https://drawio.ai-servicers.com"
    echo -e "  2. File → Open from → URL"
    echo -e "  3. Enter: https://nginx.ai-servicers.com/infrastructure.drawio"
    
else
    echo -e "${RED}❌ Failed to generate diagram${NC}"
    exit 1
fi