import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const services = ['User', 'Catalog', 'Commerce', 'Log', 'Auction', 'Fulfillment', 'Notification', 'Wallet', 'CheckHeal', 'Gateway'];

const PROFILES = ['.env.example', '.env.local', '.env.local.example', '.env.server', '.env.server.example'];

const LEGACY_EXACT = [
  'CONNECTION_STRING',
  'POSTGRES_USER',
  'POSTGRES_PASSWORD',
  'USERS_DB_CONNECTION',
  'CHECKHEAL_PROBE_TIMEOUT',
  'CHECKHEAL_DEFAULT_ENABLED',
  'GATEWAY_AUTH_MODE',
  'HEALTHCHECK_SERVICE_URL',
  'DOCKER_IMAGE',
];

const CHECKHEAL_ONLY_LEGACY = ['USERS_SERVICE_URL'];
const ROOT_ONLY_LEGACY = ['USERS_DB_CONNECTION', 'CHECKHEAL_PROBE_TIMEOUT', 'CHECKHEAL_DEFAULT_ENABLED', 'GATEWAY_AUTH_MODE', 'HEALTHCHECK_SERVICE_URL'];

let failures = 0;

function rel(p) {
  return path.relative(ROOT, p) || '.';
}

function fail(message) {
  console.log(message);
  failures += 1;
}

function isLegacyKey(key, scope) {
  if (LEGACY_EXACT.includes(key)) return true;
  if (key.endsWith('_CONNECTION_STRING') && key !== 'REDIS_CONNECTION_STRING') return true;
  if (key.endsWith('_DB_PORT') && key !== 'REDIS_PORT') return true;
  if (scope === 'CheckHeal' && CHECKHEAL_ONLY_LEGACY.includes(key)) return true;
  if (scope === 'root' && ROOT_ONLY_LEGACY.includes(key)) return true;
  return false;
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
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) continue;
    if (seen.has(key)) fail('DUPLICATE KEY ' + key + ' in ' + rel(file));
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
  if (left === null) return fail('MISSING FILE ' + rel(leftFile));
  if (right === null) return fail('MISSING FILE ' + rel(rightFile));
  const missing = left.filter((k) => !right.includes(k));
  const extra = right.filter((k) => !left.includes(k));
  if (missing.length || extra.length) {
    fail('ENV MISMATCH ' + label);
    if (missing.length) console.log('  missing in ' + rel(rightFile) + ': ' + missing.join(', '));
    if (extra.length) console.log('  extra in ' + rel(rightFile) + ': ' + extra.join(', '));
  }
}

function checkLegacyKeys(label, file, scope) {
  const keys = parseEnvFile(file);
  if (keys === null) return;
  const legacy = keys.filter((k) => isLegacyKey(k, scope));
  if (legacy.length) fail('LEGACY KEY in ' + label + ' (' + rel(file) + '): ' + legacy.join(', '));
}

function compareJsonKeySets(label, leftFile, rightFile, options = {}) {
  const ignore = options.ignore || [];
  const clean = (keys) => keys.filter((k) => !ignore.some((prefix) => k.startsWith(prefix)));
  const left = clean(jsonKeys(leftFile));
  const right = clean(jsonKeys(rightFile));
  const missing = right.filter((k) => !left.includes(k));
  const extra = left.filter((k) => !right.includes(k));
  if (missing.length || extra.length) {
    // appsettings files are local-only in this repo, so drift is reported but not fatal.
    console.log('CONFIG WARNING ' + label + ' (not tracked, informational only)');
    if (missing.length) console.log('  missing in ' + rel(leftFile) + ': ' + missing.join(', '));
    if (extra.length) console.log('  extra in ' + rel(leftFile) + ': ' + extra.join(', '));
  }
}

function composeRequiredVars(file) {
  const content = fs.readFileSync(file, 'utf8');
  const vars = new Set();
  for (const match of content.matchAll(/\$\{([A-Z0-9_]+):\?/g)) vars.add(match[1]);
  return [...vars].sort();
}

const serviceRoots = {};
for (const name of services) {
  const base = path.join(ROOT, 'src', 'Services', name);
  serviceRoots[name] = base;

  const env = path.join(base, '.env');
  const envKeys = parseEnvFile(env);
  if (envKeys === null) {
    fail('MISSING FILE ' + rel(env));
    continue;
  }

  checkLegacyKeys(name + ' .env', env, name);

  for (const profile of PROFILES) {
    const profileFile = path.join(base, profile);
    compareKeySets(name + ' .env vs ' + profile, env, profileFile);
    checkLegacyKeys(name + ' ' + profile, profileFile, name);
  }

  const composeFile = path.join(base, 'docker-compose.yml');
  if (fs.existsSync(composeFile)) {
    for (const variable of composeRequiredVars(composeFile)) {
      if (!envKeys.includes(variable)) fail('COMPOSE REQUIRED VAR MISSING in ' + name + ' .env: ' + variable);
    }
    if (!fs.readFileSync(composeFile, 'utf8').includes('nexus-network')) {
      fail('COMPOSE MISSING nexus-network ' + name);
    }
  } else {
    fail('MISSING FILE ' + rel(composeFile));
  }

  const apiName = name === 'Gateway' ? 'Gateway' : name + '.Api';
  const apiDir = path.join(base, apiName);
  if (fs.existsSync(path.join(apiDir, 'appsettings.example.json'))) {
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
}

const rootEnv = path.join(ROOT, '.env');
const rootEnvKeys = parseEnvFile(rootEnv);
if (rootEnvKeys === null) {
  fail('MISSING FILE .env');
} else {
  checkLegacyKeys('root .env', rootEnv, 'root');
  for (const profile of PROFILES) {
    const profileFile = path.join(ROOT, profile);
    compareKeySets('root .env vs ' + profile, rootEnv, profileFile);
    checkLegacyKeys('root ' + profile, profileFile, 'root');
  }

  for (const name of services) {
    const keys = parseEnvFile(path.join(serviceRoots[name], '.env')) || [];
    const missing = keys.filter((k) => !rootEnvKeys.includes(k));
    if (missing.length) fail('ROOT ENV MISSING keys for ' + name + ': ' + missing.join(', '));
  }
}

const rootCompose = fs.readFileSync(path.join(ROOT, 'docker-compose.yml'), 'utf8');
if (fs.existsSync(path.join(ROOT, 'docker-compose.infra.yml'))) {
  if (!rootCompose.includes('nexus-network')) fail('ROOT COMPOSE MISSING nexus-network');
}
for (const name of services) {
  const composeFile = path.join(serviceRoots[name], 'docker-compose.yml');
  if (!fs.existsSync(composeFile)) continue;
  const svcName = fs.readFileSync(composeFile, 'utf8').match(/^  ([a-z-]+):$/m);
  if (!svcName) {
    fail('COMPOSE SERVICE NAME NOT FOUND ' + name);
    continue;
  }
  if (!rootCompose.includes('  ' + svcName[1] + ':')) fail('ROOT COMPOSE MISSING SERVICE ' + svcName[1]);
}

if (failures > 0) {
  console.log('\n' + failures + ' parity check(s) failed.');
  process.exit(1);
}

console.log('all env and compose parity checks passed.');
