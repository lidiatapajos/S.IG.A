import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

// Migrações incrementais: nunca apagar dados de versões anteriores.
export function openDatabase(filename = ':memory:') {
  if (filename !== ':memory:') mkdirSync(dirname(filename), { recursive: true });
  const db = new DatabaseSync(filename);
  db.exec('PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
  if (filename !== ':memory:') db.exec('PRAGMA journal_mode = WAL;');
  const version = db.prepare('PRAGMA user_version').get().user_version;
  if (version > 4) {
    db.close();
    throw new Error('O banco pertence a uma versão mais recente da API.');
  }
  if (version === 0) {
    db.exec(`
      BEGIN;
      CREATE TABLE bairros (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL UNIQUE,
        cidade TEXT NOT NULL DEFAULT 'Belém',
        uf TEXT NOT NULL DEFAULT 'PA'
      );
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY,
        codigo TEXT NOT NULL UNIQUE,
        nome TEXT NOT NULL
      );
      CREATE TABLE ecopontos (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL UNIQUE CHECK(length(nome) BETWEEN 3 AND 120),
        endereco TEXT NOT NULL CHECK(length(endereco) BETWEEN 5 AND 240),
        categoria_id INTEGER NOT NULL REFERENCES categorias(id),
        bairro_id INTEGER NOT NULL REFERENCES bairros(id),
        horario TEXT NOT NULL CHECK(length(horario) BETWEEN 3 AND 160),
        latitude REAL NOT NULL CHECK(latitude BETWEEN -90 AND 90),
        longitude REAL NOT NULL CHECK(longitude BETWEEN -180 AND 180),
        demonstrativo INTEGER NOT NULL DEFAULT 0 CHECK(demonstrativo IN (0, 1)),
        criado_em TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        atualizado_em TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      );
      CREATE INDEX idx_ecopontos_categoria ON ecopontos(categoria_id);
      CREATE INDEX idx_ecopontos_bairro ON ecopontos(bairro_id);
      CREATE TABLE residuos (
        id INTEGER PRIMARY KEY,
        codigo TEXT NOT NULL UNIQUE,
        titulo TEXT NOT NULL,
        descricao TEXT NOT NULL,
        ordem INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE dicas (
        id INTEGER PRIMARY KEY,
        texto TEXT NOT NULL UNIQUE,
        ordem INTEGER NOT NULL DEFAULT 0
      );
      PRAGMA user_version = 1;
      COMMIT;
    `);
  }
  // Migração v2: preserva todas as tabelas e dados da versão anterior.
  if (db.prepare('PRAGMA user_version').get().user_version === 1) {
    db.exec(`
      BEGIN;
      CREATE TABLE IF NOT EXISTS denuncias (
        id INTEGER PRIMARY KEY,
        protocolo_hash TEXT NOT NULL UNIQUE,
        categoria TEXT NOT NULL CHECK(categoria IN ('lixo_domestico','entulho','moveis','perigosos','outros')),
        descricao TEXT NOT NULL DEFAULT '' CHECK(length(descricao) <= 500),
        foto_public_id TEXT NOT NULL,
        foto_url TEXT NOT NULL,
        latitude REAL NOT NULL CHECK(latitude BETWEEN -90 AND 90),
        longitude REAL NOT NULL CHECK(longitude BETWEEN -180 AND 180),
        status TEXT NOT NULL DEFAULT 'pendente' CHECK(status IN ('pendente','em_analise','em_atendimento','resolvida','rejeitada')),
        criado_em TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        atualizado_em TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      );
      CREATE INDEX IF NOT EXISTS idx_denuncias_status ON denuncias(status);
      PRAGMA user_version = 2;
      COMMIT;
    `);
  }
  // v3: armazena imagens de demonstração no próprio SQLite quando
  // o Cloudinary ainda não está configurado. As imagens NÃO são públicas.
  if (db.prepare('PRAGMA user_version').get().user_version === 2) {
    db.exec(`
      BEGIN;
      ALTER TABLE denuncias ADD COLUMN foto_local BLOB;
      ALTER TABLE denuncias ADD COLUMN foto_mime TEXT;
      PRAGMA user_version = 3;
      COMMIT;
    `);
  }
  if (db.prepare('PRAGMA user_version').get().user_version === 3) {
    db.exec(`
      BEGIN;
      ALTER TABLE denuncias ADD COLUMN foto_tipo TEXT NOT NULL DEFAULT 'upload';
      CREATE TABLE rastreamento (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL CHECK(length(nome) BETWEEN 3 AND 60),
        token_hash TEXT NOT NULL,
        expira_em INTEGER NOT NULL,
        latitude REAL CHECK(latitude BETWEEN -90 AND 90),
        longitude REAL CHECK(longitude BETWEEN -180 AND 180),
        precisao REAL,
        capturado_em INTEGER,
        recebido_em INTEGER
      );
      PRAGMA user_version = 4;
      COMMIT;
    `);
  }
  return db;
}
