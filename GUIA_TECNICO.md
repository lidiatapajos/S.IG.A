# SIGA — rastreamento com aparelho real

## Alterações

- Atalho **Onde está o caminhão?** no Flutter: mapa consulta a API a cada 5 segundos.
- **/rastreador** usa o GPS real do navegador do aparelho autorizado. Não instala app adicional.
- **/admin** cria/revoga sessões, consulta denúncias, exibe fotos e altera o andamento.
- Chaves individuais de 4 horas, armazenadas como hash. O token administrativo nunca vai ao rastreador nem ao Flutter.
- Apenas a última posição: sem histórico de trajetos. Após 30 segundos, sinal desatualizado; após 120 segundos, oculto. Limpeza de coordenadas no servidor a cada 20 segundos e nas consultas. Encerrar/revogar apaga a sessão assim que o servidor recebe a requisição.
- Validação de coordenadas, precisão até 100 m, idade do GPS e ordem das atualizações.
- Antiabuso por IP: 300 requisições/minuto na API, 60/minuto no admin, 120/minuto no envio de posição, 5 tentativas de denúncia/15 minutos. Limites em memória para uma instância.
- Fotos decodificadas de verdade e normalizadas sem metadados no servidor. Novos uploads Cloudinary são autenticados; painel recebe fotos pela API autorizada.
- Migração SQLite v4 preserva registros existentes. Listagem administrativa paginada não carrega os BLOBs.
- Android: `br.com.siga.app`, alvos Java/Kotlin 17, menor uso de RAM no Gradle e assinatura própria obrigatória para release.
- Fotos orientadas corretamente no Flutter; processamento em isolate no Android/iOS. No navegador, `compute` não cria isolate separado. Formulário bloqueia mudanças durante envio.

## 1. Backend local

Instale Node.js 24. Na pasta `backend`:

```bash
npm ci
cp .env.example .env
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Copie a chave para `ADMIN_API_TOKEN` no `.env`. Não a publique. Depois:

```bash
npm run seed
npm test
npm start
```

Abra `http://localhost:3000/api/health` e `http://localhost:3000/admin`.
O seed contém ecopontos fictícios. Execute uma vez no banco demonstrativo, não em cada inicialização: ele pode reinserir exemplos removidos.

## 2. Publicar a API para acessar pelo celular

O celular precisa de URL **HTTPS**. `http://192.168...` normalmente não permite GPS no navegador. `localhost` no celular é o próprio celular.

Atualize a pasta `backend` no seu serviço. Instalação: `npm ci --omit=dev`. Inicialização: `npm start`. Configure:

| Variável | Valor/ação |
|---|---|
| `NODE_ENV` | `production` |
| `ADMIN_API_TOKEN` | Chave aleatória própria de pelo menos 32 caracteres |
| `DB_FILE` | Caminho absoluto no volume persistente; por exemplo `/var/data/siga.db`, somente se esse for seu ponto de montagem |
| `PERSISTENT_STORAGE_CONFIRMED` | `true`, após verificar o volume persistente |
| `TRUST_PROXY_HOPS` | Quantidade exata de proxies confiáveis; no Render geralmente `1`, confirme a topologia |
| `CORS_ORIGINS` | Origem HTTPS da própria API e origens do Flutter Web, separadas por vírgula, sem barra final |

Exemplo para seu endereço habitual:

```text
CORS_ORIGINS=https://s-ig-a.onrender.com,http://localhost:8080
```

Em produção, sem token e confirmação de persistência, o servidor recusa iniciar. A flag **não cria nem inspeciona disco**: configure um volume real. Se o plano não oferecer persistência, use uma hospedagem com volume ou planeje a migração do banco. Mantenha uma instância nesta versão SQLite. Preserve o banco antigo antes de trocar `DB_FILE` e teste um reinício/redeploy. Faça backups consistentes; copiar somente `.db` durante escrita pode perder dados no WAL.

Cloudinary é opcional. Sem as três credenciais, fotos ficam no SQLite privado. Credenciais incompletas causam erro de configuração. **Fotos antigas públicas no Cloudinary exigem migração/remoção no provedor**: novos uploads são protegidos, mas URLs antigas não são revogadas por esta atualização.

Esta entrega contém código. Não altera automaticamente seu serviço já hospedado.

## 3. Teste com aparelho real

