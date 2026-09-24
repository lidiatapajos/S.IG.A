import { config } from './config.js';
import { openDatabase } from './database.js';
import { createApp } from './app.js';

const db = openDatabase(config.databasePath);
const app = createApp({ db, ...config });
const server = app.listen(config.port, config.host, () => {
  console.log(`SIGA API na porta ${config.port}. Teste: http://localhost:${config.port}/api/health`);
});
function shutdown() {
  server.close(() => { db.close(); process.exit(0); });
  server.closeIdleConnections();
  setTimeout(() => process.exit(1), 10000).unref();
}
process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
