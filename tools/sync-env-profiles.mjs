import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// =============================================================================
// NEXUS ENV PROFILE SYNC
// =============================================================================
// Regenerates every derived env profile from the canonical .env of each repo so
// that the key list always matches. Values are never printed.
//
//   node tools/sync-env-profiles.mjs           # dry run, reports drift only
//   node tools/sync-env-profiles.mjs --write   # rewrite drifted profile files
// =============================================================================

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const WRITE = process.argv.includes('--write');

const DB_LOCAL = {
  USER_DB_CONNECTION: { port: 5433, database: 'usermanagement_db' },
  CATALOG_DB_CONNECTION: { port: 5434, database: 'category_db' },
  COMMERCE_DB_CONNECTION: { port: 5435, database: 'commerce_db' },
  LOG_DB_CONNECTION: { port: 5436, database: 'log_db' },
  AUCTION_DB_CONNECTION: { port: 5437, database: 'auction_db' },
  FULFILLMENT_DB_CONNECTION: { port: 5438, database: 'fulfillment_db' },
  NOTIFICATION_DB_CONNECTION: { port: 5439, database: 'notification_db' },
  WALLET_DB_CONNECTION: { port: 5440, database: 'wallet_db' },
};

const SERVICES = [
  { dir: 'User', label: 'NEXUS USER SERVICE' },
  { dir: 'Catalog', label: 'NEXUS CATALOG SERVICE' },
  { dir: 'Commerce', label: 'NEXUS COMMERCE SERVICE' },
  { dir: 'Log', label: 'NEXUS LOG SERVICE' },
  { dir: 'Auction', label: 'NEXUS AUCTION SERVICE' },
  { dir: 'Fulfillment', label: 'NEXUS FULFILLMENT SERVICE' },
  { dir: 'Notification', label: 'NEXUS NOTIFICATION SERVICE' },
  { dir: 'Wallet', label: 'NEXUS WALLET SERVICE' },
  { dir: 'CheckHeal', label: 'NEXUS CHECKHEAL SERVICE' },
  { dir: 'Gateway', label: 'NEXUS YARP GATEWAY', gateway: true },
];

const SERVICE_TARGETS = {
  '.env.local': {
    title: 'LOCAL ENVIRONMENT (.env.local)',
    note: 'DB local (localhost:5433-5440). Hạ tầng dùng chung nexus-network.',
    dbLocal: true,
  },
  '.env.server': {
    title: 'SERVER ENVIRONMENT (.env.server)',
    note: 'DB Neon Cloud. Hạ tầng dùng chung nexus-network.',
    dbLocal: false,
    aliases: true,
  },
  '.env.server.example': {
    title: 'SERVER ENVIRONMENT CONFIGURATION (.env.server.example)',
    note: 'Áp dụng: cp .env.server.example .env',
    dbLocal: false,
    aliases: true,
  },
};

const GATEWAY_TARGETS = {
  '.env.local': {
    title: 'LOCAL ENVIRONMENT (.env.local)',
    note: 'URL downstream trỏ về localhost. Hạ tầng dùng chung nexus-network.',
    template: '.env.local.example',
    dbLocal: false,
  },
  '.env.server': {
    title: 'SERVER ENVIRONMENT (.env.server)',
    note: 'URL downstream trỏ về container nexus-network.',
    template: '.env',
    dbLocal: false,
  },
  '.env.server.example': {
    title: 'SERVER ENVIRONMENT CONFIGURATION (.env.server.example)',
    note: 'Áp dụng: cp .env.server.example .env',
    template: '.env.example',
    dbLocal: false,
  },
};

const ROOT_TARGETS = {
  '.env.local': {
    title: 'LOCAL ENVIRONMENT (.env.local)',
    note: 'DB local (localhost:5433-5440). Hạ tầng dùng chung nexus-network.',
    dbLocal: true,
  },
  '.env.local.example': {
    title: 'LOCAL ENVIRONMENT CONFIGURATION (.env.local.example)',
    note: 'Áp dụng: cp .env.local.example .env',
    dbLocal: true,
  },
  '.env.server': {
    title: 'SERVER ENVIRONMENT (.env.server)',
    note: 'DB Neon Cloud. Hạ tầng dùng chung nexus-network.',
    dbLocal: false,
    aliases: true,
  },
  '.env.server.example': {
    title: 'SERVER ENVIRONMENT CONFIGURATION (.env.server.example)',
    note: 'Áp dụng: cp .env.server.example .env',
    dbLocal: false,
    aliases: true,
  },
};

function readLines(file) {
  return fs.readFileSync(file, 'utf8').split(/\r?\n/);
}

function parseEnv(file) {
  const map = new Map();
  for (const line of readLines(file)) {
    const match = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line.trim());
    if (match) map.set(match[1], match[2]);
  }
  return map;
}

