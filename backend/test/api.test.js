
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { once } from 'node:events';

import { createApp } from '../src/app.js';
import { openDatabase } from '../src/database.js';

test('API: autenticação e rastreamento', async () => {
  const db = openDatabase();
  const token = 'SIGA-api-test-' + 'b'.repeat(40);

  const server = createApp({ db, adminToken: token })
    .listen(0, '127.0.0.1');

  await once(server, 'listening');

  const base = `http://127.0.0.1:${server.address().port}`;
  const auth = { Authorization: `Bearer ${token}` };

  try {
    // API funcionando
    const health = await fetch(`${base}/api/health`);
    assert.equal(health.status, 200);
    assert.equal((await health.json()).status, 'ok');

    // Painel disponível
    assert.equal(
      (await fetch(`${base}/admin`)).status,
      200
    );

    // Rota web antiga removida
    assert.equal(
      (await fetch(`${base}/rastreador`)).status,
      404
    );

    // Acesso administrativo protegido
    assert.equal(
      (await fetch(`${base}/api/admin/rastreamento`)).status,
      401
    );

    // Criar autorização
    const create = await fetch(
      `${base}/api/admin/rastreamento`,
      {
        method: 'POST',
        headers: {
          ...auth,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ nome: 'SIGA Teste' }),
      }
    );

    assert.equal(create.status, 201);

    const { data: session } = await create.json();
    const [id, trackerToken] = session.chave.split('.');

    assert.equal(id, session.id);

    // Transmitir GPS simulado
    const position = await fetch(
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

    assert.equal(position.status, 200);

    // Consultar rastreamento
    const tracking = await (
      await fetch(`${base}/api/rastreamento`)
    ).json();

    assert.equal(tracking.data.length, 1);
    assert.equal(tracking.data[0].nome, 'SIGA Teste');

    // Revogar autorização
    const remove = await fetch(
      `${base}/api/admin/rastreamento/${id}`,
      {
        method: 'DELETE',
        headers: auth,
      }
    );

    assert.equal(remove.status, 204);

    const after = await (
      await fetch(`${base}/api/rastreamento`)
    ).json();

    assert.deepEqual(after.data, []);

  } finally {
    await new Promise(resolve => server.close(resolve));
    db.close();
  }
});
