
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { chromium } from 'playwright';
import sharp from 'sharp';
import { openDatabase } from '../src/database.js';
import { createApp } from '../src/app.js';

const db = openDatabase();
const adminToken = 'SIGA-browser-test-' + 'a'.repeat(40);

const server = createApp({ db, adminToken })
  .listen(0, '127.0.0.1');

await once(server, 'listening');

const base = `http://127.0.0.1:${server.address().port}`;
let browser;

try {
  browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox'],
  });

  const page = await browser.newPage({
    viewport: { width: 1280, height: 800 },
  });

  const errors = [];
  page.on('pageerror', error => errors.push(error.message));

  // 1. Testar acesso ao painel
  const adminResponse = await page.goto(`${base}/admin`);
  assert.equal(adminResponse.status(), 200);

  await page.locator('#token').fill(adminToken);
  await page.locator('#connect').click();
  await page.locator('#app-content')
    .waitFor({ state: 'visible' });

  // 2. Criar sessão de rastreamento
  await page.locator('[data-view="tracking"]').first().click();
  await page.locator('#name').fill('SIGA-TESTE-001');
  await page.locator('#create').click();

  await page.locator('#key-modal')
    .waitFor({ state: 'visible' });

  const key = await page.locator('#key').inputValue();

  assert.match(key, /^[0-9a-f-]{36}\.[0-9a-f]{64}$/);

  const [id, trackerToken] = key.split('.');

  await page.locator('#close-modal').click();

  // 3. Simular envio de localização pelo protocolo do APK
  const update = await fetch(
    `${base}/api/rastreamento/${id}/posicao`,
    {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${trackerToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        latitude: -1.45,
        longitude: -48.49,
        precisao: 5,
        capturado_em: Date.now(),
      }),
    }
  );

  assert.equal(update.status, 200);

  const positions = await (
    await fetch(`${base}/api/rastreamento`)
  ).json();

  assert.equal(positions.data.length, 1);
  assert.equal(positions.data[0].latitude, -1.45);

  // 4. Criar uma denúncia com foto
  const png = await sharp({
    create: {
      width: 20,
      height: 20,
      channels: 3,
      background: 'green',
    },
  }).png().toBuffer();

  const created = await fetch(`${base}/api/denuncias`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      categoria: 'entulho',
      descricao: '<script>alert(1)</script>',
      latitude: -1.45,
      longitude: -48.49,
      foto_base64: `data:image/png;base64,${png.toString('base64')}`,
    }),
  });

  assert.equal(created.status, 201);

  const { data: report } = await created.json();

  // 5. Conferir denúncia no painel novo
  await page.locator('[data-view="reports"]').first().click();
  await page.locator('#refresh').click();

  const card = page.locator('#reports .report-card').first();
  await card.waitFor();

  assert.match(
    await card.locator('.report-description').innerText(),
    /<script>alert\(1\)<\/script>/
  );

  // 6. Abrir foto
  await card.getByRole('button', {
    name: 'Ver foto anexada',
  }).click();

  await page.locator('#photo-modal')
    .waitFor({ state: 'visible' });

  await page.waitForFunction(() =>
    document.getElementById('report-photo').naturalWidth > 0
  );

  await page.locator('#close-photo').click();

  // 7. Alterar situação da denúncia
  await card.locator('select').selectOption('em_atendimento');

  await card.getByRole('button', {
    name: 'Salvar',
    exact: true,
  }).click();

  await page.waitForFunction(async protocol => {
    const response = await fetch(
      '/api/denuncias/protocolo/' + protocol
    );

    const result = await response.json();
    return result.data.status === 'em_atendimento';
  }, report.protocolo);

  // 8. Revogar o rastreador
  await page.locator('[data-view="tracking"]').first().click();

  await page.locator('#sessions .session-card')
    .first()
    .getByRole('button', { name: 'Revogar acesso' })
    .click();

  await page.locator('#confirm-revoke').click();

  await page.waitForFunction(() =>
    document.querySelectorAll('#sessions .session-card').length === 0
  );

  const afterRevoke = await (
    await fetch(`${base}/api/rastreamento`)
  ).json();

  assert.equal(afterRevoke.data.length, 0);

  // 9. Verificar interface mobile
  await page.setViewportSize({
    width: 390,
    height: 844,
  });

  assert.equal(
    await page.locator('#mobile-nav').isVisible(),
    true
  );

  // 10. Sair
  await page.locator('#logout').click();

  await page.locator('#login-panel')
    .waitFor({ state: 'visible' });

  assert.equal(await page.locator('#key').inputValue(), '');
  assert.deepEqual(errors, []);

  console.log(
    'PASS: login, autorização, posição, denúncia, ' +
    'foto, status, revogação e layout mobile.'
  );

} finally {
  await browser?.close();

  await new Promise(resolve => server.close(resolve));
  db.close();
}
