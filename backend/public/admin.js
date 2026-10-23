'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const names = {pendente:'Pendente',em_analise:'Em análise',em_atendimento:'Em atendimento',resolvida:'Resolvida',rejeitada:'Rejeitada'};
  const colors = {pendente:'warn',em_analise:'info',em_atendimento:'info',resolvida:'good',rejeitada:'bad'};
  let token = '', cursor = null, reports = [], sessions = [];
  const el = (tag, text, className) => { const n = document.createElement(tag); if (text !== undefined) n.textContent = String(text); if (className) n.className = className; return n; };
  const badge = (text, type = 'neutral') => el('span', text, 'badge ' + type);
  const fmt = value => { const d = new Date(value); return value && !Number.isNaN(d.getTime()) ? d.toLocaleString('pt-BR') : 'Não informado'; };
  function toast(message, error = false) { const n = el('div', message, 'toast' + (error ? ' error' : '')); $('toasts').append(n); setTimeout(() => n.remove(), 4500); }
  async function api(path, options = {}) {
    const response = await fetch(path, { ...options, headers: { Authorization: 'Bearer ' + token, ...(options.body ? {'Content-Type':'application/json'} : {}) }, cache:'no-store' });
    if (!response.ok) { const data = await response.json().catch(() => ({})); throw new Error(data.error?.message || 'Erro HTTP ' + response.status); }
    return response.status === 204 ? null : response.json();
  }
  async function run(button, fn) {
    if (button.disabled) return;
    const original = button.textContent; button.disabled = true; button.textContent = 'Aguarde…';
    try { await fn(); } catch (error) { toast(error.message, true); }
    finally { button.disabled = false; button.textContent = original; }
  }
  function page(name) {
    for (const key of ['dashboard','denuncias','rastreadores']) $(key).hidden = key !== name;
    document.querySelectorAll('[data-page]').forEach(b => b.classList.toggle('active', b.dataset.page === name));
    const title = {dashboard:'Visão geral',denuncias:'Denúncias',rastreadores:'Rastreadores'};
    $('page-title').textContent = title[name];
    $('page-description').textContent = {dashboard:'Acompanhe as operações do SIGA.',denuncias:'Gerencie os registros recebidos.',rastreadores:'Controle as sessões de localização.'}[name];
  }
  function stats() {
    $('total').textContent = reports.length;
    $('pending').textContent = reports.filter(r => r.status === 'pendente').length;
    $('resolved').textContent = reports.filter(r => r.status === 'resolvida').length;
    $('trackers').textContent = sessions.length;
    $('session-count').textContent = sessions.length;
    const recent = $('recent'); recent.replaceChildren();
    if (!reports.length) recent.append(el('div','Nenhuma denúncia carregada.','empty'));
    for (const r of reports.slice(0,5)) {
      const row = el('div',undefined,'mini-row'), info = el('div');
      info.append(el('strong','#' + r.id + ' · ' + r.categoria),el('small',fmt(r.criado_em)));
      row.append(info,badge(names[r.status] || r.status,colors[r.status])); recent.append(row);
    }
    const summary = $('summary'); summary.replaceChildren();
    summary.append(el('div',sessions.length + ' sessão(ões) cadastrada(s)','mini-row'));
    summary.append(el('div',sessions.filter(s => new Date(s.expira_em).getTime() > Date.now()).length + ' autorização(ões) não expiradas','mini-row'));
    summary.append(el('p','Sessão autorizada não significa GPS transmitindo em tempo real.','meta'));
  }
  function renderSessions() {
    const root = $('sessions'); root.replaceChildren();
    if (!sessions.length) root.append(el('div','Nenhum aparelho autorizado.','empty'));
    for (const s of sessions) {
      const card = el('article',undefined,'item'), top = el('div',undefined,'item-top');
      const expired = new Date(s.expira_em).getTime() <= Date.now();
      top.append(el('strong',s.nome),badge(expired?'Expirada':'Autorizada',expired?'neutral':'good'));
      card.append(top,el('p','Expira: ' + fmt(s.expira_em),'meta'));
      if (s.recebido_em) card.append(el('p','Última atualização: ' + fmt(s.recebido_em),'meta'));
      const btn = el('button','Revogar acesso','secondary');
      btn.addEventListener('click', () => { if (!confirm('Revogar acesso de ' + s.nome + '?')) return; run(btn,async () => {
        await api('/api/admin/rastreamento/' + encodeURIComponent(s.id), {method:'DELETE'});
        sessions = sessions.filter(item => item.id !== s.id); renderSessions(); toast('Acesso revogado: ' + s.nome);
      }); });
      card.append(btn); root.append(card);
    }
    stats();
  }
  function renderReports() {
    const root = $('reports'); root.replaceChildren();
    const search = $('search').value.trim().toLocaleLowerCase('pt-BR'), filter = $('filter').value;
    const visible = reports.filter(r => (!filter || r.status === filter) && (!search || [r.id,r.categoria,r.descricao].some(v => String(v ?? '').toLocaleLowerCase('pt-BR').includes(search))));
    if (!visible.length) root.append(el('div','Nenhuma denúncia encontrada.','empty'));
    for (const r of visible) {
      const card = el('article',undefined,'item'), top = el('div',undefined,'item-top');
      const status = badge(names[r.status] || r.status,colors[r.status]);
      top.append(el('strong','#' + r.id + ' · ' + r.categoria),status);
      card.append(top,el('p',r.descricao || 'Sem descrição.','item-description'),el('div','Recebida: ' + fmt(r.criado_em),'meta'));
      const actions = el('div',undefined,'item-actions'), select = el('select');
      select.setAttribute('aria-label','Status da denúncia ' + r.id);
      for (const [key,label] of Object.entries(names)) { const option = el('option',label); option.value = key; option.selected = key === r.status; select.append(option); }
      const save = el('button','Salvar alteração','primary'); save.disabled = true;
      select.addEventListener('change', () => { save.disabled = select.value === r.status; });
      save.addEventListener('click', () => run(save,async () => {
        const next = select.value;
        await api('/api/admin/denuncias/' + encodeURIComponent(r.id) + '/status', {method:'PATCH',body:JSON.stringify({status:next})});
        r.status = next; status.textContent = names[next]; status.className = 'badge ' + colors[next];
        stats(); toast('Denúncia #' + r.id + ' atualizada para ' + names[next] + '.');
        save.textContent = 'Salvo ✓'; save.disabled = true;
      }));
      actions.append(select,save); card.append(actions); root.append(card);
    }
    stats();
  }
  async function loadSessions() { const result = await api('/api/admin/rastreamento'); sessions = result.data || []; renderSessions(); }
  async function loadReports(reset = true) {
    const url = '/api/admin/denuncias' + (!reset && cursor ? '?antes=' + encodeURIComponent(cursor) : '');
    const result = await api(url), items = result.data || [];
    reports = reset ? items : reports.concat(items);
    cursor = result.proxima_pagina ?? null;
    $('more').hidden = !cursor;
    renderReports();
  }
  async function refreshAll() { await Promise.all([loadSessions(),loadReports()]); toast('Dados atualizados com sucesso.'); }
  document.querySelectorAll('[data-page]').forEach(b => b.addEventListener('click', () => page(b.dataset.page)));
  document.querySelectorAll('[data-go]').forEach(b => b.addEventListener('click', () => page(b.dataset.go)));
  $('login-form').addEventListener('submit',e => { e.preventDefault(); run($('connect'),async () => {
    token = $('token').value.trim(); if (!token) throw new Error('Informe a credencial.');
    try { await Promise.all([loadSessions(),loadReports()]); } catch (error) { token = ''; throw error; }
    $('token').value = ''; $('login').hidden = true; $('content').hidden = false; $('logout').hidden = false;
    $('connected').textContent = '● Conectado'; $('connected').className = 'badge good'; toast('Acesso autorizado.');
  }); });
  $('logout').addEventListener('click', () => {
    token = ''; cursor = null; reports = []; sessions = []; $('login').hidden = false; $('content').hidden = true;
    $('logout').hidden = true; $('connected').textContent = '● Desconectado'; $('connected').className = 'badge neutral';
    $('key').value = ''; $('key-modal').hidden = true; page('dashboard'); toast('Sessão encerrada.');
  });
  $('refresh-all').addEventListener('click',() => run($('refresh-all'),refreshAll));
  $('refresh-reports').addEventListener('click',() => run($('refresh-reports'),async () => { await loadReports(); toast('Denúncias atualizadas.'); }));
  $('refresh-sessions').addEventListener('click',() => run($('refresh-sessions'),async () => { await loadSessions(); toast('Sessões atualizadas.'); }));
  $('more').addEventListener('click',() => run($('more'),async () => { await loadReports(false); toast('Mais denúncias carregadas.'); }));
  $('search').addEventListener('input',renderReports); $('filter').addEventListener('change',renderReports);
  $('create-form').addEventListener('submit',e => { e.preventDefault(); run($('create'),async () => {
    const name = $('name').value.trim(); if (name.length < 3) throw new Error('Informe pelo menos três caracteres.');
    const result = await api('/api/admin/rastreamento',{method:'POST',body:JSON.stringify({nome:name})});
    $('key').value = result.data.chave; $('key-modal').hidden = false;
    await loadSessions(); toast('Autorização criada. Copie a chave agora.');
  }); });
  const close = () => { $('key-modal').hidden = true; $('key').value = ''; };
  $('close-modal').addEventListener('click',close); $('done-modal').addEventListener('click',close);
  $('key-modal').addEventListener('click',e => { if (e.target === $('key-modal')) close(); });
  document.addEventListener('keydown',e => { if (e.key === 'Escape' && !$('key-modal').hidden) close(); });
  $('copy-key').addEventListener('click',() => run($('copy-key'),async () => {
    try { await navigator.clipboard.writeText($('key').value); }
    catch { $('key').focus(); $('key').select(); if (!document.execCommand('copy')) throw new Error('Selecione e copie a chave manualmente.'); }
    toast('Chave copiada.');
  }));
})();
