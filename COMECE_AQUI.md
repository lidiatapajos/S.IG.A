# S.I.G.A — Entrega e execução no VS Code

**Para esta versão com rastreamento, siga primeiro [GUIA_HACKATHON.md](GUIA_HACKATHON.md).** Ele detalha as variáveis obrigatórias, o painel `/admin`, o transmissor `/rastreador` e a assinatura Android.

Este projeto é um **protótipo acadêmico**, não um aplicativo oficial da Prefeitura de Belém. A interface é azul e verde e inclui localização, mapas, ecopontos, separação de resíduos e denúncias anônimas.

## Caminho rápido — usar no VS Code (Linux/Zorin, Windows ou macOS)

1. Extraia o ZIP e abra a pasta **S.IG.A-main** no VS Code (a pasta que contém `pubspec.yaml`).
2. Instale o Flutter SDK seguindo https://docs.flutter.dev/get-started/install e as extensões **Flutter** e **Dart** no VS Code.
3. Abra um terminal **na raiz do projeto**, rode `flutter doctor` e depois `flutter pub get`. No Linux/Zorin você também pode usar `./executar.sh api` ou `./executar.sh demo`.
4. Para abrir no Chrome: `flutter run -d chrome --web-port=8080`.
5. Se a API do Render não responder ou o navegador bloquear CORS, use a apresentação: `flutter run -d chrome --web-port=8080 --dart-define=DEMO_MODE=true`.
6. Também pode usar **Executar > Iniciar depuração (F5)** com as configurações em `.vscode/launch.json`.

**Importante:** o modo de demonstração mostra bairros e ecopontos **fictícios**, devidamente identificados; não envia denúncias de verdade. O modo normal usa a API `https://s-ig-a.onrender.com/api`.

## API hospedada no Render

Para usar outra API: `flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=https://SEU-RENDER.onrender.com/api`.

No Render, para testar via Chrome local, inclua o domínio `http://localhost:8080` em `CORS_ORIGINS` (junto com eventuais outras origens, separadas por vírgula). Essa variável só se aplica ao Flutter **Web**; Android não tem bloqueio CORS de navegador.

No modo real, as telas consultam `GET /api/bairros`, `/api/ecopontos`, `/api/categorias`, `/api/residuos`, `/api/dicas`. A tela de denúncias envia `POST /api/denuncias` e consulta `GET /api/denuncias/protocolo/:codigo`.

## Backend Node.js + SQLite — modo local (independente do Render)

Instale **Node.js 24**. Depois abra terminal na pasta `backend`:

```bash
npm ci
npm run seed
npm start
```

Abra `http://localhost:3000/api/health`. Para conectar o Flutter localmente:

```bash
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

Atenção: o backend precisa ser iniciado separadamente; ele não é executado pelo comando `flutter run`.

O backend armazena fotos de denúncias no Cloudinary, se as três credenciais `CLOUDINARY_*` estiverem configuradas. **Sem Cloudinary, este projeto atualizado usa armazenamento privado de imagens no SQLite para fins de MVP**. Não use essa opção para receber alto volume de fotos ou operar um serviço público; configure disco persistente, backup, regras de retenção e moderação para produção.

## Teste da denúncia

1. Entre por localização manual e marque um ponto no mapa.
2. Na tela principal, toque em **Denunciar descarte irregular**.
3. Selecione foto JPG/PNG (o app converte e reduz a foto), categoria, localização e descrição.
4. Envie. Somente quando a API responder HTTP 201 haverá tela de confirmação com protocolo.
5. Copie o protocolo e consulte em **Acompanhar denúncia**.
6. Se a API no Render ainda estiver com versão antiga (sem fallback SQLite/sem Cloudinary), o envio mostrará erro. **É preciso publicar a pasta `backend` atualizada** para que essa modalidade funcione.

## Observações para a apresentação

- O GPS do Chrome depende de permissão do navegador e de contexto seguro (`localhost` ou HTTPS). Se não funcionar, use **Escolher no mapa**.
- O mapa usa OpenStreetMap e depende de internet para carregar os mosaicos.
- Os ecopontos de demonstração não são endereços verificados.
- A confirmação de denúncia depende do backend real. O modo demo é só para apresentar telas e navegação.
- O código não exige login para denunciar. Não promete anonimato absoluto: hospedagem, redes e servidores podem registrar informações técnicas. Evite fotos com rostos e dados pessoais.
- O backend inclui o painel básico `/admin` para acompanhar denúncias e autorizar aparelhos, protegido por credencial administrativa. Não é uma central municipal de atendimento.
- No Render, SQLite pode perder dados após redeploy/restart sem disco persistente. Para produção, migre para armazenamento gerenciado e política de segurança adequada.

## Comandos úteis

```bash
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d chrome --web-port=8080
```

Para rodar em Android, conecte um dispositivo com depuração USB ou um emulador e use `flutter run` selecionando o dispositivo.
