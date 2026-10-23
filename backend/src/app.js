import express from 'express';
import { createHash, timingSafeEqual, randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { rateLimit } from 'express-rate-limit';
import sharp from 'sharp';
import { v2 as cloudinary } from 'cloudinary';
import { installTracking } from './tracking.js';

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

export function createApp({ db, adminToken = '', environment = 'development', corsOrigins = [], cloudinaryCloudName = '', cloudinaryApiKey = '', cloudinaryApiSecret = '', trustProxyHops = 0, reportLimit = 5, now = Date.now }) {
  const app = express();
  app.set('trust proxy', trustProxyHops);
  app.disable('x-powered-by');
  app.set('query parser', 'simple');
  app.use((req, res, next) => {
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Cache-Control', 'no-store');
    res.set('Referrer-Policy', 'no-referrer');
    res.set('Permissions-Policy', 'geolocation=(self), camera=(), microphone=()');
    res.set('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
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
      res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    }
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });
  const limiter = (limit, windowMs = 60_000) => rateLimit({ limit, windowMs,
    standardHeaders: 'draft-8', legacyHeaders: false,
    message: { error: { message: 'Muitas solicitações. Aguarde antes de tentar novamente.' } } });
  app.use('/api', limiter(300));
  app.use('/api/admin', limiter(60));
  app.post('/api/denuncias', limiter(reportLimit, 15 * 60_000));
  app.use('/api/denuncias', express.json({ limit: '3mb' }));
  app.use(express.json({ limit: '16kb' }));
  const publicDir = fileURLToPath(new URL('../public/', import.meta.url));
  app.get('/rastreador', (req, res) => res.sendFile('tracker.html', { root: publicDir }));
  app.get('/admin', (req, res) => res.sendFile('admin.html', { root: publicDir }));
  app.use('/assets', express.static(publicDir, { index: false, dotfiles: 'deny' }));
  app.get('/', (req, res) => res.json({ status: 'ok', servico: 'SIGA API', health: '/api/health' }));

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
  installTracking(app, { db, requireAdmin, now });

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

  // Denúncias anônimas: protocolo é um segredo de consulta, não sequencial.
  // Imagens devem estar em JPEG/PNG e até 2 MiB antes da codificação base64.
  const categoriasDenuncia = new Set(['lixo_domestico', 'entulho', 'moveis', 'perigosos', 'outros']);
  async function photoInput(value) {
    if (typeof value !== 'string') throw new ApiError(400, 'Envie foto_base64 em JPEG ou PNG.');
    const match = /^data:image\/(jpeg|png);base64,([A-Za-z0-9+/]+={0,2})$/.exec(value);
    if (!match) throw new ApiError(400, 'Foto inválida. Envie uma imagem JPEG ou PNG em base64.');
    const raw = match[2];
    if (raw.length > 2_800_000) throw new ApiError(413, 'A foto excede 2 MiB.');
    const buffer = Buffer.from(raw, 'base64');
    if (buffer.length < 64 || buffer.length > 2_097_152) throw new ApiError(400, 'Tamanho da foto inválido.');
    const jpeg = buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
    const png = buffer.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
    if ((match[1] === 'jpeg' && !jpeg) || (match[1] === 'png' && !png)) throw new ApiError(400, 'Formato da foto não corresponde ao conteúdo.');
    try {
      // Decodifica de verdade, limita pixels e remove metadados no servidor.
      // Validação só no Flutter pode ser contornada por clientes HTTP.
      const clean = await sharp(buffer, { limitInputPixels: 16_000_000, failOn: 'warning' })
        .rotate().resize({ width: 1550, height: 1550, fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 80 }).toBuffer();
      if (clean.length > 2_097_152) throw new Error('too large');
      return `data:image/jpeg;base64,${clean.toString('base64')}`;
    } catch {
      throw new ApiError(400, 'Imagem corrompida ou grande demais. Use uma foto JPG/PNG de até 16 megapixels.');
    }
  }
  function serializeReport(report) {
    return {
      id: report.id, categoria: report.categoria, descricao: report.descricao,
      latitude: report.latitude, longitude: report.longitude,
      status: report.status, criado_em: report.criado_em, atualizado_em: report.atualizado_em,
    };
  }
  app.post('/api/denuncias', async (req, res, next) => {
    try {
      if (!req.is('application/json')) throw new ApiError(415, 'Envie JSON.');
      const body = req.body;
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new ApiError(400, 'JSON inválido.');
      if (Object.keys(body).some((key) => !['categoria','descricao','latitude','longitude','foto_base64'].includes(key))) throw new ApiError(400, 'Campos desconhecidos.');
      if (!categoriasDenuncia.has(body.categoria)) throw new ApiError(400, 'Categoria inválida.');
      const descricao = body.descricao ?? '';
      if (typeof descricao !== 'string' || descricao.length > 500) throw new ApiError(400, 'Descrição deve ter até 500 caracteres.');
      for (const [key, max] of [['latitude',90],['longitude',180]]) {
        if (typeof body[key] !== 'number' || !Number.isFinite(body[key]) || Math.abs(body[key]) > max) throw new ApiError(400, `${key} inválida.`);
      }
      const photo = await photoInput(body.foto_base64);
      const externalStorage = Boolean(cloudinaryCloudName && cloudinaryApiKey && cloudinaryApiSecret);
      let photoId = 'sqlite';
      let photoUrl = '';
      let localBytes = null;
      let imageMime = null;
      if (externalStorage) {
        const timestamp = Math.floor(Date.now() / 1000);
        const folder = 'siga/denuncias';
        const signature = createHash('sha1').update(`folder=${folder}&timestamp=${timestamp}&type=authenticated${cloudinaryApiSecret}`).digest('hex');
        const form = new FormData();
        form.append('file', photo);
        form.append('api_key', cloudinaryApiKey);
        form.append('timestamp', String(timestamp));
        form.append('folder', folder);
        form.append('type', 'authenticated');
        form.append('signature', signature);
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 15000);
        try {
          const response = await fetch(`https://api.cloudinary.com/v1_1/${encodeURIComponent(cloudinaryCloudName)}/image/upload`, {
            method:'POST', body:form, signal:controller.signal,
          });
          if (!response.ok) throw new Error('Falha no serviço de imagens.');
          const upload = await response.json();
          if (typeof upload.secure_url !== 'string' || typeof upload.public_id !== 'string') {
            throw new Error('Resposta inválida do armazenamento.');
          }
          photoId = upload.public_id;
          photoUrl = upload.secure_url;
        } finally { clearTimeout(timer); }
      } else {
        // Fallback acadêmico: o arquivo fica privado dentro do banco SQLite.
        // Em Render, o DB_FILE deve apontar para um disco persistente.
        imageMime = photo.startsWith('data:image/png;') ? 'image/png' : 'image/jpeg';
        localBytes = Buffer.from(photo.split(',')[1], 'base64');
      }
      const protocolo = randomBytes(24).toString('hex');
      const hash = createHash('sha256').update(protocolo).digest('hex');
      const result = db.prepare(`INSERT INTO denuncias
        (protocolo_hash,categoria,descricao,foto_public_id,foto_url,latitude,longitude,foto_local,foto_mime,foto_tipo)
        VALUES (?,?,?,?,?,?,?,?,?,?)`).run(hash,body.categoria,descricao.trim(),photoId,photoUrl,body.latitude,body.longitude,localBytes,imageMime,externalStorage ? 'authenticated' : 'local');
      res.status(201).json({ data: { protocolo, id: Number(result.lastInsertRowid), status: 'pendente' } });
    } catch (error) { next(error); }
  });
  app.get('/api/denuncias/protocolo/:codigo', (req, res) => {
    const codigo = req.params.codigo;
    if (!/^[0-9a-f]{48}$/.test(codigo)) throw new ApiError(400, 'Protocolo inválido.');
    const hash = createHash('sha256').update(codigo).digest('hex');
    const result = db.prepare('SELECT id,categoria,descricao,latitude,longitude,status,criado_em,atualizado_em FROM denuncias WHERE protocolo_hash = ?').get(hash);
    if (!result) throw new ApiError(404, 'Protocolo não encontrado.');
    res.json({data: serializeReport(result)});
  });
  app.get('/api/admin/denuncias', requireAdmin, (req, res) => {
    const before = req.query.antes === undefined ? Number.MAX_SAFE_INTEGER : idFrom(req.query.antes);
    const rows = db.prepare('SELECT id,categoria,descricao,latitude,longitude,status,criado_em,atualizado_em FROM denuncias WHERE id < ? ORDER BY id DESC LIMIT 50').all(before);
    const data = rows.map(serializeReport);
    res.json({data, proxima_pagina: rows.length === 50 ? rows.at(-1).id : null});
  });
  // A foto armazenada no SQLite não é pública; só o operador autorizado pode ler.
  app.get('/api/admin/denuncias/:id/foto', requireAdmin, async (req, res) => {
    const id = idFrom(req.params.id);
    const report = db.prepare('SELECT foto_local, foto_mime, foto_url, foto_public_id, foto_tipo FROM denuncias WHERE id=?').get(id);
    if (!report) throw new ApiError(404, 'Denúncia não encontrada.');
    if (report.foto_local) {
      res.type(report.foto_mime || 'image/jpeg');
      return res.send(Buffer.from(report.foto_local));
    }
    let url;
    if (report.foto_tipo === 'authenticated' && cloudinaryApiSecret) {
      url = cloudinary.utils.private_download_url(report.foto_public_id, 'jpg', {
        cloud_name: cloudinaryCloudName, api_key: cloudinaryApiKey, api_secret: cloudinaryApiSecret,
        type: 'authenticated', resource_type: 'image', expires_at: Math.floor(Date.now()/1000)+60,
      });
    }
    // Legado: uploads públicos anteriores precisam ser migrados no provedor.
    if (report.foto_url && report.foto_tipo === 'upload') {
      const legacy = new URL(report.foto_url);
      if (legacy.protocol === 'https:' && legacy.hostname === 'res.cloudinary.com') url = legacy.toString();
    }
    if (url) {
      const response = await fetch(url, { signal: AbortSignal.timeout(15000), redirect: 'error' });
      if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) throw new ApiError(502, 'Não foi possível carregar a foto.');
      const chunks = []; let bytes = 0;
      for await (const chunk of response.body) {
        bytes += chunk.length;
        if (bytes > 2_097_152) throw new ApiError(502, 'Imagem externa acima do limite.');
        chunks.push(chunk);
      }
      return res.type(response.headers.get('content-type')).send(Buffer.concat(chunks));
    }
    throw new ApiError(404, 'Foto não disponível.');
  });
  app.patch('/api/admin/denuncias/:id/status', requireAdmin, (req, res) => {
    if (!req.is('application/json')) throw new ApiError(415, 'Envie JSON.');
    if (!req.body || Object.keys(req.body).length !== 1 || typeof req.body.status !== 'string' ||
        !['pendente','em_analise','em_atendimento','resolvida','rejeitada'].includes(req.body.status)) throw new ApiError(400, 'Status inválido.');
    const id = idFrom(req.params.id);
    const result = db.prepare("UPDATE denuncias SET status=?, atualizado_em=strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id=?")
      .run(req.body.status,id);
    if (!result.changes) throw new ApiError(404, 'Denúncia não encontrada.');
    res.json({data: serializeReport(db.prepare('SELECT * FROM denuncias WHERE id=?').get(id))});
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
