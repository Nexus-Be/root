import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const services = ['User', 'Catalog', 'Commerce', 'Log', 'Auction', 'Fulfillment', 'Notification', 'Wallet', 'CheckHeal', 'Gateway'];

let failures = 0;

function rel(p) {
  return path.relative(ROOT, p) || '.';
}

function parseEnvFile(file) {
  if (!fs.existsSync(file)) return null;
  const keys = [];
  const seen = new Set();
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    if (seen.has(key)) {
      console.log('DUPLICATE KEY ' + key + ' in ' + rel(file));
      failures += 1;
    }
    seen.add(key);
    keys.push(key);
  }
  return keys.sort();
}

function flattenKeys(value, prefix, out) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    out.push(prefix);
    return out;
  }
  for (const [k, v] of Object.entries(value)) {
    flattenKeys(v, prefix ? prefix + '.' + k : k, out);
  }
  return out;
}

function jsonKeys(file) {
  const value = JSON.parse(fs.readFileSync(file, 'utf8'));
  return flattenKeys(value, '', []).sort();
}

function compareKeySets(label, leftFile, rightFile) {
  const left = parseEnvFile(leftFile);
  const right = parseEnvFile(rightFile);
  if (left === null || right === null) {
    console.log('MISSING FILE ' + label);
    failures += 1;
    return;
  }
  const missing = right.filter((k) => !left.includes(k));
  const extra = left.filter((k) => !right.includes(k));
  if (missing.length || extra.length) {
    console.log('ENV MISMATCH ' + label);
    if (missing.length) console.log('  missing in ' + rel(leftFile) + ': ' + missing.join(', '));
    if (extra.length) console.log('  extra in ' + rel(leftFile) + ': ' + extra.join(', '));
    failures += 1;
  }
}

function compareJsonKeySets(label, leftFile, rightFile, options = {}) {
  const ignore = options.ignore || [];
  const clean = (keys) => keys.filter((k) => !ignore.some((prefix) => k.startsWith(prefix)));
  const left = clean(jsonKeys(leftFile));
  const right = clean(jsonKeys(rightFile));
  const missing = right.filter((k) => !left.includes(k));
  const extra = left.filter((k) => !right.includes(k));
  if (missing.length || extra.length) {
    console.log('CONFIG MISMATCH ' + label);
    if (missing.length) console.log('  missing in ' + rel(leftFile) + ': ' + missing.join(', '));
    if (extra.length) console.log('  extra in ' + rel(leftFile) + ': ' + extra.join(', '));
    failures += 1;
  }
}

const serviceRoots = {};
for (const name of services) {
  const base = path.join(ROOT, 'src', 'Services', name);
  serviceRoots[name] = base;

  const env = path.join(base, '.env');
  compareKeySets(name + ' .env vs .env.example', env, path.join(base, '.env.example'));
  compareKeySets(name + ' .env vs .env.local.example', env, path.join(base, '.env.local.example'));

  const apiName = name === 'Gateway' ? 'Gateway' : name + '.Api';
  const apiDir = path.join(base, apiName);
  if (name !== 'Gateway') {
    compareJsonKeySets(
      name + ' appsettings.example vs appsettings.Development.example',
      path.join(apiDir, 'appsettings.example.json'),
      path.join(apiDir, 'appsettings.Development.example.json'),
      { ignore: ['Logging.'] }
    );
  }
  compareJsonKeySets(
    name + ' appsettings vs appsettings.example',
    path.join(apiDir, 'appsettings.json'),
    path.join(apiDir, 'appsettings.example.json')
  );
}

compareKeySets('root .env vs .env.example', path.join(ROOT, '.env'), path.join(ROOT, '.env.example'));

const rootKeys = parseEnvFile(path.join(ROOT, '.env'));
for (const name of services) {
  const keys = parseEnvFile(path.join(serviceRoots[name], '.env'));
  const missing = keys.filter((k) => !rootKeys.includes(k));
  if (missing.length) {
    console.log('ROOT ENV MISSING keys for ' + name + ': ' + missing.join(', '));
    failures += 1;
  }
}

for (const name of services) {
  const compose = fs.readFileSync(path.join(serviceRoots[name], 'docker-compose.yml'), 'utf8');
  if (!compose.includes('ConnectionStrings__DefaultConnection')) {
    if (name !== 'Gateway' && name !== 'CheckHeal') {
      console.log('COMPOSE MISSING DB MAPPING ' + name);
      failures += 1;
    }
  }
  if (!compose.includes('nexus-network')) {
    console.log('COMPOSE MISSING nexus-network ' + name);
    failures += 1;
  }
}

const rootCompose = fs.readFileSync(path.join(ROOT, 'docker-compose.yml'), 'utf8');
for (const name of services) {
  const apiDir = path.join(serviceRoots[name], 'docker-compose.yml');
  const svcName = fs.readFileSync(apiDir, 'utf8').match(/^  ([a-z-]+):$/m);
  if (!svcName) {
    console.log('COMPOSE SERVICE NAME NOT FOUND ' + name);
    failures += 1;
    continue;
  }
  if (!rootCompose.includes('  ' + svcName[1] + ':')) {
    console.log('ROOT COMPOSE MISSING SERVICE ' + svcName[1]);
    failures += 1;
  }
}

if (failures > 0) {
  console.log('\n' + failures + ' parity check(s) failed.');
  process.exit(1);
}

console.log('all env and compose parity checks passed.');
