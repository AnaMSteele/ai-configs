import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import { spawn, spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { claimCommentsSchema, createCommentSchema, registerPlanSchema } from '../schemas.js';
import { renderPlan } from '../render/render.js';
import { PlanReviewStore } from '../storage/database.js';
import { createApp } from '../server/app.js';
import { findImageSources } from '../htmlImages.js';
import { domAnchor, registeredApp, sampleHtml, sampleRegisterPayload, tempDbPath } from './helpers.js';

test('schemas validate locked registration, comment, and claim contracts', () => {
  const register = registerPlanSchema.parse(sampleRegisterPayload());
  assert.equal(register.updateMode, 'upsert');

  const comment = createCommentSchema.parse({
    versionId: 'ver_1',
    body: 'This section needs more acceptance detail.',
    anchorType: 'dom',
    anchor: domAnchor(),
    createdBy: { displayName: '' }
  });
  assert.equal(comment.anchorType, 'dom');

  assert.equal(claimCommentsSchema.parse({ mode: 'one' }).leaseSeconds, 300);
  assert.throws(() => claimCommentsSchema.parse({ mode: 'bulk', limit: 0 }));
});

test('renderer strips active content, rewrites images, and adds deterministic node ids', () => {
  const output = renderPlan(sampleRegisterPayload());

  assert.equal(output.warnings.some(item => item.code === 'blocked_script'), true);
  assert.equal(output.renderedHtml.includes('<script>'), false);
  assert.equal(output.renderedHtml.includes('src="/assets/'), true);
  assert.equal(output.renderedHtml.includes('data-plan-image-hash='), true);
  assert.equal(output.renderedHtml.includes('data-plan-node-id="phase-p1"'), true);

  const repeated = renderPlan(sampleRegisterPayload({ html: sampleHtml() }));
  assert.equal(output.renderedHtml, repeated.renderedHtml);

  const external = renderPlan(sampleRegisterPayload({
    html: '<!doctype html><html><body><img src="https://example.com/track.png" alt="external"></body></html>'
  }));
  assert.equal(external.warnings.some(item => item.code === 'blocked_external_image'), true);
  assert.equal(external.renderedHtml.includes('src="https://example.com/track.png"'), false);

  const unquotedImage = renderPlan(sampleRegisterPayload({
    html: '<!doctype html><html><body><img src=diagram.png alt=Diagram></body></html>',
    fileHash: 'unquoted-image'
  }));
  assert.equal(unquotedImage.renderedHtml.includes('src="/assets/'), true);
  assert.equal(unquotedImage.renderedHtml.includes('data-plan-image-source="diagram.png"'), true);
  assert.deepEqual(findImageSources('<img src=diagram.png><img src="./two.png"><img alt=x src=\'three.png\'><img data-src="placeholder.png" alt="preview src=placeholder.png" src="actual.png">'), [
    'diagram.png',
    './two.png',
    'three.png',
    'actual.png'
  ]);

  const lazyImage = renderPlan(sampleRegisterPayload({
    html: '<!doctype html><html><body><img data-src="placeholder.png" alt="lazy preview src=placeholder.png" src="diagram.png"></body></html>',
    fileHash: 'lazy-image'
  }));
  assert.equal(lazyImage.renderedHtml.includes('data-src="placeholder.png"'), true);
  assert.equal(lazyImage.renderedHtml.includes('alt="lazy preview src=placeholder.png"'), true);
  assert.equal(lazyImage.renderedHtml.includes('data-plan-image-source="diagram.png"'), true);

  const quotedAttributeImage = renderPlan(sampleRegisterPayload({
    html: '<!doctype html><html><body><img alt=\'preview src="diagram.png"\' src="diagram.png"></body></html>',
    fileHash: 'quoted-attribute-image'
  }));
  assert.equal(quotedAttributeImage.renderedHtml.includes('data-plan-image-source="diagram.png"'), true);
  assert.equal(quotedAttributeImage.renderedHtml.includes('alt="preview src=&quot;/assets/'), false);

  const unsafeLink = renderPlan(sampleRegisterPayload({
    html: '<!doctype html><html><body><a href="data:text/html,bad">bad link</a><img src="data:image/png;base64,abc" alt="inline"></body></html>'
  }));
  assert.equal(unsafeLink.renderedHtml.includes('href="data:text/html,bad"'), false);
  assert.equal(unsafeLink.renderedHtml.includes('src="data:image/png;base64,abc"'), true);

  assert.throws(
    () => renderPlan(sampleRegisterPayload({ html: '<!doctype html><html><body><div id="x" id="y"></div></body></html>', fileHash: 'invalid-html' })),
    /Plan HTML could not be parsed safely/
  );
});

test('registration upserts by default and creates a distinct plan for new-thread', async () => {
  const { app } = await registeredApp('new-thread');
  try {
    const upsert = await app.inject({
      method: 'POST',
      url: '/api/plans/register',
      payload: sampleRegisterPayload()
    });
    assert.equal(upsert.statusCode, 200);

    const newThread = await app.inject({
      method: 'POST',
      url: '/api/plans/register',
      payload: sampleRegisterPayload({ updateMode: 'new-thread' })
    });
    assert.equal(newThread.statusCode, 200);

    const plans = await app.inject({ method: 'GET', url: '/api/plans' });
    assert.equal(plans.statusCode, 200);
    assert.equal(plans.json().data.plans.length, 2);
    assert.notEqual(newThread.json().data.planId, upsert.json().data.planId);
  } finally {
    await app.close();
  }
});

test('HTTP API reports schema errors as validation_failed and renders canonical escaped plan ids', async () => {
  const app = createApp({ dbPath: tempDbPath('validation-shell') });
  try {
    const invalid = await app.inject({
      method: 'POST',
      url: '/api/plans/register',
      payload: { html: '<html></html>' }
    });
    assert.equal(invalid.statusCode, 400);
    assert.equal(invalid.json().error.code, 'validation_failed');
    assert.match(invalid.json().error.nextAction, /documented endpoint contract/);

    const unsafeSlug = 'bad" onmouseover="alert(1)';
    const registered = await app.inject({
      method: 'POST',
      url: '/api/plans/register',
      payload: sampleRegisterPayload({ slug: unsafeSlug, fileHash: 'unsafe-slug' })
    });
    assert.equal(registered.statusCode, 200);
    const planId = registered.json().data.planId;

    const shell = await app.inject({
      method: 'GET',
      url: `/p/${encodeURIComponent(unsafeSlug)}`
    });
    assert.equal(shell.statusCode, 200);
    assert.match(shell.body, new RegExp(`data-plan-id="${planId}"`));
    assert.match(shell.body, new RegExp(`src="/render/${planId}"`));
    assert.doesNotMatch(shell.body, /onmouseover/);
  } finally {
    await app.close();
  }
});

test('plan versions are distinct for the same content on a different branch or commit', () => {
  const store = new PlanReviewStore(tempDbPath('version-key'));
  try {
    const payload = sampleRegisterPayload();
    const rendered = renderPlan(payload);
    const first = store.registerPlan(payload, rendered.renderedHtml, rendered.warnings);
    const second = store.registerPlan(
      { ...payload, branch: 'feature/review', commitSha: 'def456' },
      rendered.renderedHtml,
      rendered.warnings
    );
    assert.equal(first.planId, second.planId);
    assert.notEqual(first.versionId, second.versionId);
  } finally {
    store.close();
  }
});

test('HTTP API registers plans, creates comments, claims, acks, resolves, and polls events', async () => {
  const { app, planId, versionId } = await registeredApp('contracts');
  try {
    const index = await app.inject({ method: 'GET', url: '/api/plans' });
    assert.equal(index.statusCode, 200);
    assert.equal(index.json().data.plans.length, 1);

    const planMeta = await app.inject({ method: 'GET', url: `/api/plans/${planId}` });
    assert.equal(planMeta.statusCode, 200);
    assert.equal(planMeta.json().data.assets.length, 1);
    assert.equal(planMeta.json().data.assets[0].sourceUrl, './diagram.png');
    assert.equal(planMeta.json().data.assets[0].contentType, 'image/png');
    const planAsset = await app.inject({ method: 'GET', url: `/assets/${planMeta.json().data.assets[0].id}` });
    assert.equal(planAsset.statusCode, 200);
    assert.equal(planAsset.headers['cache-control'], 'public, max-age=31536000, immutable');

    const html2canvas = await app.inject({ method: 'GET', url: '/vendor/html2canvas.js' });
    assert.equal(html2canvas.statusCode, 200);
    assert.match(html2canvas.body, /html2canvas/);
    const finder = await app.inject({ method: 'GET', url: '/vendor/finder.js' });
    assert.equal(finder.statusCode, 200);
    assert.match(finder.body, /export function finder/);
    const washi = await app.inject({ method: 'GET', url: '/vendor/washi.js' });
    assert.equal(washi.statusCode, 200);
    assert.match(washi.body, /export \{\s*Washi\s*\}/);

    const commentResponse = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments`,
      payload: {
        versionId,
        body: 'Add the agent watch contract here.',
        anchorType: 'dom',
        anchor: domAnchor(),
        markerScreenshot: {
          contentType: 'image/png',
          bytesBase64: Buffer.from('screen').toString('base64'),
          width: 20,
          height: 10,
          captureRect: { x: 0, y: 0, width: 20, height: 10 },
          viewport: { width: 1280, height: 800 }
        },
        createdBy: { displayName: 'Reviewer' },
        clientMutationId: 'comment-1'
      }
    });
    assert.equal(commentResponse.statusCode, 200);
    const comment = commentResponse.json().data.comment;
    assert.equal(comment.status, 'pending');
    assert.equal(comment.sequence, 1);
    assert.equal(comment.conversationPayload.type, 'browser.comment.v1');
    const commentAsset = await app.inject({ method: 'GET', url: `/comment-assets/${comment.screenshotAssetId}` });
    assert.equal(commentAsset.statusCode, 200);
    assert.equal(commentAsset.headers['cache-control'], 'public, max-age=31536000, immutable');

    const wrongVersion = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments`,
      payload: {
        versionId: 'ver_missing',
        body: 'wrong version',
        anchorType: 'dom',
        anchor: domAnchor()
      }
    });
    assert.equal(wrongVersion.statusCode, 400);
    assert.equal(wrongVersion.json().error.code, 'validation_failed');

    const ackWithoutClaim = await app.inject({
      method: 'POST',
      url: `/api/comments/${comment.id}/ack`,
      payload: { claimId: 'missing', action: { responseSummary: 'no claim' } }
    });
    assert.equal(ackWithoutClaim.statusCode, 409);
    assert.equal(ackWithoutClaim.json().error.code, 'claim_required');

    const claimResponse = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments/claim`,
      headers: { 'x-agent-id': 'agent-a' },
      payload: { mode: 'one' }
    });
    assert.equal(claimResponse.statusCode, 200);
    const claimed = claimResponse.json().data.claimed[0];
    assert.equal(claimed.status, 'claimed');

    const resolveClaimed = await app.inject({
      method: 'POST',
      url: `/api/comments/${comment.id}/resolve`,
      payload: { resolutionNote: 'skip ack' }
    });
    assert.equal(resolveClaimed.statusCode, 409);
    assert.equal(resolveClaimed.json().error.code, 'invalid_state');

    const ackResponse = await app.inject({
      method: 'POST',
      url: `/api/comments/${comment.id}/ack`,
      payload: {
        claimId: claimed.claim.id,
        action: { responseSummary: 'Updated the plan.', changedFiles: ['thoughts/plans/sample-plan.html'] }
      }
    });
    assert.equal(ackResponse.statusCode, 200);
    assert.equal(ackResponse.json().data.comment.status, 'acknowledged');

    const releaseAcknowledged = await app.inject({
      method: 'POST',
      url: `/api/comments/${comment.id}/release`,
      payload: { claimId: claimed.claim.id }
    });
    assert.equal(releaseAcknowledged.statusCode, 409);
    assert.equal(releaseAcknowledged.json().error.code, 'invalid_state');

    const resolveResponse = await app.inject({
      method: 'POST',
      url: `/api/comments/${comment.id}/resolve`,
      payload: { resolutionNote: 'done' }
    });
    assert.equal(resolveResponse.statusCode, 200);
    assert.equal(resolveResponse.json().data.comment.status, 'resolved');

    const eventsBeforeRetry = await app.inject({ method: 'GET', url: `/api/plans/${planId}/events/poll?afterSequence=0&mode=queue` });
    const lastQueueSequence = eventsBeforeRetry.json().data.events.at(-1).sequence;

    const duplicateCreate = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments`,
      payload: {
        versionId,
        body: 'Retry after resolution.',
        anchorType: 'dom',
        anchor: domAnchor(),
        clientMutationId: 'comment-1'
      }
    });
    assert.equal(duplicateCreate.statusCode, 200);
    assert.equal(duplicateCreate.json().data.created, false);
    assert.equal(duplicateCreate.json().data.comment.id, comment.id);
    assert.equal(duplicateCreate.json().data.event.eventType, 'comment.created');
    assert.equal(duplicateCreate.json().data.event.commentId, comment.id);

    const retryEvents = await app.inject({
      method: 'GET',
      url: `/api/plans/${planId}/events/poll?afterSequence=${lastQueueSequence}&mode=queue`
    });
    assert.equal(retryEvents.statusCode, 200);
    assert.deepEqual(retryEvents.json().data.events, []);

    const events = await app.inject({ method: 'GET', url: `/api/plans/${planId}/events/poll?afterSequence=0&mode=queue` });
    assert.equal(events.statusCode, 200);
    assert.deepEqual(
      events.json().data.events.map((event: { eventType: string }) => event.eventType),
      ['comment.created', 'comment.claimed', 'comment.acknowledged', 'comment.resolved']
    );
  } finally {
    await app.close();
  }
});

