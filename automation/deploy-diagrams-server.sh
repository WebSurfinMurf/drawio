#!/bin/bash

# Deploy script for Diagram Server with OAuth2 Proxy and Traefik
# Provides authentication via Keycloak

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="${PROJECTS_DIR}/data/diagrams-nginx"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAIN_DOMAIN="nginx.ai-servicers.com"
DIAGRAMS_DOMAIN="diagrams.nginx.ai-servicers.com"
KEYCLOAK_REALM="master"
KEYCLOAK_URL="http://keycloak:8080"
KEYCLOAK_PUBLIC_URL="https://keycloak.ai-servicers.com"

echo -e "${GREEN}=== Deploying Diagram Server with Authentication ===${NC}"
echo ""

# Function to generate secure random string
generate_secret() {
    openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64
}

# Check if we need to set up OAuth2 client in Keycloak
echo -e "${YELLOW}Note: You need to create a client in Keycloak for 'diagrams' if not already done${NC}"
echo -e "${YELLOW}Client settings needed:${NC}"
echo "  - Client ID: nginx-diagrams"
echo "  - Client Protocol: openid-connect"
echo "  - Valid Redirect URIs: https://${DIAGRAMS_DOMAIN}/oauth2/callback"
echo "  - Web Origins: https://${DIAGRAMS_DOMAIN}"
echo ""

# Ask for configuration
read -p "Do you want to deploy WITH authentication? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    WITH_AUTH=true
    
    # Get client secret
    echo -e "${YELLOW}Enter the Keycloak client secret for 'nginx-diagrams' client:${NC}"
    read -s CLIENT_SECRET
    echo
    
    if [ -z "$CLIENT_SECRET" ]; then
        echo -e "${RED}Client secret is required for authenticated deployment${NC}"
        exit 1
    fi
    
    # Generate cookie secret
    COOKIE_SECRET=$(generate_secret)
else
    WITH_AUTH=false
fi

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"

# Create nginx configuration
cat > "$DATA_DIR/nginx-diagrams.conf" << 'NGINX'
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Enable directory listing
    location / {
        try_files $uri $uri/ =404;
        autoindex on;
        autoindex_exact_size off;
        autoindex_format html;
        autoindex_localtime on;
    }
    
    # Set correct MIME types
    location ~ \.svg$ {
        add_header Content-Type image/svg+xml;
    }
    
    location ~ \.drawio$ {
        add_header Content-Type application/xml;
        add_header Content-Disposition "attachment";
    }
    
    # Enable CORS
    location ~* \.(svg|drawio|png|jpg|jpeg)$ {
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept";
    }
}
NGINX

# Stop and remove existing containers
echo -e "${YELLOW}Removing existing containers if present...${NC}"
docker stop diagrams-nginx diagrams-auth-proxy 2>/dev/null
docker rm diagrams-nginx diagrams-auth-proxy 2>/dev/null

# Deploy nginx container (backend)
echo -e "${GREEN}Starting nginx diagram server...${NC}"
docker run -d \
    --name diagrams-nginx \
    --network traefik-proxy \
    -v "$DATA_DIR:/usr/share/nginx/html:ro" \
    -v "$DATA_DIR/nginx-diagrams.conf:/etc/nginx/conf.d/default.conf:ro" \
    --restart unless-stopped \
    nginx:alpine

