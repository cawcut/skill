#!/usr/bin/env node
// Shared deterministic editing pipeline for Bash and PowerShell. No LLM key inference.
import { realpathSync, readFileSync, writeFileSync, mkdirSync, renameSync, existsSync, unlinkSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const fields = new Set(['duration','shot_type','shot_description','dialogue','camera','light','sfx','shot_prompt','video_prompt']);
const template = /\{\{\s*([^{}]+?)\s*\}\}/gu;
const read = path => JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/u, ''));
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
// Signed URL query strings change between reads; mapping conflicts must track
// entity identity/name and the underlying image, never a temporary signature.
export function assetFingerprint(assets) {
  const stableUrl = value => {
    if (!value) return '';
    try { const u = new URL(value); return u.origin + u.pathname; } catch { return String(value); }
  };
  return hash(['characters','scenes'].flatMap(type => (assets?.[type] ?? []).map(a => {
    const image = a.image ?? a.reference_image ?? {};
    return { type, key:a.key, name:a.name ?? a.key, source:a.source ?? '', source_ref_id:a.source_ref_id ?? '',
      image_id:image.asset_id ?? image.id ?? a.image_asset_id ?? '',
      image_path:stableUrl(image.url ?? image.preview_url) };
  })).sort((a,b) => `${a.type}:${a.key}`.localeCompare(`${b.type}:${b.key}`)));
}
function write(path, value) {
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(value, null, 2) + '\n', 'utf8'); renameSync(tmp, path);
}
export function mentions(plan) {
  const all = ['characters','scenes'].flatMap(type => (plan.assets?.[type] ?? []).map(a => ({ key: a.key, name: a.name || a.key, type })));
  const keys = new Set();
  for (const a of all) { if (typeof a.key !== 'string' || !a.key || keys.has(a.key)) throw new Error('Duplicate/invalid asset key'); keys.add(a.key); }
  return all.map(a => ({ ...a, label: all.filter(b => b.name === a.name).length > 1 ? `${a.name} [${a.type}:${a.key}]` : a.name }));
}
export function displayText(text, map) {
  return String(text ?? '').replace(template, (token, key) => {
    const entry = map.find(a => a.key === key.trim()); return entry ? `@${entry.label}` : token;
  });
}
function endBoundary(char) { return boundary(char) || /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/u.test(char || ''); }
function boundary(char) { return !char || !/[\p{L}\p{N}_@]/u.test(char); }
export function rawText(text, map) {
  // Match a known label only at an @ token boundary; never rewrite emails or run replacements over inserted tokens.
  let result = '';
  const sorted = [...map].sort((a,b) => b.label.length - a.label.length);
  for (let i = 0; i < text.length;) {
    if (text.startsWith('{{', i)) {
      const match = /^\{\{\s*([^{}]+?)\s*\}\}/u.exec(text.slice(i));
      if (match) {
        if (!map.some(a => a.key === match[1].trim())) throw new Error(`Unknown asset reference: ${match[1]}`);
        result += match[0]; i += match[0].length; continue;
      }
    }
    const email = text[i] === '@' && /[\p{L}\p{N}_.+-]/u.test(text[i-1] || '') && /^[^\s@]+\.[A-Za-z]{2,}(?:\b|$)/u.test(text.slice(i+1));
    if (text[i] === '@' && !email && endBoundary(text[i-1])) {
      const item = sorted.find(a => text.startsWith(`@${a.label}`, i) && endBoundary(text[i+a.label.length+1]));
      if (item) { result += `{{ ${item.key} }}`; i += item.label.length+1; continue; }
      const ambiguous = map.find(a => a.label !== a.name && text.startsWith(`@${a.name}`, i) && endBoundary(text[i+a.name.length+1]));
      if (ambiguous) throw new Error(`Ambiguous mention @${ambiguous.name}; select a qualified label from render output`);
      // Plain non-entity @text is preserved, as in FE. It is never guessed to be an asset.
    }
    result += text[i++];
  }
  return result;
}
export function applyEdits(plan, edits) {
  if (!edits || Array.isArray(edits) || typeof edits !== 'object') throw new Error('Edits must be an object');
  if (!Array.isArray(plan.shots)) throw new Error('Plan has no shots');
  const out = structuredClone(plan), map = mentions(plan);
  for (const [id, patch] of Object.entries(edits)) {
    if (id === 'title' || id === 'synopsis') {
      if (typeof patch !== 'string') throw new Error(`${id} must be text`);
      out[id] = rawText(patch, map); continue;
    }
    const shot = out.shots.find(s => s.shot_id === id);
    if (!shot) throw new Error(`Unknown shot: ${id}`);
    if (!patch || Array.isArray(patch) || typeof patch !== 'object') throw new Error(`Invalid edits for ${id}`);
    for (const [field,value] of Object.entries(patch)) {
      if (!fields.has(field)) throw new Error(`Field not editable: ${id}.${field}`);
      if (field === 'duration') { if (!['number','string'].includes(typeof value)) throw new Error('Invalid duration'); shot[field] = value; }
      else { if (typeof value !== 'string') throw new Error(`${id}.${field} must be text`); shot[field] = rawText(value, map); }
    }
    // Mirror BE bindMentionedScriptAssets: append referenced characters; fill scene only when empty.
    const refs = new Set(shot.character_refs ?? []);
    for (const field of ['shot_description','shot_prompt','video_prompt']) {
      for (const match of String(shot[field] ?? '').matchAll(template)) {
        const a = map.find(a => a.key === match[1].trim());
        if (!a) throw new Error(`Unknown reference: ${match[1]}`);
        if (a.type === 'characters') refs.add(a.key);
        else if (!shot.scene_ref) shot.scene_ref = a.key;
        else if (shot.scene_ref !== a.key) throw new Error(`Shot ${id} cannot reference multiple scenes`);
      }
    }
    shot.character_refs = [...refs];
  }
  return out;
}
function cell(value, map) { return displayText(value, map).replace(/\r?\n/g, '<br>').replace(/\|/g, '\\|'); }
export function render(plan, videoType) {
  const map = mentions(plan), columns = ['shot_no','duration','shot_type','shot_description',...(videoType === 'product_showcase' ? [] : ['dialogue']),'camera','light','sfx'];
  const header = {shot_no:'Shot #',duration:'Duration',shot_type:'Shot Type',shot_description:'Shot Description',dialogue:'Voiceover',camera:'Camera',light:'Light',sfx:'SFX'};
  const lines = [`**${cell(plan.title,map)}**`, '', cell(plan.synopsis,map), '', `| ${columns.map(c=>header[c]).join(' | ')} |`, `| ${columns.map(()=>'---').join(' | ')} |`];
  for (const shot of plan.shots) lines.push(`| ${columns.map(c=>cell(shot[c],map)).join(' | ')} |`);
  // Prompts also use display tokens, so the model never has to transform a raw template while editing.

  const unresolved = JSON.stringify(plan).match(/\{\{\s*([^{}]+?)\s*\}\}/gu)?.filter(t => !map.some(a => t.replace(/[{}]/g,'').trim() === a.key)) ?? [];
  if (unresolved.length) lines.push('', `Unresolved references (preserved; repair before saving): ${[...new Set(unresolved)].join(', ')}`);
  return lines.join('\n');
}
function cawcut(args) {
  // Shell-free and Windows compatible: invoke the installed Node CLI entry when available.
  let launcher = process.env.CAWCUT_SCRIPT_CLI;
  if (!launcher && process.platform === 'win32') {
    const paths = spawnSync('where.exe', ['cawcut'], { encoding:'utf8' });
    for (const path of (paths.stdout || '').trim().split(/\r?\n/)) {
      const entry = join(dirname(path),'node_modules','@ubnt','cawcut','dist','index.js');
      if (existsSync(entry)) { launcher = entry; break; }
    }
    if (!launcher) throw new Error('Cannot resolve Windows cawcut entry; set CAWCUT_SCRIPT_CLI to its dist/index.js');
  }
  const result = launcher ? spawnSync(process.execPath, [launcher, ...args], { encoding:'utf8' })
    : spawnSync('cawcut', args, { encoding:'utf8', shell:false });
  if (result.error || result.status !== 0) throw new Error(result.stderr || result.error?.message || `cawcut exited ${result.status}`);
  return JSON.parse(result.stdout);
}
export function main(args) {
  const [command, path, editsPath] = args;
  if (command === 'take') {
    const detail = cawcut(['ad-video','detail',path,'--json']), plan = detail.outputs?.storyboard_plan?.value;
    if (!Array.isArray(plan?.shots) || !plan.shots.length) throw new Error('Storyboard has no readable shots yet');
    const destFlag = args.findIndex(a=>a === '--dest' || a === '-Destination');
    const slug = String(detail.product_info?.name || detail.name || path).replace(/[^A-Za-z0-9_-]+/g,'-').replace(/^-|-$/g,'').slice(0,60) || path;
    const dest = join(destFlag >= 0 ? args[destFlag+1] : join(homedir(),'Downloads',`ad-video-${slug}`),'storyboard');
    mkdirSync(dest,{recursive:true});
    write(join(dest,'script.json'),plan);
    write(join(dest,'script.meta.json'),{ id:path, revision:plan.revision ?? 0, assets_hash:assetFingerprint(plan.assets), video_type:detail.product_info?.video_settings?.video_type, mentions:mentions(plan) });
    write(join(dest,'script.display.json'),{...plan, title:displayText(plan.title,mentions(plan)), synopsis:displayText(plan.synopsis,mentions(plan)), shots:plan.shots.map(shot=>Object.fromEntries(Object.entries(shot).map(([k,v])=>[k,fields.has(k) && typeof v==='string' ? displayText(v,mentions(plan)) : v]))) });
    console.log(`plan: ${join(dest,'script.json')}\ndisplay: ${join(dest,'script.display.json')}`); return;
  }
  if (!['apply','render','show'].includes(command)) throw new Error('Usage: script_plan take <id> [--dest dir] | apply/render/show <plan.json> [edits.json]');
  const plan = read(path), metaPath = join(dirname(path),'script.meta.json'), meta = existsSync(metaPath) ? read(metaPath) : {};
  if (!Array.isArray(plan.shots) || !plan.shots.length) throw new Error('Plan has no readable shots');
  if (command !== 'render') {
    if (!editsPath) throw new Error('Missing edits file');
    if (meta.assets_hash && (assetFingerprint(plan.assets) !== meta.assets_hash || (plan.revision ?? 0) !== meta.revision)) throw new Error('Working-copy asset mapping/revision changed; take a fresh copy');
    if (meta.id) {
      const current = cawcut(['ad-video','detail',meta.id,'--json']).outputs?.storyboard_plan?.value;
      if (!current || (current.revision ?? 0) !== meta.revision || assetFingerprint(current.assets) !== meta.assets_hash) throw new Error('Project changed; take a fresh copy before applying edits');
    }
    const edited = applyEdits(plan, read(editsPath));
    // Server constraints/revision remain authoritative at storyboard set; structural conversion errors fail before writing.
    if (meta.id) {
      const candidate = `${path}.${process.pid}.check.json`;
      try {
        write(candidate, edited);
        cawcut(['ad-video','storyboard','check',meta.id,'--base-revision',String(meta.revision),'--plan-file',candidate,'--json']);
      } finally { if (existsSync(candidate)) unlinkSync(candidate); }
    }
    write(path,edited);
    if (command === 'apply') { console.log('Edits applied; @ mentions restored to template keys'); return; }
    console.log(render(edited,meta.video_type)); return;
  }
  console.log(render(plan,meta.video_type));
}
// Compare real paths: the skill is usually installed as a symlink (~/.claude/skills/...), and Node resolves
// import.meta.url through it while argv[1] keeps the link, so a plain compare silently skipped main().
const realPath = path => { try { return realpathSync(path); } catch { return resolve(path); } };
if (process.argv[1] && realPath(process.argv[1]) === realPath(fileURLToPath(import.meta.url))) {
  try { main(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode=2; }
}
