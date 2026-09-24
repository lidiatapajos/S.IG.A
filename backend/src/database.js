import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

// Versão 1. Próximas mudanças devem criar novas migrações, sem apagar os dados.
export function openDatabase(filename = ':memory:') {
  if (filename !== ':memory:') mkdirSync(dirname(filename), { recursive: true });
  const db = new DatabaseSync(filename);
  db.exec('PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
  if (filename !== ':memory:') db.exec('PRAGMA journal_mode = WAL;');
  const version = db.prepare('PRAGMA user_version').get().user_version;
  if (version > 1) {
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
  return db;
}
