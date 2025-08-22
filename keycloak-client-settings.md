# Keycloak Client Configuration for Draw.io

## Login to Keycloak
1. Go to: https://keycloak.ai-servicers.com/admin
2. Username: `admin`
3. Password: `SecureAdminPass2024!`

## Create Client

### 1. Navigate to Clients
- In left menu: Click **Clients**
- Click **Create client** button

### 2. General Settings (Step 1)
- **Client type**: `OpenID Connect`
- **Client ID**: `drawio`
- **Name**: `Draw.io Diagram Editor`
- **Description**: `Self-hosted Draw.io with group-based access`
- **Always display in console**: `Off`
- Click **Next**

### 3. Capability config (Step 2)
- **Client authentication**: `On` ✅ (This makes it confidential)
- **Authorization**: `Off`
- **Authentication flow**: ✅ Check these:
  - ✅ Standard flow
  - ✅ Direct access grants
  - ❌ Implicit flow (leave unchecked)
  - ❌ Service accounts roles (leave unchecked)
  - ❌ OAuth 2.0 Device Authorization Grant (leave unchecked)
  - ❌ OIDC CIBA Grant (leave unchecked)
- Click **Next**

### 4. Login settings (Step 3)
- **Root URL**: `https://drawio.ai-servicers.com`
- **Home URL**: `https://drawio.ai-servicers.com`
- **Valid redirect URIs**: 
  ```
  https://drawio.ai-servicers.com/oauth2/callback
  https://drawio.ai-servicers.com/*
  http://linuxserver.lan:8085/oauth2/callback
  ```
- **Valid post logout redirect URIs**: `+` (means use Valid redirect URIs)
- **Web origins**: 
  ```
  https://drawio.ai-servicers.com
  http://linuxserver.lan:8085
  ```
- Click **Save**

## After Client Creation

### 5. Get Client Secret
- Go to **Clients** → Click on `drawio`
- Go to **Credentials** tab
- Copy the **Client secret** value
- Save this secret - you'll need it for the deployment

### 6. Configure Client Scopes
- Still in the `drawio` client
- Go to **Client scopes** tab
- You should see these already assigned:
  - `email` (default)
  - `profile` (default)
  - `roles` (default)
  - `web-origins` (default)
- These are sufficient for basic operation

### 7. Create Groups (if not already created)
- Go to **Groups** (left menu)
- Click **Create group**
- Create two groups:
  1. **Name**: `administrators`
     - **Description**: `Full access to Draw.io`
  2. **Name**: `developers`
     - **Description**: `View access to Draw.io`

### 8. Create Group Mapper
- Go to **Clients** → `drawio`
- Go to **Client scopes** tab
- Click on `drawio-dedicated` (should be at top of list)
- Click **Add mapper** → **By configuration**
- Select **Group Membership**
- Configure:
  - **Name**: `groups`
  - **Token Claim Name**: `groups`
  - **Full group path**: `Off`
  - **Add to ID token**: `On` ✅
  - **Add to access token**: `On` ✅
  - **Add to userinfo**: `On` ✅
- Click **Save**

### 9. Assign Users to Groups
- Go to **Users** (left menu)
- Click on a user (e.g., `admin`)
- Go to **Groups** tab
- Click **Join Group**
- Select `administrators`
- Click **Join**

## Advanced Settings (Optional)

### 10. Session Settings (in Client → Settings)
If you want to customize session behavior:
- **Access Token Lifespan**: `5 minutes` (default)
- **Client Session Idle**: `30 minutes`
- **Client Session Max**: `10 hours`

### 11. Authentication Flow Overrides
Usually not needed, but available in **Advanced** tab:
- **Browser Flow**: `browser` (default)
- **Direct Grant Flow**: `direct grant` (default)

## Testing the Configuration

### 12. Test OIDC Discovery
Open in browser (should return JSON):
```
https://keycloak.ai-servicers.com/realms/master/.well-known/openid-configuration
```

### 13. Update Draw.io Deployment
1. Edit `/home/administrator/projects/secrets/drawio.env`:
   ```bash
   KEYCLOAK_CLIENT_SECRET=<paste-secret-here>
   OAUTH2_PROXY_ENABLED=true
   ```

2. Redeploy:
   ```bash
   cd /home/administrator/projects/drawio
   sudo ./deploy.sh
   ```

## Troubleshooting

### If authentication fails:
1. Check OAuth2 Proxy logs: `docker logs drawio-auth-proxy`
2. Verify client secret is correct
3. Ensure redirect URI matches exactly
4. Check that Keycloak is accessible from the Docker network

### Common Issues:
- **Invalid redirect_uri**: Make sure URLs in Keycloak match exactly
- **Invalid client credentials**: Double-check the client secret
- **CORS errors**: Check Web Origins settings
- **Groups not showing**: Verify mapper is configured correctly

---
*Created: 2025-08-22*
*For: administrator@ai-servicers.com*