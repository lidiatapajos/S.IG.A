# Registro de validação desta entrega

## Executado

- Node.js 24.19.0.
- `npm test`: **23 testes aprovados**, zero falhas.
- `npm audit --audit-level=moderate`: **0 vulnerabilidades conhecidas reportadas** para o lockfile final, incluindo dependências de desenvolvimento. Isso não certifica ausência de falhas no código.
- Verificação sintática JavaScript do servidor, painel e transmissor.
- Testes HTTP com SQLite em memória/disco: catálogo, filtros, distâncias, CRUD, autenticação, CORS, persistência, denúncia, foto, mudança de status e migração v3→v4.
- Segurança: limite de taxa com 429/Retry-After, rejeição de falsa imagem PNG, remoção de EXIF no servidor.
- Rastreamento: sessão protegida, hash da chave, isolamento entre aparelhos, coordenadas/precisão/idade do GPS, posições fora de ordem, atualização de coordenadas, sinal desatualizado, remoção do mapa, expiração e revogação.
- Script real `public/tracker.js` executado em VM com DOM/GPS simulados, conectado à API HTTP real: bloqueio sem consentimento, envio inicial, deslocamento e encerramento. **Não é teste em celular nem validação visual do navegador.**

## Não validado neste ambiente

- Flutter SDK indisponível: não foram executados `flutter analyze`, `flutter test` nem build de APK. Os três testes Flutter de rastreamento foram adicionados, mas ainda precisam rodar.
- O Chromium chegou a ser instalado para o smoke test, porém sua inicialização foi bloqueada pelo ambiente: `socket() failed: Operation not permitted`. Não foi contornada a restrição. O smoke test permanece em `backend/scripts/browser-smoke.mjs` para executar em máquina/CI compatível.
- Não houve deploy no serviço Render existente, configuração real de volume persistente, assinatura com chave do proprietário nem uso de GPS de aparelho físico.
- O caminho Cloudinary autenticado não foi exercitado com credenciais reais. Novos uploads usam acesso autenticado; conteúdo legado público deve ser tratado no provedor.
- Não foi fornecido regulamento do hackathon para validar elegibilidade.

## Antes de apresentar

Siga `GUIA_HACKATHON.md`. Publique a API com as variáveis novas, confirme persistência após reiniciar, execute as verificações Flutter e teste com celular real autorizado. O workflow em `.github/workflows/checks.yml` faz testes de backend/navegador, análise/testes Flutter e gera APK debug ao ser executado no GitHub; não foi executado nesta entrega. Ele usa Flutter stable: após obter um build verde, preserve o `pubspec.lock` produzido e fixe a versão do SDK usada para repetir o build.

Os dados de ecopontos continuam explicitamente demonstrativos. O mapa do caminhão recebe localização real quando o aparelho opta por compartilhar; não representa frota municipal oficial. A atualização é por polling de 5 segundos, com envelhecimento do sinal. Não há rastreamento oculto ou em segundo plano.