test('lease expiry emits a queue release event during polling', async () => {
  const { app, planId, versionId } = await registeredApp('lease-expiry');
  try {
    const commentResponse = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments`,
      payload: {
        versionId,
        body: 'Claim should expire.',
        anchorType: 'dom',
        anchor: domAnchor()
      }
    });
    assert.equal(commentResponse.statusCode, 200);

    const claimResponse = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments/claim`,
      payload: { mode: 'one', leaseSeconds: 1 }
    });
    assert.equal(claimResponse.statusCode, 200);
    const claim = claimResponse.json().data.claimed[0];

    await new Promise(resolve => setTimeout(resolve, 1100));
    const events = await app.inject({ method: 'GET', url: `/api/plans/${planId}/events/poll?afterSequence=0&mode=queue` });
    assert.equal(events.statusCode, 200);
    assert.deepEqual(
      events.json().data.events.map((event: { eventType: string }) => event.eventType),
      ['comment.created', 'comment.claimed', 'comment.released']
    );

    const comments = await app.inject({ method: 'GET', url: `/api/plans/${planId}/comments` });
    assert.equal(comments.json().data.comments[0].status, 'pending');

    const expiredAck = await app.inject({
      method: 'POST',
      url: `/api/comments/${claim.id}/ack`,
      payload: { claimId: claim.claim.id, action: { responseSummary: 'too late' } }
    });
    assert.equal(expiredAck.statusCode, 409);
    assert.equal(expiredAck.json().error.code, 'claim_required');
  } finally {
    await app.close();
  }
});