1. No computador: abra `https://SUA-API/admin` e entre com `ADMIN_API_TOKEN`.
2. Informe **Caminhão da equipe 1** e toque em **Gerar sessão de 4 horas**.
3. Copie a chave gerada para o celular autorizado. Não entregue o token administrativo.
4. No celular: abra `https://SUA-API/rastreador`, cole a chave, leia o aviso e marque a autorização.
5. Toque em **Iniciar compartilhamento**, permita GPS e aguarde **Compartilhando**.
6. Mantenha página visível, tela acesa, internet e GPS ligados. Em locais fechados o GPS pode não atingir a precisão necessária.
7. Em outro aparelho/computador, no SIGA, abra **Onde está o caminhão?**. A posição aparece normalmente em 5–10 segundos após o primeiro sinal aceito, mais latência da rede.
8. Caminhe alguns metros em um lugar seguro e confira o marcador. O trajeto não é inventado.
9. Encerre no transmissor ou painel. O marcador some na próxima consulta.

Não rastreia por número de telefone/IMEI, nem funciona oculto/em segundo plano. Ao trocar de aba/aplicativo ou bloquear a tela, a página tenta encerrar a sessão; gere outra chave para recomeçar. Sem conexão para avisar o servidor, a posição envelhece e sai do mapa em até 2 minutos. GPS pode ser simulado pelo usuário do aparelho; não há autenticação de hardware.

A localização é pública: use aparelho da equipe, com consentimento, sem expor residência/rotina. Não opere o celular ao dirigir. Não há vínculo com a prefeitura, histórico de trajetos nem previsão de chegada. Proxies/hospedagem ainda podem guardar logs técnicos.

## 4. Flutter e APK

Na raiz, com Flutter instalado:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=https://SUA-API/api
```

Para Android, selecione o celular com `flutter run` e a mesma definição de URL. O padrão continua `https://s-ig-a.onrender.com/api`, que precisa receber este backend atualizado.

Não habilite `DEMO_MODE=true` para rastrear. Esse modo serve só para catálogo/navegação; envio, consulta de denúncia e rastreamento exigem API. Os mosaicos do mapa precisam de internet.

APK de teste: `flutter build apk --debug`. Ele serve para demonstração, mas não é um release assinado com sua chave.

Para release, com Java 17, gere a chave na sua máquina:

```bash
mkdir -p android/keys
keytool -genkeypair -v -keystore android/keys/siga-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias siga
cp android/key.properties.example android/key.properties
```

Preencha as senhas no arquivo copiado; `storeFile=keys/siga-release.jks` é relativo a `android`. Guarde chave/senhas fora do GitHub. Depois:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://SUA-API/api
```

O release não usa mais assinatura debug silenciosamente. O novo identificador pode gerar uma instalação separada da versão `com.example.siga`.

Java 11 como alvo de bytecode não era, por si só, incompatível com executar Gradle em Java 17. A mudança padroniza os alvos; a cadeia Flutter/Android SDK/Gradle ainda deve ser validada no seu ambiente.

## 5. Verificação

Veja `VALIDACAO.md` para o que foi efetivamente executado. Para repetir:

```bash
cd backend
npm ci
npm test
npx playwright install chromium
node scripts/browser-smoke.mjs
```

O teste do navegador usa GPS simulado e não substitui a seção 3. Teste no celular: câmera/galeria, permissões negadas, denúncia, protocolo, alteração de status no painel, deslocamento, perda de sinal, encerramento e reinício da API. A compilação e os testes Flutter precisam passar antes da apresentação.

Limitações restantes: sem idempotência no envio de denúncia (uma conexão perdida após gravar pode causar duplicação em nova tentativa), sem moderação automática, sem contas individuais de operadores, sem política de retenção municipal nem integração oficial. Para múltiplas instâncias, banco e limitador precisam de arquitetura compartilhada. Código não garante vitória nem ausência absoluta de falhas. Confira se o regulamento permite código prévio/bibliotecas/IA; ele não foi fornecido.

## Rotas novas

| Método/rota | Credencial | Uso |
|---|---|---|
| `POST /api/admin/rastreamento` | Admin | `{ "nome": "Caminhão 1" }`, retorna chave uma vez |
| `GET /api/admin/rastreamento` | Admin | Lista sessões sem chaves |
| `DELETE /api/admin/rastreamento/:id` | Admin | Revoga e apaga posição |
| `PUT /api/rastreamento/:id/posicao` | Chave do aparelho no Bearer | `latitude`, `longitude`, `precisao` em metros e `capturado_em` Unix em milissegundos do GPS |
| `DELETE /api/rastreamento/:id` | Chave do aparelho | Encerra |
| `GET /api/rastreamento` | Público | Posições recentes, idade e estado do sinal |

Referências: [Geolocation / MDN](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/watchPosition), [Cloudinary](https://cloudinary.com/documentation/control_access_to_media), [Express/proxies](https://expressjs.com/en/guide/behind-proxies.html).
