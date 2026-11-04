import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PROJECT_ID } from '../.github/scripts/curseforge-comments.mjs';
import { discordPayload, findFile, releaseNotes, validVersion, waitForCurseForge } from '../.github/scripts/discord-release.mjs';

const changelog = await readFile(new URL('../CHANGELOG.txt', import.meta.url), 'utf8');
const file = (displayName, extra = {}) => ({ projectId: PROJECT_ID, displayName, fileName: `EraUI-${displayName}.zip`, status: 4, ...extra });

test('only plain version tags are announced', () => {
  assert.equal(validVersion('1.2.0'), true);
  assert.equal(validVersion('1.2'), true);
  assert.equal(validVersion('v1.2.0'), false);
  assert.equal(validVersion('1.2.0; rm -rf'), false);
  assert.equal(validVersion(undefined), false);
});

test('the version\'s own changelog section, by heading, and nothing after it', () => {
  const notes = releaseNotes(changelog, '1.2.0');
  assert.deepEqual(notes.map(section => [section.title, section.items.length]), [['Added', 8], ['Changed', 3], ['Fixed', 1]]);
  assert.match(notes[0].items[0], /^Damage text font:/);
  assert.equal(releaseNotes(changelog, '9.9.9'), null);
  assert.equal(releaseNotes('## 1.0.0\n\nNothing listed.', '1.0.0'), null);
});

test('CurseForge counts once the file for that version is available', () => {
  assert.equal(findFile([file('1.1.0'), file('1.2.0')], '1.2.0').displayName, '1.2.0');
  assert.equal(findFile([file('1.2.0', { status: 1 })], '1.2.0'), null, 'still processing');
  assert.equal(findFile([file('1.2.0', { projectId: 12 })], '1.2.0'), null, 'another project');
  assert.equal(findFile([file('1.2.0', { displayName: 'EraUI 1.2.0' })], '1.2.0').fileName, 'EraUI-1.2.0.zip', 'matched by file name too');
  assert.equal(findFile(undefined, '1.2.0'), null);
});

test('waits for CurseForge, checking again after errors, and gives up after the limit', async () => {
  let clock = 0, calls = 0;
  const sleep = async ms => { clock += ms; };
  const pages = [new Error('CurseForge: HTTP 503'), { data: [file('1.1.0')] }, { data: [file('1.2.0')] }];
  const found = await waitForCurseForge('1.2.0', {
    getFiles: async () => { const page = pages[calls++]; if (page instanceof Error) throw page; return page; },
    sleep, now: () => clock, log: () => {},
  });
  assert.equal(found.displayName, '1.2.0');
  assert.equal(calls, 3);
  assert.equal(clock, 120000, 'a minute between checks');
  clock = 0;
  const missing = await waitForCurseForge('1.3.0', { getFiles: async () => ({ data: [] }), sleep, now: () => clock, log: () => {} });
  assert.equal(missing, null);
  assert.equal(clock, 3600000, 'an hour at most');
});

test('the Discord post: @here, the notes in sections, and where to get it', () => {
  const payload = discordPayload('1.2.0', releaseNotes(changelog, '1.2.0'));
  assert.equal(payload.content, '@here');
  assert.deepEqual(payload.allowed_mentions, { parse: ['everyone'] });
  const [embed] = payload.embeds;
  assert.equal(embed.title, 'EraUI 1.2.0 is out');
  assert.match(embed.description, /^\*\*Added\*\*\n• Damage text font:/);
  assert.match(embed.description, /\*\*Changed\*\*\n• Class reminders:/);
  assert.match(embed.description, /Update through the CurseForge app, or download it from \[CurseForge\]\(https:\/\/www\.curseforge\.com\/wow\/addons\/eraui\) or \[GitHub\]\(https:\/\/github\.com\/squirtwow\/EraUI\)\.$/);
  assert.ok(embed.description.length <= 4096);
  const late = discordPayload('1.2.0', releaseNotes(changelog, '1.2.0'), false);
  assert.match(late.embeds[0].description, /It'll be on CurseForge shortly/);
});

test('very long notes stop at a whole bullet, within Discord\'s limit', () => {
  const notes = [{ title: 'Added', items: Array.from({ length: 200 }, (_, i) => `Feature ${i} with a longer description to fill the space.`) }];
  const { description } = discordPayload('2.0.0', notes).embeds[0];
  assert.ok(description.length <= 4096);
  assert.match(description, /…and more in the changelog\./);
  assert.doesNotMatch(description, /Feature 199/);
});
