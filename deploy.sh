#!/bin/bash

# Draw.io Deployment Script (with optional OAuth2 Proxy)
# Owner: administrator
# Purpose: Deploy Draw.io with or without authentication

set -e

# Load environment variables
ENV_FILE="$HOME/projects/secrets/drawio.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "❌ Environment file not found: $ENV_FILE"
    exit 1
fi

echo "========================================="
echo "Deploying Draw.io"
echo "========================================="

# Stop and remove existing containers
echo "Stopping existing containers..."
docker stop "$DRAWIO_CONTAINER" 2>/dev/null || true
docker rm "$DRAWIO_CONTAINER" 2>/dev/null || true
docker stop "$OAUTH2_PROXY_CONTAINER" 2>/dev/null || true
docker rm "$OAUTH2_PROXY_CONTAINER" 2>/dev/null || true

# Create Docker volume for persistent data
echo "Creating Docker volume for Draw.io data..."
docker volume create drawio_data 2>/dev/null || true

if [ "$OAUTH2_PROXY_ENABLED" = "true" ] && [ "$KEYCLOAK_CLIENT_SECRET" != "CHANGE_ME_IN_KEYCLOAK" ]; then
    echo "==========================================="
    echo "Deploying with OAuth2 Proxy Authentication"
    echo "==========================================="
    
    # Generate cookie secret if not exists
    COOKIE_SECRET_FILE="$HOME/projects/secrets/oauth2-proxy-cookie.secret"
    if [ ! -f "$COOKIE_SECRET_FILE" ]; then
        echo "Generating cookie secret..."
        python3 -c 'import os,base64; print(base64.b64encode(os.urandom(24)).decode())' > "$COOKIE_SECRET_FILE"
        chmod 600 "$COOKIE_SECRET_FILE"
    fi
    COOKIE_SECRET=$(cat "$COOKIE_SECRET_FILE")
    
    # Deploy Draw.io (internal only) with larger header buffer
    echo "Starting Draw.io container (internal)..."
    docker run -d \
        --name "$DRAWIO_CONTAINER" \
        --network "$DRAWIO_NETWORK" \
        --restart unless-stopped \
        -v drawio_data:/var/lib/drawio \
        -e DRAWIO_SELF_CONTAINED="$DRAWIO_SELF_CONTAINED" \
        -e DRAWIO_LIGHTBOX="$DRAWIO_LIGHTBOX" \
        -e DRAWIO_OFFLINE="$DRAWIO_OFFLINE" \
        -e DRAWIO_PLUGINS="1" \
        -e CATALINA_OPTS="-Dorg.apache.coyote.http11.Http11Protocol.MAX_HEADER_SIZE=65536" \
        "$DRAWIO_IMAGE"
    
    # Deploy OAuth2 Proxy
    echo "Starting OAuth2 Proxy..."
    docker run -d \
        --name "$OAUTH2_PROXY_CONTAINER" \
        --network "$DRAWIO_NETWORK" \
        --restart unless-stopped \
        -p "${OAUTH2_PROXY_PORT}:4180" \
        -e OAUTH2_PROXY_PROVIDER=oidc \
        -e OAUTH2_PROXY_SKIP_OIDC_DISCOVERY=true \
        -e OAUTH2_PROXY_OIDC_ISSUER_URL="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}" \
        -e OAUTH2_PROXY_CLIENT_ID="$KEYCLOAK_CLIENT_ID" \
        -e OAUTH2_PROXY_CLIENT_SECRET="$KEYCLOAK_CLIENT_SECRET" \
        -e OAUTH2_PROXY_REDIRECT_URL="https://drawio.ai-servicers.com/oauth2/callback" \
        -e OAUTH2_PROXY_LOGIN_URL="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth" \
        -e OAUTH2_PROXY_REDEEM_URL="${KEYCLOAK_INTERNAL_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
        -e OAUTH2_PROXY_OIDC_JWKS_URL="${KEYCLOAK_INTERNAL_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/certs" \
        -e OAUTH2_PROXY_VALIDATE_URL="${KEYCLOAK_INTERNAL_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/userinfo" \
        -e OAUTH2_PROXY_COOKIE_SECRET="$COOKIE_SECRET" \
        -e OAUTH2_PROXY_COOKIE_SECURE=true \
        -e OAUTH2_PROXY_EMAIL_DOMAINS="*" \
        -e OAUTH2_PROXY_UPSTREAMS="http://${DRAWIO_CONTAINER}:8080" \
        -e OAUTH2_PROXY_HTTP_ADDRESS="0.0.0.0:4180" \
        -e OAUTH2_PROXY_PASS_ACCESS_TOKEN=false \
        -e OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER=false \
        -e OAUTH2_PROXY_PASS_USER_HEADERS=false \
        -e OAUTH2_PROXY_SET_XAUTHREQUEST=false \
        -e OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true \
        -e OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=true \
        -e OAUTH2_PROXY_INSECURE_OIDC_SKIP_ISSUER_VERIFICATION=true \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.drawio.rule=Host(\`drawio.ai-servicers.com\`)" \
        --label "traefik.http.routers.drawio.entrypoints=websecure" \
        --label "traefik.http.routers.drawio.tls=true" \
        --label "traefik.http.routers.drawio.tls.certresolver=letsencrypt" \
        --label "traefik.http.services.drawio.loadbalancer.server.port=4180" \
        "$OAUTH2_PROXY_IMAGE"

    # Connect OAuth2 proxy to keycloak-net for authentication
    echo "Connecting OAuth2 proxy to keycloak-net..."
    docker network create keycloak-net 2>/dev/null || echo "Network keycloak-net already exists"
    docker network connect keycloak-net "$OAUTH2_PROXY_CONTAINER" 2>/dev/null || true

    echo ""
    echo "✅ Deployed with OAuth2 Proxy authentication"
    echo "Access: https://drawio.ai-servicers.com (requires Keycloak login)"
    
else
    echo "==========================================="
    echo "Deploying without Authentication (Direct)"
    echo "==========================================="
    
    # Deploy Draw.io with direct access
    echo "Starting Draw.io container..."
    docker run -d \
        --name "$DRAWIO_CONTAINER" \
        --network "$DRAWIO_NETWORK" \
        --restart unless-stopped \
        -p "${DRAWIO_PORT}:8080" \
        -v drawio_data:/var/lib/drawio \
        -e DRAWIO_SELF_CONTAINED="$DRAWIO_SELF_CONTAINED" \
        -e DRAWIO_LIGHTBOX="$DRAWIO_LIGHTBOX" \
        -e DRAWIO_OFFLINE="$DRAWIO_OFFLINE" \
        -e DRAWIO_PLUGINS="1" \
        --label "traefik.enable=true" \
        --label "traefik.http.routers.drawio.rule=Host(\`drawio.ai-servicers.com\`)" \
        --label "traefik.http.routers.drawio.entrypoints=websecure" \
        --label "traefik.http.routers.drawio.tls=true" \
        --label "traefik.http.routers.drawio.tls.certresolver=letsencrypt" \
        --label "traefik.http.services.drawio.loadbalancer.server.port=8080" \
        "$DRAWIO_IMAGE"
    
    echo ""
    echo "✅ Deployed without authentication"
    echo "Access Points:"
    echo "  - External: https://drawio.ai-servicers.com"
    echo "  - Local: http://linuxserver.lan:${DRAWIO_PORT}"
    echo ""
    echo "To enable authentication:"
    echo "1. Configure Keycloak client for 'drawio'"
    echo "2. Update KEYCLOAK_CLIENT_SECRET in $ENV_FILE"
    echo "3. Set OAUTH2_PROXY_ENABLED=true in $ENV_FILE"
    echo "4. Run this script again"
fi

echo ""
echo "Waiting for services to start..."
sleep 5

# Check status
echo ""
echo "Container Status:"
docker ps | grep -E "drawio|oauth2" || echo "No containers running"

echo ""
echo "==========================================="
echo "Deployment Complete"
echo "==========================================="
echo ""
echo "Mermaid Diagrams:"
echo "  1. Open Draw.io"
echo "  2. Insert → Advanced → Mermaid"
echo "  3. Paste generated Mermaid code"
echo ""
echo "Sample diagram at: /home/administrator/projects/drawio/sample-network-diagram.mermaid"