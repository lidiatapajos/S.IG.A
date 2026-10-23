# SIGA Rastreador — Android (primeira versão)

Este pacote adiciona **um SEGUNDO aplicativo Flutter** (`siga_rastreador/`) ao repositório SIGA, sem mudar o aplicativo do cidadão nem o backend atual.

## Como juntar ao repositório

Copie as pastas `siga_rastreador/` e `.github/workflows/build-rastreador.yml` para a raiz do repositório **S.IG.A**. Faça commit.

No GitHub, abra **Actions > Gerar APK SIGA Rastreador > Run workflow** e, quando terminar, baixe o artifact `SIGA-Rastreador-Android-debug`. Instale o APK de teste nos aparelhos da equipe. APK debug é apenas para testes; para distribuir oficialmente é necessário criar e proteger assinatura release.

### No VS Code

```bash
cd siga_rastreador
flutter create --platforms=android --org br.com.siga .
flutter pub get
flutter run
```

> Flutter create completa arquivos de plataforma que o ZIP original não continha, como o gradle wrapper. Rode sem `--overwrite` para preservar as configurações customizadas.

### Como testar

1. Render precisa estar no ar, com backend `https://siga-05o2.onrender.com` e `DB_FILE` persistente se quiser manter sessões entre deploys.
2. Abra `/admin`, entre com a chave de administrador e gere **uma nova sessão para cada celular** (nome SIGA-001, SIGA-002...).
3. Em cada celular, instale `SIGA Rastreador`, cole a própria chave de sessão, marque o consentimento e toque em **Iniciar transmissão**.
4. Permita GPS **preciso** e notificações. Espere receber a confirmação.
5. Bloqueie a tela. O Android deve manter uma notificação de localização ativa enquanto o serviço estiver rodando.
6. Em outro celular ou navegador, abra `https://siga-05o2.onrender.com/api/rastreamento`. Cada sessão ativa deve aparecer com `status: ao_vivo` e coordenadas distintas.
7. Toque em **Parar e desvincular** para solicitar a exclusão da sessão do backend.

### Limitações que ainda existem

- O **backend atual** expira autorizações após 4 horas e oculta posições sem atualização depois de até 2 minutos. Requer nova chave para outra sessão.
- Se o Android encerrar o serviço, o celular ficar sem bateria ou reiniciar, é necessário reabrir o rastreador e iniciar de novo. **Não** há reinício automático ou GPS invisível.
- Sem internet, não há fila persistente de coordenadas nesta versão. O app tenta enviar na próxima oportunidade, se o serviço continuar vivo.
- A posição é visível na API/mapa públicos do SIGA enquanto ativa. Use somente aparelhos autorizados da equipe, com consentimento.
- No Android, algumas marcas limitam serviços mesmo com notificação; teste em aparelhos reais. Permitir uso irrestrito de bateria pode ajudar, se o responsável aceitar.
- Não compartilhar chaves no GitHub ou em capturas de tela. A chave do rastreador é **diferente** de `ADMIN_API_TOKEN`, que fica apenas no Render/painel admin.
- O app usa a URL pública do projeto atual. Se o domínio Render mudar, ajuste `lib/tracking_api.dart` e gere outro APK.
- **Não foi possível compilar um APK aqui** porque não há Flutter SDK no ambiente de preparação. Os arquivos foram verificados estruturalmente, mas precisam passar pelo `flutter analyze`/build do workflow.

### Versões adotadas

Flutter >=3.22; Dart >=3.4 (compatíveis com Dart 3.8), `flutter_foreground_task 9.2.2`, `geolocator 13.0.4`, `http 1.2.2`. A versão do plugin do foreground foi fixada para evitar alterações de compatibilidade que surgiram em versões mais recentes.
