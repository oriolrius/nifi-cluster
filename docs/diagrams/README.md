# Architecture Diagrams

This directory contains professional draw.io diagrams that provide comprehensive visualizations of the Multi-Cluster NiFi Platform architecture.

## Available Diagrams

### 1. Single Cluster Architecture
**File**: [`01-single-cluster-architecture.drawio`](01-single-cluster-architecture.drawio)

Detailed view of a single 3-node NiFi cluster showing:
- NiFi cluster nodes with HTTPS and Site-to-Site ports
- ZooKeeper ensemble configuration
- Cluster protocol connections
- PKI infrastructure (Shared CA and node certificates)
- Storage volumes layout
- Network topology (cluster01-network)
- User access paths

**Use this diagram to**:
- Understand the internal architecture of a single cluster
- Learn about port allocations and networking
- See how NiFi nodes coordinate via ZooKeeper
- Understand certificate distribution

### 2. Multi-Cluster Architecture
**File**: [`02-multi-cluster-architecture.drawio`](02-multi-cluster-architecture.drawio)

Comprehensive view of multiple independent clusters running on the same host:
- Complete isolation between Cluster01 and Cluster02
- Separate Docker networks (cluster01-network vs cluster02-network)
- Shared Certificate Authority (PKI) infrastructure
- Port allocation strategy (30xxx vs 31xxx)
- Independent ZooKeeper ensembles per cluster
- Isolated storage volumes
- Certificate signing relationships

**Use this diagram to**:
- Understand multi-tenancy and environment separation
- Learn how clusters are isolated yet share the same PKI
- See the complete port allocation strategy
- Understand the benefits of multi-cluster architecture

### 3. Site-to-Site Communication Flow
**File**: [`03-site-to-site-communication.drawio`](03-site-to-site-communication.drawio)

Detailed flow diagram showing inter-cluster communication:
- TLS handshake and mutual authentication process
- S2S peer discovery protocol
- Load-balanced data transfer across cluster nodes
- FlowFile processing flow
- Certificate verification using Shared CA
- Prerequisites for cross-cluster S2S

**Use this diagram to**:
- Understand how clusters communicate securely
- Learn about the Site-to-Site protocol
- See the complete authentication and data transfer flow
- Understand why Shared CA enables seamless S2S

## How to View/Edit

### Online (Recommended)
1. Go to [app.diagrams.net](https://app.diagrams.net) (also known as draw.io)
2. Click "Open Existing Diagram"
3. Select the `.drawio` file from this directory
4. View, edit, and export as needed

### VS Code Extension
Install the [Draw.io Integration extension](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio):
```bash
code --install-extension hediet.vscode-drawio
```

Then simply click on any `.drawio` file in VS Code to view and edit.

### Desktop Application
Download the [draw.io desktop app](https://github.com/jgraph/drawio-desktop/releases) for offline editing.

## Exporting Diagrams

To export diagrams to other formats (PNG, SVG, PDF):

1. Open the diagram in draw.io (online or desktop)
2. Click **File** → **Export as**
3. Choose your desired format:
   - **PNG**: For documentation and presentations
   - **SVG**: For scalable web graphics
   - **PDF**: For high-quality prints

### Recommended Export Settings
- **PNG**: Zoom 100%, Border 10px, Transparent Background
- **SVG**: Embed Images, Include Copy of Diagram
- **PDF**: Include Copy of Diagram

## Diagram Conventions

### Color Coding
- **Blue (#4a90e2)**: NiFi nodes (Cluster01)
- **Purple (#7b68ee)**: NiFi nodes (Cluster02)
- **Green (#50c878)**: ZooKeeper nodes
- **Red (#ff6b6b)**: Certificate Authority (CA)
- **Yellow (#fff4e6)**: PKI/Certificates
- **Gray (#f5f5f5)**: Storage volumes

### Connection Styles
- **Solid lines**: Active connections (NiFi ↔ ZooKeeper)
- **Dashed lines**: Protocol connections (Cluster Protocol, Ensemble)
- **Dotted lines**: Certificate relationships (CA signs certificates)
- **Thick arrows**: Data transfer (S2S communication)

## Related Documentation

- [README.md](../../README.md) - Main project documentation with Mermaid diagrams
- [doc-001](../../backlog/docs/doc-001%20-%20Multi-Cluster-NiFi-Architecture-Decision-Document.md) - Architecture Decision Document
- [doc-002](../../backlog/docs/doc-002%20-%20Multi-Cluster-NiFi-Directory-Structure.md) - Directory Structure Documentation
- [doc-006](../../backlog/docs/doc-006%20-%20create-cluster.sh-Complete-Architecture-Documentation.md) - Cluster Creation Architecture

## Contributing

When updating diagrams:

1. Open the diagram in draw.io
2. Make your changes
3. Save the diagram (File → Save)
4. Export as PNG for quick reference: `File → Export as → PNG`
5. Place PNG in `docs/diagrams/exports/` (optional)
6. Commit both the `.drawio` file and any exports
7. Update this README if adding new diagrams

## Tips for Best Results

- **Use layers**: Organize complex diagrams into layers (View → Layers)
- **Align elements**: Use Arrange → Align to keep diagrams professional
- **Consistent spacing**: Use Arrange → Layout for automatic spacing
- **Add annotations**: Use text boxes for explanatory notes
- **Version control**: draw.io files are XML-based and work well with Git

## Questions?

For questions about these diagrams or the architecture they represent, please refer to:
- Project README: [../../README.md](../../README.md)
- Architecture docs: [../../backlog/docs/](../../backlog/docs/)
- Unified CLI documentation: [doc-010](../../backlog/docs/doc-010%20-%20cluster-Unified-Cluster-Management-CLI.md)
