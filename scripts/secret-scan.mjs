#!/usr/bin/env node
// Pre-push secret scan.
//
// Purpose: the repository is private and GitHub secret scanning is not enabled
// on this account's plan, so this is the local control that stands in for it
// (EP-00-005 finding F-05-01). It scans the content that a push would publish
// and exits non-zero if anything matches a credential pattern.
//
// Usage:
//   node scripts/secret-scan.mjs            # scan every tracked file
//   node scripts/secret-scan.mjs <path>...  # scan specific paths (used by tests)
//
// This is a guard, not a guarantee. It recognises common credential shapes and
// nothing more; it does not replace a provider-side scanner.

import { execFileSync } from 'node:child_process';
import { readFileSync, statSync } from 'node:fs';

const RULES = [
  { id: 'github-token', re: /\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}\b/ },
  { id: 'github-fine-grained-pat', re: /\bgithub_pat_[A-Za-z0-9_]{22,}\b/ },
  { id: 'aws-access-key', re: /\bAKIA[0-9A-Z]{16}\b/ },
  { id: 'private-key-block', re: /-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/ },
  { id: 'slack-token', re: /\bxox[baprs]-[A-Za-z0-9-]{10,}\b/ },
  { id: 'google-api-key', re: /\bAIza[0-9A-Za-z_-]{35}\b/ },
  { id: 'openai-key', re: /\bsk-[A-Za-z0-9]{32,}\b/ },
  { id: 'vfd-or-paystack-secret', re: /\b(?:sk|pk)_(?:live|test)_[A-Za-z0-9]{20,}\b/ },
];

const MAX_FILE_BYTES = 2 * 1024 * 1024;

function trackedFiles() {
  const out = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8', maxBuffer: 1e8 });
  return out.split('\0').filter(Boolean);
}

const explicit = process.argv.slice(2);
const files = explicit.length ? explicit : trackedFiles();

const findings = [];

for (const file of files) {
  let stat;
  try {
    stat = statSync(file);
  } catch {
    continue;
  }
  if (!stat.isFile() || stat.size > MAX_FILE_BYTES) continue;

  let content;
  try {
    content = readFileSync(file, 'utf8');
  } catch {
    continue; // binary or unreadable: not a text secret carrier
  }
  if (content.includes('\0')) continue;

  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    for (const rule of RULES) {
      if (rule.re.test(lines[i])) {
        findings.push({ file, line: i + 1, rule: rule.id });
      }
    }
  }
}

if (findings.length) {
  console.error('secret-scan: blocked - possible credential(s) detected\n');
  for (const f of findings) {
    console.error(`  ${f.file}:${f.line}  [${f.rule}]`);
  }
  console.error('\nRemove the value, rotate it if it was ever real, and commit again.');
  console.error('This is a local guard, not a substitute for provider-side scanning.');
  process.exit(1);
}

console.log(`secret-scan: clean (${files.length} file(s) scanned)`);