test('CLI watch polling fallback keeps waiting for once until timeout or event', async () => {
  let polls = 0;
  const server = http.createServer((request, response) => {
    if (request.url?.startsWith('/api/plans/plan_1/events/poll')) {
      polls += 1;
      response.setHeader('content-type', 'application/json');
      response.end(JSON.stringify({
        ok: true,
        data: {
              events: polls >= 2 ? [{ sequence: 1, eventType: 'comment.created', payload: { eventType: 'comment.created', sequence: 1, comment: { conversationPayload: { type: 'browser.comment.v1', commentId: 'cmt_1', evidence: { reviewUrl: '/p/plan_1' } } } } }] : [],
          latestSequence: polls >= 2 ? 1 : 0,
          retryAfterMs: 25
        }
      }));
      return;
    }
    if (request.url?.startsWith('/api/plans/plan_1/events')) {
      response.statusCode = 503;
      response.end('sse unavailable');
      return;
    }
    response.statusCode = 404;
    response.end('not found');
  });

  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const conversationOut = path.join('/tmp', `plan-reviewer-conversation-${process.pid}.ndjson`);
  fs.rmSync(conversationOut, { force: true });
  try {
    const address = server.address();
    assert(address && typeof address !== 'string');
    const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
    const result = await new Promise<{ code: number | null; stdout: string; stderr: string }>(resolve => {
      const child = spawn(process.execPath, ['dist/cli.js', 'watch', 'plan_1', '--url', `http://127.0.0.1:${address.port}`, '--once', '--timeout', '1000', '--json', '--conversation-out', conversationOut], {
        cwd: root,
        stdio: ['ignore', 'pipe', 'pipe']
      });
      let stdout = '';
      let stderr = '';
      child.stdout.on('data', chunk => { stdout += chunk; });
      child.stderr.on('data', chunk => { stderr += chunk; });
      child.on('close', code => resolve({ code, stdout, stderr }));
    });

    assert.equal(result.code, 0, result.stderr);
    assert.match(result.stdout, /comment\.created/);
    const conversation = JSON.parse(fs.readFileSync(conversationOut, 'utf8').trim());
    assert.equal(conversation.type, 'browser.comment.v1');
    assert.equal(conversation.evidence.reviewUrl, `http://127.0.0.1:${address.port}/p/plan_1`);
    assert.equal(polls >= 2, true);
  } finally {
    await new Promise<void>(resolve => server.close(() => resolve()));
  }
});

