'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const statusNames = {
    pendente: 'Pendente', em_analise: 'Em análise', em_atendimento: 'Em atendimento',
    resolvida: 'Resolvida', rejeitada: 'Rejeitada',
  };
  const statusStyle = {
    pendente: 'pending', em_analise: 'analysis', em_atendimento: 'analysis',
    resolvida: 'resolved', rejeitada: 'rejected',
  };
  let adminToken = '';
  let reports = [];
  let trackers = [];
  let nextPage = null;
  let revokeTarget = null;
  let photoUrl = null;
  let requestGeneration = 0;

  function node(tag, text, cls) {
    const element = document.createElement(tag);
    if (text !== undefined) element.textContent = String(text);
    if (cls) element.className = cls;
    return element;
  }
  function svg(icon) {
    const svgNode = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svgNode.classList.add('ico');
    svgNode.setAttribute('aria-hidden', 'true');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', '#i-' + icon);
    svgNode.append(use);
    return svgNode;
  }
  function empty(text) {
    const result = node('div', undefined, 'empty-state');
    result.append(svg('leaf'), node('p', text));
    return result;
  }
  function formatDate(value) {
    if (value === null || value === undefined || value === '') return 'Sem registro';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Data indisponível' : date.toLocaleString('pt-BR');
  }
  function badge(label, style = 'neutral') { return node('span', label, 'badge ' + style); }
  function alertUser(text, kind = 'success') {
    const toast = node('div', text, 'toast ' + kind);
    toast.setAttribute('role', kind === 'error' ? 'alert' : 'status');
    $('toast-region').append(toast);
    setTimeout(() => toast.remove(), 4500);
  }
  async function busy(button, callback) {
    if (button?.disabled) return;
    const previous = button ? button.innerHTML : '';
    if (button) {
      button.disabled = true;
      button.textContent = 'Aguarde…';
    }
    try { await callback(); }
    catch (error) { alertUser(error.message || 'Não foi possível concluir a ação.', 'error'); }
    finally {
      if (button) {
        button.innerHTML = previous;
        button.disabled = button.dataset.unchanged === 'true';
      }
    }
  }
  async function api(path, options = {}) {
    if (!adminToken) throw new Error('Faça login para continuar.');
    const response = await fetch(path, {
      ...options, cache: 'no-store',
      headers: {
        Authorization: 'Bearer ' + adminToken,
        ...(options.body ? { 'Content-Type': 'application/json' } : {}),
        ...(options.headers || {}),
      },
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error?.message || 'Erro HTTP ' + response.status);
    }
    return response.status === 204 ? null : response.json();
  }
  function view(page) {
    const names = ['overview', 'reports', 'tracking'];
    if (!names.includes(page)) return;
    for (const name of names) $('view-' + name).hidden = name !== page;
    document.querySelectorAll('[data-view]').forEach(button => {
      const active = button.dataset.view === page;
      button.classList.toggle('active', active);
      if (active) button.setAttribute('aria-current', 'page');
      else button.removeAttribute('aria-current');
    });
    window.scrollTo({ top: 0, behavior: 'auto' });
  }
  function setAuthenticated(yes) {
    $('login-panel').hidden = yes;
    $('app-content').hidden = !yes;
    $('logout').hidden = !yes;
    $('mobile-nav').hidden = !yes;
    $('connection-badge').textContent = yes ? '● Conectado' : 'Desconectado';
    $('connection-badge').className = 'connection ' + (yes ? 'connected' : 'disconnected');
    if (yes) view('overview');
  }
  function summaries() {
    const count = status => reports.filter(r => r.status === status).length;
    $('stat-total').textContent = reports.length;
    $('stat-pending').textContent = count('pendente');
    $('stat-resolved').textContent = count('resolvida');
    $('stat-trackers').textContent = trackers.length;
    $('session-count').textContent = trackers.length;
    const container = $('recent-reports');
    container.replaceChildren();
    if (!reports.length) return container.append(empty('Nenhuma denúncia carregada no momento.'));
    for (const r of reports.slice(0, 4)) {
      const row = node('div', undefined, 'recent-row');
      const left = node('div');
      left.append(node('strong', 'Denúncia #' + r.id + ' • ' + r.categoria), node('small', formatDate(r.criado_em)));
      row.append(left, badge(statusNames[r.status] || r.status, statusStyle[r.status] || 'neutral'));
      container.append(row);
    }
  }
  function renderReports() {
    const root = $('reports');
    root.replaceChildren();
    const filter = $('report-filter').value;
    const search = $('report-search').value.trim().toLocaleLowerCase('pt-BR');
    const filtered = reports.filter(r =>
      (!filter || r.status === filter) &&
      (!search || [r.id, r.categoria, r.descricao]
        .some(value => String(value ?? '').toLocaleLowerCase('pt-BR').includes(search))));
    $('reports-count').textContent = filtered.length + ' denúncia(s) encontrada(s) entre ' + reports.length + ' registro(s) carregado(s).';
    if (!filtered.length) root.append(empty('Nenhuma denúncia encontrada. Experimente alterar os filtros.'));
    for (const r of filtered) {
      const card = node('article', undefined, 'report-card');
      const heading = node('div', undefined, 'report-top');
      const statusBadge = badge(statusNames[r.status] || r.status, statusStyle[r.status] || 'neutral');
      heading.append(node('strong', 'Denúncia #' + r.id + ' • ' + r.categoria, 'report-title'), statusBadge);
      card.append(heading, node('div', r.descricao || 'Sem descrição informada.', 'report-description'));
      const meta = node('div', undefined, 'report-meta');
      const created = node('span'); created.append(svg('clock'), node('span', 'Recebida em ' + formatDate(r.criado_em)));
      meta.append(created);
      if (Number.isFinite(Number(r.latitude)) && Number.isFinite(Number(r.longitude)) && r.latitude !== null && r.longitude !== null) {
        const location = node('span');
        const link = node('a', 'Ver localização no mapa ↗');
        link.href = 'https://www.openstreetmap.org/?mlat=' + encodeURIComponent(r.latitude) + '&mlon=' + encodeURIComponent(r.longitude) + '#map=16/' + encodeURIComponent(r.latitude) + '/' + encodeURIComponent(r.longitude);
        link.target = '_blank'; link.rel = 'noopener noreferrer';
        location.append(svg('pin'), link); meta.append(location);
      }
      card.append(meta);
      const actions = node('div', undefined, 'report-actions');
      const control = node('div', undefined, 'control');
      const label = node('label', 'Andamento da denúncia');
      const select = node('select');
      select.id = 'status-' + r.id;
      label.htmlFor = select.id;
      for (const [value, name] of Object.entries(statusNames)) {
        const option = node('option', name);
        option.value = value;
        option.selected = value === r.status;
        select.append(option);
      }
      const save = node('button', 'Salvar', 'btn btn-primary');
      save.type = 'button';
      save.dataset.unchanged = 'true';
      save.disabled = true;
      select.addEventListener('change', () => {
        save.dataset.unchanged = String(select.value === r.status);
        save.disabled = select.value === r.status;
      });
      save.addEventListener('click', () => busy(save, async () => {
        const desired = select.value;
        const result = await api('/api/admin/denuncias/' + encodeURIComponent(r.id) + '/status', {
          method: 'PATCH', body: JSON.stringify({ status: desired }),
        });
        r.status = result.data?.status || desired;
        statusBadge.textContent = statusNames[r.status] || r.status;
        statusBadge.className = 'badge ' + (statusStyle[r.status] || 'neutral');
        select.value = r.status;
        save.dataset.unchanged = 'true';
        summaries();
        alertUser('Denúncia #' + r.id + ' atualizada para ' + statusNames[r.status] + '.');
        if ($('report-filter').value && $('report-filter').value !== r.status) renderReports();
      }));
      control.append(label, select);
      actions.append(control, save);
      card.append(actions);
      const tools = node('div', undefined, 'report-tools');
      const photo = node('button', undefined, 'mini-link');
      photo.type = 'button';
      photo.append(svg('eye'), node('span', 'Ver foto anexada'));
      photo.addEventListener('click', () => busy(photo, () => openPhoto(r.id)));
      tools.append(photo);
      card.append(tools);
      root.append(card);
    }
    $('more').hidden = nextPage === null;
    summaries();
  }
  function trackerState(session) {
    const now = Date.now();
    if (new Date(session.expira_em).getTime() <= now) return ['Expirada', 'neutral'];
    const received = new Date(session.recebido_em).getTime();
    if (session.recebido_em && Number.isFinite(received) && now - received < 120000 && now - received >= -5000) return ['Transmitindo', 'resolved'];
    return ['Aguardando GPS', 'analysis'];
  }
  function renderTrackers() {
    const root = $('sessions');
    root.replaceChildren();
    $('session-count').textContent = trackers.length;
    if (!trackers.length) root.append(empty('Ainda não há aparelhos autorizados. Gere uma chave ao lado.'));
    for (const s of trackers) {
      const card = node('article', undefined, 'session-card');
      const heading = node('div', undefined, 'session-top');
      const [status, tone] = trackerState(s);
      heading.append(node('strong', s.nome, 'session-name'), badge(status, tone));
      const details = node('div', undefined, 'session-meta');
      details.append(node('span', 'Autorização válida até ' + formatDate(s.expira_em)));
      details.append(node('span', 'Último sinal: ' + formatDate(s.recebido_em)));
      const footer = node('div', undefined, 'session-bottom');
      footer.append(node('span', 'ID: ' + String(s.id).slice(0, 8) + '…', 'session-id'));
      const revoke = node('button', 'Revogar acesso', 'btn btn-outline');
      revoke.type = 'button';
      revoke.addEventListener('click', () => {
        revokeTarget = s;
        $('confirm-text').textContent = 'Deseja revogar a autorização de “' + s.nome + '”? O aparelho não poderá continuar enviando localização com esta chave.';
        $('confirm-modal').hidden = false;
        $('cancel-revoke').focus();
      });
      footer.append(revoke);
      card.append(heading, details, footer);
      root.append(card);
    }
    summaries();
  }
  async function loadReports(reset = true) {
    const existing = reset ? null : nextPage;
    const url = '/api/admin/denuncias' + (existing ? '?antes=' + encodeURIComponent(existing) : '');
    const data = await api(url);
    const incoming = data.data || [];
    reports = reset ? incoming : reports.concat(incoming);
    nextPage = data.proxima_pagina ?? null;
    renderReports();
  }
  async function loadTrackers() {
    const data = await api('/api/admin/rastreamento');
    trackers = data.data || [];
    renderTrackers();
  }
  async function refresh() {
    await Promise.all([loadReports(), loadTrackers()]);
    alertUser('Informações atualizadas com sucesso.');
  }
  function cleanPhoto() {
    if (photoUrl) URL.revokeObjectURL(photoUrl);
    photoUrl = null;
    $('report-photo').removeAttribute('src');
    $('photo-modal').hidden = true;
  }
  async function openPhoto(id) {
    const response = await fetch('/api/admin/denuncias/' + encodeURIComponent(id) + '/foto', {
      headers: { Authorization: 'Bearer ' + adminToken }, cache: 'no-store',
    });
    if (!response.ok) {
      const body = await response.json().catch(() => ({}));
      throw new Error(body.error?.message || (response.status === 404 ? 'Esta denúncia não possui foto disponível.' : 'Não foi possível carregar a foto.'));
    }
    const blob = await response.blob();
    if (!blob.type.startsWith('image/')) throw new Error('A resposta não contém uma imagem válida.');
    cleanPhoto();
    photoUrl = URL.createObjectURL(blob);
    $('report-photo').src = photoUrl;
    $('photo-modal').hidden = false;
    $('close-photo').focus();
  }
  function closeKey() {
    $('key-modal').hidden = true;
    $('key').value = '';
  }
  function closeRevoke() {
    $('confirm-modal').hidden = true;
    revokeTarget = null;
  }
  function logout() {
    adminToken = '';
    requestGeneration++;
    reports = [];
    trackers = [];
    nextPage = null;
    closeKey();
    closeRevoke();
    cleanPhoto();
    $('token').value = '';
    setAuthenticated(false);
    alertUser('Você saiu do painel administrativo.', 'info');
  }

  document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => view(button.dataset.view)));
  document.querySelectorAll('[data-go]').forEach(button => button.addEventListener('click', () => view(button.dataset.go)));
  $('login-form').addEventListener('submit', event => {
    event.preventDefault();
    busy($('connect'), async () => {
      const candidate = $('token').value.trim();
      if (!candidate) throw new Error('Informe a credencial administrativa.');
      adminToken = candidate;
      const generation = ++requestGeneration;
      try { await Promise.all([loadReports(), loadTrackers()]); }
      catch (error) { adminToken = ''; reports = []; trackers = []; throw error; }
      if (generation !== requestGeneration) return;
      $('token').value = '';
      setAuthenticated(true);
      alertUser('Bem-vinda ao SIGA! Acesso autorizado.');
    });
  });
  $('logout').addEventListener('click', logout);
  $('refresh-all').addEventListener('click', () => busy($('refresh-all'), refresh));
  $('refresh').addEventListener('click', () => busy($('refresh'), async () => { await loadReports(); alertUser('Denúncias atualizadas.'); }));
  $('refresh-sessions').addEventListener('click', () => busy($('refresh-sessions'), async () => { await loadTrackers(); alertUser('Rastreadores atualizados.'); }));
  $('more').addEventListener('click', () => busy($('more'), async () => { await loadReports(false); alertUser('Mais denúncias carregadas.'); }));
  $('report-search').addEventListener('input', renderReports);
  $('report-filter').addEventListener('change', renderReports);
  $('create-form').addEventListener('submit', event => {
    event.preventDefault();
    busy($('create'), async () => {
      const name = $('name').value.trim();
      if (name.length < 3) throw new Error('Informe um nome com pelo menos 3 caracteres.');
      const result = await api('/api/admin/rastreamento', { method: 'POST', body: JSON.stringify({ nome: name }) });
      $('key').value = result.data.chave;
      $('key-modal').hidden = false;
      $('copy-key').focus();
      try { await loadTrackers(); }
      catch (error) { alertUser('Chave criada, mas não foi possível atualizar a lista: ' + error.message, 'error'); }
      alertUser('Autorização criada! Copie a chave do aparelho.');
    });
  });
  $('copy-key').addEventListener('click', () => busy($('copy-key'), async () => {
    const key = $('key').value;
    try { await navigator.clipboard.writeText(key); }
    catch (_) {
      $('key').focus(); $('key').select();
      if (!document.execCommand('copy')) throw new Error('Não foi possível copiar. Selecione a chave e copie manualmente.');
    }
    alertUser('Chave copiada para a área de transferência.');
  }));
  $('close-modal').addEventListener('click', closeKey);
  $('done-modal').addEventListener('click', closeKey);
  $('key-modal').addEventListener('click', e => { if (e.target === $('key-modal')) closeKey(); });
  $('cancel-revoke').addEventListener('click', closeRevoke);
  $('confirm-revoke').addEventListener('click', () => busy($('confirm-revoke'), async () => {
    const target = revokeTarget;
    if (!target) return;
    await api('/api/admin/rastreamento/' + encodeURIComponent(target.id), { method: 'DELETE' });
    trackers = trackers.filter(s => s.id !== target.id);
    closeRevoke();
    renderTrackers();
    alertUser('Autorização de “' + target.nome + '” revogada.');
  }));
  $('close-photo').addEventListener('click', cleanPhoto);
  $('photo-modal').addEventListener('click', e => { if (e.target === $('photo-modal')) cleanPhoto(); });
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (!$('key-modal').hidden) closeKey();
    if (!$('confirm-modal').hidden) closeRevoke();
    if (!$('photo-modal').hidden) cleanPhoto();
  });
})();
