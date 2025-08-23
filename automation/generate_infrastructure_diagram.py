#!/usr/bin/env python3
"""
Infrastructure to Draw.io Diagram Generator
Scans Docker infrastructure and generates editable Draw.io diagrams
"""

import subprocess
import json
import re
from N2G import drawio_diagram
from datetime import datetime
import os
from pathlib import Path

class InfrastructureScanner:
    """Scans Docker infrastructure and collects information"""
    
    def __init__(self):
        self.containers = []
        self.networks = []
        self.volumes = []
        
    def scan_containers(self):
        """Get all running Docker containers with details"""
        cmd = ["docker", "ps", "--format", "json"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        for line in result.stdout.strip().split('\n'):
            if line:
                container = json.loads(line)
                # Get additional details
                inspect_cmd = ["docker", "inspect", container['Names']]
                inspect_result = subprocess.run(inspect_cmd, capture_output=True, text=True)
                if inspect_result.returncode == 0:
                    details = json.loads(inspect_result.stdout)[0]
                    
                    # Extract network information
                    networks = list(details['NetworkSettings']['Networks'].keys())
                    
                    # Extract exposed ports
                    ports = []
                    if details['NetworkSettings']['Ports']:
                        for port, bindings in details['NetworkSettings']['Ports'].items():
                            if bindings:
                                for binding in bindings:
                                    ports.append(f"{binding.get('HostPort', '')}:{port.split('/')[0]}")
                    
                    self.containers.append({
                        'name': container['Names'],
                        'image': container['Image'],
                        'status': container['Status'],
                        'networks': networks,
                        'ports': ports,
                        'labels': details['Config'].get('Labels', {})
                    })
        
        return self.containers
    
    def scan_networks(self):
        """Get all Docker networks"""
        cmd = ["docker", "network", "ls", "--format", "json"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        for line in result.stdout.strip().split('\n'):
            if line:
                network = json.loads(line)
                if network['Name'] not in ['bridge', 'host', 'none']:  # Skip default networks
                    self.networks.append({
                        'name': network['Name'],
                        'driver': network['Driver'],
                        'scope': network['Scope']
                    })
        
        return self.networks
    
    def scan_volumes(self):
        """Get all Docker volumes"""
        cmd = ["docker", "volume", "ls", "--format", "json"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        for line in result.stdout.strip().split('\n'):
            if line:
                volume = json.loads(line)
                self.volumes.append({
                    'name': volume['Name'],
                    'driver': volume['Driver']
                })
        
        return self.volumes


class DrawioDiagramGenerator:
    """Generates Draw.io diagrams from infrastructure data"""
    
    def __init__(self, infrastructure_data):
        self.data = infrastructure_data
        self.diagram = drawio_diagram()
        self.diagram.add_diagram("Infrastructure Overview")
        
        # Position tracking
        self.x_pos = 100
        self.y_pos = 100
        self.network_positions = {}
        self.container_positions = {}
        
    def categorize_container(self, container):
        """Categorize container by type based on image/name"""
        name = container['name'].lower()
        image = container['image'].lower()
        
        if 'postgres' in image or 'mysql' in image or 'mongo' in image or 'redis' in image:
            return 'database'
        elif 'nginx' in image or 'traefik' in image or 'haproxy' in image:
            return 'proxy'
        elif 'keycloak' in name or 'auth' in name or 'oauth' in name:
            return 'auth'
        elif 'ui' in name or 'frontend' in name or 'webui' in name:
            return 'frontend'
        elif 'api' in name or 'backend' in name:
            return 'backend'
        elif 'admin' in name or 'pgadmin' in name:
            return 'admin'
        else:
            return 'service'
    
    def get_shape_style(self, category):
        """Get shape style based on container category"""
        styles = {
            'database': {
                'shape': 'cylinder',
                'fillColor': '#FFE6CC',
                'strokeColor': '#D79B00'
            },
            'proxy': {
                'shape': 'hexagon',
                'fillColor': '#E6F3FF',
                'strokeColor': '#0066CC'
            },
            'auth': {
                'shape': 'rectangle',
                'fillColor': '#FFE6F2',
                'strokeColor': '#CC0066'
            },
            'frontend': {
                'shape': 'rectangle',
                'fillColor': '#E6FFE6',
                'strokeColor': '#00CC00'
            },
            'backend': {
                'shape': 'rectangle',
                'fillColor': '#F0E6FF',
                'strokeColor': '#6600CC'
            },
            'admin': {
                'shape': 'rectangle',
                'fillColor': '#FFFFE6',
                'strokeColor': '#CCCC00'
            },
            'service': {
                'shape': 'rectangle',
                'fillColor': '#F5F5F5',
                'strokeColor': '#666666'
            }
        }
        return styles.get(category, styles['service'])
    
    def generate_diagram(self):
        """Generate the Draw.io diagram"""
        
        # First, create network groups with specified order
        # Order: traefik-proxy (double height), keycloak-net, postgres-net, mailu, then all others
        network_order = ['traefik-proxy', 'keycloak-net', 'postgres-net', 'mailu']
        network_y_positions = {
            'traefik-proxy': 280,   # Just below Traefik
            'keycloak-net': 930,    # 280 + 600 (traefik-proxy height) + 50 (gap)
            'postgres-net': 1280,   # 930 + 350
            'mailu': 1630,          # 1280 + 350
        }
        other_network_y = 1980  # Start position for other networks (1630 + 350)
        
        # Process networks in specified order first
        processed_networks = []
        
        # Add priority networks first
        for priority_network in network_order:
            for network in self.data['networks']:
                if network['name'] == priority_network:
                    network_id = f"network_{network['name']}"
                    net_x = 100
                    net_y = network_y_positions[network['name']]
                    # Make traefik-proxy network twice as tall
                    net_height = 600 if network['name'] == 'traefik-proxy' else 300
                    
                    self.diagram.add_node(
                        id=network_id,
                        label=f"Network: {network['name']}",
                        width=800,
                        height=net_height,
                        x_pos=net_x,
                        y_pos=net_y,
                        shape="rectangle",
                        style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F0F0F0;strokeColor=#909090;dashed=1;strokeWidth=2;"
                    )
                    self.network_positions[network['name']] = {
                        'x': net_x,
                        'y': net_y,
                        'width': 800,
                        'height': net_height,
                        'containers': []
                    }
                    processed_networks.append(network['name'])
                    break
        
        # Add remaining networks
        for network in self.data['networks']:
            if network['name'] not in processed_networks:
                network_id = f"network_{network['name']}"
                net_x = 100
                net_y = other_network_y
                other_network_y += 350  # Increment for next network
                
                self.diagram.add_node(
                    id=network_id,
                    label=f"Network: {network['name']}",
                    width=800,
                    height=300,
                    x_pos=net_x,
                    y_pos=net_y,
                    shape="rectangle",
                    style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F0F0F0;strokeColor=#909090;dashed=1;strokeWidth=2;"
                )
                self.network_positions[network['name']] = {
                    'x': net_x,
                    'y': net_y,
                    'width': 800,
                    'height': 300,
                    'containers': []
                }
        
        # Add containers to their networks
        for container in self.data['containers']:
            category = self.categorize_container(container)
            style = self.get_shape_style(category)
            
            # Special positioning for Traefik - right below Internet node for visual flow
            # Internet (y=50) -> Traefik (y=180) -> traefik-proxy network box below
            if container['name'] == 'traefik':
                x = 425  # Center it below the Internet cloud (which is at x=400, width=200)
                y = 180  # Just below Internet node (which ends at y=150)
            else:
                # Place container in its primary network
                primary_network = container['networks'][0] if container['networks'] else None
                
                if primary_network and primary_network in self.network_positions:
                    net_pos = self.network_positions[primary_network]
                    # Calculate position within network
                    containers_in_network = len(net_pos['containers'])
                    x = net_pos['x'] + 50 + (containers_in_network % 4) * 180
                    y = net_pos['y'] + 50 + (containers_in_network // 4) * 120
                    net_pos['containers'].append(container['name'])
                else:
                    # Standalone container
                    x = 950
                    y = 100 + len([c for c in self.container_positions.values()]) * 120
            
            container_id = f"container_{container['name']}"
            
            # Prepare label with details
            ports_str = ', '.join(container['ports'][:3]) if container['ports'] else 'No ports'
            label = f"{container['name']}\n{container['image'].split(':')[0]}\n{ports_str}"
            
            # Add container node
            if style['shape'] == 'cylinder':
                self.diagram.add_node(
                    id=container_id,
                    label=label,
                    width=150,
                    height=80,
                    x_pos=x,
                    y_pos=y,
                    shape="cylinder",
                    style=f"shape=cylinder;whiteSpace=wrap;html=1;fillColor={style['fillColor']};strokeColor={style['strokeColor']};"
                )
            elif style['shape'] == 'hexagon':
                self.diagram.add_node(
                    id=container_id,
                    label=label,
                    width=150,
                    height=80,
                    x_pos=x,
                    y_pos=y,
                    shape="hexagon",
                    style=f"shape=hexagon;whiteSpace=wrap;html=1;fillColor={style['fillColor']};strokeColor={style['strokeColor']};"
                )
            else:
                self.diagram.add_node(
                    id=container_id,
                    label=label,
                    width=150,
                    height=80,
                    x_pos=x,
                    y_pos=y,
                    shape="rectangle",
                    style=f"rounded=1;whiteSpace=wrap;html=1;fillColor={style['fillColor']};strokeColor={style['strokeColor']};"
                )
            
            self.container_positions[container['name']] = {'x': x, 'y': y}
        
        # Add external internet node
        self.add_external_nodes()
        
        # Add connections based on common patterns
        self.add_connections()
        
        # Add legend
        self.add_legend()
        
    def add_external_nodes(self):
        """Add external/internet nodes to show traffic sources"""
        # Add Internet cloud node
        self.diagram.add_node(
            id="internet",
            label="Internet\n(Public Traffic)",
            width=200,
            height=100,
            x_pos=400,
            y_pos=50,
            shape="cloud",
            style="ellipse;shape=cloud;whiteSpace=wrap;html=1;fillColor=#FFE6E6;strokeColor=#CC0000;strokeWidth=2;"
        )
        
        # Add Internal Network node at same level as Traefik (both are entry points)
        # Internet (y=50) -> Both Traefik and Internal Network at y=180
        self.diagram.add_node(
            id="internal_network",
            label="Internal Network\n(LAN Traffic)",
            width=200,
            height=100,
            x_pos=650,  # To the right of Traefik (which is at x=425)
            y_pos=180,  # Same level as Traefik
            shape="cloud",
            style="ellipse;shape=cloud;whiteSpace=wrap;html=1;fillColor=#E6F3FF;strokeColor=#0066CC;strokeWidth=2;"
        )
    
    def add_connections(self):
        """Add connections between containers based on common patterns"""
        
        # Connect Internet to Traefik (main ingress point)
        traefik_main = next((c for c in self.data['containers'] if c['name'] == 'traefik'), None)
        if traefik_main:
            traefik_id = f"container_{traefik_main['name']}"
            # Internet -> Traefik (ports 80/443)
            self.diagram.add_link(
                source="internet",
                target=traefik_id,
                label="HTTPS (443)\nHTTP (80)",
                style="edgeStyle=orthogonalEdgeStyle;curved=1;strokeColor=#CC0000;strokeWidth=2;"
            )
            
            # Internal Network -> Services with internal access
            # Connect to services with direct port access
            direct_access_services = [
                ('keycloak', '8443'),
                ('pgadmin', '8901'),
                ('postgres', '5432'),
                ('portainer', '9000'),
                ('shellhub-ssh', '2222'),
            ]
            
            for service_name, port in direct_access_services:
                service = next((c for c in self.data['containers'] if c['name'] == service_name), None)
                if service:
                    self.diagram.add_link(
                        source="internal_network",
                        target=f"container_{service['name']}",
                        label=f"Port {port}",
                        style="edgeStyle=orthogonalEdgeStyle;curved=1;strokeColor=#0066CC;dashed=1;"
                    )
        
        # Only connect Traefik to services it actually routes to (based on labels)
        traefik_containers = [c for c in self.data['containers'] if 'traefik' in c['name'].lower() and 'certs-dumper' not in c['name'].lower()]
        
        for traefik in traefik_containers:
            traefik_id = f"container_{traefik['name']}"
            
            # Check Traefik labels for routing - only connect containers with traefik labels
            for container in self.data['containers']:
                if container['name'] != traefik['name']:
                    labels = container.get('labels', {})
                    # Check if container has Traefik routing enabled
                    if any('traefik.enable=true' in f"{key}={value}" for key, value in labels.items()):
                        container_id = f"container_{container['name']}"
                        self.diagram.add_link(
                            source=traefik_id,
                            target=container_id,
                            label="routes",
                            style="edgeStyle=orthogonalEdgeStyle;curved=1;strokeColor=#0066CC;"
                        )
        
        # Connect Keycloak ONLY to its database
        keycloak_containers = [c for c in self.data['containers'] if c['name'] == 'keycloak']
        for keycloak in keycloak_containers:
            keycloak_id = f"container_{keycloak['name']}"
            # Only connect to keycloak-postgres
            for container in self.data['containers']:
                if container['name'] == 'keycloak-postgres':
                    db_id = f"container_{container['name']}"
                    self.diagram.add_link(
                        source=keycloak_id,
                        target=db_id,
                        label="database",
                        style="edgeStyle=orthogonalEdgeStyle;curved=1;strokeColor=#CC0066;"
                    )
        
        # Connect OAuth2 proxies to their backend services
        oauth_proxies = [c for c in self.data['containers'] if 'oauth2-proxy' in c['image'].lower() or 'oauth' in c['name'].lower()]
        for oauth in oauth_proxies:
            oauth_id = f"container_{oauth['name']}"
            # Connect drawio-auth-proxy to drawio
            if oauth['name'] == 'drawio-auth-proxy':
                for container in self.data['containers']:
                    if container['name'] == 'drawio':
                        service_id = f"container_{container['name']}"
                        self.diagram.add_link(
                            source=oauth_id,
                            target=service_id,
                            label="protects",
                            style="edgeStyle=orthogonalEdgeStyle;curved=1;strokeColor=#FF9900;dashed=1;"
                        )
        
        # Connect pgAdmin to main postgres database only
        pgadmin = next((c for c in self.data['containers'] if c['name'] == 'pgadmin'), None)
        postgres = next((c for c in self.data['containers'] if c['name'] == 'postgres'), None)
        
        if pgadmin and postgres:
            self.diagram.add_link(
                source=f"container_{pgadmin['name']}",
                target=f"container_{postgres['name']}",
                label="manages",
                style="edgeStyle=orthogonalEdgeStyle;curved=1;strokeColor=#CCCC00;dashed=1;"
            )
    
    def add_legend(self):
        """Add a legend to explain the shapes and colors"""
        legend_x = 950
        legend_y = 600
        
        self.diagram.add_node(
            id="legend_title",
            label="Legend",
            width=200,
            height=30,
            x_pos=legend_x,
            y_pos=legend_y,
            shape="rectangle",
            style="rounded=0;whiteSpace=wrap;html=1;fillColor=#E0E0E0;fontStyle=1;"
        )
        
        legend_items = [
            ("Database", "cylinder", "#FFE6CC", "#D79B00"),
            ("Proxy/LB", "hexagon", "#E6F3FF", "#0066CC"),
            ("Auth", "rectangle", "#FFE6F2", "#CC0066"),
            ("Frontend", "rectangle", "#E6FFE6", "#00CC00"),
            ("Backend", "rectangle", "#F0E6FF", "#6600CC"),
            ("Admin", "rectangle", "#FFFFE6", "#CCCC00"),
        ]
        
        for i, (label, shape, fill, stroke) in enumerate(legend_items):
            y = legend_y + 40 + (i * 35)
            
            if shape == "cylinder":
                style = f"shape=cylinder;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            elif shape == "hexagon":
                style = f"shape=hexagon;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            else:
                style = f"rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            
            self.diagram.add_node(
                id=f"legend_{label}",
                label=label,
                width=80,
                height=30,
                x_pos=legend_x,
                y_pos=y,
                shape=shape if shape != "rectangle" else None,
                style=style
            )
    
    def save_diagram(self, output_path):
        """Save the diagram to a file"""
        self.diagram.dump_file(output_path)
        print(f"✅ Diagram saved to: {output_path}")


def main():
    """Main function to generate the infrastructure diagram"""
    
    print("🔍 Scanning Docker infrastructure...")
    scanner = InfrastructureScanner()
    
    infrastructure = {
        'containers': scanner.scan_containers(),
        'networks': scanner.scan_networks(),
        'volumes': scanner.scan_volumes()
    }
    
    print(f"Found: {len(infrastructure['containers'])} containers, "
          f"{len(infrastructure['networks'])} networks, "
          f"{len(infrastructure['volumes'])} volumes")
    
    print("\n🎨 Generating Draw.io diagram...")
    generator = DrawioDiagramGenerator(infrastructure)
    generator.generate_diagram()
    
    # Use environment variable or default to user home
    base_path = os.environ.get('DRAWIO_BASE_PATH', str(Path.home()))
    output_dir = Path(base_path) / "projects" / "drawio" / "output"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Create history subdirectory
    history_dir = output_dir / "history"
    history_dir.mkdir(parents=True, exist_ok=True)
    
    # Save with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = output_dir / f"infrastructure_{timestamp}.drawio"
    generator.save_diagram(str(output_file))
    
    # Also save as latest
    latest_file = output_dir / "infrastructure_latest.drawio"
    generator.save_diagram(str(latest_file))
    
    # Also save to history
    history_file = history_dir / f"infrastructure_{timestamp}.drawio"
    generator.save_diagram(str(history_file))
    
    print(f"\n✅ Diagram generation complete!")
    print(f"📁 Files created:")
    print(f"   - {output_file}")
    print(f"   - {latest_file}")
    print(f"   - {history_file}")
    print(f"\n📝 Next steps:")
    print(f"   1. Open {latest_file} in Draw.io")
    print(f"   2. All shapes are editable - move, resize, recolor as needed")
    print(f"   3. Save your manual edits back to the same file")


if __name__ == "__main__":
    main()