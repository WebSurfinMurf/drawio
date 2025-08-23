# Draw.io Infrastructure Automation Pipeline

This pipeline automatically generates editable Draw.io diagrams from your Docker infrastructure.

## Features

- 🔍 **Automatic Discovery**: Scans all Docker containers, networks, and volumes
- 🎨 **Smart Categorization**: Automatically categorizes services (database, proxy, auth, etc.)
- ✏️ **Fully Editable**: Generates native Draw.io shapes, not images
- 🔄 **Version Control**: Keeps history of diagram versions
- 🌐 **Web Accessible**: Automatically deploys to nginx servers

## Files

- `generate_infrastructure_diagram.py` - Main scanner and generator
- `update-diagram.sh` - Automation wrapper script
- `infrastructure_latest.drawio` - Latest generated diagram
- `history/` - Version history of diagrams

## Usage

### Generate Diagram Manually
```bash
python3 generate_infrastructure_diagram.py
```

### Run Full Pipeline (scan, generate, deploy)
```bash
./update-diagram.sh
```

### Automate with Cron
Add to crontab for hourly updates:
```bash
0 * * * * /home/administrator/projects/drawio-automation/update-diagram.sh
```

### Access Generated Diagrams

- **Main Portal**: https://nginx.ai-servicers.com/infrastructure.drawio
- **Diagrams Server**: https://diagrams.nginx.ai-servicers.com/infrastructure.drawio

## How to Edit

1. Open Draw.io: https://drawio.ai-servicers.com
2. File → Open from → URL
3. Enter: `https://nginx.ai-servicers.com/infrastructure.drawio`
4. Edit as needed (all shapes are individual objects)
5. Save back to same location or export

## Diagram Legend

- 🔷 **Hexagon (Blue)**: Proxy/Load Balancer (Traefik, Nginx)
- 🟡 **Cylinder (Orange)**: Database (PostgreSQL, MySQL, MongoDB)
- 🟣 **Rectangle (Purple)**: Backend Services
- 🟢 **Rectangle (Green)**: Frontend/UI Services  
- 🔴 **Rectangle (Pink)**: Authentication Services
- 🟨 **Rectangle (Yellow)**: Admin Tools
- ⬜ **Rectangle (Gray)**: Generic Services

## Architecture

```
Docker Infrastructure
        ↓
    Python Scanner
        ↓
    N2G Library
        ↓
    Draw.io XML
        ↓
    Web Servers
        ↓
    Draw.io Editor
```

## Requirements

- Python 3.x
- N2G library (`pip install N2G`)
- Docker access
- Write access to nginx data directories

## Future Enhancements

- [ ] Add service dependency detection
- [ ] Include container health status
- [ ] Add CPU/Memory usage indicators
- [ ] Support for Docker Compose labels
- [ ] Git integration for change tracking
- [ ] Merge manual edits with updates