if [ "$WITH_AUTH" = true ]; then
    # Deploy OAuth2 Proxy
    echo -e "${GREEN}Starting OAuth2 proxy for authentication...${NC}"
    docker run -d \
        --name diagrams-auth-proxy \
        --network traefik-proxy \
        -e OAUTH2_PROXY_PROVIDER=oidc \
        -e OAUTH2_PROXY_CLIENT_ID=nginx-diagrams \
        -e OAUTH2_PROXY_CLIENT_SECRET="$CLIENT_SECRET" \
        -e OAUTH2_PROXY_COOKIE_SECRET="$COOKIE_SECRET" \
        -e OAUTH2_PROXY_EMAIL_DOMAINS="*" \
        -e OAUTH2_PROXY_OIDC_ISSUER_URL="${KEYCLOAK_PUBLIC_URL}/realms/${KEYCLOAK_REALM}" \
        -e OAUTH2_PROXY_LOGIN_URL="${KEYCLOAK_PUBLIC_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth" \
        -e OAUTH2_PROXY_REDEEM_URL="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
        -e OAUTH2_PROXY_OIDC_JWKS_URL="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/certs" \
        -e OAUTH2_PROXY_REDIRECT_URL="https://${DIAGRAMS_DOMAIN}/oauth2/callback" \
        -e OAUTH2_PROXY_UPSTREAMS="http://diagrams-nginx:80" \
        -e OAUTH2_PROXY_HTTP_ADDRESS="0.0.0.0:4180" \
        -e OAUTH2_PROXY_COOKIE_SECURE=true \
        -e OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true \
        -e OAUTH2_PROXY_SKIP_OIDC_DISCOVERY=true \
        -e OAUTH2_PROXY_INSECURE_OIDC_SKIP_ISSUER_VERIFICATION=true \
        -e OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=true \
        -e OAUTH2_PROXY_PASS_ACCESS_TOKEN=false \
        -e OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER=false \
        -e OAUTH2_PROXY_PASS_USER_HEADERS=false \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.diagrams.rule=Host(\`${DIAGRAMS_DOMAIN}\`)" \
        --label "traefik.http.routers.diagrams.entrypoints=websecure" \
        --label "traefik.http.routers.diagrams.tls=true" \
        --label "traefik.http.routers.diagrams.tls.certresolver=letsencrypt" \
        --label "traefik.http.services.diagrams.loadbalancer.server.port=4180" \
        --restart unless-stopped \
        quay.io/oauth2-proxy/oauth2-proxy:v7.12.0
    
    CONTAINER_NAME="diagrams-auth-proxy"
else
    # Direct nginx exposure without auth
    echo -e "${GREEN}Configuring direct access (no authentication)...${NC}"
    docker stop diagrams-nginx
    docker rm diagrams-nginx
    
    docker run -d \
        --name diagrams-nginx \
        --network traefik-proxy \
        -v "$DATA_DIR:/usr/share/nginx/html:ro" \
        -v "$DATA_DIR/nginx-diagrams.conf:/etc/nginx/conf.d/default.conf:ro" \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.diagrams.rule=Host(\`${DIAGRAMS_DOMAIN}\`)" \
        --label "traefik.http.routers.diagrams.entrypoints=websecure" \
        --label "traefik.http.routers.diagrams.tls=true" \
        --label "traefik.http.routers.diagrams.tls.certresolver=letsencrypt" \
        --label "traefik.http.services.diagrams.loadbalancer.server.port=80" \
        --restart unless-stopped \
        nginx:alpine
    
    CONTAINER_NAME="diagrams-nginx"
fi

# Check if container started successfully
sleep 3
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo ""
    echo -e "${GREEN}=== Deployment Successful ===${NC}"
    echo ""
    echo -e "${BLUE}📊 Access your diagrams at:${NC}"
    echo -e "   ${GREEN}https://${DIAGRAMS_DOMAIN}${NC}"
    echo -e "   ${GREEN}https://${DIAGRAMS_DOMAIN}/infrastructure.drawio${NC}"
    echo ""
    if [ "$WITH_AUTH" = true ]; then
        echo -e "${YELLOW}🔒 Authentication: Required (via Keycloak)${NC}"
    else
        echo -e "${YELLOW}⚠️  Authentication: DISABLED (public access)${NC}"
    fi
    echo ""
    echo -e "${BLUE}Available files:${NC}"
    ls -la "$DATA_DIR"/*.svg 2>/dev/null | awk '{print "  - " $NF}'
    echo ""
    echo -e "${YELLOW}Note: Make sure ${DIAGRAMS_DOMAIN} points to your server's IP${NC}"
    echo -e "${YELLOW}      You'll also want to set up ${MAIN_DOMAIN} for the main nginx site${NC}"
else
    echo -e "${RED}Failed to start container${NC}"
    docker logs "$CONTAINER_NAME"
    exit 1
fi