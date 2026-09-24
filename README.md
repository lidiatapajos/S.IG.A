# SIGA — aplicativo de resíduos + API

Este projeto reúne o aplicativo Flutter existente e uma primeira versão de backend em Node.js + Express, com banco SQLite. A API atende as telas de bairros, mapa, pontos de descarte e guia de resíduos.

Os quatro ecopontos iniciais são exemplos vindos do protótipo, com endereços e horários **não verificados**. Eles são identificados como demonstração na API e no app. Não representam um serviço oficial da Prefeitura de Belém.

## 1. Iniciar o backend

Pré-requisitos: **Node.js 24.x**, npm e, para abrir o aplicativo, Flutter. O banco SQLite já está disponível no Node.js usado pelo projeto; não precisa instalar MySQL ou PostgreSQL nesta etapa.

Abra o terminal na pasta principal do projeto:

```bash
cd backend
npm ci
cp .env.example .env
npm run seed
npm start
```

No Windows/PowerShell, troque `cp .env.example .env` por `Copy-Item .env.example .env` se necessário.

Mantenha esse terminal aberto. Acesse no navegador:

- `http://localhost:3000/api/health` — verifica se a API e o banco respondem.
- `http://localhost:3000/api/ecopontos` — mostra os pontos em JSON.
- `http://localhost:3000/api/bairros` — mostra os bairros do protótipo.

`npm run seed` cria 19 bairros, 3 categorias, 4 ecopontos demonstrativos, 4 orientações e 3 dicas. Pode ser executado novamente sem duplicar os registros iniciais nem sobrescrever alterações em registros com o mesmo nome/código. Um ponto inicial excluído será recriado se você repetir o seed; ele é uma ferramenta de preparação dos exemplos, não de sincronização de produção.

O banco é criado em `backend/data/siga.db`. Ele continua com os dados após reiniciar o servidor. Não apague essa pasta para reiniciar a API. Para desenvolver com recarga automática, use `npm run dev`.

## 2. Abrir o Flutter

Em **outro terminal**, na pasta principal do projeto:

```bash
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

Esse comando executa a versão Web para testar a integração. Para testar no emulador Android:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Se houver vários dispositivos, selecione o emulador com `-d ID_DO_DISPOSITIVO`.

| Onde o app está executando | Endereço da API |
| --- | --- |
| Navegador ou simulador iOS no mesmo computador do backend | `http://localhost:3000/api` |
| Emulador Android padrão | `http://10.0.2.2:3000/api` |
| Celular físico na mesma rede Wi-Fi | `http://IP_DO_COMPUTADOR:3000/api` |
| FlutLab ou app publicado | URL pública HTTPS da API, terminando em `/api` |

No celular físico, substitua `IP_DO_COMPUTADOR` pelo IP local real do seu computador e permita conexões à porta 3000 no firewall da sua rede de desenvolvimento. `localhost` no celular se refere ao próprio celular. No iOS, prefira HTTPS ao testar uma API remota; a configuração do projeto permite rede local, sem liberar HTTP geral.

No FlutLab, o servidor na sua máquina não é acessível pelo `localhost` do ambiente remoto. Você precisa de uma API com URL HTTPS. O passo a passo a seguir usa um arquivo de configuração no próprio app, sem exigir parâmetros de compilação na interface do FlutLab.

### Se você está usando o FlutLab

1. Importe o arquivo ZIP atualizado como projeto no FlutLab. Verifique se o `pubspec.yaml` contém `http` e deixe o FlutLab resolver os pacotes.
2. Publique **o backend separadamente** em um servidor com URL HTTPS. O projeto Flutter no FlutLab não executa o servidor Node.js. Uma opção de teste é criar um Web Service no Render conectado ao repositório: diretório raiz `backend`, versão do Node `24`, build `npm ci`, start `npm run seed && npm start`, `NODE_ENV=production` e `CORS_ORIGINS` com a origem exata da prévia Web. Consulte a URL pública `https://SEU_SERVICO/api/health` antes de abrir o app.
3. No editor do FlutLab, abra `lib/core/config/api_config.dart` e substitua a string vazia de `backendOnlineUrl` por `https://SEU_SERVICO/api`. Não cole ali um token de administrador. Salve e execute o app novamente.
4. Se a prévia Web indicar que a origem não é permitida, abra a prévia no navegador, copie a origem (`https://dominio`, sem o restante do caminho) para `CORS_ORIGINS` no servidor e reinicie-o. Apps Android não usam CORS.

