import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync, SpawnSyncReturns } from 'node:child_process';

const CLI_PATH = path.resolve('bin/ltui');
const MOCK_CLIENT = path.resolve('dist/test-utils/mockLinearClient.js');

interface EnvContext {
  baseDir: string;
  configDir: string;
  workDir: string;
}

function createContext(): EnvContext {
  const baseDir = mkdtempSync(path.join(os.tmpdir(), 'ltui-regression-'));
  const configDir = path.join(baseDir, 'config');
  const workDir = path.join(baseDir, 'workspace');
  mkdirSync(configDir, { recursive: true });
  mkdirSync(workDir, { recursive: true });
  return { baseDir, configDir, workDir };
}

function cleanupContext(ctx: EnvContext): void {
  rmSync(ctx.baseDir, { recursive: true, force: true });
}

function runCli(ctx: EnvContext, args: string[], extraEnv: Record<string, string> = {}): SpawnSyncReturns<string> {
  return spawnSync('node', [CLI_PATH, ...args], {
    cwd: ctx.workDir,
    encoding: 'utf-8',
    env: {
      ...process.env,
      LTUI_CONFIG_DIR: ctx.configDir,
      LINEAR_API_KEY: 'lin_api_test',
      LTUI_TEST_CLIENT_MODULE: MOCK_CLIENT,
      ...extraEnv,
    },
  });
}

function assertOk(result: SpawnSyncReturns<string>, message: string): void {
  assert.equal(result.status, 0, `${message}: ${result.stderr || result.stdout}`);
}

function ensureLtuiDefaults(ctx: EnvContext): void {
  const defaults = {
    profile: 'test',
    teamKey: 'ENG',
    projectId: 'proj-1',
    defaultIssueState: 'Todo',
    defaultLabels: ['bug'],
    defaultAssignee: 'me',
  };
  writeFileSync(path.join(ctx.workDir, '.ltui.json'), JSON.stringify(defaults, null, 2));
}

function expectOutput(result: SpawnSyncReturns<string>, text: string): void {
  assert.ok(result.stdout.includes(text), `expected output to include '${text}' but got\n${result.stdout}`);
}

function expectPureJsonOutput(result: SpawnSyncReturns<string>, commandLabel: string): unknown {
  assertOk(result, commandLabel);
  assert.equal(result.stderr.trim(), '', `${commandLabel}: expected no stderr but got\n${result.stderr}`);
  const trimmed = result.stdout.trim();
  assert.notEqual(trimmed.length, 0, `${commandLabel}: expected JSON stdout`);
  const first = trimmed[0];
  assert.ok(first === '{' || first === '[', `${commandLabel}: stdout must start with JSON token`);
  return JSON.parse(trimmed);
}

test('json mode emits pure JSON suitable for jq parsing', () => {
  const ctx = createContext();
  ensureLtuiDefaults(ctx);
  try {
    let result = runCli(ctx, ['--format', 'json', 'issues', 'view', 'ENG-1']);
    const issue = expectPureJsonOutput(result, 'issues view json') as Record<string, unknown>;
    assert.equal(issue.identifier, 'ENG-1');
    assert.ok(!result.stdout.includes('ISSUE_DETAIL'));

    result = runCli(ctx, ['--format', 'json', 'teams', 'view', 'ENG']);
    const team = expectPureJsonOutput(result, 'teams view json') as Record<string, unknown>;
    assert.equal(team.key, 'ENG');
    assert.ok(Array.isArray(team.states));
    assert.ok(!result.stdout.includes('TEAM_DETAIL'));

    result = runCli(ctx, ['--format', 'json', 'auth', 'list']);
    const profiles = expectPureJsonOutput(result, 'auth list json') as {
      meta: { count: number };
      rows: unknown[];
    };
    assert.ok(Array.isArray(profiles.rows));
    assert.ok(profiles.meta.count >= 0);
  } finally {
    cleanupContext(ctx);
  }
});

test('auth commands operate end-to-end', () => {
  const ctx = createContext();
  try {
    let result = runCli(ctx, ['auth', 'add', '--profile', 'test', '--workspace', 'demo'], {
      LINEAR_API_KEY: 'lin_api_auth',
    });
    assertOk(result, 'auth add');
    result = runCli(ctx, ['auth', 'list']);
    assertOk(result, 'auth list');
    expectOutput(result, 'test\tdemo');
    result = runCli(ctx, ['auth', 'test', '--profile', 'test']);
    assertOk(result, 'auth test');
    result = runCli(ctx, ['auth', 'remove', '--profile', 'test']);
    assertOk(result, 'auth remove');
  } finally {
    cleanupContext(ctx);
  }
});

