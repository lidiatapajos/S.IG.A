import express from 'express';
import { createHash, timingSafeEqual } from 'node:crypto';

const selectPoints = `SELECT e.*, c.codigo AS categoria, c.nome AS categoria_nome,
  b.nome AS bairro, b.cidade, b.uf FROM ecopontos e
  JOIN categorias c ON c.id = e.categoria_id JOIN bairros b ON b.id = e.bairro_id`;
const serialize = (row) => ({ ...row, demonstrativo: Boolean(row.demonstrativo) });
const normalize = (value) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

class ApiError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function idFrom(value) {
  if (!/^[1-9]\d*$/.test(String(value)) || !Number.isSafeInteger(Number(value))) {
    throw new ApiError(400, 'Informe um ID inteiro positivo.');
  }
  return Number(value);
}
function queryText(query, key, max = 120) {
  const value = query[key];
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || value.length > max) throw new ApiError(400, `Parâmetro ${key} inválido.`);
  return value.trim();
}
function queryNumber(query, key, min, max) {
  const value = queryText(query, key, 40);
  if (value === undefined) return undefined;
  const number = Number(value);
  if (!value || !Number.isFinite(number) || number < min || number > max) {
    throw new ApiError(400, `Parâmetro ${key} fora do intervalo permitido.`);
  }
  return number;
}
function pointInput(body, db) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new ApiError(400, 'Envie um objeto JSON.');
  const fields = ['nome', 'endereco', 'categoria_id', 'bairro_id', 'horario', 'latitude', 'longitude', 'demonstrativo'];
  if (Object.keys(body).some((key) => !fields.includes(key))) throw new ApiError(400, 'O JSON contém campos desconhecidos.');
  const input = {};
  for (const [key, min, max] of [['nome', 3, 120], ['endereco', 5, 240], ['horario', 3, 160]]) {
    if (typeof body[key] !== 'string' || body[key].trim().length < min || body[key].trim().length > max) {
      throw new ApiError(400, `${key} deve ter entre ${min} e ${max} caracteres.`);
    }
    input[key] = body[key].trim();
  }
  for (const [key, table] of [['categoria_id', 'categorias'], ['bairro_id', 'bairros']]) {
    if (!Number.isSafeInteger(body[key]) || body[key] < 1 ||
        !db.prepare(`SELECT id FROM ${table} WHERE id = ?`).get(body[key])) {
      throw new ApiError(400, `${key} deve identificar um registro existente.`);
    }
    input[key] = body[key];
  }
  for (const [key, max] of [['latitude', 90], ['longitude', 180]]) {
    if (typeof body[key] !== 'number' || !Number.isFinite(body[key]) || Math.abs(body[key]) > max) {
      throw new ApiError(400, `${key} inválida.`);
    }
    input[key] = body[key];
  }
  if (body.demonstrativo !== undefined && typeof body.demonstrativo !== 'boolean') {
    throw new ApiError(400, 'demonstrativo deve ser true ou false.');
  }
  input.demonstrativo = body.demonstrativo ?? false;
  return input;
}
function distanceKm(lat1, lon1, lat2, lon2) {
  const radians = (degrees) => degrees * Math.PI / 180;
  const a = Math.sin(radians(lat2 - lat1) / 2) ** 2 +
    Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(radians(lon2 - lon1) / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(a)));
}