test('CLI release maps to the REST release endpoint', async () => {
  let captured: { method?: string; url?: string; body?: string } = {};
  const server = http.createServer((request, response) => {
    if (request.url === '/api/comments/cmt_1/release') {
      captured = { method: request.method, url: request.url, body: '' };
      request.on('data', chunk => { captured.body += chunk; });
      request.on('end', () => {
        response.setHeader('content-type', 'application/json');
        response.end(JSON.stringify({ ok: true, data: { comment: { id: 'cmt_1', status: 'pending' } } }));
      });
      return;
    }
    response.statusCode = 404;
    response.end('not found');
  });

  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address();
    assert(address && typeof address !== 'string');
    const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
    const result = await new Promise<{ code: number | null; stdout: string; stderr: string }>(resolve => {
      const child = spawn(process.execPath, [
        'dist/cli.js',
        'release',
        'cmt_1',
        '--url',
        `http://127.0.0.1:${address.port}`,
        '--claim',
        'claim_1',
        '--reason',
        'needs-retry',
        '--json'
      ], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
      let stdout = '';
      let stderr = '';
      child.stdout.on('data', chunk => { stdout += chunk; });
      child.stderr.on('data', chunk => { stderr += chunk; });
      child.on('close', code => resolve({ code, stdout, stderr }));
    });

    assert.equal(result.code, 0, result.stderr);
    assert.equal(captured.method, 'POST');
    assert.equal(JSON.parse(captured.body ?? '{}').claimId, 'claim_1');
    assert.equal(JSON.parse(captured.body ?? '{}').reason, 'needs-retry');
    assert.equal(JSON.parse(result.stdout).comment.status, 'pending');
  } finally {
    await new Promise<void>(resolve => server.close(() => resolve()));
  }
});

