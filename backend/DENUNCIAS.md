# Denúncias anônimas — backend do S.I.G.A (MVP)

`POST /api/denuncias` aceita JSON `{ "categoria": "entulho", "descricao": "...", "latitude": -1.45, "longitude": -48.49, "foto_base64": "data:image/jpeg;base64,..." }`. Foto JPG/PNG <= 2 MiB. A API retorna **201** e `{ "data": { "protocolo": "...", "status": "pendente" } }` somente após gravar o registro.

`GET /api/denuncias/protocolo/:codigo` permite ao detentor do protocolo consultar status (código aleatório, 48 dígitos hexadecimais).

Rotas administrativas protegidas por `Authorization: Bearer <ADMIN_API_TOKEN>`:
- `GET /api/admin/denuncias`: últimas 200 denúncias
- `GET /api/admin/denuncias/:id/foto`: foto no SQLite (ou redirecionamento da imagem externa)
- `PATCH /api/admin/denuncias/:id/status`: `{ "status": "em_analise" }`

O armazenamento usa **Cloudinary** se `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` e `CLOUDINARY_API_SECRET` estiverem configurados. Caso contrário, por conveniência do MVP, a imagem fica em **BLOB privado no mesmo SQLite** (migração v3). A foto não é exposta na rota pública de status. É indispensável usar disco persistente e backups no Render, ou imagens e denúncias podem ser perdidas num redeploy.

**Não exponha ADMIN_API_TOKEN no Flutter.** Gere no servidor com 32+ caracteres. Em produção implante limite de taxa, antispam/CAPTCHA, remoção/verificação server-side de metadados, política de retenção, revisão de conteúdo, autenticação administrativa e restrições para vazamento de informações. O app tenta reenquadrar fotos removendo metadados antes do envio, mas a segurança não deve depender só do cliente.
