'use strict';
(() => {
  const $ = id => document.getElementById(id);
  let token = '';
  let cursor = null;
  const status = message => { $('status').textContent = message; };
  const el = (tag, text) => { const node = document.createElement(tag); if (text !== undefined) node.textContent = String(text); return node; };
  async function api(path, options = {}) {
    const headers = { Authorization: `Bearer ${token}`, ...(options.body ? { 'Content-Type': 'application/json' } : {}) };
    const response = await fetch(path, { ...options, headers, cache: 'no-store' });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error?.message || `Erro HTTP ${response.status}`);
    }
    return response.status === 204 ? null : response.json();
  }
  async function execute(fn) { try { await fn(); } catch (e) { status(e.message); } }
  async function sessions() {
    const result = await api('/api/admin/rastreamento');
    $('sessions').replaceChildren();
    for (const s of result.data || []) {
      const item = el('div');
      item.className = 'card';
      item.append(el('p', `${s.nome} — expira: ${new Date(s.expira_em).toLocaleString('pt-BR')}`));
      const remove = el('button', 'Revogar aparelho');
      remove.type = 'button';
      remove.className = 'danger';
      remove.addEventListener('click', () => execute(async () => {
        if (!confirm(`Revogar ${s.nome}?`)) return;
        await api(`/api/admin/rastreamento/${encodeURIComponent(s.id)}`, { method: 'DELETE' });
        await sessions();
        status('Aparelho revogado.');
      }));
      item.append(remove);
      $('sessions').append(item);
    }
  }
  async function reports(reset = true) {
    if (reset) { cursor = null; $('reports').replaceChildren(); }
    const url = '/api/admin/denuncias' + (cursor ? `?antes=${encodeURIComponent(cursor)}` : '');
    const result = await api(url);
    const data = result.data || [];
    for (const r of data) {
      const item = el('div'); item.className = 'card';
      item.append(el('p', `Denúncia #${r.id} — ${r.categoria}`));
      item.append(el('p', r.descricao || 'Sem descrição'));
      const select = el('select');
      for (const value of ['pendente','em_analise','em_atendimento','resolvida','rejeitada']) {
        const option = el('option', value.replaceAll('_', ' ')); option.value = value;
        option.selected = value === r.status; select.append(option);
      }
      const save = el('button', 'Salvar status');
      save.addEventListener('click', () => execute(async () => {
        await api(`/api/admin/denuncias/${r.id}/status`, { method: 'PATCH', body: JSON.stringify({ status: select.value }) });
        status(`Denúncia #${r.id} atualizada.`);
      }));
      item.append(select, save); $('reports').append(item);
    }
    cursor = data.length ? data[data.length - 1].id : null;
    $('more').hidden = data.length < 50;
  }
  $('connect').addEventListener('click', () => execute(async () => {
    token = $('token').value.trim();
    if (!token) throw new Error('Informe a credencial administrativa.');
    await sessions(); await reports();
    $('token').value = '';
    status('Conectado ao painel administrativo.');
  }));
  $('logout').addEventListener('click', () => {
    token = ''; $('token').value = ''; $('key').value = ''; $('secret').hidden = true;
    $('sessions').replaceChildren(); $('reports').replaceChildren(); $('more').hidden = true;
    status('Sessão encerrada.');
  });
  $('create').addEventListener('click', () => execute(async () => {
    if (!token) throw new Error('Entre com a credencial primeiro.');
    const result = await api('/api/admin/rastreamento', { method: 'POST', body: JSON.stringify({ nome: $('name').value.trim() }) });
    $('key').value = result.data.chave;
    $('secret').hidden = false;
    await sessions(); status('Sessão criada. Copie a chave para o celular motorista.');
  }));
  $('refresh').addEventListener('click', () => execute(async () => { await reports(); status('Denúncias atualizadas.'); }));
  $('more').addEventListener('click', () => execute(() => reports(false)));
})();
