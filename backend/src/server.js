import { config } from './config.js';
import { openDatabase } from './database.js';
import { createApp } from './app.js';

const db = openDatabase(config.databasePath);
const app = createApp({ db, ...config });
// Remove posições sem sinal mesmo quando nenhum usuário abre o mapa.
const cleanup = setInterval(() => {
  const now = Date.now();
  db.prepare('DELETE FROM rastreamento WHERE expira_em <= ?').run(now);
  db.prepare('UPDATE rastreamento SET latitude=NULL,longitude=NULL,precisao=NULL WHERE capturado_em < ?').run(now - 120000);
}, 20000);
cleanup.unref();
const server = app.listen(config.port, config.host, () => {
  console.log(`SIGA API na porta ${config.port}. Teste: http://localhost:${config.port}/api/health`);
});
function shutdown() {
  clearInterval(cleanup);
  server.close(() => { db.close(); process.exit(0); });
  server.closeIdleConnections();
  setTimeout(() => process.exit(1), 10000).unref();
}
process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
