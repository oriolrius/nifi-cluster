# Architecture Diagrams - Content Guide

This guide provides the exact content needed to create professional architecture diagrams using draw.io's visual editor.

## Why This Approach?

Creating diagrams by writing XML directly results in poor layouts, overlapping elements, and cut-off text. Instead, use draw.io's visual editor with this content guide.

---

## Diagram 1: Single Cluster Architecture

### Layout: Top to Bottom
- Title: "Single NiFi Cluster Architecture (cluster01)"
- Canvas: 1200x800px

### Components:

**NiFi Cluster Section (Top)**
- Blue container (#dae8fc border, #E6F2FF fill)
- Label: "NiFi Cluster"

Inside NiFi Cluster:
1. **Node 1** (blue box #4a90e2)
   - Text: "NiFi Node 1"
   - "HTTPS: :30443"
   - "S2S: :30100"
   - "cluster01.nifi-1"

2. **Node 2** (blue box #4a90e2)
   - Text: "NiFi Node 2"
   - "HTTPS: :30444"
   - "S2S: :30101"
   - "cluster01.nifi-2"

3. **Node 3** (blue box #4a90e2)
   - Text: "NiFi Node 3"
   - "HTTPS: :30445"
   - "S2S: :30102"
   - "cluster01.nifi-3"

Connect nodes with dashed arrows labeled "Cluster Protocol"

**ZooKeeper Section (Middle)**
- Green container (#ffe6cc border, #FFF3E0 fill)
- Label: "ZooKeeper Ensemble"

Inside ZooKeeper:
1. **ZK 1** (green box #50c878)
   - Text: "ZooKeeper 1"
   - "Port: :30181"

2. **ZK 2** (green box #50c878)
   - Text: "ZooKeeper 2"
   - "Port: :30182"

3. **ZK 3** (green box #50c878)
   - Text: "ZooKeeper 3"
   - "Port: :30183"

Connect ZK nodes with solid arrows labeled "Ensemble"
Connect each NiFi node to all ZK nodes with thin arrows

**PKI Section (Right)**
- Yellow container (#fff4e6 border)
- Label: "PKI Infrastructure"

Inside PKI:
1. **CA** (red box #ff6b6b)
   - Text: "Shared Certificate Authority"
   - "certs/ca/"

2. **Certs** (yellow boxes)
   - "Node 1 Cert: CN=cluster01.nifi-1"
   - "Node 2 Cert: CN=cluster01.nifi-2"
   - "Node 3 Cert: CN=cluster01.nifi-3"

Connect CA to certs with dotted arrows labeled "signs"

**Storage Section (Right)**
- Gray container (#f5f5f5)
- Label: "Storage (Host Volumes)"

Inside Storage:
- "Node 1 Volumes: content, flowfile, provenance, database"
- "Node 2 Volumes"
- "Node 3 Volumes"

**User** (Bottom left)
- Actor shape
- Text: "User Browser"
- "Access via HTTPS:"
- "localhost:30443/nifi"

Connect user to all NiFi nodes with arrows

**Legend Box** (Bottom right)
- "Cluster Protocol (internal)" - dashed line
- "ZooKeeper Ensemble" - solid green line
- "NiFi ↔ ZK" - solid blue line
- "User Access (HTTPS)" - solid purple line

---

## Diagram 2: Multi-Cluster Architecture

### Layout: Side by Side
- Title: "Multi-Cluster NiFi Architecture - Complete Isolation"
- Canvas: 1600x1000px

### Components:

**Top Center: Shared PKI**
- Red box (#ff6b6b)
- "Certificate Authority (Shared by ALL Clusters)"
- "Location: certs/ca/"
- "Trusted by all clusters"

**Left: Cluster01**
- Blue container (#dae8fc)
- Label: "Cluster01 - Network: cluster01-network"

Inside Cluster01:
- **3 NiFi Nodes** (blue #4a90e2)
  - "NiFi 1: :30443, :30100"
  - "NiFi 2: :30444, :30101"
  - "NiFi 3: :30445, :30102"
- **3 ZK Nodes** (green #50c878)
  - "ZK 1: :30181"
  - "ZK 2: :30182"
  - "ZK 3: :30183"
- Info box: "Ports: 30000-30999"
- Info box: "Volumes: clusters/cluster01/"

**Right: Cluster02**
- Purple container (#e1d5e7)
- Label: "Cluster02 - Network: cluster02-network"

Inside Cluster02:
- **3 NiFi Nodes** (purple #7b68ee)
  - "NiFi 1: :31443, :31100"
  - "NiFi 2: :31444, :31101"
  - "NiFi 3: :31445, :31102"
- **3 ZK Nodes** (green #50c878)
  - "ZK 1: :31181"
  - "ZK 2: :31182"
  - "ZK 3: :31183"
- Info box: "Ports: 31000-31999"
- Info box: "Volumes: clusters/cluster02/"

Connect Shared CA to both clusters with dashed arrows labeled "signs certificates"

**Bottom: Storage**
- "Cluster01 Volumes: clusters/cluster01/volumes/"
- "Cluster02 Volumes: clusters/cluster02/volumes/"

**Key Points Box** (Right side)
- List key principles:
  1. Complete Isolation (separate networks)
  2. Separate Port Ranges
  3. Shared PKI for trust
  4. Independent ZooKeeper
  5. Isolated Storage

---

## Diagram 3: Site-to-Site Communication Flow

### Layout: Sequence Diagram Style
- Title: "Inter-Cluster Communication: Site-to-Site (S2S) Protocol"
- Canvas: 1600x900px

### Components:

**Left: Cluster01 (Source)**
- Blue container
- "Cluster01 (Source)"

Inside:
- **cluster01.nifi-1** (blue box)
  - "HTTPS: :30443"
  - "S2S Port: :30100"
  - "Certificate: CN=cluster01.nifi-1.ymbihq.local"
  - "Remote Process Group (RPG)"
  - "Target: cluster02"

**Right: Cluster02 (Target)**
- Purple container
- "Cluster02 (Target)"

Inside:
- **cluster02.nifi-1** (purple box)
  - "HTTPS: :31443"
  - "S2S Port: :31100"
  - "Certificate: CN=cluster02.nifi-1.ymbihq.local"
  - "Input Port: 'From Cluster01'"

**Middle: Flow Steps** (Top to bottom)

1. **Step 1: TLS Handshake** (blue box)
   - "• Cluster01 initiates TLS connection"
   - "• Both present certificates"
   - "• Both verify against Shared CA"
   - "• Mutual TLS succeeds ✓"

2. **Step 2: Peer Discovery** (purple box)
   - "• GET /nifi-api/site-to-site/peers"
   - "• Cluster02 returns peer list"
   - "• All nodes: nifi-1, nifi-2, nifi-3"

3. **Step 3: Data Transfer** (green box)
   - "• Load-balanced across cluster02 nodes"
   - "• Batch 1 → nifi-1:31100"
   - "• Batch 2 → nifi-2:31101"
   - "• Batch 3 → nifi-3:31102"
   - "• All traffic encrypted with TLS"

4. **Step 4: Processing** (yellow box)
   - "• FlowFiles arrive at Input Port"
   - "• Cluster02 processes data"
   - "• Route to downstream processors"

**Top: Shared CA** (red box)
- "Shared Certificate Authority"
- Arrows to both clusters labeled "trusts"

**Bottom: Prerequisites Box**
- List requirements:
  1. DOMAIN configured in .env
  2. DNS resolution or extra_hosts
  3. Shared CA certificates
  4. RPG configured in source
  5. Input Port in target

**Bottom: Summary Box**
- "Why Shared CA Enables S2S:"
- List benefits of single CA approach

---

## General Guidelines

### Colors to Use:
- **NiFi (Cluster01)**: Blue #4a90e2
- **NiFi (Cluster02)**: Purple #7b68ee
- **ZooKeeper**: Green #50c878
- **Certificate Authority**: Red #ff6b6b
- **PKI/Certificates**: Yellow #fff4e6
- **Storage**: Gray #f5f5f5
- **Containers**: Light versions of primary colors

### Line Styles:
- **Solid arrows**: Active connections (NiFi ↔ ZK)
- **Dashed arrows**: Protocol connections (Cluster Protocol)
- **Dotted arrows**: Certificate relationships (CA signs)
- **Thick arrows**: Data transfer (S2S)

### Text Sizing:
- **Titles**: 18-24pt, bold
- **Component labels**: 12-14pt, bold
- **Details**: 10-11pt, regular
- **Annotations**: 9-10pt, italic

### Spacing:
- **Between components**: 40-60px minimum
- **Box padding**: 20px minimum
- **Arrow labels**: Position on arrow, not overlapping

### Best Practices:
1. Start with containers, then add components
2. Use Arrange → Auto-size for text boxes
3. Use Arrange → Align for consistent positioning
4. Use View → Grid for precise placement
5. Add connections last to avoid tangles
6. Use layers for organization (optional)
7. Export at 100% zoom with 10px border

---

## How to Create:

1. **Open draw.io**: Go to https://app.diagrams.net
2. **Start blank diagram**: Choose blank canvas
3. **Set canvas size**: File → Page Setup → Size (use dimensions above)
4. **Follow layout**: Use content above for each section
5. **Style consistently**: Apply colors and styles as specified
6. **Test layout**: Zoom out to see full diagram
7. **Adjust spacing**: Ensure no overlaps or cut-off text
8. **Add legend**: Include at bottom with line style examples
9. **Save**: File → Save as → [diagram-name].drawio
10. **Export**: File → Export as → PNG/SVG

---

## Quality Checklist:

Before exporting, verify:
- [ ] No text is cut off or overflowing boxes
- [ ] All labels are readable at 100% zoom
- [ ] Arrows don't overlap other elements
- [ ] Consistent spacing between components
- [ ] Colors match specification
- [ ] Legend explains all line styles
- [ ] Canvas size appropriate for content
- [ ] Border padding around edges (20px+)
- [ ] No overlapping elements
- [ ] Professional appearance

---

## Alternative: Use Template

If creating from scratch is too time-consuming, consider:
1. Using draw.io's built-in network/architecture templates
2. Using AWS/Azure architecture icon libraries
3. Exporting existing Mermaid diagrams and enhancing them
4. Hiring a technical illustrator for professional diagrams

The key is **visual editing** - never create diagrams programmatically without seeing the result.