function localConnectionString(key) {
  const target = DB_LOCAL[key];
  return `Host=localhost;Port=${target.port};Database=${target.database};Username=postgres;Password=postgres`;
}

function legacyAliases(key, existing, isCheckHeal) {
  const candidates = [];

  if (key === 'USER_DB_CONNECTION') {
    candidates.push('USERS_DB_CONNECTION', 'USER_CONNECTION_STRING');
  }
  if (key.endsWith('_DB_CONNECTION')) {
    candidates.push(key.replace(/_DB_CONNECTION$/, '_CONNECTION_STRING'));
  }
  if (key.endsWith('_DB_CONNECTION') || candidates.length > 0) {
    candidates.push('CONNECTION_STRING');
  }
  if (isCheckHeal && key.startsWith('CHECKHEAL_') && key.endsWith('_URL')) {
    const service = key.slice('CHECKHEAL_'.length, -'_URL'.length);
    candidates.push(`${service}_SERVICE_URL`);
  }

  for (const candidate of candidates) {
    if (existing.has(candidate)) return existing.get(candidate);
  }
  return undefined;
}

function buildContent({ label, target, templateFile, existingFile, isCheckHeal }) {
  const template = readLines(templateFile);
  const existing = existingFile && fs.existsSync(existingFile) ? parseEnv(existingFile) : new Map();
  const templateValues = parseEnv(templateFile);

  const header = [
    '# =============================================================================',
    `# ${label} - ${target.title}`,
    '# =============================================================================',
    `# ${target.note}`,
    '',
  ];

  const body = [];
  let inHeader = true;
  for (const raw of template) {
    const line = raw.trim();

    if (inHeader) {
      if (line === '' || line.startsWith('#')) continue;
      inHeader = false;
    }

    const match = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line);
    if (!match) {
      if (target.dbLocal && line.startsWith('#')) {
        body.push(raw.replace('Neon Cloud PostgreSQL', 'PostgreSQL local').replace('Database Neon', 'Database local'));
      } else {
        body.push(raw);
      }
      continue;
    }

    const key = match[1];
    let value = templateValues.get(key) ?? '';

    if (target.dbLocal && Object.prototype.hasOwnProperty.call(DB_LOCAL, key)) {
      value = localConnectionString(key);
    } else if (target.aliases) {
      value = existing.get(key) ?? legacyAliases(key, existing, isCheckHeal) ?? value;
    }

    body.push(`${key}=${value}`);
  }

  // Collapse trailing blank lines, keep a single trailing newline.
  while (body.length > 0 && body[body.length - 1].trim() === '') body.pop();

  const lines = header.concat(body);
  // Drop leading blank line produced by template blanks directly after header.
  while (lines.length > 0 && lines[lines.length - 1].trim() === '') lines.pop();
  return lines.join('\n') + '\n';
}

const planned = [];
const drift = [];

function planRepo(baseDir, label, targets, defaults = {}) {
  const envFile = path.join(baseDir, '.env');
  if (!fs.existsSync(envFile)) {
    console.log('SKIP (no .env): ' + path.relative(ROOT, baseDir));
    return;
  }

  for (const [fileName, target] of Object.entries(targets)) {
    const templateName = target.template ?? '.env';
    const templateFile = path.join(baseDir, templateName);
    if (!fs.existsSync(templateFile)) {
      console.log('SKIP (no template ' + templateName + '): ' + path.relative(ROOT, path.join(baseDir, fileName)));
      continue;
    }

    const existingFile = path.join(baseDir, fileName);
    const content = buildContent({
      label,
      target,
      templateFile,
      existingFile,
      isCheckHeal: defaults.isCheckHeal === true,
    });

    const current = fs.existsSync(existingFile) ? fs.readFileSync(existingFile, 'utf8') : null;
    if (current === content) continue;

    planned.push({ file: existingFile, content, created: current === null });
    drift.push(path.relative(ROOT, existingFile));
  }
}

for (const service of SERVICES) {
  const baseDir = path.join(ROOT, 'src', 'Services', service.dir);
  const targets = service.gateway ? GATEWAY_TARGETS : SERVICE_TARGETS;
  planRepo(baseDir, service.label, targets, { isCheckHeal: service.dir === 'CheckHeal' });
}

planRepo(ROOT, 'NEXUS ROOT STACK', ROOT_TARGETS);

if (!WRITE) {
  if (drift.length === 0) {
    console.log('env profiles already in sync.');
    process.exit(0);
  }
  console.log('env profile drift detected in ' + drift.length + ' file(s):');
  for (const file of drift) console.log('  ' + file);
  console.log('\nRun with --write to regenerate them.');
  process.exit(1);
}

for (const item of planned) {
  fs.writeFileSync(item.file, item.content, 'utf8');
  console.log((item.created ? 'CREATED ' : 'UPDATED ') + path.relative(ROOT, item.file));
}

console.log('\n' + (planned.length === 0 ? 'nothing to write.' : planned.length + ' env profile file(s) synced.'));