export function createApp({ db, adminToken = '', environment = 'development', corsOrigins = [] }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('query parser', 'simple');
  app.use((req, res, next) => {
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Cache-Control', 'no-store');
    res.vary('Origin');
    const origin = req.get('Origin');
    if (origin) {
      let local = false;
      try {
        const url = new URL(origin);
        local = ['http:', 'https:'].includes(url.protocol) && ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
      } catch { /* Origens inválidas não são aceitas. */ }
      if (!corsOrigins.includes(origin) && !(environment === 'development' && local)) {
        return next(new ApiError(403, 'Origem não autorizada.'));
      }
      res.set('Access-Control-Allow-Origin', origin);
      res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    }
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });
  app.use(express.json({ limit: '16kb' }));

  function requireAdmin(req, res, next) {
    if (!adminToken) return next(new ApiError(503, 'As alterações administrativas não estão configuradas.'));
    const expected = createHash('sha256').update(`Bearer ${adminToken}`).digest();
    const actual = createHash('sha256').update(req.get('Authorization') || '').digest();
    if (!timingSafeEqual(actual, expected)) return next(new ApiError(401, 'Credencial administrativa inválida.'));
    if (['POST', 'PUT'].includes(req.method) && !req.is('application/json')) {
      return next(new ApiError(415, 'Use Content-Type: application/json.'));
    }
    next();
  }
  function getPoint(id) {
    const row = db.prepare(`${selectPoints} WHERE e.id = ?`).get(id);
    if (!row) throw new ApiError(404, 'Ecoponto não encontrado.');
    return serialize(row);
  }

  app.get('/api/health', (req, res) => {
    db.prepare('SELECT 1').get();
    res.json({ status: 'ok', servico: 'SIGA API' });
  });
  app.get('/api/bairros', (req, res) => {
    const busca = normalize(queryText(req.query, 'busca') || '');
    const data = db.prepare('SELECT * FROM bairros ORDER BY nome').all()
      .filter((row) => normalize(row.nome).includes(busca));
    res.json({ data });
  });
  app.get('/api/categorias', (req, res) => res.json({ data: db.prepare('SELECT * FROM categorias ORDER BY id').all() }));
  app.get('/api/residuos', (req, res) => res.json({ data: db.prepare('SELECT * FROM residuos ORDER BY ordem, id').all() }));
  app.get('/api/dicas', (req, res) => res.json({ data: db.prepare('SELECT * FROM dicas ORDER BY ordem, id').all() }));

  app.get('/api/ecopontos', (req, res) => {
    const busca = normalize(queryText(req.query, 'busca') || '');
    const categoria = queryText(req.query, 'categoria');
    const bairro = queryText(req.query, 'bairro_id');
    const bairroId = bairro === undefined ? undefined : idFrom(bairro);
    const lat = queryNumber(req.query, 'latitude', -90, 90);
    const lon = queryNumber(req.query, 'longitude', -180, 180);
    const raio = queryNumber(req.query, 'raio_km', 0, 200);
    if ((lat === undefined) !== (lon === undefined) || (raio !== undefined && lat === undefined)) {
      throw new ApiError(400, 'Informe latitude e longitude juntas para consultar distâncias.');
    }
    let data = db.prepare(`${selectPoints} ORDER BY e.nome`).all().map(serialize)
      .filter((row) => (!categoria || row.categoria === categoria) &&
        (bairroId === undefined || row.bairro_id === bairroId) &&
        normalize(`${row.nome} ${row.endereco} ${row.bairro}`).includes(busca));
    if (lat !== undefined) {
      data = data.map((row) => ({ ...row, distancia_km: distanceKm(lat, lon, row.latitude, row.longitude) }))
        .filter((row) => raio === undefined || row.distancia_km <= raio)
        .sort((a, b) => a.distancia_km - b.distancia_km)
        .map((row) => ({ ...row, distancia_km: Math.round(row.distancia_km * 1000) / 1000 }));
    }
    res.json({ data, total: data.length });
  });
  app.get('/api/ecopontos/:id', (req, res) => res.json({ data: getPoint(idFrom(req.params.id)) }));
  app.post('/api/ecopontos', requireAdmin, (req, res) => {
    const p = pointInput(req.body, db);
    const result = db.prepare(`INSERT INTO ecopontos
      (nome, endereco, categoria_id, bairro_id, horario, latitude, longitude, demonstrativo)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(p.nome, p.endereco, p.categoria_id, p.bairro_id, p.horario, p.latitude, p.longitude, Number(p.demonstrativo));
    const id = Number(result.lastInsertRowid);
    res.status(201).location(`/api/ecopontos/${id}`).json({ data: getPoint(id) });
  });
  app.put('/api/ecopontos/:id', requireAdmin, (req, res) => {
    const id = idFrom(req.params.id);
    const current = getPoint(id);
    const p = pointInput(req.body, db);
    if (req.body.demonstrativo === undefined) p.demonstrativo = current.demonstrativo;
    db.prepare(`UPDATE ecopontos SET nome=?, endereco=?, categoria_id=?, bairro_id=?, horario=?,
      latitude=?, longitude=?, demonstrativo=?, atualizado_em=strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id=?`)
      .run(p.nome, p.endereco, p.categoria_id, p.bairro_id, p.horario, p.latitude, p.longitude, Number(p.demonstrativo), id);
    res.json({ data: getPoint(id) });
  });
  app.delete('/api/ecopontos/:id', requireAdmin, (req, res) => {
    const id = idFrom(req.params.id);
    getPoint(id);
    db.prepare('DELETE FROM ecopontos WHERE id = ?').run(id);
    res.sendStatus(204);
  });
  app.use((req, res) => res.status(404).json({ error: { message: 'Rota não encontrada.' } }));
  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    if (error instanceof ApiError) return res.status(error.status).json({ error: { message: error.message } });
    if (error.type === 'entity.parse.failed') return res.status(400).json({ error: { message: 'JSON inválido.' } });
    if (error.type === 'entity.too.large') return res.status(413).json({ error: { message: 'Corpo da requisição muito grande.' } });
    if (error.errcode === 2067) return res.status(409).json({ error: { message: 'Já existe um ecoponto com esse nome.' } });
    console.error('Erro interno da API:', error.message);
    return res.status(500).json({ error: { message: 'Não foi possível concluir a operação.' } });
  });
  return app;
}
