#!/usr/bin/env node
/**
 * Status line: model, repo/branch, context window, 5h plan usage.
 *
 * Reads the Status payload on stdin. Fields used (Claude Code >= 2.1.x):
 *   model.display_name
 *   workspace.current_dir
 *   context_window.{used_percentage,total_input_tokens,context_window_size}
 *   rate_limits.five_hour -> {used_percentage, resets_at (epoch s)}
 *
 * rate_limits is absent when the account has no plan-utilisation data yet
 * (e.g. before the first API response of a session); the segment is skipped.
 */

const { execSync } = require('child_process');
const path = require('path');

const C = {
  reset: '\x1b[0m', dim: '\x1b[2m',
  gray: '\x1b[38;5;245m', blue: '\x1b[38;5;75m', mag: '\x1b[38;5;177m',
  green: '\x1b[38;5;71m', yellow: '\x1b[38;5;179m', red: '\x1b[38;5;167m',
};

// Green under 50%, amber under 80%, red above.
const heat = (pct) => (pct >= 80 ? C.red : pct >= 50 ? C.yellow : C.green);

function tokens(n) {
  if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1).replace(/\.0$/, '') + 'M';
  if (n >= 1e3) return Math.round(n / 1e3) + 'k';
  return String(n);
}

// Local clock time the quota window rolls over, e.g. "23:45". The 5h window
// is always within a few hours, so HH:MM needs no date qualifier.
function resetAt(epochSeconds) {
  const d = new Date(epochSeconds * 1000);
  if (Number.isNaN(d.getTime())) return null;
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

// The payload multiplies the raw header utilisation by 100; that header has
// been seen both as a 0-1 fraction and as a 0-100 percentage. Normalise.
const pct = (v) => (typeof v === 'number' && Number.isFinite(v) ? (v > 100 ? v / 100 : v) : null);

function branch(dir) {
  try {
    const b = execSync('git rev-parse --abbrev-ref HEAD 2>/dev/null', {
      cwd: dir, encoding: 'utf8', timeout: 1000,
    }).trim();
    if (!b) return null;
    const dirty = execSync('git status --porcelain 2>/dev/null', {
      cwd: dir, encoding: 'utf8', timeout: 1000,
    }).trim().length > 0;
    return b + (dirty ? '*' : '');
  } catch {
    return null;
  }
}

function render(d) {
  const seg = [];

  const model = d.model?.display_name;
  if (model) seg.push(`${C.mag}${model}${C.reset}`);

  const dir = d.workspace?.current_dir || d.cwd || process.cwd();
  const br = branch(dir);
  seg.push(`${C.blue}${path.basename(dir)}${C.reset}` + (br ? ` ${C.gray}${br}${C.reset}` : ''));

  const cw = d.context_window;
  if (cw && Number.isFinite(cw.used_percentage)) {
    const p = Math.round(cw.used_percentage);
    const used = tokens(cw.total_input_tokens || 0);
    const size = tokens(cw.context_window_size || 0);
    seg.push(`${C.gray}ctx${C.reset} ${heat(p)}${p}%${C.reset} ${C.dim}${used}/${size}${C.reset}`);
  }

  const lim = d.rate_limits?.five_hour;
  const p = pct(lim?.used_percentage);
  if (p !== null) {
    const at = Number.isFinite(lim.resets_at) ? resetAt(lim.resets_at) : null;
    const r = at ? ` ${C.dim}↻${at}${C.reset}` : '';
    seg.push(`${C.gray}5h${C.reset} ${heat(p)}${Math.round(p)}%${C.reset}${r}`);
  }

  return seg.join(`${C.dim} | ${C.reset}`);
}

let raw = '';
try { raw = require('fs').readFileSync(0, 'utf8'); } catch { /* no stdin */ }

try {
  process.stdout.write(render(raw.trim() ? JSON.parse(raw) : {}));
} catch (err) {
  process.stdout.write(`${C.red}statusline: ${err.message}${C.reset}`);
}