No modo de teste do passo 2, o SQLite está num disco temporário: alterações feitas em pontos podem desaparecer após um reinício ou nova publicação, e o `seed` restaura os quatro exemplos. Para manter cadastros feitos por pessoas, use um disco persistente ou migre para um banco hospedado antes de colocar o app em produção. No Render, o disco persistente exige um plano pago. O endereço da API é público, mas `ADMIN_API_TOKEN` deve ficar somente nas variáveis do servidor.

O Android permite HTTP local **apenas no build debug**. Para publicar builds release, configure uma API HTTPS. Esta entrega não inclui hospedagem.

## 3. O que mudou no app

- Os bairros, categorias, ecopontos, orientações e dicas agora vêm da API.
- A busca de ecopontos consulta nome, endereço e bairro; pode combinar busca e categoria.
- As distâncias são calculadas em **linha reta**, usando o ponto escolhido como origem. Não são trajetos de carro ou caminhada.
- O mapa inicial e a tela de descarte consultam a mesma tabela de pontos.
- A localização escolhida na confirmação é passada à próxima tela. Ela não é substituída automaticamente pelo GPS.
- O botão “Usar minha localização” consulta o GPS com tratamento de permissão e falha.
- Ao escolher um bairro, o mapa abre em uma referência de Belém e exige que você marque o ponto. Ainda não há geocodificação de bairros ou endereços.
- As telas mostram carregamento, lista vazia, falha e opção de repetir a consulta.
- O guia não cria um segundo `MaterialApp`; voltar mantém a navegação anterior.

A localização fica na memória do aplicativo durante o uso. As coordenadas são enviadas à API para calcular distância, mas esta versão não as salva no banco. Não há login de morador nesta etapa.

## 4. Tabelas do banco

| Tabela | Conteúdo | Relação |
| --- | --- | --- |
| `bairros` | `id`, nome, cidade e UF | Um bairro pode ter vários ecopontos. |
| `categorias` | `id`, código e nome | Uma categoria pode ter vários ecopontos. |
| `ecopontos` | Nome, endereço, categoria, bairro, horário, latitude, longitude, indicação de demonstração e datas de atualização | `categoria_id` e `bairro_id` são chaves estrangeiras. |
| `residuos` | Código, título, descrição e ordem | Conteúdo da aba “Tipos de resíduos”. |
| `dicas` | Texto e ordem | Conteúdo da aba “Dicas”. |

Cada ecoponto tem uma categoria nesta primeira versão, acompanhando o modelo original. Para pontos que aceitem várias categorias, uma próxima migração pode adicionar uma tabela de associação. A lista inicial de bairros veio do código enviado e não é um cadastro oficial completo.

O arquivo `backend/src/database.js` cria a versão 1 do banco. Mudanças futuras na estrutura devem criar novas migrações; não é preciso apagar o banco dos usuários.

## 5. Rotas

| Método e caminho | Função | Acesso |
| --- | --- | --- |
| `GET /api/health` | Verificar funcionamento | Público |
| `GET /api/bairros?busca=nazare` | Listar/buscar bairros | Público |
| `GET /api/categorias` | Listar categorias | Público |
| `GET /api/ecopontos` | Listar, filtrar e ordenar pontos por distância | Público |
| `GET /api/ecopontos/:id` | Consultar um ponto | Público |
| `POST /api/ecopontos` | Cadastrar ponto | Token administrativo |
| `PUT /api/ecopontos/:id` | Atualizar os campos do ponto | Token administrativo |
| `DELETE /api/ecopontos/:id` | Excluir ponto | Token administrativo |
| `GET /api/residuos` | Consultar orientações | Público |
| `GET /api/dicas` | Consultar dicas | Público |

Filtros opcionais de `/api/ecopontos`:

- `busca`: nome, endereço ou bairro; ignora acentos e maiúsculas.
- `categoria`: código obtido de `/api/categorias` (`Reciclaveis`, `Eletronicos` ou `Oleo` nos exemplos).
- `bairro_id`: ID inteiro do bairro.
- `latitude` e `longitude`: devem ser informadas juntas; habilitam ordenação e `distancia_km`.
- `raio_km`: entre 0 e 200; exige latitude e longitude.

