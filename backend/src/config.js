import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const backendDir = fileURLToPath(new URL('../', import.meta.url));
const envPath = resolve(backendDir, '.env');
if (existsSync(envPath)) loadEnvFile(envPath);

export const config = {
  port: Number(process.env.PORT || 3000),
  host: process.env.HOST || '0.0.0.0',
  databasePath: resolve(backendDir, process.env.DB_FILE || 'data/siga.db'),
  adminToken: process.env.ADMIN_API_TOKEN || '',
  environment: process.env.NODE_ENV || 'development',
  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',').map((origin) => origin.trim()).filter(Boolean),
};
if (!Number.isInteger(config.port) || config.port < 1 || config.port > 65535) {
  throw new Error('PORT deve ser um inteiro entre 1 e 65535.');
}
if (config.adminToken && config.adminToken.length < 32) {
  throw new Error('ADMIN_API_TOKEN deve ter pelo menos 32 caracteres.');
}
