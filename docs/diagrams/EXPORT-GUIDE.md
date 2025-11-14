# Draw.io Export Guide

Since the export API isn't accessible in this environment, here are the best methods to export these diagrams to PNG and SVG formats:

## ✅ Verification Status

All three draw.io files have been validated:
- ✓ **01-single-cluster-architecture.drawio** (20.5 KB) - Valid draw.io format
- ✓ **02-multi-cluster-architecture.drawio** (26.1 KB) - Valid draw.io format
- ✓ **03-site-to-site-communication.drawio** (21.4 KB) - Valid draw.io format

## 🚀 Quick Start: Open in Browser

1. **Open the viewer**: Open [`viewer.html`](viewer.html) in your browser
2. **Click buttons**: Click "Open in draw.io" for any diagram
3. **Export**: Once opened, go to **File → Export as → PNG/SVG**

## 📤 Export Methods

### Method 1: Online (Fastest)

1. Go to [app.diagrams.net](https://app.diagrams.net)
2. Click **File → Open from → Device**
3. Select a `.drawio` file from this directory
4. Once opened, click **File → Export as**
5. Choose format and settings:

**For PNG (Documentation/Presentations):**
```
Format: PNG
Zoom: 100%
Border Width: 10
Transparent Background: ☑ (or use #FFFFFF for white)
Selection Only: ☐
```

**For SVG (Web/Scalable):**
```
Format: SVG
Embed Images: ☑
Include a copy of my diagram: ☑ (recommended)
Transparent Background: ☑
Selection Only: ☐
```

6. Click **Export** and save to `exports/` directory

### Method 2: VS Code Extension

1. Install the extension:
   ```bash
   code --install-extension hediet.vscode-drawio
   ```

2. Open any `.drawio` file in VS Code

3. The diagram will render in the editor

4. Right-click in the editor → **Export to...** → Choose format

5. Save to `exports/` directory

### Method 3: Desktop Application

1. Download from: https://github.com/jgraph/drawio-desktop/releases

2. Install the application

3. Open draw.io desktop app

4. **File → Open** → Select `.drawio` file

5. **File → Export as** → Choose format

6. Use the same settings as Method 1

7. Save to `exports/` directory

### Method 4: Command Line (Docker)

If Docker is available:

```bash
# Pull draw.io export image
docker pull jgraph/export-server

# Export to PNG
docker run --rm -v $(pwd):/data jgraph/export-server \
  --format png \
  --scale 1 \
  --border 10 \
  /data/01-single-cluster-architecture.drawio \
  /data/exports/01-single-cluster-architecture.png

# Export to SVG
docker run --rm -v $(pwd):/data jgraph/export-server \
  --format svg \
  /data/01-single-cluster-architecture.drawio \
  /data/exports/01-single-cluster-architecture.svg
```

Repeat for all three diagrams.

## 📁 Recommended Export Structure

After exporting, your directory should look like:

```
docs/diagrams/
├── 01-single-cluster-architecture.drawio
├── 02-multi-cluster-architecture.drawio
├── 03-site-to-site-communication.drawio
├── exports/
│   ├── 01-single-cluster-architecture.png
│   ├── 01-single-cluster-architecture.svg
│   ├── 02-multi-cluster-architecture.png
│   ├── 02-multi-cluster-architecture.svg
│   ├── 03-site-to-site-communication.png
│   └── 03-site-to-site-communication.svg
├── viewer.html
├── export-diagrams.js (automated script - requires network access)
├── EXPORT-GUIDE.md (this file)
└── README.md
```

## 🎨 Export Settings Recommendations

### For README.md / Documentation
- **Format**: PNG
- **Zoom**: 100%
- **Border**: 10px
- **Background**: White (#FFFFFF)
- **DPI**: 96 (default)

### For Presentations / Slides
- **Format**: PNG
- **Zoom**: 150% or 200% (for high-DPI displays)
- **Border**: 10px
- **Background**: White or Transparent
- **DPI**: 150 or 300

### For Web / HTML
- **Format**: SVG
- **Embed Images**: Yes
- **Background**: Transparent
- **Include diagram copy**: Yes (for future editing)

### For Printing / PDF Documentation
- **Format**: PDF or PNG
- **Zoom**: 200%
- **Border**: 20px
- **Background**: White
- **DPI**: 300

## 🔍 Viewing Diagrams

You can view the diagrams without exporting:

1. **Online**: Open [app.diagrams.net](https://app.diagrams.net) and drag `.drawio` file
2. **VS Code**: Install draw.io extension and open file
3. **Browser**: Use [`viewer.html`](viewer.html) for quick access

## ✨ Tips

- **Layers**: Diagrams use layers for organization (View → Layers in draw.io)
- **Zoom**: Adjust zoom level for better export quality
- **Transparent Background**: Use for dark mode documentation
- **Border**: Adds padding around diagram edges
- **Embed Images**: Important for SVG to include all graphics

## 🆘 Troubleshooting

**Problem**: Export is blurry
- **Solution**: Increase zoom to 150% or 200%

**Problem**: SVG missing elements
- **Solution**: Check "Embed Images" and "Include fonts"

**Problem**: PNG too large file size
- **Solution**: Reduce zoom or use SVG instead

**Problem**: Can't open file in draw.io
- **Solution**: Files are valid - try refreshing or different browser

## 📚 Additional Resources

- [Draw.io Documentation](https://www.diagrams.net/doc/)
- [Export Options Guide](https://www.diagrams.net/doc/faq/export-diagram)
- [VS Code Extension Docs](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio)

## 🤝 Contributing

When exporting diagrams:
1. Export both PNG and SVG formats
2. Place in `exports/` directory
3. Update documentation if needed
4. Commit both `.drawio` source and exports
5. Use consistent naming conventions

---

**Last Updated**: 2025-11-14
**Diagram Versions**: 1.0.0
