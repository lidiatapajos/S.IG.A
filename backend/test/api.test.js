import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { openDatabase } from '../src/database.js';
import { seedDemo } from '../src/seed.js';
import { createApp } from '../src/app.js';

const token = 'test-only-token-with-at-least-32-characters';
let db, server, base;
before(async () => {
  db = openDatabase();
  seedDemo(db);
  server = createApp({ db, adminToken: token }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(async () => {
  server.close();
  await once(server, 'close');
  db.close();
});
const request = (path, options) => fetch(`${base}${path}`, options);
const write = (method, body) => ({ method,
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  ...(body === undefined ? {} : { body: JSON.stringify(body) }),
});
const point = () => ({ nome: 'Ponto criado pelo teste', endereco: 'Endereço de teste, 10',
  categoria_id: 1, bairro_id: 1, horario: 'Seg a Sex, 8h às 12h',
  latitude: -1.4558, longitude: -48.4788, demonstrativo: true });

test('catálogos correspondem ao conteúdo necessário para as telas', async () => {
  for (const [resource, expected] of [['bairros', 19], ['categorias', 3], ['residuos', 4], ['dicas', 3]]) {
    const response = await request(`/${resource}`);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).data.length, expected);
  }
  assert.equal((await (await request('/health')).json()).status, 'ok');
});
test('busca ignora acentos e filtros combinam categoria e bairro', async () => {
  const rows = (await (await request('/ecopontos?busca=nazare&categoria=Oleo')).json()).data;
  assert.equal(rows.length, 1);
  assert.equal(rows[0].categoria, 'Oleo');
  assert.equal(rows[0].demonstrativo, true);
  assert.equal((await (await request(`/ecopontos?bairro_id=${rows[0].bairro_id}`)).json()).total, 2);
  assert.equal((await (await request('/bairros?busca=sao')).json()).data[0].nome, 'São Brás');
});
test('distância zero, ordem e raio usam as coordenadas informadas', async () => {
  const rows = (await (await request('/ecopontos?latitude=-1.4558&longitude=-48.4788')).json()).data;
  assert.equal(rows[0].distancia_km, 0);
  assert.ok(rows.every((row, i) => i === 0 || row.distancia_km >= rows[i - 1].distancia_km));
  assert.equal((await (await request('/ecopontos?latitude=-1.4558&longitude=-48.4788&raio_km=0')).json()).total, 1);
});
test('consultas inválidas não viram resultados plausíveis', async () => {
  for (const query of ['latitude=0', 'raio_km=5', 'latitude=91&longitude=0',
    'latitude=&longitude=0', 'latitude=abc&longitude=0', 'bairro_id=1.2', 'busca=a&busca=b']) {
    assert.equal((await request(`/ecopontos?${query}`)).status, 400, query);
  }
  assert.equal((await request('/ecopontos/xyz')).status, 400);
  assert.equal((await request('/ecopontos/999999')).status, 404);
});
test('escrita exige credencial e catálogo permanece público', async () => {
  for (const method of ['POST', 'PUT', 'DELETE']) {
    const path = method === 'POST' ? '/ecopontos' : '/ecopontos/1';
    assert.equal((await request(path, { method })).status, 401);
    assert.equal((await request(path, { method, headers: { Authorization: 'Bearer invalid' } })).status, 401);
  }
  const unconfigured = createApp({ db }).listen(0, '127.0.0.1');
  await once(unconfigured, 'listening');
  try {
    const response = await fetch(`http://127.0.0.1:${unconfigured.address().port}/api/ecopontos`, { method: 'POST' });
    assert.equal(response.status, 503);
  } finally { unconfigured.close(); await once(unconfigured, 'close'); }
});
test('CRUD persiste alterações e não perde o marcador de demonstração ao editar', async () => {
  let response = await request('/ecopontos', write('POST', point()));
  assert.equal(response.status, 201);
  const created = (await response.json()).data;
  assert.ok(created.id > 4);
  const updated = { ...point(), nome: 'Ponto atualizado' };
  delete updated.demonstrativo;
  response = await request(`/ecopontos/${created.id}`, write('PUT', updated));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).data.demonstrativo, true);
  assert.equal((await (await request(`/ecopontos/${created.id}`)).json()).data.nome, updated.nome);
  assert.equal((await request(`/ecopontos/${created.id}`, write('DELETE'))).status, 204);
  assert.equal((await request(`/ecopontos/${created.id}`)).status, 404);
});
test('campos, referências e JSON inválidos são rejeitados sem modificar o banco', async () => {
  for (const overrides of [{ latitude: 100 }, { longitude: null }, { bairro_id: 99999 },
    { categoria_id: '1' }, { nome: '' }, { demonstrativo: 'true' }, { admin: true }]) {
    const response = await request('/ecopontos', write('POST', { ...point(), ...overrides }));
    assert.equal(response.status, 400, JSON.stringify(overrides));
  }
  assert.equal((await request('/ecopontos', { ...write('POST'), body: '{broken' })).status, 400);
  assert.equal((await request('/ecopontos', { method: 'POST', headers: { Authorization: `Bearer ${token}` }, body: '{}' })).status, 415);
  const duplicate = { ...point(), nome: 'Ecoponto Nazaré (exemplo)' };
  assert.equal((await request('/ecopontos', write('POST', duplicate))).status, 409);
  assert.equal(db.prepare('SELECT count(*) AS count FROM ecopontos').get().count, 4);
});
test('CORS permite a origem local e recusa sites não autorizados', async () => {
  const accepted = await request('/ecopontos', { method: 'OPTIONS', headers: { Origin: 'http://localhost:8080' } });
  assert.equal(accepted.status, 204);
  assert.equal(accepted.headers.get('access-control-allow-origin'), 'http://localhost:8080');
  assert.equal((await request('/ecopontos', { headers: { Origin: 'https://example.invalid' } })).status, 403);
  const production = createApp({ db, environment: 'production', corsOrigins: ['https://siga.example'] }).listen(0, '127.0.0.1');
  await once(production, 'listening');
  try {
    const url = `http://127.0.0.1:${production.address().port}/api/health`;
    assert.equal((await fetch(url, { headers: { Origin: 'http://localhost:8080' } })).status, 403);
    assert.equal((await fetch(url, { headers: { Origin: 'https://siga.example' } })).status, 200);
  } finally { production.close(); await once(production, 'close'); }
});
test('seed é repetível e banco em disco mantém alterações após reinício', () => {
  const dir = mkdtempSync(join(tmpdir(), 'siga-test-'));
  const path = join(dir, 'siga.db');
  let persistent = openDatabase(path);
  try {
    seedDemo(persistent);
    persistent.prepare('UPDATE ecopontos SET horario=? WHERE id=1').run('Horário atualizado');
    seedDemo(persistent);
    persistent.close();
    persistent = openDatabase(path);
    assert.equal(persistent.prepare('SELECT horario FROM ecopontos WHERE id=1').get().horario, 'Horário atualizado');
    assert.equal(persistent.prepare('SELECT count(*) AS count FROM ecopontos').get().count, 4);
    assert.throws(() => persistent.prepare('UPDATE ecopontos SET categoria_id=999 WHERE id=1').run());
  } finally { persistent.close(); rmSync(dir, { recursive: true }); }
});
