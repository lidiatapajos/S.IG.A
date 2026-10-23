'use strict';
(() => {
  const $ = (id) => document.getElementById(id);
  const keyInput = $('key');
  const consent = $('consent');
  const startButton = $('start');
  const stopButton = $('stop');
  const status = $('status');
  let session = null;
  let watchId = null;
  let lastSent = 0;
  let sending = false;
  let stopping = false;
  const intervalMs = 5000;
  const show = (message) => { status.textContent = message; };

  function parseKey(value) {
    const match = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.([0-9a-f]{64})$/i.exec(value.trim());
    return match ? { id: match[1], token: match[2] } : null;
  }
  async function request(method, path, activeSession, payload, keepalive = false) {
    const response = await fetch(path, {
      method,
      headers: {
        Authorization: `Bearer ${activeSession.token}`,
        ...(payload ? { 'Content-Type': 'application/json' } : {}),
      },
      ...(payload ? { body: JSON.stringify(payload) } : {}),
      cache: 'no-store',
      keepalive,
    });
    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      throw new Error(data?.error?.message || `Erro HTTP ${response.status}`);
    }
    return response;
  }
  function gpsError(error) {
    const messages = {
      1: 'Permissão de localização negada. Autorize o GPS nas configurações do navegador.',
      2: 'Localização indisponível. Verifique o GPS e o sinal do aparelho.',
      3: 'O GPS demorou para responder. Tentando novamente...',
    };
    show(messages[error.code] || `Erro ao acessar GPS: ${error.message}`);
  }
  async function onPosition(position) {
    if (!session || stopping || sending) return;
    const now = Date.now();
    if (now - lastSent < intervalMs) return;
    const { latitude, longitude, accuracy } = position.coords;
    if (![latitude, longitude, accuracy].every(Number.isFinite)) {
      show('Aguardando coordenadas válidas do GPS...');
      return;
    }
    if (accuracy > 100) {
      show(`Aguardando GPS mais preciso (atual: ${Math.round(accuracy)} m; máximo: 100 m).`);
      return;
    }
    const capturedAt = position.timestamp;
    if (now - capturedAt > 30000) {
      show('Aguardando uma posição recente do GPS...');
      return;
    }
    sending = true;
    const active = session;
    try {
      await request('PUT', `/api/rastreamento/${encodeURIComponent(active.id)}/posicao`, active, {
        latitude, longitude, precisao: accuracy, capturado_em: Math.round(capturedAt),
      });
      lastSent = Date.now();
      if (session === active) show(`Localização enviada às ${new Date().toLocaleTimeString('pt-BR')}. Precisão: ${Math.round(accuracy)} m.`);
    } catch (error) {
      if (session === active) show(`Falha ao enviar localização: ${error.message}`);
    } finally {
      sending = false;
    }
  }
  startButton.addEventListener('click', () => {
    if (session) return;
    const parsed = parseKey(keyInput.value);
    if (!parsed) return show('Chave inválida. Cole a chave completa gerada pelo administrador.');
    if (!consent.checked) return show('Marque a autorização de compartilhamento para continuar.');
    if (!window.isSecureContext || !navigator.geolocation) return show('GPS indisponível. Abra a página por HTTPS em um navegador compatível.');
    session = parsed;
    keyInput.value = '';
    keyInput.disabled = true;
    consent.disabled = true;
    startButton.disabled = true;
    stopButton.disabled = false;
    lastSent = 0;
    show('Solicitando permissão do GPS e aguardando a primeira posição...');
    watchId = navigator.geolocation.watchPosition(onPosition, gpsError, {
      enableHighAccuracy: true, maximumAge: 0, timeout: 20000,
    });
  });
  async function stop() {
    if (!session || stopping) return;
    stopping = true;
    stopButton.disabled = true;
    if (watchId !== null) navigator.geolocation.clearWatch(watchId);
    watchId = null;
    const active = session;
    show('Encerrando sessão e removendo posição do mapa...');
    try {
      await request('DELETE', `/api/rastreamento/${encodeURIComponent(active.id)}`, active);
      show('Compartilhamento encerrado. A posição foi removida do servidor.');
      session = null;
      keyInput.disabled = false;
      consent.disabled = false;
      consent.checked = false;
      startButton.disabled = false;
    } catch (error) {
      show(`Não foi possível encerrar no servidor: ${error.message}. Tente novamente.`);
      stopButton.disabled = false;
    } finally {
      stopping = false;
    }
  }
  stopButton.addEventListener('click', stop);
  window.addEventListener('pagehide', () => {
    if (!session || stopping) return;
    const active = session;
    if (watchId !== null) navigator.geolocation.clearWatch(watchId);
    request('DELETE', `/api/rastreamento/${encodeURIComponent(active.id)}`, active, null, true).catch(() => {});
  });
})();
