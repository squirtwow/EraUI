// EraUI release announcements, by Squirt. No third-party runtime dependencies.
// When a version tag is pushed, waits until CurseForge lists that version as
// available, then posts its changelog to the Discord announcements channel.
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { PROJECT_ID, requestJson, sendDiscord, validateWebhook } from './curseforge-comments.mjs';

const CURSEFORGE_URL = 'https://www.curseforge.com/wow/addons/eraui';
const GITHUB_URL = 'https://github.com/squirtwow/EraUI';
const FILES_URL = `https://www.curseforge.com/api/v1/mods/${PROJECT_ID}/files?pageIndex=0&pageSize=20&sort=dateCreated&sortDescending=true&removeAlphas=false`;
const AVAILABLE = new Set([4, 10]); // CurseForge file statuses: approved, released
const COLOUR = 0xd8b25c; // EraUI's gold
const headers = {
  Accept: 'application/json',
  'User-Agent': 'EraUI release announcer (https://github.com/squirtwow/EraUI)',
};
const pause = ms => new Promise(resolvePause => setTimeout(resolvePause, ms));

export function validVersion(version) {
  return typeof version === 'string' && /^\d{1,2}\.\d{1,2}(\.\d{1,2})?$/.test(version);
}

// The version's own section of CHANGELOG.txt: its "### Added", "### Changed"
// and so on, each with its bullets. Nothing else is read from the file.
export function releaseNotes(changelog, version) {
  const lines = String(changelog).split(/\r?\n/);
  const start = lines.findIndex(line => line.trim() === `## ${version}`);
  if (start < 0) return null;
  const sections = [];
  for (const line of lines.slice(start + 1)) {
    if (/^## /.test(line)) break;
    const heading = line.match(/^### (.+)$/);
    if (heading) sections.push({ title: heading[1].trim(), items: [] });
    else if (/^- /.test(line) && sections.length) sections.at(-1).items.push(line.slice(2).trim());
  }
  const filled = sections.filter(section => section.items.length);
  return filled.length ? filled : null;
}

// The version's file on CurseForge, once it can be downloaded.
export function findFile(files, version) {
  if (!Array.isArray(files)) return null;
  return files.find(file => file && file.projectId === PROJECT_ID && AVAILABLE.has(file.status)
    && (file.displayName === version || file.fileName === `EraUI-${version}.zip`)) || null;
}

// Checks CurseForge every minute, for up to an hour.
export async function waitForCurseForge(version, {
  getFiles = async () => requestJson(FILES_URL, { headers }, 'CurseForge'),
  sleep = pause, now = () => Date.now(), limitMs = 60 * 60 * 1000, everyMs = 60 * 1000, log = console.log,
} = {}) {
  const start = now();
  for (;;) {
    try {
      const file = findFile((await getFiles())?.data, version);
      if (file) return file;
    } catch (error) {
      log(`${error.message}; trying again.`);
    }
    if (now() - start >= limitMs) return null;
    await sleep(everyMs);
  }
}

// Discord allows 4096 characters in an embed; long notes end at a whole bullet.
export function discordPayload(version, notes, onCurseForge = true) {
  const closing = (onCurseForge
    ? 'Update through the CurseForge app, or download it from'
    : "It'll be on CurseForge shortly. Download it from")
    + ` [CurseForge](${CURSEFORGE_URL}) or [GitHub](${GITHUB_URL}).`;
  const limit = 4000 - closing.length;
  const parts = [];
  let length = 0, cut = false;
  for (const section of notes) {
    for (const [index, item] of section.items.entries()) {
      const piece = `${index === 0 ? `${parts.length ? '\n' : ''}**${section.title}**\n` : ''}• ${item}\n`;
      if (length + piece.length > limit) { cut = true; break; }
      parts.push(piece);
      length += piece.length;
    }
    if (cut) break;
  }
  const description = `${parts.join('')}${cut ? '…and more in the changelog.\n' : ''}\n${closing}`;
  return {
    content: '@here',
    allowed_mentions: { parse: ['everyone'] },
    embeds: [{
      title: `EraUI ${version} is out`,
      url: CURSEFORGE_URL,
      color: COLOUR,
      description,
      footer: { text: `EraUI ${version} • Classic WoW, restored for WoW Forever` },
      timestamp: new Date().toISOString(),
    }],
  };
}

async function main() {
  const version = process.env.RELEASE_VERSION;
  if (!validVersion(version)) throw new Error('Expected a version tag such as 1.2.0');
  const webhook = validateWebhook(process.env.DISCORD_RELEASE_WEBHOOK);
  const notes = releaseNotes(await readFile('CHANGELOG.txt', 'utf8'), version);
  if (!notes) throw new Error(`CHANGELOG.txt has no notes for ${version}`);
  const file = await waitForCurseForge(version);
  console.log(file ? `CurseForge has ${version}.` : `CurseForge doesn't list ${version} after an hour; announcing anyway.`);
  await sendDiscord(webhook, discordPayload(version, notes, Boolean(file)));
  console.log(`Announced EraUI ${version} on Discord.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
