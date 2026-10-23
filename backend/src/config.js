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
  cloudinaryCloudName: process.env.CLOUDINARY_CLOUD_NAME || '',
  cloudinaryApiKey: process.env.CLOUDINARY_API_KEY || '',
  cloudinaryApiSecret: process.env.CLOUDINARY_API_SECRET || '',
  environment: process.env.NODE_ENV || 'development',
  trustProxyHops: Number(process.env.TRUST_PROXY_HOPS || 0),
  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',').map((origin) => origin.trim()).filter(Boolean),
};
if (!Number.isInteger(config.trustProxyHops) || config.trustProxyHops < 0 || config.trustProxyHops > 5) {
  throw new Error('TRUST_PROXY_HOPS deve ser um inteiro entre 0 e 5.');
}
const cloudinaryFields = [config.cloudinaryCloudName, config.cloudinaryApiKey, config.cloudinaryApiSecret];
if (cloudinaryFields.some(Boolean) && !cloudinaryFields.every(Boolean)) {
  throw new Error('Configure as três variáveis CLOUDINARY_* ou deixe todas vazias.');
}
if (config.environment === 'production' && (!process.env.DB_FILE || process.env.PERSISTENT_STORAGE_CONFIRMED !== 'true')) {
  throw new Error('Em produção, configure DB_FILE em disco persistente e PERSISTENT_STORAGE_CONFIRMED=true após verificar o volume.');
}
if (config.environment === 'production' && !config.adminToken) throw new Error('Configure ADMIN_API_TOKEN em produção.');
if (!Number.isInteger(config.port) || config.port < 1 || config.port > 65535) {
  throw new Error('PORT deve ser um inteiro entre 1 e 65535.');
}
if (config.adminToken && config.adminToken.length < 32) {
  throw new Error('ADMIN_API_TOKEN deve ter pelo menos 32 caracteres.');
}