test('issues commands including relationships succeed', () => {
  const ctx = createContext();
  ensureLtuiDefaults(ctx);
  try {
    let result = runCli(ctx, ['issues', 'list', '--team', 'ENG']);
    assertOk(result, 'issues list');
    expectOutput(result, 'identifier');

    result = runCli(ctx, ['issues', 'view', 'ENG-1', '--include-comments', '--include-history']);
    assertOk(result, 'issues view');
    expectOutput(result, 'ISSUE_DETAIL');

    result = runCli(ctx, ['--format', 'json', 'issues', 'view', 'ENG-1']);
    assertOk(result, 'issues view json');
    const issueViewJson = JSON.parse(result.stdout.trim());
    assert.equal(issueViewJson.identifier, 'ENG-1');
    assert.equal(issueViewJson.state, 'Todo');
    assert.equal(issueViewJson.url, 'https://linear.app/issue/ENG-1');
    assert.ok(!result.stdout.includes('ISSUE_DETAIL'));

    result = runCli(ctx, [
      '--format',
      'json',
      '--fields',
      'identifier,url,state',
      'issues',
      'view',
      'ENG-1',
    ]);
    assertOk(result, 'issues view json selected fields');
    const issueFieldsJson = JSON.parse(result.stdout.trim());
    assert.deepEqual(Object.keys(issueFieldsJson).sort(), ['identifier', 'state', 'url']);
    assert.equal(issueFieldsJson.identifier, 'ENG-1');

    result = runCli(ctx, ['issues', 'attachments', 'ENG-1', '--only-images']);
    assertOk(result, 'issues attachments');
    expectOutput(result, 'sourceType');

    result = runCli(ctx, ['--format', 'json', '--limit', '1', 'issues', 'attachments', 'ENG-1']);
    assertOk(result, 'issues attachments paginated first page');
    const pageOne = JSON.parse(result.stdout.trim());
    assert.equal(pageOne.meta.count, 1);
    assert.equal(pageOne.rows.length, 1);
    assert.equal(pageOne.meta.cursorNext, 'cursor:0');
    assert.equal(pageOne.meta.cursorPrev, '');

    result = runCli(ctx, [
      '--format',
      'json',
      '--limit',
      '1',
      '--cursor',
      'cursor:0',
      'issues',
      'attachments',
      'ENG-1',
    ]);
    assertOk(result, 'issues attachments paginated second page');
    const pageTwo = JSON.parse(result.stdout.trim());
    assert.equal(pageTwo.meta.count, 1);
    assert.equal(pageTwo.rows.length, 1);
    assert.equal(pageTwo.meta.cursorNext, 'cursor:1');
    assert.equal(pageTwo.meta.cursorPrev, 'cursor:1');

    result = runCli(ctx, [
      '--format',
      'json',
      '--limit',
      '1',
      '--cursor',
      'cursor:1',
      'issues',
      'attachments',
      'ENG-1',
    ]);
    assertOk(result, 'issues attachments paginated third page');
    const pageThree = JSON.parse(result.stdout.trim());
    assert.equal(pageThree.meta.count, 1);
    assert.equal(pageThree.rows.length, 1);
    assert.equal(pageThree.meta.cursorNext, '');
    assert.equal(pageThree.meta.cursorPrev, 'cursor:2');

    result = runCli(ctx, [
      'issues',
      'create',
      '--team',
      'ENG',
      '--project',
      'proj-1',
      '--title',
      'Regression Issue',
      '--description',
      'Created via regression test',
      '--state',
      'Todo',
      '--label',
      'bug',
      '--assignee',
      'me',
      '--priority',
      '2',
    ]);
    assertOk(result, 'issues create');
    expectOutput(result, 'ISSUE_CREATED');

    result = runCli(ctx, [
      'issues',
      'update',
      'ENG-1',
      '--title',
      'Updated title',
      '--state',
      'In Progress',
      '--add-label',
      'backend',
      '--remove-label',
      'bug',
      '--assignee',
      'alice@example.com',
      '--priority',
      '1',
      '--estimate',
      '3',
      '--due',
      '2024-12-31',
    ]);
    assertOk(result, 'issues update');
    expectOutput(result, 'ISSUE_UPDATED');

    result = runCli(ctx, ['issues', 'comment', 'ENG-1', '--body', 'Looks good']);
    assertOk(result, 'issues comment');
    expectOutput(result, 'COMMENT_CREATED');

    result = runCli(ctx, [
      'issues',
      'link',
      'ENG-1',
      '--url',
      'https://example.com',
      '--title',
      'Example',
      '--branch',
      'main',
      '--commit',
      'deadbeef',
    ]);
    assertOk(result, 'issues link');
    expectOutput(result, 'LINK_ATTACHED');

    result = runCli(ctx, ['issues', 'relate', 'ENG-2', '--parent', 'ENG-1']);
    assertOk(result, 'issues relate');
    expectOutput(result, 'RELATIONSHIP_UPDATED');

    result = runCli(ctx, ['issues', 'block', 'ENG-1', '--blocked-by', 'ENG-2']);
    assertOk(result, 'issues block');
    expectOutput(result, 'RELATIONSHIP_UPDATED');

    result = runCli(ctx, ['issues', 'saved', 'add', '--name', 'default', '--search', 'bug']);
    assertOk(result, 'issues saved add');

    result = runCli(ctx, ['issues', 'saved', 'list']);
    assertOk(result, 'issues saved list');
    expectOutput(result, 'default');

    result = runCli(ctx, ['issues', 'saved', 'remove', '--name', 'default']);
    assertOk(result, 'issues saved remove');
  } finally {
    cleanupContext(ctx);
  }
});

