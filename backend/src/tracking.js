import { randomBytes, randomUUID, createHash, timingSafeEqual } from 'node:crypto';
import { rateLimit } from 'express-rate-limit';

export const STALE_MS = 30_000;
export const HIDE_MS = 120_000;
const digest = (value) => createHash('sha256').update(value).digest();
const fail = (res, code, message) => res.status(code).json({ error: { message } });

export function installTracking(app, { db, requireAdmin, now = Date.now }) {
  const limiter = rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: 'draft-8', legacyHeaders: false,
    message: { error: { message: 'Muitas atualizações. Aguarde um minuto.' } } });
  function cleanup(req, res, next) {
    db.prepare('DELETE FROM rastreamento WHERE expira_em <= ?').run(now());
    db.prepare(`UPDATE rastreamento SET latitude=NULL, longitude=NULL, precisao=NULL
      WHERE capturado_em < ?`).run(now() - HIDE_MS);
    next();
  }
  app.use('/api/rastreamento', cleanup);
  app.use('/api/admin/rastreamento', cleanup);
  function authorize(req, res, next) {
    const row = db.prepare('SELECT * FROM rastreamento WHERE id=?').get(req.params.id);
    const token = (req.get('Authorization') || '').replace(/^Bearer /, '');
    if (!row || !timingSafeEqual(digest(token), Buffer.from(row.token_hash, 'hex'))) {
      return fail(res, 401, 'Sessão inválida ou expirada. Solicite uma nova autorização.');
    }
    req.tracker = row;
    next();
  }
  app.post('/api/admin/rastreamento', requireAdmin, (req, res) => {
    const body = req.body;
    if (!body || typeof body.nome !== 'string' || body.nome.trim().length < 3 || body.nome.trim().length > 60 ||
        Object.keys(body).some(k => k !== 'nome')) return fail(res, 400, 'Informe somente nome, com 3 a 60 caracteres.');
    if (db.prepare('SELECT count(*) AS n FROM rastreamento').get().n >= 20) return fail(res, 409, 'Encerre uma sessão antes de criar outra (limite 20).');
    const id = randomUUID();
    const token = randomBytes(32).toString('hex');
    const expira = now() + 4 * 60 * 60 * 1000;
    db.prepare('INSERT INTO rastreamento (id,nome,token_hash,expira_em) VALUES (?,?,?,?)')
      .run(id, body.nome.trim(), digest(token).toString('hex'), expira);
    res.status(201).json({ data: { id, nome: body.nome.trim(), chave: `${id}.${token}`, expira_em: new Date(expira).toISOString() } });
  });
  app.get('/api/admin/rastreamento', requireAdmin, (req, res) => {
    res.json({ data: db.prepare('SELECT id,nome,expira_em,recebido_em FROM rastreamento ORDER BY nome').all() });
  });
  app.delete('/api/admin/rastreamento/:id', requireAdmin, (req, res) => {
    db.prepare('DELETE FROM rastreamento WHERE id=?').run(req.params.id);
    res.sendStatus(204);
  });
  app.put('/api/rastreamento/:id/posicao', limiter, authorize, (req, res) => {
    if (!req.is('application/json')) return fail(res, 415, 'Envie JSON.');
    const b = req.body;
    if (!b || Array.isArray(b) || Object.keys(b).some(k => !['latitude','longitude','precisao','capturado_em'].includes(k))) {
      return fail(res, 400, 'Posição inválida.');
    }
    for (const [key, min, max] of [['latitude',-90,90],['longitude',-180,180],['precisao',0,100]]) {
      if (typeof b[key] !== 'number' || !Number.isFinite(b[key]) || b[key] < min || b[key] > max) {
        return fail(res, 400, key === 'precisao' ? 'GPS impreciso: aguarde precisão de até 100 metros.' : `${key} inválida.`);
      }
    }
    if (!Number.isSafeInteger(b.capturado_em) || b.capturado_em < now() - STALE_MS || b.capturado_em > now() + 5000) {
      return fail(res, 400, 'Localização antiga ou relógio incorreto. Obtenha um novo sinal GPS.');
    }
    if (req.tracker.capturado_em !== null && b.capturado_em <= req.tracker.capturado_em) {
      return fail(res, 409, 'Essa posição já foi recebida ou é mais antiga que a atual.');
    }
    db.prepare(`UPDATE rastreamento SET latitude=?,longitude=?,precisao=?,capturado_em=?,recebido_em=? WHERE id=?`)
      .run(b.latitude,b.longitude,b.precisao,b.capturado_em,now(),req.params.id);
    res.json({ data: { recebido_em: new Date(now()).toISOString() } });
  });
  app.delete('/api/rastreamento/:id', limiter, authorize, (req, res) => {
    db.prepare('DELETE FROM rastreamento WHERE id=?').run(req.params.id);
    res.sendStatus(204);
  });
  app.get('/api/rastreamento', (req, res) => {
    const data = db.prepare(`SELECT id,nome,latitude,longitude,precisao,capturado_em FROM rastreamento
      WHERE latitude IS NOT NULL AND capturado_em >= ? ORDER BY nome`).all(now() - HIDE_MS)
      .map(row => ({ ...row, idade_segundos: Math.max(0, Math.floor((now()-row.capturado_em)/1000)),
        status: now()-row.capturado_em <= STALE_MS ? 'ao_vivo' : 'sem_sinal', demonstrativo: true }));
    res.json({ data });
  });
}
