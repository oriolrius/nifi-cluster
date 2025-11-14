#!/usr/bin/env node

/**
 * Export draw.io diagrams to PNG and SVG
 *
 * This script uses the draw.io public export API to convert .drawio files
 * to PNG and SVG formats.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const EXPORT_API = 'https://exp.draw.io/ImageExport4/export';

const diagrams = [
  '01-single-cluster-architecture.drawio',
  '02-multi-cluster-architecture.drawio',
  '03-site-to-site-communication.drawio'
];

async function exportDiagram(filename, format) {
  return new Promise((resolve, reject) => {
    const inputPath = path.join(__dirname, filename);
    const outputPath = path.join(__dirname, 'exports', filename.replace('.drawio', `.${format}`));

    console.log(`Exporting ${filename} to ${format.toUpperCase()}...`);

    // Read the draw.io file
    const diagramXml = fs.readFileSync(inputPath, 'utf8');

    // Prepare export parameters
    const params = new URLSearchParams({
      format: format,
      xml: diagramXml,
      scale: '1',
      border: '10',
      bg: format === 'png' ? '#FFFFFF' : 'none'
    });

    const options = {
      method: 'POST',
      hostname: 'exp.draw.io',
      path: '/ImageExport4/export',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(params.toString())
      }
    };

    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`Export failed with status ${res.statusCode}`));
        return;
      }

      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        fs.writeFileSync(outputPath, buffer);
        console.log(`✓ Exported: ${outputPath}`);
        resolve(outputPath);
      });
    });

    req.on('error', reject);
    req.write(params.toString());
    req.end();
  });
}

async function exportAll() {
  console.log('Starting export of draw.io diagrams...\n');

  try {
    for (const diagram of diagrams) {
      // Export to PNG
      await exportDiagram(diagram, 'png');

      // Export to SVG
      await exportDiagram(diagram, 'svg');

      console.log('');
    }

    console.log('✅ All exports completed successfully!');
    console.log('\nExported files are in: docs/diagrams/exports/');
  } catch (error) {
    console.error('❌ Export failed:', error.message);
    console.error('\nFallback: Please export manually using draw.io:');
    console.error('1. Open https://app.diagrams.net');
    console.error('2. Open each .drawio file');
    console.error('3. File → Export as → PNG/SVG');
    process.exit(1);
  }
}

exportAll();