test('new plan versions remap changed anchors to stale or unmapped', async () => {
  const { app, planId, versionId } = await registeredApp('anchor-remap');
  try {
    const commentResponse = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments`,
      payload: {
        versionId,
        body: 'Old phase disappeared.',
        anchorType: 'dom',
        anchor: domAnchor()
      }
    });
    assert.equal(commentResponse.statusCode, 200);

    const changedTextHtml = '<!doctype html><html><body><main><section id="phase-p1"><h2>Phase 1</h2><p>Different copy remains.</p></section></main></body></html>';
    const staleRegister = await app.inject({
      method: 'POST',
      url: '/api/plans/register',
      payload: sampleRegisterPayload({ html: changedTextHtml, fileHash: 'changed-anchor-text' })
    });
    assert.equal(staleRegister.statusCode, 200);

    const staleComments = await app.inject({ method: 'GET', url: `/api/plans/${planId}/comments` });
    assert.equal(staleComments.json().data.comments[0].anchorState, 'stale');

    const missingHtml = '<!doctype html><html><body><main><section id="different"><h2>Different</h2><p>Nothing remains.</p></section></main></body></html>';
    const missingRegister = await app.inject({
      method: 'POST',
      url: '/api/plans/register',
      payload: sampleRegisterPayload({ html: missingHtml, fileHash: 'changed-anchor-missing' })
    });
    assert.equal(missingRegister.statusCode, 200);

    const unmappedComments = await app.inject({ method: 'GET', url: `/api/plans/${planId}/comments` });
    assert.equal(unmappedComments.json().data.comments[0].anchorState, 'unmapped');
  } finally {
    await app.close();
  }
});

test('index groups plans by repo and sorts API plans by comment activity', async () => {
  const { app, planId, versionId } = await registeredApp('index-activity');
  try {
    const second = await app.inject({
      method: 'POST',
      url: '/api/plans/register',
      payload: sampleRegisterPayload({
        repoKey: 'git@example.com:demo/other.git',
        repoName: 'other',
        remoteUrl: 'git@example.com:demo/other.git',
        rootPath: '/tmp/other',
        planPath: 'thoughts/plans/other.html',
        slug: 'other-plan',
        fileHash: 'other-plan-hash'
      })
    });
    assert.equal(second.statusCode, 200);
    await new Promise(resolve => setTimeout(resolve, 5));

    const commentResponse = await app.inject({
      method: 'POST',
      url: `/api/plans/${planId}/comments`,
      payload: {
        versionId,
        body: 'Activity bump.',
        anchorType: 'dom',
        anchor: domAnchor()
      }
    });
    assert.equal(commentResponse.statusCode, 200);

    const apiIndex = await app.inject({ method: 'GET', url: '/api/plans' });
    assert.equal(apiIndex.json().data.plans[0].plan.id, planId);

    const repoFiltered = await app.inject({ method: 'GET', url: '/api/plans?repoKey=git%40example.com%3Ademo%2Fother.git' });
    assert.equal(repoFiltered.json().data.plans.length, 1);
    assert.equal(repoFiltered.json().data.plans[0].plan.repoName, 'other');

    const queryFiltered = await app.inject({ method: 'GET', url: '/api/plans?q=other&limit=1' });
    assert.equal(queryFiltered.json().data.plans.length, 1);
    assert.equal(queryFiltered.json().data.nextCursor, undefined);

    const paged = await app.inject({ method: 'GET', url: '/api/plans?limit=1' });
    assert.equal(paged.json().data.plans.length, 1);
    assert.equal(paged.json().data.nextCursor, '1');

    const htmlIndex = await app.inject({ method: 'GET', url: '/' });
    assert.match(htmlIndex.body, /class="repo-group"/);
    assert.match(htmlIndex.body, />sample</);
    assert.match(htmlIndex.body, />other</);
  } finally {
    await app.close();
  }
});

test('CLI help is wired through the installed bin entrypoint', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  const result = spawnSync(process.execPath, ['dist/cli.js', '--help'], {
    cwd: root,
    encoding: 'utf8'
  });

  assert.equal(result.status, 0);
  assert.match(result.stdout, /plan-review/);
  assert.match(result.stdout, /watch/);
  assert.match(result.stdout, /ack/);
  assert.match(result.stdout, /resolve/);
  assert.match(result.stdout, /release/);
  assert.match(spawnSync(process.execPath, ['dist/cli.js', 'register', '--help'], { cwd: root, encoding: 'utf8' }).stdout, /--new-thread/);
  assert.match(spawnSync(process.execPath, ['dist/cli.js', 'index', '--help'], { cwd: root, encoding: 'utf8' }).stdout, /--repo-key/);
  assert.match(spawnSync(process.execPath, ['dist/cli.js', 'queue', '--help'], { cwd: root, encoding: 'utf8' }).stdout, /list/);
  assert.match(spawnSync(process.execPath, ['dist/cli.js', 'ack', '--help'], { cwd: root, encoding: 'utf8' }).stdout, /--changed-files/);
  assert.match(spawnSync(process.execPath, ['dist/cli.js', 'resolve', '--help'], { cwd: root, encoding: 'utf8' }).stdout, /--commit/);
  assert.match(spawnSync(process.execPath, ['dist/cli.js', 'release', '--help'], { cwd: root, encoding: 'utf8' }).stdout, /--claim/);
});

test('Homebrew formula locks the daemon service contract', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
  const formula = fs.readFileSync(path.join(root, 'Formula/plan-reviewer.rb'), 'utf8');

  assert.match(formula, /class PlanReviewer < Formula/);
  assert.match(formula, /bin\.install_symlink/);
  assert.match(formula, /"serve", "--host", "0\.0\.0\.0", "--port", "4317"/);
  assert.match(formula, /"\#\{Dir\.home\}\/\.plan-reviewer\/plan-reviewer\.sqlite"/);
  assert.match(formula, /keep_alive true/);
  assert.match(formula, /log_path var\/"log\/plan-reviewer\.log"/);
  assert.match(formula, /error_log_path var\/"log\/plan-reviewer\.err\.log"/);
  assert.match(formula, /brew services stop plan-reviewer/);
  assert.match(formula, /rm -rf ~\/\.plan-reviewer/);
});
