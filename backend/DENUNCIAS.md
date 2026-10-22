# Denúncias anônimas — backend do S.I.G.A (MVP)

`POST /api/denuncias` aceita JSON `{ "categoria": "entulho", "descricao": "...", "latitude": -1.45, "longitude": -48.49, "foto_base64": "data:image/jpeg;base64,..." }`. Foto JPG/PNG <= 2 MiB. A API retorna **201** e `{ "data": { "protocolo": "...", "status": "pendente" } }` somente após gravar o registro.

`GET /api/denuncias/protocolo/:codigo` permite ao detentor do protocolo consultar status (código aleatório, 48 dígitos hexadecimais).

Rotas administrativas protegidas por `Authorization: Bearer <ADMIN_API_TOKEN>`:
- `GET /api/admin/denuncias`: até 50 denúncias; `proxima_pagina` fornece cursor para `?antes=ID`
- `GET /api/admin/denuncias/:id/foto`: bytes da foto via API autorizada (local ou Cloudinary)
- `PATCH /api/admin/denuncias/:id/status`: `{ "status": "em_analise" }`

O armazenamento usa **Cloudinary** se `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` e `CLOUDINARY_API_SECRET` estiverem configurados. Caso contrário, por conveniência do MVP, a imagem fica em **BLOB privado no mesmo SQLite** (migração v3). A foto não é exposta na rota pública de status. É indispensável usar disco persistente e backups no Render, ou imagens e denúncias podem ser perdidas num redeploy.

**Não exponha ADMIN_API_TOKEN no Flutter.** Gere com 32+ caracteres e use somente no painel `/admin`. Esta versão limita a 5 tentativas por IP/15 minutos, decodifica imagens de verdade e remove metadados no servidor. Limite de 16 megapixels além dos 2 MiB. Novos uploads Cloudinary usam `type=authenticated`; fotos antigas públicas exigem migração/remoção no provedor. Ainda são necessárias política de retenção, moderação e backups. Consulte `GUIA_HACKATHON.md`.
