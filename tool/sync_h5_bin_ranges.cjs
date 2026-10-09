// Read-only import of the adjacent H5's editorial BIN fallback.
// Run with Node after the H5's existing dependencies have been installed.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const h5 = path.resolve(root, '../card.lengziyu.cn');
const ts = require(path.join(h5, 'node_modules/typescript'));
const source = fs.readFileSync(path.join(h5, 'src/data/cardBinRanges.ts'), 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
}).outputText;
const exported = {};
new Function('exports', compiled)(exported);
const directory = path.join(root, 'assets/tools');
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(path.join(directory, 'h5-card-bin-ranges.json'),
  `${JSON.stringify(exported.defaultCardBinRangesByCardId, null, 2)}\n`);
process.stdout.write(`Imported ${Object.keys(exported.defaultCardBinRangesByCardId).length} H5 BIN entries.\n`);
