#!/bin/bash

# Deploy script for Main Nginx Server (nginx.ai-servicers.com)
# This will be the main landing page for all nginx-hosted services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$(dirname "$SCRIPT_DIR")"
NGINX_DATA_DIR="${PROJECTS_DIR}/data/nginx-main"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAIN_DOMAIN="nginx.ai-servicers.com"

echo -e "${GREEN}=== Deploying Main Nginx Server ===${NC}"
echo ""

# Create directory structure
mkdir -p "$NGINX_DATA_DIR"

# Create a landing page for nginx.ai-servicers.com
cat > "$NGINX_DATA_DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nginx Services Portal</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 800px;
            width: 100%;
        }
        
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 40px;
            font-size: 1.1em;
        }
        
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .service-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            text-decoration: none;
            color: #333;
            transition: all 0.3s;
            border: 2px solid transparent;
        }
        
        .service-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.15);
            border-color: #667eea;
        }
        
        .service-card h3 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 1.3em;
        }
        
        .service-card p {
            color: #666;
            line-height: 1.6;
        }
        
        .status {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            margin-left: 10px;
        }
        
        .status.active {
            background: #d4edda;
            color: #155724;
        }
        
        .status.coming-soon {
            background: #fff3cd;
            color: #856404;
        }
        
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e9ecef;
            color: #666;
        }
        
        .icon {
            font-size: 2em;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Nginx Services Portal</h1>
        <p class="subtitle">Central hub for nginx-hosted applications</p>
        
        <div class="services-grid">
            <a href="https://diagrams.nginx.ai-servicers.com" class="service-card">
                <div class="icon">📊</div>
                <h3>Diagrams <span class="status active">Active</span></h3>
                <p>View and import generated infrastructure diagrams, architecture visualizations, and Draw.io files</p>
            </a>
            
            <div class="service-card" style="opacity: 0.6; cursor: not-allowed;">
                <div class="icon">📝</div>
                <h3>Docs <span class="status coming-soon">Coming Soon</span></h3>
                <p>Technical documentation, API references, and system guides</p>
            </div>
            
            <div class="service-card" style="opacity: 0.6; cursor: not-allowed;">
                <div class="icon">📈</div>
                <h3>Metrics <span class="status coming-soon">Coming Soon</span></h3>
                <p>System metrics, performance dashboards, and monitoring tools</p>
            </div>
            
            <div class="service-card" style="opacity: 0.6; cursor: not-allowed;">
                <div class="icon">🔧</div>
                <h3>Tools <span class="status coming-soon">Coming Soon</span></h3>
                <p>Web-based utilities and administrative tools</p>
            </div>
        </div>
        
        <div class="footer">
            <p><strong>Server:</strong> linuxserver.lan | <strong>Powered by:</strong> Nginx + Traefik</p>
            <p style="margin-top: 10px; font-size: 0.9em;">
                Add more services by creating subdomains like <code>[service].nginx.ai-servicers.com</code>
            </p>
        </div>
    </div>
</body>
</html>
HTML

# Create nginx configuration
cat > "$NGINX_DATA_DIR/nginx.conf" << 'NGINX'
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX

# Stop and remove existing container if it exists
echo -e "${YELLOW}Removing existing main-nginx container if present...${NC}"
docker stop main-nginx 2>/dev/null
docker rm main-nginx 2>/dev/null

# Deploy main nginx container
echo -e "${GREEN}Starting main nginx server...${NC}"
docker run -d \
    --name main-nginx \
    --network traefik-proxy \
    -v "$NGINX_DATA_DIR:/usr/share/nginx/html:ro" \
    -v "$NGINX_DATA_DIR/nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.nginx-main.rule=Host(\`${MAIN_DOMAIN}\`)" \
    --label "traefik.http.routers.nginx-main.entrypoints=websecure" \
    --label "traefik.http.routers.nginx-main.tls=true" \
    --label "traefik.http.routers.nginx-main.tls.certresolver=letsencrypt" \
    --label "traefik.http.services.nginx-main.loadbalancer.server.port=80" \
    --restart unless-stopped \
    nginx:alpine

# Check if container started successfully
sleep 2
if docker ps | grep -q main-nginx; then
    echo ""
    echo -e "${GREEN}=== Main Nginx Server Deployed Successfully ===${NC}"
    echo ""
    echo -e "${BLUE}🌐 Main portal accessible at:${NC}"
    echo -e "   ${GREEN}https://${MAIN_DOMAIN}${NC}"
    echo ""
    echo -e "${BLUE}📊 Available subdomains:${NC}"
    echo -e "   ${GREEN}https://diagrams.nginx.ai-servicers.com${NC} - Diagram server"
    echo ""
    echo -e "${YELLOW}Note: Make sure these domains point to your server's IP:${NC}"
    echo -e "   - ${MAIN_DOMAIN}"
    echo -e "   - diagrams.nginx.ai-servicers.com"
    echo ""
    echo -e "${BLUE}To add more services:${NC}"
    echo "   1. Create a new subdomain like [service].nginx.ai-servicers.com"
    echo "   2. Deploy with similar Traefik labels"
    echo "   3. Update the main portal page at $NGINX_DATA_DIR/index.html"
else
    echo -e "${RED}Failed to start main nginx container${NC}"
    docker logs main-nginx
    exit 1
fi