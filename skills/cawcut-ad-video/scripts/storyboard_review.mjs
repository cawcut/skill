#!/usr/bin/env node
// One call that prepares the Stage 4 review: wait for the script + assets to be displayable, render the
// script table, download the character/location images, and print one JSON the agent can show as-is.
// Usage: storyboard_review.mjs <id> [--dest dir] [--timeout seconds] [--until display|ready]
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const [id, ...rest] = process.argv.slice(2);
if (!id || id.startsWith('--')) { console.error('Usage: storyboard_review.mjs <id> [--dest dir] [--timeout seconds] [--until display|ready]'); process.exit(2); }
const opt = (name, fallback) => { const i = rest.indexOf(name); return i >= 0 ? rest[i + 1] : fallback; };
const until = opt('--until', 'display'), timeout = opt('--timeout', '3600'), destArg = opt('--dest');
if (!['display', 'ready'].includes(until)) { console.error('--until must be display or ready'); process.exit(2); }

const run = (cmd, args) => spawnSync(cmd, args, { encoding: 'utf8', shell: cmd === 'cawcut' && process.platform === 'win32', maxBuffer: 64 * 1024 * 1024 });
const cawcut = args => run('cawcut', ['ad-video', ...args]);
const fail = (step, r) => { console.error(`${step} failed (exit ${r.status}): ${(r.stderr || r.stdout || '').trim()}`); process.exit(r.status || 1); };
const parse = (step, r) => { try { return JSON.parse(r.stdout); } catch { fail(`${step}: unparseable output`, r); } };

// 1. wait until the script and at least one decided entity side can be shown (exit 1 = failed terminal state)
const waited = cawcut(['storyboard', 'status', id, '--wait', '--until', until, '--wait-timeout', timeout, '--json']);
const state = waited.stdout.trim() ? parse('storyboard status', waited) : fail('storyboard status', waited);
if (waited.status !== 0 && state.next_step !== 'fix_failed') fail('storyboard status', waited);

const result = { id, next_step: state.next_step, portal_url: state.portal_url, script_status: state.script_status, script_stale: state.script_stale, instruction: state.instruction ?? null };
if (state.next_step === 'fix_failed' || !state.content_revealed) {
  result.entities = state.entities.map(({ entity, status, error }) => ({ entity, status, error }));
  console.log(JSON.stringify(result, null, 2)); process.exit(state.next_step === 'fix_failed' ? 1 : 0);
}

// 2. working copy + readable table (the shared helper owns every @mention conversion)
const take = run(process.execPath, [join(here, 'script_plan.mjs'), 'take', id, ...(destArg ? ['--dest', destArg] : [])]);
if (take.status !== 0) fail('script_plan take', take);
const plan = /plan: (.+)/.exec(take.stdout)?.[1]?.trim();
if (!plan) fail('script_plan take: no plan path', take);
const dest = destArg ?? dirname(dirname(plan));
const table = run(process.execPath, [join(here, 'script_plan.mjs'), 'render', plan]);
if (table.status !== 0) fail('script_plan render', table);

// 3. entity images, saved under <dest>/entities
const downloaded = cawcut(['entities', 'download', id, '--dest', dest, '--json']);
const saved = downloaded.stdout.trim() ? parse('entities download', downloaded) : { files: [], failed: [] };

result.plan_path = plan; result.script_table = table.stdout.trim();
result.entities = state.entities.map(e => ({ entity: e.entity, status: e.status, editable: e.editable, ready: e.ready, need_regenerate: e.need_regenerate, names: e.names, prompts: e.prompts, files: saved.files.filter(f => f.entity === e.entity).map(f => f.path), error: e.error }));
result.failed_downloads = saved.failed;
const queue = cawcut(['review', 'next', id]);
result.review = queue.status === 0 ? JSON.parse(queue.stdout.replace(/^[^{]*/, '')) : null;
result.reminder = 'Show only the item named by review.next (character, location, script) - one item per reply, each ending with its review question; after the user approves run `cawcut ad-video review approve <id> --item <item>`, then `review next`. Refresh while next_step is "review".';
console.log(JSON.stringify(result, null, 2));
