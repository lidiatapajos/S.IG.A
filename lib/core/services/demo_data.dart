/// Conteúdo explicitamente fictício, usado SOMENTE com DEMO_MODE=true.
/// Nunca tratar os locais abaixo como estabelecimentos verificados.
class DemoData {
  static const bairros = [
    'Água Branca', 'Área Militar', 'Benguí', 'Campina', 'Canudos', 'Condor',
    'Cremação', 'Guamá', 'Jurunas', 'Marco', 'Nazaré', 'Pedreira', 'Reduto',
    'Sacramenta', 'São Brás', 'Tapanã', 'Terra Firme', 'Umarizal', 'Val-de-Cans',
  ];
  static List<Map<String, dynamic>> get bairrosJson => [
    for (var i = 0; i < bairros.length; i++) {'id': i + 1, 'nome': bairros[i]},
  ];
  static const categorias = [
    {'id': 1, 'codigo': 'Reciclaveis', 'nome': 'Recicláveis'},
    {'id': 2, 'codigo': 'Eletronicos', 'nome': 'Eletrônicos'},
    {'id': 3, 'codigo': 'Oleo', 'nome': 'Óleo'},
  ];
  static const ecopontos = [
    {'id':1, 'nome':'Ecoponto Nazaré (exemplo)', 'endereco':'Av. Nazaré, 987 - Nazaré, Belém/PA', 'categoria':'Reciclaveis', 'categoria_nome':'Recicláveis', 'horario':'Horário fictício: 8h às 17h', 'latitude':-1.4558, 'longitude':-48.4788, 'demonstrativo':true},
    {'id':2, 'nome':'Coleta Marco (exemplo)', 'endereco':'R. do Marco, 123 - Marco, Belém/PA', 'categoria':'Reciclaveis', 'categoria_nome':'Recicláveis', 'horario':'Horário fictício: 9h às 18h', 'latitude':-1.4490, 'longitude':-48.4650, 'demonstrativo':true},
    {'id':3, 'nome':'Eletrônicos São Brás (exemplo)', 'endereco':'Av. José Bonifácio, 500 - São Brás, Belém/PA', 'categoria':'Eletronicos', 'categoria_nome':'Eletrônicos', 'horario':'Horário fictício: 8h às 16h', 'latitude':-1.4570, 'longitude':-48.4700, 'demonstrativo':true},
    {'id':4, 'nome':'Óleo Nazaré (exemplo)', 'endereco':'Tv. Padre Eutíquio, 200 - Nazaré, Belém/PA', 'categoria':'Oleo', 'categoria_nome':'Óleo', 'horario':'Horário fictício: 7h às 19h', 'latitude':-1.4610, 'longitude':-48.4790, 'demonstrativo':true},
  ];
  static const residuos = [
    {'codigo':'Organicos', 'titulo':'Resíduos orgânicos', 'descricao':'Restos de comida, frutas, cascas, verduras e borra de café.'},
    {'codigo':'Reciclaveis', 'titulo':'Recicláveis', 'descricao':'Papel, papelão, plásticos, metais e vidros. Confira as regras locais.'},
    {'codigo':'Rejeitos', 'titulo':'Rejeitos', 'descricao':'Fraldas e outros materiais sem opção de reciclagem na coleta local.'},
    {'codigo':'Perigosos', 'titulo':'Resíduos perigosos', 'descricao':'Pilhas, baterias, lâmpadas e medicamentos: descarte em pontos especializados.'},
  ];
  static const dicas = [
    {'texto':'Retire os restos de alimentos das embalagens recicláveis.'},
    {'texto':'Não misture pilhas e baterias com o lixo comum.'},
    {'texto':'Armazene óleo usado e frio em recipiente fechado.'},
    {'texto':'Mantenha vidros quebrados protegidos para evitar acidentes.'},
  ];
}
