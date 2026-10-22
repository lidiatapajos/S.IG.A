// GPS simulado pelo navegador para teste automatizado; não substitui teste no celular.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import sharp from 'sharp';
import { openDatabase } from '../src/database.js';
import { createApp } from '../src/app.js';

const db = openDatabase();
const token = 'browser-test-only-'.repeat(4);
const server = createApp({ db, adminToken: token }).listen(0,'127.0.0.1');
await once(server,'listening');
const base = `http://127.0.0.1:${server.address().port}`;
let browser;
try {
  browser = await chromium.launch({channel:'chromium',headless:true,args:['--no-sandbox']});
  const context = await browser.newContext({ permissions: ['geolocation'], geolocation: { latitude:-1.45, longitude:-48.49, accuracy:5 } });
  const admin = await context.newPage(); const errors = [];
  admin.on('pageerror', e=>errors.push(e.message));
  await admin.goto(`${base}/admin`);
  await admin.locator('#token').fill(token);
  await admin.locator('#connect').click();
  await admin.waitForFunction(()=>document.getElementById('status').textContent==='Painel atualizado.');
  await admin.locator('#create').click();
  await admin.locator('#secret').waitFor({state:'visible'});
  const key = await admin.locator('#key').inputValue();
  assert.match(key,/^[a-f0-9-]{36}\.[a-f0-9]{64}$/);
  const tracker = await context.newPage(); tracker.on('pageerror',e=>errors.push(e.message));
  await tracker.setViewportSize({width:390,height:844});
  await tracker.goto(`${base}/rastreador`);
  await tracker.locator('#key').fill(key);
  await tracker.locator('#start').click();
  assert.match(await tracker.locator('#status').innerText(),/Confirme a autorização/);
  await tracker.locator('#consent').check(); await tracker.locator('#start').click();
  await tracker.waitForFunction(()=>document.getElementById('status').textContent.startsWith('Compartilhando'),{},{timeout:15000});
  let data = (await (await fetch(`${base}/api/rastreamento`)).json()).data;
  assert.equal(data[0].latitude,-1.45);
  await context.setGeolocation({latitude:-1.46,longitude:-48.48,accuracy:6});
  await tracker.waitForFunction(async()=>{
    const r=await fetch('/api/rastreamento');return (await r.json()).data[0]?.latitude===-1.46;
  },{},{timeout:15000});
  await tracker.locator('#stop').click();
  await tracker.waitForFunction(()=>document.getElementById('status').textContent.startsWith('Compartilhamento encerrado'));
  assert.deepEqual((await (await fetch(`${base}/api/rastreamento`)).json()).data,[]);
  assert.equal(await tracker.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  // Exercita denúncia/foto/status pelo painel, incluindo proteção contra HTML injetado.
  const png = await sharp({create:{width:20,height:20,channels:3,background:'green'}}).png().toBuffer();
  const r = await fetch(`${base}/api/denuncias`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({categoria:'entulho',descricao:'<script>alert(1)</script>',latitude:0,longitude:0,foto_base64:`data:image/png;base64,${png.toString('base64')}`})});
  assert.equal(r.status,201); const report=(await r.json()).data;
  await admin.locator('#refresh').click(); await admin.locator('article').waitFor();
  await admin.getByRole('button',{name:'Ver foto'}).click();
  await admin.waitForFunction(()=>document.querySelector('article img')?.naturalWidth===20);
  await admin.locator('article select').selectOption('em_atendimento');
  await admin.getByRole('button',{name:'Salvar situação'}).click();
  await admin.waitForFunction(()=>document.getElementById('status').textContent.includes('atualizada.'));
  assert.equal((await (await fetch(`${base}/api/denuncias/protocolo/${report.protocolo}`)).json()).data.status,'em_atendimento');
  await admin.locator('#logout').click();
  assert.equal(await admin.locator('article').count(),0);
  assert.equal(await admin.locator('#key').inputValue(),'');
  assert.deepEqual(errors,[]);
  console.log('PASS: painel, consentimento, GPS simulado, deslocamento, encerramento, layout mobile, foto e alteração de status.');
} finally {
  await browser?.close(); server.close(); await once(server,'close'); db.close();
}
