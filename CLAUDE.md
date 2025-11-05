# Claude AI Assistant Notes - Draw.io

> **For overall environment context, see: `/home/administrator/projects/AINotes/AINotes.md`**

## Project Overview
Draw.io is a self-hosted diagram editor with:
- Mermaid diagram support for Claude-generated diagrams
- OAuth2 Proxy for Keycloak authentication
- Group-based access control (administrators vs developers)
- Full offline shape libraries

## Recent Work & Changes
_This section is updated by Claude during each session_

### Session: 2025-11-04
- **Data Location Standardization**: Moved runtime data to centralized location
  - Moved `drawio/output/` to `/projects/data/drawio/output/`
  - Updated automation scripts to use new path
  - Follows project data standard: all runtime data in `projects/data/{project}/`
- **Infrastructure Simplification**: Removed main-nginx container from drawio project
  - Portal page for nginx.ai-servicers.com moved to main nginx container
  - Consolidated from 3 nginx containers down to 2 (nginx, diagrams-nginx)
  - Removed deploy-main-nginx.sh from automation (no longer needed)
  - Data moved from data/nginx-main to nginx project

### Session: 2025-08-23
- **Automation Migration**: Moved from Kroki (static) to N2G/Draw.io (editable) diagrams
- Created Python-based infrastructure diagram generator
- Made output paths dynamic using environment variables
- Fixed network visualization (removed false routing through Keycloak)
- Added Internet and Internal Network nodes for better topology
- Created .gitignore to exclude generated output

### Session: 2025-08-22
- **Initial Deployment**: Set up Draw.io with OAuth2 Proxy
- Created deployment scripts for Keycloak integration
- Fixed cookie secret length issue (must be 24 bytes for 32-byte base64)
- Configured Traefik routing through OAuth2 proxy
- Created sample Mermaid diagram for testing

## Network Architecture
- **Primary Service**: Draw.io on `traefik-net` network (internal only)
- **Auth Proxy**: OAuth2 Proxy on `traefik-net` (exposed via Traefik)
- **Authentication**: Keycloak OIDC integration
- **URL**: https://drawio.ai-servicers.com

## Container Configuration
### Draw.io Container
- **Container**: drawio
- **Image**: jgraph/drawio:latest
- **Network**: traefik-net (internal only)
- **Port**: 8080 (not exposed directly)

### OAuth2 Proxy Container
- **Container**: drawio-auth-proxy
- **Image**: quay.io/oauth2-proxy/oauth2-proxy:latest
- **Network**: traefik-net
- **Port**: 8085 → 4180
- **Traefik Route**: drawio.ai-servicers.com

## Important Files & Paths
- **Deploy Script**: `/home/administrator/projects/drawio/deploy.sh` (handles both auth modes)
- **Environment**: `$HOME/projects/secrets/drawio.env`
- **Cookie Secret**: `$HOME/projects/secrets/oauth2-proxy-cookie.secret`
- **Keycloak Config Guide**: `/home/administrator/projects/drawio/keycloak-client-settings.md`
- **Automation Scripts**: `/home/administrator/projects/drawio/automation/`
  - `generate_infrastructure_diagram.py` - Creates editable Draw.io diagrams
  - `update-diagram.sh` - Pipeline runner script
- **Generated Output**: `/home/administrator/projects/data/drawio/output/` (centralized data location)
- **Served via NGINX**: https://diagrams.nginx.ai-servicers.com/

## Access Points
- **External**: https://drawio.ai-servicers.com (requires Keycloak login)
- **Local**: http://linuxserver.lan:8085 (requires Keycloak login)

## Keycloak Configuration Required
1. **Create Client in Keycloak Admin**:
   - Client ID: `drawio`
   - Client Protocol: `openid-connect`
   - Access Type: `confidential`
   - Valid Redirect URIs: `https://drawio.ai-servicers.com/oauth2/callback`
   - Web Origins: `https://drawio.ai-servicers.com`

2. **Get Client Secret**:
   - Go to Credentials tab
   - Copy the secret
   - Update in `deploy-with-oauth2-proxy.sh`

3. **Create Groups**:
   - `administrators` - Full access
   - `developers` - View access

4. **Create Group Mapper**:
   - Name: `groups`
   - Mapper Type: `Group Membership`
   - Token Claim Name: `groups`
   - Add to ID token: ON
   - Add to access token: ON

## Claude Integration
I can generate diagrams for Draw.io using:
1. **Mermaid syntax** (recommended):
   ```mermaid
   graph TD
       A[Start] --> B[Process]
       B --> C[End]
   ```
   - Insert → Advanced → Mermaid in Draw.io
   - Paste the generated code

2. **PlantUML** (if plugin enabled)
3. **Draw.io XML** (complex but possible)

## Known Issues & TODOs
- [ ] Configure Keycloak client and get secret
- [ ] Update CLIENT_SECRET in deployment script
- [ ] Test group-based access control
- [ ] Consider adding PlantUML server for additional diagram types

## Common Commands
```bash
# Deploy with OAuth2 Proxy
cd /home/administrator/projects/drawio
./deploy-with-oauth2-proxy.sh

# Check container status
docker ps | grep -E "drawio|oauth2"

# Check OAuth2 Proxy logs
docker logs drawio-auth-proxy --tail 20

# Check Draw.io logs
docker logs drawio --tail 20

# Restart services
docker restart drawio drawio-auth-proxy
```

## Troubleshooting
1. **OAuth2 Proxy restarting**: Check cookie secret is exactly 32 bytes (base64 of 24 bytes)
2. **Authentication errors**: Verify Keycloak client configuration
3. **Can't access Draw.io**: Ensure both containers are running
4. **Mermaid not working**: Use Insert → Advanced → Mermaid (not regular Insert)

## Backup Considerations
- **Docker Volume**: `drawio_data` contains saved diagrams
- **Cookie Secret**: Back up the OAuth2 proxy cookie secret
- **Keycloak Client**: Document the client configuration

## Diagram Automation
The project now includes automated infrastructure diagram generation:
- **Technology**: N2G library creates editable Draw.io XML files
- **Dynamic Paths**: Uses DRAWIO_BASE_PATH environment variable
- **Docker Discovery**: Automatically finds and maps container relationships
- **Network Visualization**: Shows proper traffic flow through Traefik
- **Output**: Editable diagrams served via NGINX

---
*Last Updated: 2025-08-23 by Claude*