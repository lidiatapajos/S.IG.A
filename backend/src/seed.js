import { pathToFileURL } from 'node:url';
import { openDatabase } from './database.js';
import { config } from './config.js';

// Conteúdo inicial do protótipo. Não representa cadastro municipal verificado.
export function seedDemo(db) {
  const bairros = ['Água Branca', 'Área Militar', 'Benguí', 'Campina', 'Canudos',
    'Condor', 'Cremação', 'Guamá', 'Jurunas', 'Marco', 'Nazaré', 'Pedreira',
    'Reduto', 'Sacramenta', 'São Brás', 'Tapanã', 'Terra Firme', 'Umarizal', 'Val-de-Cans'];
  db.exec('BEGIN');
  try {
    const addBairro = db.prepare('INSERT OR IGNORE INTO bairros (nome) VALUES (?)');
    for (const nome of bairros) addBairro.run(nome);
    const addCategoria = db.prepare('INSERT OR IGNORE INTO categorias (codigo, nome) VALUES (?, ?)');
    for (const row of [['Reciclaveis', 'Recicláveis'], ['Eletronicos', 'Eletrônicos'], ['Oleo', 'Óleo']]) {
      addCategoria.run(...row);
    }
    const points = [
      ['Ecoponto Nazaré (exemplo)', 'Av. Nazaré, 987 - Nazaré, Belém/PA', 'Reciclaveis', 'Nazaré', 'Seg a Sáb - 8h às 17h', -1.4558, -48.4788],
      ['Ponto de Coleta Marco (exemplo)', 'R. do Marco, 123 - Marco, Belém/PA', 'Reciclaveis', 'Marco', 'Seg a Sex - 9h às 18h', -1.4490, -48.4650],
      ['Coleta Eletrônicos São Brás (exemplo)', 'Av. José Bonifácio, 500 - São Brás, Belém/PA', 'Eletronicos', 'São Brás', 'Seg a Sex - 8h às 16h', -1.4570, -48.4700],
      ['Ponto de Óleo Nazaré (exemplo)', 'Tv. Padre Eutíquio, 200 - Nazaré, Belém/PA', 'Oleo', 'Nazaré', 'Todos os dias - 7h às 19h', -1.4610, -48.4790],
    ];
    const addPoint = db.prepare(`INSERT OR IGNORE INTO ecopontos
      (nome, endereco, categoria_id, bairro_id, horario, latitude, longitude, demonstrativo)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1)`);
    for (const [nome, endereco, categoria, bairro, horario, lat, lon] of points) {
      addPoint.run(nome, endereco,
        db.prepare('SELECT id FROM categorias WHERE codigo = ?').get(categoria).id,
        db.prepare('SELECT id FROM bairros WHERE nome = ?').get(bairro).id,
        horario, lat, lon);
    }
    const addResiduo = db.prepare('INSERT OR IGNORE INTO residuos (codigo, titulo, descricao, ordem) VALUES (?, ?, ?, ?)');
    const residuos = [
      ['Organicos', 'Resíduos orgânicos', 'Restos de alimentos, frutas, verduras, cascas e borra de café.'],
      ['Reciclaveis', 'Recicláveis', 'Papel, papelão, plásticos, metais e vidros. Confirme quais materiais o ponto recebe.'],
      ['Rejeitos', 'Rejeitos', 'Papel higiênico usado, fraldas e outros materiais sem possibilidade de recuperação na coleta local.'],
      ['Perigosos', 'Resíduos perigosos', 'Pilhas, baterias, lâmpadas e medicamentos precisam de destinos específicos. Confirme o recebimento antes de levar.'],
    ];
    residuos.forEach((row, i) => addResiduo.run(...row, i));
    const addDica = db.prepare('INSERT OR IGNORE INTO dicas (texto, ordem) VALUES (?, ?)');
    ['Retire os restos de alimentos das embalagens antes de separar os recicláveis.',
      'Nunca misture pilhas e baterias com o lixo comum.',
      'Guarde óleo de cozinha usado e frio em recipiente fechado e confirme um ponto que o receba.']
      .forEach((texto, i) => addDica.run(texto, i));
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const db = openDatabase(config.databasePath);
  try {
    seedDemo(db);
    console.log('Dados de demonstração cadastrados. Os ecopontos não são locais confirmados.');
  } finally { db.close(); }
}