test('team and project commands run', () => {
  const ctx = createContext();
  ensureLtuiDefaults(ctx);
  try {
    let result = runCli(ctx, ['teams', 'list']);
    assertOk(result, 'teams list');
    expectOutput(result, 'Engineering');

    result = runCli(ctx, ['teams', 'view', 'ENG']);
    assertOk(result, 'teams view');
    expectOutput(result, 'TEAM_DETAIL');

    result = runCli(ctx, ['--format', 'json', 'teams', 'view', 'ENG']);
    assertOk(result, 'teams view json');
    const teamViewJson = JSON.parse(result.stdout.trim());
    assert.equal(teamViewJson.key, 'ENG');
    assert.ok(Array.isArray(teamViewJson.states));
    assert.ok(teamViewJson.states.length > 0);
    assert.ok(!result.stdout.includes('TEAM_DETAIL'));

    result = runCli(ctx, ['projects', 'list', '--team', 'ENG']);
    assertOk(result, 'projects list');

    result = runCli(ctx, ['projects', 'view', 'proj-1']);
    assertOk(result, 'projects view');

    result = runCli(ctx, [
      'projects',
      'align',
      'proj-1',
      '--profile',
      'test',
      '--team',
      'ENG',
      '--state',
      'Todo',
      '--label',
      'bug',
      '--assignee',
      'me',
    ]);
    assertOk(result, 'projects align');
    expectOutput(result, 'PROJECT_ALIGNED');
  } finally {
    cleanupContext(ctx);
  }
});

test('cycles, labels, and users commands', () => {
  const ctx = createContext();
  ensureLtuiDefaults(ctx);
  try {
    let result = runCli(ctx, ['cycles', '--team', 'ENG']);
    assertOk(result, 'cycles list');

    result = runCli(ctx, ['labels', '--team', 'ENG']);
    assertOk(result, 'labels list');

    result = runCli(ctx, ['users', '--active-only']);
    assertOk(result, 'users list');
  } finally {
    cleanupContext(ctx);
  }
});

test('documents, roadmaps, milestones, and notifications', () => {
  const ctx = createContext();
  ensureLtuiDefaults(ctx);
  try {
    let result = runCli(ctx, ['documents', 'list', '--project', 'proj-1']);
    assertOk(result, 'documents list');

    result = runCli(ctx, ['documents', 'view', 'doc-1', '--max-content-chars', '10']);
    assertOk(result, 'documents view');
    expectOutput(result, 'DOCUMENT_DETAIL');

    result = runCli(ctx, ['roadmaps', 'list']);
    assertOk(result, 'roadmaps list');

    result = runCli(ctx, ['roadmaps', 'view', 'roadmap-1']);
    assertOk(result, 'roadmaps view');

    result = runCli(ctx, ['milestones', 'list', '--project', 'proj-1']);
    assertOk(result, 'milestones list');

    result = runCli(ctx, ['milestones', 'view', 'milestone-1']);
    assertOk(result, 'milestones view');

    result = runCli(ctx, ['notifications', '--unread-only']);
    assertOk(result, 'notifications');
  } finally {
    cleanupContext(ctx);
  }
});