Exemplo: `http://localhost:3000/api/ecopontos?categoria=Reciclaveis&latitude=-1.4558&longitude=-48.4788&raio_km=5`

Listagens retornam `{ "data": [...] }`; ecopontos também retornam `total`. Um ponto retorna `{ "data": {...} }`. Falhas retornam `{ "error": { "message": "..." } }` com status HTTP apropriado. Exclusão bem-sucedida retorna `204`, sem corpo.

## 6. Cadastrar, editar e excluir pontos

As consultas do app funcionam sem token. Para habilitar alterações, gere uma credencial no terminal:

```bash
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Cole o resultado em `ADMIN_API_TOKEN=` no arquivo `backend/.env` e reinicie a API. Nunca coloque essa credencial no código Flutter, no GitHub ou em um app distribuído. Ela serve ao administrador do protótipo; um painel com contas e permissões poderá substituí-la depois.

No Postman:

1. Método `POST`, URL `http://localhost:3000/api/ecopontos`.
2. Na aba Authorization, tipo **Bearer Token**, informe o token gerado.
3. Em Body, selecione **raw / JSON** e informe:

```json
{
  "nome": "Ponto de teste do grupo",
  "endereco": "Endereço fictício para teste, 10",
  "categoria_id": 1,
  "bairro_id": 11,
  "horario": "Seg a Sex, 8h às 17h",
  "latitude": -1.4558,
  "longitude": -48.4788,
  "demonstrativo": true
}
```

Consulte `/api/bairros` e `/api/categorias` para usar IDs existentes no seu banco. No seed inicial, o bairro de ID 11 é Nazaré. Para dados reais, valide o local, os materiais aceitos e o horário antes de cadastrar com `demonstrativo: false`.

Para editar, use `PUT /api/ecopontos/ID` com todos os campos do mesmo JSON. Se omitir `demonstrativo`, o valor atual é preservado. Para excluir, use `DELETE /api/ecopontos/ID`, com o mesmo Bearer Token. Atualize o mapa para visualizar a mudança.

## 7. Testes

```bash
cd backend
npm test
```

Os testes da API usam banco temporário: consultas, filtros, distâncias, CRUD, token, CORS, validação, referências e persistência após reabrir o banco. Eles não alteram o banco de desenvolvimento.

Na raiz do projeto:

```bash
flutter analyze
flutter test
```

Os testes do cliente Flutter verificam os filtros enviados, a conversão dos dados, respostas vazias, falhas de rede e timeout.

Validação desta entrega: os 9 testes automatizados do backend passaram em Node.js 24.19.0. As dependências do Flutter foram resolvidas com Flutter 3.47.5 / Dart 3.13.4, e os problemas apontados na primeira análise foram corrigidos. A execução final da análise e dos testes Flutter não pôde ser confirmada porque o ambiente temporário foi reiniciado. Execute os dois comandos acima antes de usar no dispositivo; GPS e mapa ainda precisam de teste no celular.

## 8. Próximas funcionalidades

Esta etapa conecta as telas existentes. Avisos de coleta, calendário por bairro, posição de caminhão em tempo real, notificações push e painel administrativo visual ainda precisam ser implementados. O aplicativo ainda não possui dados municipais verificados.

O SQLite é adequado para iniciar este protótipo com uma instância de servidor. Ao hospedar, use um volume persistente para `DB_FILE`; um disco temporário pode perder o banco após reiniciar ou publicar. Quando o projeto exigir múltiplas instâncias ou maior concorrência de escrita, podemos migrar para PostgreSQL.

## Organização

- `backend/src/app.js`: rotas, validação e autorização.
- `backend/src/database.js`: estrutura e abertura do banco.
- `backend/src/seed.js`: carga inicial demonstrativa.
- `backend/src/config.js`: variáveis do ambiente.
- `backend/test/`: testes da API.
- `lib/core/services/siga_api.dart`: comunicação HTTP do Flutter.
- `lib/core/services/location_service.dart`: consulta do GPS.
- `lib/core/models/siga_models.dart`: conversão das respostas JSON.
- `lib/core/widgets/`: mensagens e detalhes compartilhados.
- `lib/features/`: telas conectadas à API.

Referências técnicas: [Node.js SQLite](https://nodejs.org/api/sqlite.html), [Express](https://expressjs.com/), [HTTP no Flutter](https://docs.flutter.dev/cookbook/networking/fetch-data).
