/* ================================================================
   BODYCAM // ОПЕРАЦИЯ «КАРАКУМ» — v0.1.0 (BUILD 1)
   Тактический шутер от первого лица: захват точек, боты, 10-мин раунд.
   Оружие и солдаты — GLB-модели (assets/). Online-заготовки: NET.
   ================================================================ */
'use strict';

const BC_BUILD = 2;
const BC_VERSION = '0.1.1';

/* --- авторелоад кэша (как jb_build в Jurassic-Blocky) --- */
(function () {
  try {
    const cur = localStorage.getItem('bc_build');
    if (cur && cur !== String(BC_BUILD)) { localStorage.setItem('bc_build', String(BC_BUILD)); location.reload(); return; }
    if (!cur) localStorage.setItem('bc_build', String(BC_BUILD));
  } catch (e) { /* private mode */ }
})();

/* ================= УТИЛИТЫ ================= */
const clamp = (v, a, b) => v < a ? a : (v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = t => t * t * (3 - 2 * t);
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(rand(a, b + 1));
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const fmtMMSS = s => { s = Math.max(0, Math.floor(s)); return String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0'); };
const $ = id => document.getElementById(id);
function dist2d(ax, az, bx, bz) { const dx = ax - bx, dz = az - bz; return Math.sqrt(dx * dx + dz * dz); }

/* ================= НАСТРОЙКИ (localStorage) ================= */
const SET = {
  sens: 1.0, vol: 0.7,
  load() { try { this.sens = parseFloat(localStorage.getItem('bc_sens')) || 1.0; this.vol = localStorage.getItem('bc_vol') !== null ? parseFloat(localStorage.getItem('bc_vol')) : 0.7; } catch (e) { } },
  save() { try { localStorage.setItem('bc_sens', String(this.sens)); localStorage.setItem('bc_vol', String(this.vol)); } catch (e) { } }
};
SET.load();

/* ================= АУДИО (полностью процедурный, WebAudio) ================= */
const AUDIO = {
  ctx: null, master: null, noiseBuf: null, windSrc: null,
  init() {
    if (this.ctx) return;
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.master = this.ctx.createGain();
      this.master.gain.value = SET.vol;
      this.master.connect(this.ctx.destination);
      const len = this.ctx.sampleRate * 1.2;
      this.noiseBuf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
      const d = this.noiseBuf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
      this.wind();
    } catch (e) { this.ctx = null; }
  },
  resume() { if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume(); },
  setVol(v) { if (this.master) this.master.gain.value = v; },
  _noise(dur, gainEnv, filtType, freq, q, playbackRate) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const src = this.ctx.createBufferSource();
    src.buffer = this.noiseBuf; src.loop = true;
    if (playbackRate) src.playbackRate.value = playbackRate;
    const f = this.ctx.createBiquadFilter();
    f.type = filtType; f.frequency.value = freq; f.Q.value = q || 0.8;
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(gainEnv[0], t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0001, gainEnv[1]), t + gainEnv[2]);
    src.connect(f); f.connect(g); g.connect(this.master);
    src.start(t); src.stop(t + dur);
  },
  _tone(freq, dur, vol, type, endFreq) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator(); o.type = type || 'sine';
    o.frequency.setValueAtTime(freq, t);
    if (endFreq) o.frequency.exponentialRampToValueAtTime(Math.max(1, endFreq), t + dur);
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(this.master);
    o.start(t); o.stop(t + dur);
  },
  /* выстрел: у каждого ствола свой характер */
  shot(kind) {
    if (!this.ctx) return;
    switch (kind) {
      case 'ak74': this._noise(0.16, [0.55, 0.001, 0.13], 'lowpass', 1900, 0.7, 1.0); this._tone(140, 0.09, 0.30, 'square', 55); break;
      case 'm16': this._noise(0.13, [0.5, 0.001, 0.11], 'lowpass', 2400, 0.7, 1.15); this._tone(170, 0.07, 0.24, 'square', 70); break;
      case 'svd': this._noise(0.34, [0.75, 0.001, 0.30], 'lowpass', 1400, 0.6, 0.8); this._tone(110, 0.16, 0.4, 'square', 40); break;
      case 'm82': this._noise(0.5, [0.95, 0.001, 0.44], 'lowpass', 900, 0.6, 0.62); this._tone(80, 0.24, 0.5, 'square', 30); break;
      case 'makarov': this._noise(0.1, [0.4, 0.001, 0.09], 'lowpass', 2600, 0.8, 1.2); this._tone(200, 0.05, 0.16, 'square', 90); break;
      case 'deagle': this._noise(0.22, [0.65, 0.001, 0.18], 'lowpass', 1600, 0.7, 0.9); this._tone(120, 0.12, 0.34, 'square', 48); break;
    }
  },
  enemyShot(dist) { // выстрелы чужие — тише с расстоянием
    const v = clamp(0.5 - dist * 0.006, 0.05, 0.5);
    this._noise(0.14, [v, 0.001, 0.12], 'lowpass', 1500 + dist * -8, 0.8, 1.0);
  },
  whiz() { this._noise(0.09, [0.16, 0.001, 0.08], 'bandpass', 3400, 6, 1.6); },
  hit() { this._tone(1150, 0.05, 0.16, 'square', 900); },
  headshot() { this._tone(1500, 0.06, 0.2, 'square', 700); },
  kill() { this._tone(660, 0.07, 0.16, 'square', 520); setTimeout(() => this._tone(880, 0.09, 0.16, 'square', 660), 70); },
  hurt() { this._noise(0.14, [0.3, 0.001, 0.12], 'lowpass', 500, 1, 0.6); this._tone(180, 0.1, 0.14, 'sawtooth', 90); },
  dry() { this._tone(900, 0.04, 0.1, 'square', 700); },
  reload() { this._tone(500, 0.05, 0.1, 'square', 380); setTimeout(() => this._tone(700, 0.06, 0.12, 'square', 500), 160); setTimeout(() => this._tone(300, 0.05, 0.1, 'square', 220), 380); },
  switchW() { this._tone(650, 0.05, 0.09, 'square', 480); },
  capTick(own) { this._tone(own ? 700 : 420, 0.05, 0.07, 'sine'); },
  capDone() { this._tone(520, 0.1, 0.14, 'sine'); setTimeout(() => this._tone(780, 0.14, 0.14, 'sine'), 110); },
  lost() { this._tone(400, 0.12, 0.12, 'sine', 260); setTimeout(() => this._tone(300, 0.16, 0.12, 'sine', 190), 130); },
  death() { this._noise(0.7, [0.4, 0.001, 0.6], 'lowpass', 300, 1, 0.5); this._tone(160, 0.5, 0.2, 'sawtooth', 60); },
  end(win) {
    if (win) { [523, 659, 784].forEach((f, i) => setTimeout(() => this._tone(f, 0.18, 0.14, 'sine'), i * 140)); }
    else { [400, 330, 260].forEach((f, i) => setTimeout(() => this._tone(f, 0.2, 0.14, 'sine'), i * 160)); }
  },
  wind() { // фоновый ветер пустыни
    if (!this.ctx) return;
    const src = this.ctx.createBufferSource();
    src.buffer = this.noiseBuf; src.loop = true;
    const f = this.ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 320;
    const g = this.ctx.createGain(); g.gain.value = 0.05;
    const lfo = this.ctx.createOscillator(); lfo.frequency.value = 0.13;
    const lg = this.ctx.createGain(); lg.gain.value = 0.03;
    lfo.connect(lg); lg.connect(g.gain);
    src.connect(f); f.connect(g); g.connect(this.master);
    src.start(); lfo.start();
    this.windSrc = src;
  }
};

/* ================= NET — заготовки для будущего онлайн-режима =================
   Онлайн включается позже (PeerJS). Локальная игра полностью автономна;
   при включении NET.enabled=true хаб начинает рассылать снапшоты и
   порождать удалённых игроков. Все точки интеграции помечены «NET:». */
const NET = {
  enabled: false,           // NET: переключается при подключении комнаты
  mode: 'offline',          // offline | host | guest
  room: null,
  peers: new Map(),         // netId -> {name, team, state}
  remoteActors: new Map(),  // netId -> actor (NET: удалённые игроки)
  connect(roomId) { /* NET: здесь позже создастся PeerJS-комната */ },
  disconnect() { /* NET: */ this.enabled = false; this.mode = 'offline'; this.peers.clear(); this.remoteActors.clear(); },
  send(type, payload) {
    if (!this.enabled) return;
    /* NET: peerConnection.send(JSON.stringify({t: type, p: payload})) */
  },
  onMessage(type, cb) { /* NET: подписка на события комнаты */ },
  buildSnapshot() { // NET: что рассылается о локальном игроке
    if (!P) return null;
    return { pos: [P.pos.x, P.pos.y, P.pos.z], yaw: P.yaw, pitch: P.pitch, hp: P.hp, w: P.wIdx, team: P.team, alive: P.alive };
  },
  tick() { if (this.enabled && this.mode !== 'offline' && P && P.alive) this.send('state', this.buildSnapshot()); },
  spawnRemote(netId, info) { /* NET: спавн удалённого игрока — клон soldier + телеметрия */ },
  applyRemote(netId, snap) { /* NET: применить телеметрию удалённого игрока */ }
};

/* ================= THREE: РЕНДЕР, СВЕТ, НЕБО ================= */
const renderer = new THREE.WebGLRenderer({ canvas: $('c3d'), antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.autoClear = false; // два прохода: мир + viewmodel оружия

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xc9bb9c);
scene.fog = new THREE.Fog(0xc9bb9c, 55, 400);

const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.08, 900);
const vmScene = new THREE.Scene();            // отдельная сцена для модели оружия (не режется стенами)
const vmCam = new THREE.PerspectiveCamera(62, window.innerWidth / window.innerHeight, 0.01, 12);
vmScene.add(new THREE.HemisphereLight(0xdfe6ea, 0x8a7c5c, 1.0));
const vmSun = new THREE.DirectionalLight(0xfff1d6, 1.1); vmSun.position.set(1, 2, 0.6); vmScene.add(vmSun);

scene.add(new THREE.HemisphereLight(0xd8e2ea, 0x9a8a62, 0.52));
const sun = new THREE.DirectionalLight(0xffedd0, 0.92); sun.position.set(90, 130, 45); scene.add(sun);

window.addEventListener('resize', () => {
  camera.aspect = vmCam.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix(); vmCam.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

/* ================= РЕЛЬЕФ (пустыня ~440×440 м) ================= */
const MAP = { half: 220 };
/* зоны выравнивания: точки, базы, дороги */
const FLATS = [
  { x: -110, z: -90, r: 34 },  // A хутор
  { x: 0, z: 0, r: 36 },       // B депо
  { x: 120, z: 100, r: 34 },   // C блокпост
  { x: -172, z: 152, r: 30 },  // база RU
  { x: 172, z: -152, r: 30 },  // база US
];
function rawH(x, z) {
  let h = 3.6 * Math.sin(x * 0.0115) * Math.cos(z * 0.0095)
    + 1.9 * Math.sin(x * 0.021 + z * 0.016)
    + 0.7 * Math.sin(x * 0.052) * Math.sin(z * 0.045)
    + 0.35 * Math.sin((x + z) * 0.09);
  const dEdge = Math.max(Math.abs(x), Math.abs(z));
  if (dEdge > MAP.half - 24) h += (dEdge - (MAP.half - 24)) * 0.14; // гряды по периметру
  return h;
}
FLATS.forEach(f => { f.h0 = rawH(f.x, f.z); });
function terrainH(x, z) {
  let h = rawH(x, z);
  for (const f of FLATS) {
    const d = dist2d(x, z, f.x, f.z);
    if (d < f.r) { const t = smooth(clamp(d / f.r, 0, 1)); h = lerp(f.h0, h, t); }
  }
  return h;
}

function buildTerrain() {
  const seg = 108, size = MAP.half * 2;
  const geo = new THREE.PlaneGeometry(size, size, seg, seg);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position, colors = [];
  const cLow = new THREE.Color(0x84714b), cMid = new THREE.Color(0x9f8752), cHigh = new THREE.Color(0xbfa87a);
  const tmp = new THREE.Color();
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const h = terrainH(x, z);
    pos.setY(i, h);
    const n = 0.5 + 0.5 * Math.sin(x * 0.35 + Math.sin(z * 0.31) * 2.1) * Math.cos(z * 0.23);
    tmp.copy(cLow).lerp(cMid, clamp(h * 0.16 + 0.25, 0, 1)).lerp(cHigh, clamp((h - 4) * 0.05, 0, 0.7));
    tmp.multiplyScalar(0.86 + n * 0.08);
    colors.push(tmp.r, tmp.g, tmp.b);
  }
  geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ vertexColors: true }));
  scene.add(mesh);
}

function buildRoads() {
  // грунтовки: базы -> центр, A -> B -> C
  const paths = [
    [[-160, 140], [-70, 60], [0, 0]],
    [[160, -140], [70, -60], [0, 0]],
    [[-110, -90], [-55, -45], [0, 0]],
    [[120, 100], [60, 50], [0, 0]],
  ];
  const mat = new THREE.MeshLambertMaterial({ color: 0xa08a5e });
  const m4 = new THREE.Matrix4();
  for (const p of paths) {
    for (let s = 0; s < p.length - 1; s++) {
      const [x1, z1] = p[s], [x2, z2] = p[s + 1];
      const steps = Math.ceil(dist2d(x1, z1, x2, z2) / 5);
      for (let i = 0; i < steps; i++) {
        const t0 = i / steps, t1 = (i + 1) / steps;
        const ax = lerp(x1, x2, t0), az = lerp(z1, z2, t0), bx = lerp(x1, x2, t1), bz = lerp(z1, z2, t1);
        const len = dist2d(ax, az, bx, bz) + 5, w = 7;
        const g = new THREE.PlaneGeometry(w, len);
        const m = new THREE.Mesh(g, mat);
        m.rotation.x = -Math.PI / 2;
        m.rotation.z = Math.atan2(bx - ax, bz - az);
        const mx = (ax + bx) / 2, mz = (az + bz) / 2;
        m.position.set(mx, terrainH(mx, mz) + 0.07, mz);
        m.renderOrder = 1;
        scene.add(m);
        void m4;
      }
    }
  }
}

/* ================= КОЛЛИЗИИ И ПРЕПЯТСТВИЯ ================= */
const COLLIDERS = [];      // {x1,z1,x2,z2}
const LOS_MESHES = [];     // меши, блокирующие линию огня
function addCollider(x, z, w, d) { COLLIDERS.push({ x1: x - w / 2, z1: z - d / 2, x2: x + w / 2, z2: z + d / 2 }); }
function pointBlocked(x, z, r) {
  for (const c of COLLIDERS) {
    if (x + r > c.x1 && x - r < c.x2 && z + r > c.z1 && z - r < c.z2) return true;
  }
  return false;
}

const MATS = {
  concrete: new THREE.MeshLambertMaterial({ color: 0x9a9488 }),
  concrete2: new THREE.MeshLambertMaterial({ color: 0x7e786c }),
  brick: new THREE.MeshLambertMaterial({ color: 0x8a6a4e }),
  roof: new THREE.MeshLambertMaterial({ color: 0x5c584e }),
  hesco: new THREE.MeshLambertMaterial({ color: 0xb5a06b }),
  sandbag: new THREE.MeshLambertMaterial({ color: 0x7a6f4a }),
  metal: new THREE.MeshLambertMaterial({ color: 0x5e6a66 }),
  wood: new THREE.MeshLambertMaterial({ color: 0x7d5f3c }),
  dark: new THREE.MeshLambertMaterial({ color: 0x3c3e38 }),
  rock: new THREE.MeshLambertMaterial({ color: 0x8a8072, flatShading: true }),
  bush: new THREE.MeshLambertMaterial({ color: 0x5a6134, flatShading: true }),
  pole: new THREE.MeshLambertMaterial({ color: 0x4a4a44 }),
};
const CONTAINER_COLORS = [0x8f3f2c, 0x2c4f6e, 0x4c5e33, 0x666662, 0x75592a, 0x5e3535];

function box(x, y, z, w, h, d, mat, collide, los) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y + h / 2, z);
  scene.add(m);
  if (collide) addCollider(x, z, w, d);
  if (los) LOS_MESHES.push(m);
  return m;
}

/* ================= ПОСТРОЙКИ И УКРЫТИЯ ================= */
function building(x, z, w, d, h, mat) {
  const y = terrainH(x, z);
  box(x, y, z, w, h, d, mat || MATS.concrete, true, true);
  box(x, y + h, z, w + 0.9, 0.35, d + 0.9, MATS.roof, false, false); // навес крыши
}
function container(x, z, ry) {
  const y = terrainH(x, z);
  const m = box(x, y, z, 6.1, 2.6, 2.5, new THREE.MeshLambertMaterial({ color: pick(CONTAINER_COLORS) }), true, true);
  m.rotation.y = ry || 0;
  if (Math.abs(ry) > 0.4) { COLLIDERS.pop(); const w = 2.5, d = 6.1; addCollider(x, z, w, d); }
}
function hescoRow(x, z, n, ry) {
  const y = terrainH(x, z);
  for (let i = 0; i < n; i++) {
    const dx = Math.cos(ry) * (i - (n - 1) / 2) * 2.3, dz = Math.sin(ry) * (i - (n - 1) / 2) * 2.3;
    box(x + dx, y, z + dz, 2.2, 1.7, 2.2, MATS.hesco, true, true);
  }
}
function sandbagWall(x, z, len, ry) {
  const y = terrainH(x, z);
  const m = box(x, y, z, len, 1.05, 0.7, MATS.sandbag, true, false);
  m.rotation.y = ry || 0;
}
function rock(x, z, s) {
  const y = terrainH(x, z);
  const m = new THREE.Mesh(new THREE.DodecahedronGeometry(s, 0), MATS.rock);
  m.position.set(x, y + s * 0.35, z);
  m.scale.y = 0.6; m.rotation.y = rand(0, 6.3);
  scene.add(m);
  if (s > 1.6) { addCollider(x, z, s * 1.5, s * 1.5); LOS_MESHES.push(m); }
}
function bush(x, z, s) {
  const y = terrainH(x, z);
  const m = new THREE.Mesh(new THREE.IcosahedronGeometry(s, 0), MATS.bush);
  m.position.set(x, y + s * 0.5, z); m.scale.y = 0.7; m.rotation.y = rand(0, 6.3);
  scene.add(m);
}
function tower(x, z) {
  const y = terrainH(x, z);
  box(x, y, z, 4.4, 5.6, 4.4, MATS.concrete2, true, true);
  box(x, y + 5.6, z, 5.6, 0.4, 5.6, MATS.dark, false, false);
}
function powerPole(x, z) {
  const y = terrainH(x, z);
  const p = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.2, 8.5, 5), MATS.pole);
  p.position.set(x, y + 4.2, z); scene.add(p);
  const c = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.14, 0.14), MATS.pole);
  c.position.set(x, y + 7.6, z); scene.add(c);
}

function buildMap() {
  buildTerrain(); buildRoads();
  /* --- точка A «ХУТОР» --- */
  building(-124, -102, 10, 8, 4.2, MATS.brick);
  building(-110, -78, 9, 7, 3.8, MATS.concrete);
  building(-96, -96, 8, 9, 4.0, MATS.concrete2);
  building(-118, -84, 7, 6, 3.2, MATS.brick);
  container(-102, -82, 0.2); container(-88, -86, 1.2);
  sandbagWall(-110, -90, 6, 0.4); rock(-128, -76, 1.9);
  bush(-134, -108, 1.2); bush(-92, -74, 1.4); bush(-80, -104, 1.0);
  /* --- точка B «ДЕПО» --- */
  building(0, -6, 26, 14, 8.5, MATS.metal);       // ангар
  container(-10, 8, 0); container(-2, 9, 0.35); container(7, 8.5, 1.15);
  container(-16, -12, 0.8); container(12, -14, 0);
  hescoRow(-20, 2, 4, 0.5); sandbagWall(14, 4, 7, 1.1);
  tower(-24, -20); powerPole(20, 14); powerPole(-22, 12);
  bush(24, -4, 1.3); bush(-26, 16, 1.1);
  /* --- точка C «БЛОКПОСТ» --- */
  tower(120, 100);
  hescoRow(112, 92, 5, 0.3); hescoRow(128, 108, 5, 0.3);
  sandbagWall(120, 88, 8, 0.1); sandbagWall(112, 106, 7, 1.2);
  building(134, 94, 8, 6, 3.6, MATS.concrete2);
  container(108, 112, 0.5); rock(136, 112, 2.2);
  bush(106, 92, 1.2); bush(132, 86, 1.0);
  /* --- базы --- */
  const bases = [[-172, 152, 0x3a5a2e], [172, -152, 0x2e3f5a]];
  for (const [bx, bz, tint] of bases) {
    const m = box(bx - 10, terrainH(bx - 10, bz), bz, 9, 3.2, 6, new THREE.MeshLambertMaterial({ color: tint }), true, true);
    m.rotation.y = 0.2;
    box(bx + 8, terrainH(bx + 8, bz - 6), bz - 6, 7, 3.0, 5, new THREE.MeshLambertMaterial({ color: tint }), true, true);
    box(bx, terrainH(bx, bz + 10), bz + 10, 5, 2.4, 4, MATS.metal, true, false);
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 7, 5), MATS.pole);
    pole.position.set(bx + 3, terrainH(bx + 3, bz + 3) + 3.5, bz + 3); scene.add(pole);
    addCollider(bx + 3, bz + 3, 0.4, 0.4);
  }
  /* --- рассыпанные укрытия и декор по карте --- */
  const scatter = [[-60, 30], [50, 40], [-40, -30], [70, -20], [-140, 40], [150, -60], [-30, 120], [30, -120], [90, 60], [-90, -140], [100, -100], [-60, -150], [40, 150], [150, 40], [-150, -60]];
  for (const [sx, sz] of scatter) {
    const r = Math.random();
    if (r < 0.4) container(sx, sz, rand(0, 3));
    else if (r < 0.6) { hescoRow(sx, sz, randi(3, 4), rand(0, 3)); }
    else if (r < 0.8) rock(sx, sz, rand(1.6, 2.8));
    else sandbagWall(sx, sz, rand(4, 7), rand(0, 3));
  }
  for (let i = 0; i < 46; i++) {
    const x = rand(-MAP.half + 12, MAP.half - 12), z = rand(-MAP.half + 12, MAP.half - 12);
    if (dist2d(x, z, 0, 0) < 40) continue;
    if (Math.random() < 0.45) rock(x, z, rand(0.7, 1.5)); else bush(x, z, rand(0.7, 1.6));
  }
  for (let i = 0; i < 10; i++) powerPole(lerp(-170, 170, i / 9) + rand(-8, 8), rand(-20, 20));
}

/* ================= ТОЧКИ ЗАХВАТА ================= */
const POINTS = [
  { id: 'A', name: 'ХУТОР', x: -110, z: -90, r: 15, owner: null, prog: 0, prev: null, capA: 0 },
  { id: 'B', name: 'ДЕПО', x: 0, z: 0, r: 16, owner: null, prog: 0, prev: null, capA: 0 },
  { id: 'C', name: 'БЛОКПОСТ', x: 120, z: 100, r: 15, owner: null, prog: 0, prev: null, capA: 0 },
];
const FLAG_NEUTRAL = new THREE.MeshLambertMaterial({ color: 0xb8b8ac, side: THREE.DoubleSide });
const FLAG_RU = new THREE.MeshLambertMaterial({ color: 0xd03a2c, side: THREE.DoubleSide });
const FLAG_US = new THREE.MeshLambertMaterial({ color: 0x3a6ad4, side: THREE.DoubleSide });
function buildFlags() {
  for (const p of POINTS) {
    const y = terrainH(p.x, p.z);
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.12, 6.5, 6), MATS.pole);
    pole.position.set(p.x, y + 3.2, p.z); scene.add(pole);
    p.flag = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 1.7), FLAG_NEUTRAL);
    p.flag.position.set(p.x + 1.35, y + 5.5, p.z);
    p.flag.rotation.y = 0.85;
    scene.add(p.flag);
    p.flagBase = { x: p.x + 0.05, y: y + 5.5, z: p.z };
    const ring = new THREE.Mesh(new THREE.RingGeometry(p.r - 0.4, p.r, 40), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.14, side: THREE.DoubleSide }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(p.x, y + 0.25, p.z);
    scene.add(ring);
    p.ring = ring;
  }
}
function flagMatFor(owner) { return owner === 'RU' ? FLAG_RU : owner === 'US' ? FLAG_US : FLAG_NEUTRAL; }
function refreshFlag(p) {
  p.flag.material = flagMatFor(p.owner);
  p.flag.position.x = p.flagBase.x;
  p.ring.material.color.set(p.owner === 'RU' ? 0xff5b4d : p.owner === 'US' ? 0x6fa8ff : 0xffffff);
}

/* ================= ЗАГРУЗКА GLB ================= */
const GLB = { ak74: null, deagle: null, m16: null, makarov: null, svd: null, m82: null, soldier: null, soldierH: 1.8, ok: false, loaded: 0, total: 7 };
const gltfLoader = new THREE.GLTFLoader();
function simplify(root) {
  root.traverse(o => {
    if (o.isMesh) {
      const conv = m => {
        const nm = new THREE.MeshLambertMaterial({ color: (m.color && m.color.clone()) || new THREE.Color(0xcccccc), name: m.name });
        if (o.isSkinnedMesh) nm.skinning = true; // r128: без флага SkinnedMesh рисуется в bind-позе (T)
        if (m.map) nm.map = m.map;
        if (m.transparent) { nm.transparent = true; nm.opacity = m.opacity; }
        return nm;
      };
      o.material = Array.isArray(o.material) ? o.material.map(conv) : conv(o.material);
    }
  });
}
function loadGLB(key, file) {
  gltfLoader.load(file, g => {
    simplify(g.scene);
    GLB[key] = g; GLB.loaded++;
    if (GLB.loaded >= GLB.total && !GLB.ok) { GLB.ok = true; allLoaded(); }
  }, undefined, () => { console.warn('GLB fail', key); GLB.loaded++; if (GLB.loaded >= GLB.total && !GLB.ok) { GLB.ok = true; allLoaded(); } });
}
/* всё загружено: меряем солдата, строим viewmodel, открываем кнопку */
function allLoaded() {
  GLB.soldier.scene.updateMatrixWorld(true);
  const bb = new THREE.Box3().setFromObject(GLB.soldier.scene);
  GLB.soldierH = bb.getSize(new THREE.Vector3()).y;
  buildViewmodels();
  const btn = $('btn-deploy');
  /* SkeletonUtils в этой сборке не перенаправляет skeleton на кости клона — боты застывают в T-позе.
     Поэтому каждый бот получает СВОЙ экземпляр солдата (отдельный parse — у loader'а bind корректный). */
  GLB.soldierSkins = [];
  const need = 14;
  let done = 0;
  const finish = () => { btn.disabled = false; btn.textContent = '▶ В БОЙ'; };
  for (let i = 0; i < need; i++) {
    gltfLoader.load('assets/soldier.glb', g => {
      simplify(g.scene);
      GLB.soldierSkins.push(g);
      if (++done >= need) finish();
    }, undefined, () => { done++; if (done >= need) finish(); });
  }
}

/* --- нормализация модели: масштаб -> ствол вдоль -Z -> центр в 0 ---
   Ось ствола = длиннейшая сторона bbox; дуло = тонкая половина; крен по массе.
   (эвристики выверены по калибровочным скриншотам Sketchfab-моделей) */
function worldVerts(root) {
  root.updateMatrixWorld(true);
  const out = [];
  root.traverse(o => {
    if (o.isMesh && o.geometry && o.geometry.attributes.position) {
      const pos = o.geometry.attributes.position;
      const v = new THREE.Vector3();
      for (let i = 0; i < pos.count; i++) {
        v.fromBufferAttribute(pos, i).applyMatrix4(o.matrixWorld);
        out.push(v.x, v.y, v.z);
      }
    }
  });
  return out;
}
function normalizeWeapon(sceneIn, targetLen, forceFlip, rollFix) {
  sceneIn.updateMatrixWorld(true);
  // отсекаем «оторванные» детали (патроны рядом с моделью): кластеры касаний,
  // удаляем всё, что не связано с основным телом оружия
  const parts = [];
  sceneIn.traverse(o => { if (o.isMesh) parts.push(o); });
  if (parts.length > 1) {
    const bbs = parts.map(o => new THREE.Box3().setFromObject(o));
    const uni = new THREE.Box3();
    for (const b of bbs) uni.union(b);
    const maxL = Math.max(...uni.getSize(new THREE.Vector3()).toArray());
    const marg = maxL * 0.01;
    const parent = new Array(parts.length).fill(-1).map((_, i) => i);
    const find = i => { while (parent[i] !== i) { parent[i] = parent[parent[i]]; i = parent[i]; } return i; };
    for (let i = 0; i < parts.length; i++) {
      const ai = bbs[i].clone().expandByScalar(marg);
      for (let j = i + 1; j < parts.length; j++) {
        if (ai.intersectsBox(bbs[j])) { const a = find(i), b = find(j); if (a !== b) parent[a] = b; }
      }
    }
    // главный кластер — тот, где самый крупный меш
    const bigSz = new Array(parts.length).fill(0);
    for (let i = 0; i < parts.length; i++) bigSz[i] = Math.max(...bbs[i].getSize(new THREE.Vector3()).toArray());
    let mainRoot = 0, mainSz = 0;
    for (let i = 0; i < parts.length; i++) { const r = find(i); if (bigSz[i] > mainSz) { mainSz = bigSz[i]; mainRoot = r; } }
    const drop = [];
    for (let i = 0; i < parts.length; i++) {
      if (find(i) !== mainRoot && bigSz[i] < maxL * 0.3) drop.push(parts[i]);
    }
    for (const m of drop) if (m.parent) m.parent.remove(m);
  }
  const wrap = new THREE.Group();
  let bb = new THREE.Box3().setFromObject(sceneIn);
  const size0 = bb.getSize(new THREE.Vector3());
  sceneIn.scale.setScalar(targetLen / Math.max(size0.x, size0.y, size0.z, 0.001));
  sceneIn.updateMatrixWorld(true);
  bb = new THREE.Box3().setFromObject(sceneIn);
  const size = bb.getSize(new THREE.Vector3());
  const c = bb.getCenter(new THREE.Vector3());
  let axis = 0;
  if (size.y > size.x && size.y > size.z) axis = 1; else if (size.z > size.x && size.z > size.y) axis = 2;
  const verts = worldVerts(sceneIn);
  function halfThick(sign) {
    const others = [0, 1, 2].filter(a => a !== axis);
    let mn = [1e9, 1e9], mx = [-1e9, -1e9], n = 0;
    const cv = [c.x, c.y, c.z][axis];
    for (let i = 0; i < verts.length; i += 3) {
      const a = axis === 0 ? verts[i] : axis === 1 ? verts[i + 1] : verts[i + 2];
      if (sign > 0 ? a > cv : a < cv) {
        n++;
        for (let k = 0; k < 2; k++) {
          const val = others[k] === 0 ? verts[i] : others[k] === 1 ? verts[i + 1] : verts[i + 2];
          if (val < mn[k]) mn[k] = val;
          if (val > mx[k]) mx[k] = val;
        }
      }
    }
    return n ? Math.max(mx[1] - mn[1], mx[0] - mn[0]) : 0;
  }
  const tPlus = halfThick(1), tMinus = halfThick(-1);
  const muzzleSign = tPlus <= tMinus ? 1 : -1;
  const qA = new THREE.Quaternion();
  if (axis === 0) qA.setFromAxisAngle(new THREE.Vector3(0, 1, 0), muzzleSign > 0 ? Math.PI / 2 : -Math.PI / 2);
  else if (axis === 2) qA.setFromAxisAngle(new THREE.Vector3(0, 1, 0), muzzleSign > 0 ? Math.PI : 0);
  else qA.setFromAxisAngle(new THREE.Vector3(1, 0, 0), muzzleSign > 0 ? -Math.PI / 2 : Math.PI / 2);
  sceneIn.rotation.set(0, 0, 0);
  wrap.add(sceneIn);
  wrap.quaternion.copy(qA);
  if (forceFlip) wrap.quaternion.premultiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.PI));
  if (rollFix) wrap.quaternion.premultiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), rollFix));
  wrap.updateMatrixWorld(true);
  bb = new THREE.Box3().setFromObject(wrap);
  const c2 = bb.getCenter(new THREE.Vector3());
  wrap.position.set(-c2.x, -c2.y, -c2.z); // центр в 0 (пока wrap в (0,0,0))
  wrap.updateMatrixWorld(true);
  return wrap;
}

/* ================= ОРУЖИЕ ================= */
/* vmPos — позиция viewmodel в камере [x,y,z]; flip — разворот дула на 180° */
const WPN = {
  ak74: { name: 'АК-74', file: 'assets/ak74.glb', len: 0.92, auto: true, rpm: 600, dmg: 26, mag: 30, reserve: 120, reload: 2.3, sHip: 1.5, sAds: 0.30, adsFov: 55, hipPos: [0.26, -0.28, -0.74], adsPos: [0, -0.176, -0.42], kick: 1.0, vmPitch: 0.02, flip: false, tone: 'ak74', scope: null, mode: 'АВТО' },
  m16: { name: 'М16А4', file: 'assets/m16.glb', len: 1.0, auto: true, rpm: 660, dmg: 25, mag: 30, reserve: 120, reload: 2.2, sHip: 1.4, sAds: 0.28, adsFov: 55, hipPos: [0.26, -0.28, -0.78], adsPos: [0, -0.178, -0.44], kick: 0.9, vmPitch: 0.02, flip: false, tone: 'm16', scope: null, mode: 'АВТО' },
  svd: { name: 'СВД ДРАГУНОВА', file: 'assets/svd.glb', len: 1.22, auto: false, rpm: 90, dmg: 90, mag: 10, reserve: 40, reload: 2.8, sHip: 1.9, sAds: 0.10, adsFov: 18, hipPos: [0.26, -0.30, -0.86], adsPos: [0, -0.16, -0.46], kick: 1.8, vmPitch: 0.04, flip: false, tone: 'svd', scope: { fov: 18 }, mode: 'ОДИНОЧНЫЙ' },
  m82: { name: 'M82A1 BARRETT', file: 'assets/m82.glb', len: 1.45, auto: false, rpm: 45, dmg: 135, mag: 10, reserve: 30, reload: 3.4, sHip: 2.3, sAds: 0.08, adsFov: 10, hipPos: [0.27, -0.32, -0.92], adsPos: [0, -0.155, -0.50], kick: 2.6, vmPitch: 0.05, flip: false, tone: 'm82', scope: { fov: 10 }, mode: 'ОДИНОЧНЫЙ' },
  makarov: { name: 'ПМ «МАКАРОВ»', file: 'assets/makarov.glb', len: 0.30, auto: false, rpm: 300, dmg: 24, mag: 8, reserve: 40, reload: 1.8, sHip: 1.2, sAds: 0.4, adsFov: 62, hipPos: [0.21, -0.23, -0.44], adsPos: [0, -0.16, -0.32], kick: 0.6, vmPitch: 0.01, flip: false, tone: 'makarov', scope: null, mode: 'ОДИНОЧНЫЙ' },
  deagle: { name: 'DESERT EAGLE .50', file: 'assets/deagle.glb', len: 0.36, auto: false, rpm: 200, dmg: 48, mag: 7, reserve: 35, reload: 2.0, sHip: 1.5, sAds: 0.45, adsFov: 62, hipPos: [0.21, -0.235, -0.46], adsPos: [0, -0.165, -0.33], kick: 1.4, vmPitch: 0.01, flip: false, tone: 'deagle', scope: null, mode: 'ОДИНОЧНЫЙ' },
};
/* классы и стороны */
const CLASSES = {
  RU: { assault: ['ak74', 'makarov'], sniper: ['svd', 'makarov'] },
  US: { assault: ['m16', 'deagle'], sniper: ['m82', 'deagle'] },
};

/* --- viewmodel-инстансы (строятся после загрузки GLB) --- */
const VM = {}; // key -> {group, mat for flash...}
function buildViewmodels() {
  for (const key in WPN) {
    const def = WPN[key];
    const g = GLB[key];
    if (!g) continue;
    const src = g.scene; // не клонируем: каждый ствол используется 1 раз
    const wrap = normalizeWeapon(src, def.len, def.flip, def.rollFix);
    const holder = new THREE.Group();
    holder.add(wrap);
    holder.visible = false;
    VM[key] = { holder, def };
    // вспышка
    const flash = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.spark, color: 0xffd27a, transparent: true, depthTest: false, blending: THREE.AdditiveBlending }));
    flash.scale.setScalar(def.len * 0.16);
    flash.position.set(0, def.len * 0.03, -def.len * 0.48);
    flash.visible = false;
    holder.add(flash);
    VM[key].flash = flash;
  }
}

/* --- процедурные текстуры для вспышек/маркеров --- */
function radialTex(inner, outer) {
  const cv = document.createElement('canvas'); cv.width = cv.height = 64;
  const ctx = cv.getContext('2d');
  const g = ctx.createRadialGradient(32, 32, 2, 32, 32, 30);
  g.addColorStop(0, inner); g.addColorStop(1, outer);
  ctx.fillStyle = g; ctx.fillRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(cv); return t;
}
const TEX = {
  spark: radialTex('rgba(255,255,240,1)', 'rgba(255,180,60,0)'),
  blood: radialTex('rgba(200,30,20,1)', 'rgba(120,10,5,0)'),
  smoke: radialTex('rgba(220,210,190,0.85)', 'rgba(160,150,130,0)'),
};
function makeParticles() {
  PARTICLES.pool = [];
  for (let i = 0; i < 36; i++) {
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.spark, transparent: true, depthWrite: false }));
    s.visible = false; scene.add(s);
    PARTICLES.pool.push({ s, life: 0, vel: new THREE.Vector3() });
  }
}
const PARTICLES = { pool: [], idx: 0 };
function spawnParticle(tex, pos, color, size, vel, life) {
  const p = PARTICLES.pool[PARTICLES.idx++ % PARTICLES.pool.length];
  p.s.material.map = tex; p.s.material.color.set(color);
  p.s.material.opacity = 1;
  p.s.position.copy(pos); p.s.scale.setScalar(size);
  p.vel.copy(vel); p.life = life; p.max = life; p.s.visible = true;
}
function updateParticles(dt) {
  for (const p of PARTICLES.pool) {
    if (!p.s.visible) continue;
    p.life -= dt;
    if (p.life <= 0) { p.s.visible = false; continue; }
    p.s.position.addScaledVector(p.vel, dt);
    p.vel.y -= 4 * dt;
    p.s.material.opacity = clamp(p.life / p.max, 0, 1);
  }
}

/* --- трассеры --- */
const TRACERS = { pool: [], idx: 0 };
function makeTracers() {
  for (let i = 0; i < 10; i++) {
    const g = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3(0, 0, -1)]);
    const l = new THREE.Line(g, new THREE.LineBasicMaterial({ color: 0xffe8b0, transparent: true, opacity: 0.7 }));
    l.visible = false; l.frustumCulled = false; scene.add(l);
    TRACERS.pool.push({ l, life: 0 });
  }
}
function spawnTracer(a, b) {
  const t = TRACERS.pool[TRACERS.idx++ % TRACERS.pool.length];
  const pos = t.l.geometry.attributes.position;
  pos.setXYZ(0, a.x, a.y, a.z); pos.setXYZ(1, b.x, b.y, b.z);
  pos.needsUpdate = true;
  t.l.material.opacity = 0.65; t.l.life = 0.07; t.l.visible = true;
}
function updateTracers(dt) {
  for (const t of TRACERS.pool) {
    if (!t.l.visible) continue;
    t.life -= dt;
    t.l.material.opacity = Math.max(0, t.life / 0.07) * 0.65;
    if (t.life <= 0) t.l.visible = false;
  }
}

/* --- фабрика солдат (боты) --- */
const SOLDIER_TINT = {};
function soldierTintedMats(team) {
  if (SOLDIER_TINT[team]) return SOLDIER_TINT[team];
  const map = {};
  GLB.soldier.scene.traverse(o => {
    if (o.isMesh) {
      const mats = Array.isArray(o.material) ? o.material : [o.material];
      for (const m of mats) {
        if (m.name && m.name.indexOf('Soldat') >= 0 && !map[m.name]) {
          const nm = m.clone();
          if (team === 'RU') nm.color.multiply(new THREE.Color(0.5, 0.9, 0.5));
          else nm.color.multiply(new THREE.Color(1.15, 0.85, 0.5));
          map[m.name] = nm;
        }
      }
    }
  });
  SOLDIER_TINT[team] = map;
  return map;
}
function makeSoldier(team, wkey) {
  /* собственный экземпляр солдата из пула (bind корректен); fallback — clone */
  const skinObj = GLB.soldierSkins && GLB.soldierSkins.length ? GLB.soldierSkins.pop() : null;
  const clone = skinObj ? skinObj.scene : THREE.SkeletonUtils.clone(GLB.soldier.scene);
  if (skinObj) {
    // при переиспользовании скина восстанавливаем исходную (bind) позу костей
    if (!skinObj.restQ) {
      skinObj.restQ = {};
      clone.traverse(o => { if (o.isBone) skinObj.restQ[o.name] = o.quaternion.clone(); });
    } else {
      clone.traverse(o => { if (o.isBone && skinObj.restQ[o.name]) o.quaternion.copy(skinObj.restQ[o.name]); });
    }
  }
  const tint = soldierTintedMats(team);
  clone.traverse(o => {
    if (o.isMesh) {
      const mats = Array.isArray(o.material) ? o.material : [o.material];
      const nm = mats.map(m => (m.name && tint[m.name]) ? tint[m.name] : m);
      o.material = Array.isArray(o.material) ? nm : nm[0];
      o.frustumCulled = false; // скелетная анимация за пределами bbox
    }
    if (o.isSkinnedMesh) {
      // пересчитываем boneInverses из текущих matrixWorld (модель в метрах):
      // boneMatrix = mw(теперь) × mw(bind) = чистый дельта-поворот, позы работают
      clone.updateMatrixWorld(true);
      const inv = o.skeleton.bones.map(b => new THREE.Matrix4().copy(b.matrixWorld).invert());
      o.bind(new THREE.Skeleton(o.skeleton.bones, inv), o.matrixWorld);
    }
  });
  const U = 1; // масштаб на клоне (как в исходной загрузке), units на метр
  clone.scale.setScalar(1.8 / GLB.soldierH);
  const wrap = new THREE.Group();
  wrap.add(clone);
  scene.add(wrap);
  /* анимация в GLB нет (клип нулевой длительности) — используем процедурные позы; mixer не создаём */
  // --- процедурная анимация: поза покоя + оси качания ---
  const bones = {}, rest = new Map(), ax = {};
  const want = { hips: 'hips_01', spine: 'spine_06', chest: 'chest_07', head: 'head_09',
    armL: 'armL_011', forearmL: 'forearmL_012', armR: 'armR_025', forearmR: 'forearmR_026',
    uplegL: 'uplegL_02', legL: 'legL_03', uplegR: 'uplegR_038', legR: 'legR_039' };
  for (const k in want) {
    const bn = clone.getObjectByName(want[k]);
    if (!bn) continue;
    bones[k] = bn;
    rest.set(k, { q: bn.quaternion.clone(), p: bn.position.clone() });
  }
  wrap.updateMatrixWorld(true);
  for (const k in bones) {
    const q = new THREE.Quaternion();
    bones[k].parent.getWorldQuaternion(q).invert();
    ax[k] = new THREE.Vector3(0, 0, 1).applyQuaternion(q).normalize(); // замах вперёд-назад
    ax[k + 'X'] = new THREE.Vector3(1, 0, 0).applyQuaternion(q).normalize(); // опускание/наклон вбок
  }
  // --- оружие в руках (независимый экземпляр viewmodel-обёртки) ---
  let gun = null;
  if (wkey && VM[wkey]) {
    const def = WPN[wkey];
    const gw = VM[wkey].holder.children[0].clone(true);
    const gh = new THREE.Group();
    gh.add(gw);
    gh.rotation.y = -Math.PI / 2;            // дуло (-Z) вперёд по +X солдата
    gh.position.set(0.45, 1.02, -0.14);      // перед правым бедром, вне тела
    const fl = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.spark, color: 0xffd27a, transparent: true, depthTest: false, blending: THREE.AdditiveBlending }));
    fl.scale.setScalar(def.len * 0.16);
    fl.position.set(0, def.len * 0.03, -def.len * 0.48);
    fl.visible = false;
    gh.add(fl);
    wrap.add(gh);
    gun = { holder: gh, flash: fl, flashT: 0, name: def.name };
  }
  return { wrap, bones, rest, ax, gun, skinObj, units: U };
}

/* ================= ИГРОК ================= */
const P = {
  team: 'RU', cls: 'assault', name: 'ВЫ',
  pos: new THREE.Vector3(-172, 2, 152), vel: new THREE.Vector3(),
  yaw: 0, pitch: 0, hp: 100, alive: true, deaths: 0, kills: 0, caps: 0,
  weapons: [], wIdx: 0, fireHeld: false, lastFire: 0, reloadT: 0, ads: false, adsT: 0,
  sprint: false, onGround: true, lastHurt: -99, respawnT: 0, killsBots: 0,
  stance: 0, // для качания: время шага
};
const EYE = 1.62;
const BASES = { RU: { x: -172, z: 152 }, US: { x: 172, z: -152 } };
const BOT_NAMES = {
  RU: ['Волков', 'Морозов', 'Соколов', 'Орлов', 'Кузнецов', 'Белов', 'Зайцев', 'Громов', 'Данилов', 'Ильин'],
  US: ['Miller', 'Carter', 'Brooks', 'Hayes', 'Reed', 'Coleman', 'Barnes', 'Turner', 'Ward', 'Quinn'],
};

function playerSpawn() {
  const b = BASES[P.team];
  P.pos.set(b.x + rand(-7, 7), 0, b.z + (P.team === 'US' ? -rand(13, 18) : rand(13, 18)));
  // выталкивание из построек базы, если попали внутрь
  for (let tries = 0; tries < 14 && pointBlocked(P.pos.x, P.pos.z, 0.6); tries++) {
    P.pos.z += (P.team === 'US' ? -1.5 : 1.5);
    P.pos.x += rand(-1.5, 1.5);
  }
  P.pos.y = terrainH(P.pos.x, P.pos.z) + EYE;
  P.yaw = Math.atan2(-(POINTS[1].x - P.pos.x), -(POINTS[1].z - P.pos.z)); // взгляд на центр (B)
  P.pitch = 0; P.hp = 100; P.alive = true; P.ads = false; P.reloadT = 0;
  P.vel.set(0, 0, 0);
  // полные магазины
  for (const w of P.weapons) { w.mag = w.def.mag; w.res = w.def.reserve; }
  P.wIdx = 0;
  equipWeapon();
}

function setupLoadout(side, cls) {
  P.team = side; P.cls = cls;
  P.weapons = CLASSES[side][cls].map(k => ({ def: WPN[k], key: k, mag: WPN[k].mag, res: WPN[k].reserve }));
}

function equipWeapon() {
  const w = P.weapons[P.wIdx];
  if (!w) return;
  for (const k in VM) if (VM[k].holder.parent) VM[k].holder.parent.remove(VM[k].holder);
  vmScene.add(VM[w.key].holder);
  VM[w.key].holder.visible = true;
  $('wname').textContent = w.def.name;
  $('wmode').textContent = w.def.mode;
  AUDIO.switchW();
  updateAmmoHUD();
}
function updateAmmoHUD() {
  const w = P.weapons[P.wIdx];
  if (!w) return;
  const el = $('ammo-cur');
  el.textContent = P.reloadT > 0 ? '—' : w.mag;
  el.classList.toggle('dry', w.mag <= 0 && P.reloadT <= 0);
  $('ammo-res').textContent = '/ ' + w.res;
}
function switchWeapon(idx) {
  if (!P.alive || idx === P.wIdx || !P.weapons[idx] || P.reloadT > 0) return;
  P.wIdx = idx;
  setADS(false);
  equipWeapon();
}
function startReload() {
  const w = P.weapons[P.wIdx];
  if (!P.alive || P.reloadT > 0 || w.mag >= w.def.mag || w.res <= 0) return;
  P.reloadT = w.def.reload;
  AUDIO.reload();
}
function finishReload() {
  const w = P.weapons[P.wIdx];
  const need = w.def.mag - w.mag, take = Math.min(need, w.res);
  w.mag += take; w.res -= take;
  updateAmmoHUD();
}

/* --- прицеливание --- */
function setADS(on) {
  const w = P.weapons[P.wIdx];
  const hasScope = w.def.scope;
  P.ads = on;
  if (hasScope) {
    $('scope').classList.toggle('hidden', !on);
    $('xhair').style.display = on ? 'none' : '';
    if (VM[w.key]) VM[w.key].holder.visible = !on;
  }
}

/* --- стрельба игрока --- */
const rayc = new THREE.Raycaster();
function spreadDir(base, deg) {
  const d = base.clone();
  const rad = (deg * Math.PI / 180) * Math.sqrt(Math.random());
  const ang = Math.random() * Math.PI * 2;
  const up = new THREE.Vector3(0, 1, 0);
  const right = new THREE.Vector3().crossVectors(d, up).normalize();
  const trueUp = new THREE.Vector3().crossVectors(right, d).normalize();
  d.addScaledVector(right, Math.cos(ang) * Math.tan(rad));
  d.addScaledVector(trueUp, Math.sin(ang) * Math.tan(rad));
  return d.normalize();
}
function currentSpread() {
  const w = P.weapons[P.wIdx];
  let s = P.ads ? w.def.sAds : w.def.sHip;
  const speed = Math.sqrt(P.vel.x * P.vel.x + P.vel.z * P.vel.z);
  s += speed * 0.09;
  return s;
}
function firePlayer() {
  if (!P.alive || G.state !== 'play') return;
  const w = P.weapons[P.wIdx];
  if (P.reloadT > 0) return;
  if (performance.now() - P.lastFire < 60000 / w.def.rpm) return;
  if (w.mag <= 0) { AUDIO.dry(); P.lastFire = performance.now(); return; }
  w.mag--; P.lastFire = performance.now();
  AUDIO.shot(w.def.tone);
  // вспышка viewmodel
  const vm = VM[w.key];
  vm.flash.visible = true; vm.flash.material.rotation = rand(0, 6.3);
  setTimeout(() => { vm.flash.visible = false; }, 45);
  // отдача
  P.pitch += w.def.kick * 0.010 * rand(0.7, 1.3);
  P.yaw += w.def.kick * 0.003 * rand(-1, 1);
  vmKickZ += w.def.kick * 0.018; vmKickRoll += w.def.kick * 0.012 * rand(-1, 1);
  // луч
  const fwd = new THREE.Vector3(0, 0, -1).applyQuaternion(camera.quaternion);
  const dir = spreadDir(fwd, currentSpread());
  const origin = camera.position.clone();
  rayc.set(origin, dir);
  rayc.far = 500;
  const hits = rayc.intersectObjects(LOS_MESHES, false);
  const wallD = hits.length ? hits[0].distance : 500;
  // враги: сферы (голова/тело/ноги)
  let best = null, bestD = wallD, bestHead = false;
  for (const b of BOTS) {
    if (!b.alive || b.team === P.team) continue;
    const headC = new THREE.Vector3(b.pos.x, b.pos.y + 1.58, b.pos.z);
    const bodyC = new THREE.Vector3(b.pos.x, b.pos.y + 0.95, b.pos.z);
    const legC = new THREE.Vector3(b.pos.x, b.pos.y + 0.42, b.pos.z);
    const t1 = raySphere(origin, dir, headC, 0.19);
    if (t1 > 0 && t1 < bestD) { best = b; bestD = t1; bestHead = true; }
    const t2 = raySphere(origin, dir, bodyC, 0.42);
    if (t2 > 0 && t2 < bestD) { best = b; bestD = t2; bestHead = false; }
    const t3 = raySphere(origin, dir, legC, 0.34);
    if (t3 > 0 && t3 < bestD) { best = b; bestD = t3; bestHead = false; }
  }
  const muzzleW = origin.clone().addScaledVector(fwd, 0.35).addScaledVector(new THREE.Vector3(0, 1, 0), -0.08);
  if (best) {
    const end = origin.clone().addScaledVector(dir, bestD);
    spawnTracer(muzzleW, end);
    spawnParticle(TEX.blood, end, 0xc02015, rand(0.18, 0.3), new THREE.Vector3(rand(-1, 1), rand(1, 2.5), rand(-1, 1)), 0.4);
    let dmg = w.def.dmg * (bestHead ? 1.8 : 1);
    damageBot(best, dmg, 'player', w.def.name);
    showHitmark(bestHead);
    if (bestHead) AUDIO.headshot(); else AUDIO.hit();
    NET.send('shot', { d: bestD, x: end.x, y: end.y, z: end.z }); // NET: попадания для синхронизации
  } else {
    const end = origin.clone().addScaledVector(dir, wallD);
    spawnTracer(muzzleW, end);
    if (wallD < 499) {
      spawnParticle(TEX.spark, end, 0xffd27a, rand(0.12, 0.2), new THREE.Vector3(rand(-1.5, 1.5), rand(1, 3), rand(-1.5, 1.5)), 0.22);
      spawnParticle(TEX.smoke, end, 0xd8cdb4, rand(0.2, 0.34), new THREE.Vector3(rand(-0.5, 0.5), rand(0.8, 1.6), rand(-0.5, 0.5)), 0.5);
    }
    NET.send('shot', { d: wallD, x: end.x, y: end.y, z: end.z });
  }
  updateAmmoHUD();
  if (w.mag <= 0) setTimeout(() => { if (P.alive) startReload(); }, 220);
}
function raySphere(o, d, c, r) {
  const oc = new THREE.Vector3().subVectors(o, c);
  const b = oc.dot(d);
  const cc = oc.dot(oc) - r * r;
  const disc = b * b - cc;
  if (disc < 0) return -1;
  const t = -b - Math.sqrt(disc);
  return t > 0 ? t : -1;
}

/* --- урон игроку --- */
function damagePlayer(dmg, killerName, weaponName) {
  if (!P.alive || G.state !== 'play') return;
  P.hp -= dmg; P.lastHurt = performance.now();
  AUDIO.hurt();
  const dv = $('dmg-vig');
  dv.style.opacity = String(clamp(0.35 + (1 - P.hp / 100) * 0.55, 0, 0.95));
  setTimeout(() => { dv.style.opacity = String(clamp((1 - P.hp / 100) * 0.35, 0, 0.4)); }, 240);
  if (P.hp <= 0) {
    P.hp = 0; P.alive = false; P.deaths++;
    tickets[P.team] = Math.max(0, tickets[P.team] - 1);
    AUDIO.death();
    P.respawnT = 6;
    setADS(false);
    $('death-killer').textContent = killerName ? (killerName + (weaponName ? ' • ' + weaponName : '')) : '—';
    showDeath(true);
  }
  updateHPHUD();
}
function updateHPHUD() {
  const hp = Math.max(0, Math.round(P.hp));
  $('hp-num').textContent = hp;
  const f = $('hp-fill');
  f.style.width = hp + '%';
  f.classList.toggle('low', hp < 30);
  f.classList.toggle('mid', hp >= 30 && hp < 60);
}
function playerRespawn() {
  playerSpawn();
  showDeath(false);
  const dv = $('dmg-vig'); dv.style.opacity = '0';
  updateHPHUD();
}

/* --- движение игрока --- */
const keys = {};
function movePlayer(dt) {
  if (!P.alive) return;
  const w = P.weapons[P.wIdx];
  P.sprint = !!keys['ShiftLeft'] && !P.ads && P.reloadT <= 0;
  let mx = 0, mz = 0;
  if (keys['KeyW']) mz -= 1;
  if (keys['KeyS']) mz += 1;
  if (keys['KeyA']) mx -= 1;
  if (keys['KeyD']) mx += 1;
  const moving = (mx !== 0 || mz !== 0);
  const spd = P.ads ? 2.4 : (P.sprint ? 7.0 : 4.7);
  const sin = Math.sin(P.yaw), cos = Math.cos(P.yaw);
  let dx = 0, dz = 0;
  if (moving) {
    const inv = 1 / Math.hypot(mx, mz);
    mx *= inv; mz *= inv;
    // forward = (-sin yaw, -cos yaw), right = (cos yaw, -sin yaw) — как у камеры
    dx = (mx * cos + mz * sin) * spd * dt;
    dz = (-mx * sin + mz * cos) * spd * dt;
  }
  // коллизия по осям (радиус 0.4)
  const r = 0.4;
  let nx = P.pos.x + dx, nz = P.pos.z + dz;
  if (pointBlocked(nx, P.pos.z, r)) nx = P.pos.x;
  if (pointBlocked(nx, nz, r)) nz = P.pos.z;
  nx = clamp(nx, -MAP.half + 2, MAP.half - 2);
  nz = clamp(nz, -MAP.half + 2, MAP.half - 2);
  P.vel.x = (nx - P.pos.x) / dt; P.vel.z = (nz - P.pos.z) / dt;
  P.pos.x = nx; P.pos.z = nz;
  // прыжок/гравитация
  const gy = terrainH(P.pos.x, P.pos.z) + EYE;
  if (keys['Space'] && P.onGround) { P.vel.y = 4.6; P.onGround = false; }
  P.vel.y -= 13 * dt;
  P.pos.y += P.vel.y * dt;
  if (P.pos.y <= gy) { P.pos.y = gy; P.vel.y = 0; P.onGround = true; }
  // шаг-время для бобa
  if (moving && P.onGround) P.stance += dt * (P.sprint ? 11.5 : 7.5);
  // реген HP
  if (P.hp < 100 && performance.now() - P.lastHurt > 5000) {
    P.hp = Math.min(100, P.hp + 7 * dt);
    updateHPHUD();
  }
  // перезарядка
  if (P.reloadT > 0) {
    P.reloadT -= dt;
    if (P.reloadT <= 0) { P.reloadT = 0; finishReload(); }
  }
  // огонь
  const wpn = P.weapons[P.wIdx];
  if (P.fireHeld && wpn.def.auto) firePlayer();
  else if (P.fireHeld && !P._clicked) { firePlayer(); P._clicked = true; }
}

/* ================= БОТЫ ================= */
const BOTS = [];
const tickets = { RU: 250, US: 250 };
function spawnBots() {
  for (const b of BOTS) {
    scene.remove(b.mesh.wrap);
    if (b.mesh.skinObj) GLB.soldierSkins.push(b.mesh.skinObj); // скин обратно в пул
  }
  BOTS.length = 0;
  const teams = [P.team === 'RU' ? 'US' : 'RU', P.team];
  let ni = { RU: 0, US: 0 };
  for (const team of teams) {
    const n = (team === P.team) ? 6 : 7; // 6 союзников + 7 противников (игрок 8-й за свою)
    for (let i = 0; i < n; i++) {
      const name = BOT_NAMES[team][ni[team]++ % BOT_NAMES[team].length];
      const wkey = (i % 4 === 3) ? (team === 'RU' ? 'svd' : 'm82') : (team === 'RU' ? 'ak74' : 'm16');
      const mesh = makeSoldier(team, wkey);
      const b = {
        team, name, mesh, alive: true, hp: 100,
        pos: new THREE.Vector3(), yaw: 0,
        state: 'advance', goal: null, enemy: null,
        nextThink: rand(0, 0.5), nextShot: 0, burst: 0, pauseT: 0,
        respawnT: 0, strafe: 0, kills: 0, deaths: 0, seesPlayer: false,
        weaponName: WPN[wkey].name,
        holdA: rand(0, Math.PI * 2), holdR: rand(2.5, 7), holdYaw: null, scanT: rand(0, 6),
        animT: rand(0, 6), speed: 0,
      };
      botRespawn(b, true);
      BOTS.push(b);
    }
  }
}
function botRespawn(b, instant) {
  const base = BASES[b.team];
  if (!instant) b.deaths++;
  b.pos.set(base.x + rand(-9, 9), 0, base.z + (b.team === 'US' ? -rand(12, 18) : rand(12, 18)));
  for (let tries = 0; tries < 14 && pointBlocked(b.pos.x, b.pos.z, 0.6); tries++) {
    b.pos.z += (b.team === 'US' ? -1.5 : 1.5);
    b.pos.x += rand(-1.5, 1.5);
  }
  b.pos.y = terrainH(b.pos.x, b.pos.z);
  b.hp = 100; b.alive = true; b.state = 'advance'; b.enemy = null; b.goal = null;
  b.holdA = rand(0, Math.PI * 2); b.holdR = rand(2.5, 7); b.holdYaw = null; b.speed = 0;
  if (b.mesh.gun) b.mesh.gun.holder.visible = true;
  b.mesh.wrap.visible = true;
  b.mesh.wrap.rotation.z = 0;
  b.mesh.wrap.position.copy(b.pos);
}
function botDie(b, killer, weapon) {
  if (!b.alive) return;
  b.alive = false; b.respawnT = 7; b.enemy = null;
  tickets[b.team] = Math.max(0, tickets[b.team] - 1);
  if (killer === 'player') { P.kills++; AUDIO.kill(); }
  else if (killer && killer.kills !== undefined) killer.kills++;
  addFeed(killer, killer === 'player' ? P.team : (killer && killer.team), b, weapon || b.weaponName);
  // падение
  b.mesh.wrap.rotation.z = rand(-1.5, 1.5) * 0.14 + (Math.random() < 0.5 ? 1.35 : -1.35);
  b.mesh.wrap.position.y = terrainH(b.pos.x, b.pos.z) + 0.12;
}
function damageBot(b, dmg, killer, weaponName) {
  if (!b.alive) return;
  b.hp -= dmg;
  if (killer === 'player' && b.hp > 0 && !b.enemy) { b.enemy = { pos: P.pos, isP: true }; b.state = 'combat'; } // ответный огонь
  if (b.hp <= 0) botDie(b, killer, weaponName);
}
/* выбор цели-точки: ближайшая не-своя, иначе оборона своей; офсеты разбрасывают ботов */
function pickGoal(b) {
  let best = null, bestScore = 1e9;
  for (const p of POINTS) {
    const owned = p.owner === b.team;
    const d = dist2d(b.pos.x, b.pos.z, p.x, p.z);
    let score = d + rand(0, 24); // разброс — чтобы толпа не шла в одну точку
    if (owned) score += 90; // свои менее приоритетны
    if (p.owner && p.owner !== b.team) score -= 40; // чужие — приоритет
    if (!owned && p.prog !== 0 && p.prog * (b.team === 'RU' ? 1 : -1) > 0) score += 30; // частично наша
    if (score < bestScore) { bestScore = score; best = p; }
  }
  b.goal = best;
  b.holdA = rand(0, Math.PI * 2); b.holdR = rand(2.5, 7);
}
function botLOS(b, tx, ty, tz) {
  const o = new THREE.Vector3(b.pos.x, b.pos.y + 1.5, b.pos.z);
  const t = new THREE.Vector3(tx, ty, tz);
  const d = new THREE.Vector3().subVectors(t, o);
  const dist = d.length();
  d.normalize();
  rayc.set(o, d); rayc.far = dist;
  const hits = rayc.intersectObjects(LOS_MESHES, false);
  return !(hits.length && hits[0].distance < dist - 0.5);
}
function botThink(b, dt) {
  b.nextThink -= dt;
  if (b.nextThink > 0) return;
  b.nextThink = rand(0.35, 0.65);
  // поиск врага
  let best = null, bestD = 78;
  const candidates = [];
  if (P.alive && P.team !== b.team) candidates.push({ pos: P.pos, isP: true });
  for (const o of BOTS) if (o.alive && o.team !== b.team) candidates.push({ pos: o.pos, isP: false, bot: o });
  for (const c of candidates) {
    const d = dist2d(b.pos.x, b.pos.z, c.pos.x, c.pos.z);
    if (d < bestD && botLOS(b, c.pos.x, c.pos.y + (c.isP ? 1.4 : 1.2), c.pos.z)) { best = c; bestD = d; }
  }
  if (best) {
    b.enemy = best;
    b.state = 'combat';
  } else {
    if (b.state === 'combat') { b.state = 'advance'; b.enemy = null; }
    let need = !b.goal;
    if (b.goal) {
      const gd = dist2d(b.pos.x, b.pos.z, b.goal.x, b.goal.z);
      const capturing = !b.goal.owner || b.goal.owner !== b.team;
      if (capturing && gd < b.goal.r * 0.8) need = false; // стоим и держим, пока точка не наша
      else if (gd < 6) need = true; // дошли (или точка стала нашей) — ищем следующую
      else if (Math.random() < 0.05) need = true;
    }
    if (need) pickGoal(b);
  }
}
function botShoot(b, dt) {
  b.nextShot -= dt;
  if (b.nextShot > 0 || !b.enemy) return;
  const e = b.enemy;
  const dist = dist2d(b.pos.x, b.pos.z, e.pos.x, e.pos.z);
  if (b.pauseT > 0) { b.pauseT -= dt; return; }
  if (b.burst <= 0) { b.burst = randi(3, 7); }
  b.nextShot = 60 / 600 + rand(0, 0.04);
  b.burst--;
  if (b.burst <= 0) b.pauseT = rand(0.4, 1.1);
  AUDIO.enemyShot(dist);
  // вспышка + трассер — стрельбу видно
  if (b.mesh.gun) {
    b.mesh.gun.flash.visible = true;
    b.mesh.gun.flashT = 0.05;
  }
  const hitChance = clamp(0.40 - dist * 0.0038, 0.07, 0.4) * (e.isP ? (P.sprint ? 0.72 : 1) : 1);
  const willHit = Math.random() < hitChance;
  const tp = new THREE.Vector3(
    e.pos.x + (willHit ? 0 : rand(-1.2, 1.2)),
    (e.isP ? e.pos.y - 0.35 : e.pos.y + 1.25) + (willHit ? 0 : rand(-0.5, 0.8)),
    e.pos.z + (willHit ? 0 : rand(-1.2, 1.2))
  );
  if (b.mesh.gun) {
    const mz = new THREE.Vector3();
    b.mesh.gun.flash.getWorldPosition(mz);
    spawnTracer(mz, tp);
  }
  // попадание по цели
  if (willHit) {
    const dmg = rand(8, 17);
    if (e.isP) damagePlayer(dmg, b.name, b.weaponName);
    else damageBot(e.bot, dmg * 2.2, b, b.weaponName);
    if (e.isP) AUDIO.whiz();
  } else if (e.isP) {
    AUDIO.whiz();
  }
}
function moveBot(b, dt) {
  if (!b.alive) return;
  b.speed = 0;
  let vx = 0, vz = 0;
  if (b.state === 'combat' && b.enemy) {
    // лицом к врагу, лёгкий стрейф
    const e = b.enemy;
    const wantYaw = Math.atan2(e.pos.x - b.pos.x, e.pos.z - b.pos.z);
    let dy = wantYaw - b.yaw;
    while (dy > Math.PI) dy -= Math.PI * 2;
    while (dy < -Math.PI) dy += Math.PI * 2;
    b.yaw += clamp(dy, -3.5 * dt, 3.5 * dt);
    b.strafe += dt;
    const sd = Math.sin(b.strafe * 1.7) * 1.6;
    const rx = Math.cos(b.yaw), rz = -Math.sin(b.yaw);
    vx = rx * sd * dt; vz = rz * sd * dt;
    b.speed = Math.abs(sd);
  } else if (b.goal) {
    const hx = b.goal.x + Math.cos(b.holdA) * b.holdR;
    const hz = b.goal.z + Math.sin(b.holdA) * b.holdR;
    const dx = hx - b.pos.x, dz = hz - b.pos.z;
    const dh = Math.hypot(dx, dz);
    if (dh > 1.8) {
      const wantYaw = Math.atan2(dx, dz);
      let dy = wantYaw - b.yaw;
      while (dy > Math.PI) dy -= Math.PI * 2;
      while (dy < -Math.PI) dy += Math.PI * 2;
      b.yaw += clamp(dy, -4 * dt, 4 * dt);
      const spd = 4.3;
      vx = Math.sin(b.yaw) * spd * dt; vz = Math.cos(b.yaw) * spd * dt;
      b.speed = spd; b.holdYaw = null;
    } else {
      // дошли до своего места у точки: стоим и осматриваемся
      if (b.holdYaw === null) b.holdYaw = b.yaw;
      b.scanT += dt;
      b.yaw = b.holdYaw + Math.sin(b.scanT * 0.7) * 0.9;
    }
  }
  // расталкивание ботов — без толкучки и хороводов
  let sx = 0, sz = 0;
  for (const o of BOTS) {
    if (o === b || !o.alive) continue;
    const ddx = b.pos.x - o.pos.x, ddz = b.pos.z - o.pos.z;
    const d2 = ddx * ddx + ddz * ddz;
    if (d2 < 1.44 && d2 > 1e-6) {
      const d = Math.sqrt(d2);
      sx += (ddx / d) * (1.2 - d); sz += (ddz / d) * (1.2 - d);
    }
  }
  const push = b.speed > 0 ? 2.0 : 3.2;
  vx += sx * push * dt; vz += sz * push * dt;
  // объезд препятствий
  const r = 0.45;
  let nx = b.pos.x + vx, nz = b.pos.z + vz;
  if (pointBlocked(nx, nz, r)) {
    // пробуем повороты
    const back = Math.atan2(vx, vz);
    let ok = false;
    for (const off of [0.6, -0.6, 1.2, -1.2, 1.8, -1.8]) {
      const a = back + off;
      const tx = b.pos.x + Math.sin(a) * Math.hypot(vx, vz), tz = b.pos.z + Math.cos(a) * Math.hypot(vx, vz);
      if (!pointBlocked(tx, tz, r)) { nx = tx; nz = tz; ok = true; break; }
    }
    if (!ok) { nx = b.pos.x; nz = b.pos.z; }
  }
  nx = clamp(nx, -MAP.half + 2, MAP.half - 2);
  nz = clamp(nz, -MAP.half + 2, MAP.half - 2);
  b.pos.x = nx; b.pos.z = nz;
  b.pos.y = terrainH(b.pos.x, b.pos.z);
}
/* процедурная поза поверх T-позы: ходьба / прицел / простой */
function poseBot(b, dt) {
  const bones = b.mesh.bones;
  if (!bones || !b.mesh.rest) return;
  const rest = b.mesh.rest, ax = b.mesh.ax;
  const moving = b.speed > 0.3;
  const inCombat = b.state === 'combat' && b.enemy;
  b.animT += dt * (moving ? clamp(b.speed, 2.5, 6) * 1.9 : 1.5);
  const t = b.animT;
  const q = new THREE.Quaternion();
  const set = (k, ang) => {
    const bn = bones[k];
    if (!bn || !rest.has(k)) return;
    bn.quaternion.copy(rest.get(k).q).multiply(q.setFromAxisAngle(ax[k], ang));
  };
  const set2 = (k, zAng, xAng) => {
    const bn = bones[k];
    if (!bn || !rest.has(k)) return;
    bn.quaternion.copy(rest.get(k).q)
      .multiply(q.setFromAxisAngle(ax[k], zAng)).multiply(new THREE.Quaternion().setFromAxisAngle(ax[k + 'X'], xAng));
  };
  const w = moving ? Math.sin(t) : 0;
  const hip = bones.hips;
  if (hip && rest.has('hips')) {
    hip.position.copy(rest.get('hips').p);
    hip.position.y += (moving ? Math.abs(Math.cos(t)) * 0.05 : Math.sin(t * 1.3) * 0.008) * (b.mesh.units || 1); // боб в units кости
  }
  if (inCombat) {
    // оружие к плечу: обе руки вперёд, лёгкое покачивание
    set2('armR', -1.30 + w * 0.04, -0.30); set('forearmR', 0.50);
    set2('armL', -1.00 + w * 0.04, 0.25); set('forearmL', 0.85);
    set('spine', 0.07); set('head', -0.05);
    set('uplegL', 0.05 + w * 0.35); set('uplegR', 0.05 - w * 0.35);
    set('legL', -Math.max(0, w) * 0.5); set('legR', -Math.max(0, -w) * 0.5);
    set('chest', 0.04);
  } else if (moving) {
    // ходьба: ноги машут, руки опущены и в противофазе
    set('uplegL', 0.52 * w); set('uplegR', -0.52 * w);
    set('legL', -Math.max(0, w) * 0.75); set('legR', -Math.max(0, -w) * 0.75);
    set2('armL', -0.40 * w, 1.15); set2('armR', 0.40 * w, -1.15);
    set('forearmL', 0.35); set('forearmR', 0.35);
    set('spine', 0.09); set('head', -0.04);
    set('chest', 0.02 * Math.sin(t * 2));
  } else {
    // простой: руки опущены вдоль тела, дыхание
    const br = Math.sin(t * 1.3);
    set2('armL', -0.12 + br * 0.02, 1.22); set2('armR', -0.12 - br * 0.02, -1.22);
    set('forearmL', 0.28); set('forearmR', 0.28);
    set('spine', 0.02 + br * 0.015); set('head', br * 0.02);
    set('uplegL', 0.02); set('uplegR', -0.02);
    set('legL', -0.01); set('legR', -0.01);
  }
}
function updateBots(dt) {
  for (const b of BOTS) {
    if (!b.alive) {
      b.respawnT -= dt;
      if (b.respawnT <= 0) botRespawn(b);
      continue;
    }
    botThink(b, dt);
    if (b.state === 'combat') botShoot(b, dt);
    moveBot(b, dt);
    b.mesh.wrap.position.set(b.pos.x, b.pos.y, b.pos.z);
    b.mesh.wrap.rotation.y = b.yaw - Math.PI / 2; // модель смотрит вдоль +X (по калибровке)
    poseBot(b, dt);
    if (b.mesh.gun && b.mesh.gun.flashT > 0) {
      b.mesh.gun.flashT -= dt;
      if (b.mesh.gun.flashT <= 0) b.mesh.gun.flash.visible = false;
    }
  }
}

/* ================= СОСТОЯНИЕ РАУНДА ================= */
const G = { state: 'menu', time: 600, elapsed: 0, timeScale: 1, lastCapTick: 0 };
let vmKickZ = 0, vmKickRoll = 0, lookVelX = 0, lookVelY = 0, baseFov = 75, batt = 86, battT = 0;

/* --- захват точек --- */
function updatePoints(dt) {
  for (const p of POINTS) {
    let ru = 0, us = 0;
    const pin = P.alive && dist2d(P.pos.x, P.pos.z, p.x, p.z) < p.r;
    if (pin) (P.team === 'RU' ? ru++ : us++);
    for (const b of BOTS) if (b.alive && dist2d(b.pos.x, b.pos.z, p.x, p.z) < p.r) (b.team === 'RU' ? ru++ : us++);
    p.contested = ru > 0 && us > 0;
    let dir = 0;
    if (ru > 0 && us === 0) dir = 1;
    else if (us > 0 && ru === 0) dir = -1;
    if (dir !== 0) {
      const mult = Math.min(3, Math.max(ru, us));
      const prev = p.prog;
      p.prog = clamp(p.prog + dir * 8.5 * mult * dt, -100, 100);
      // владение через пороги
      if (p.prog >= 100 && p.owner !== 'RU') {
        p.owner = 'RU'; refreshFlag(p);
        if (pin && P.team === 'RU') { P.caps++; AUDIO.capDone(); }
        addFeedPoint(p, 'RU');
      }
      if (p.prog <= -100 && p.owner !== 'US') {
        p.owner = 'US'; refreshFlag(p);
        if (pin && P.team === 'US') { P.caps++; AUDIO.capDone(); }
        addFeedPoint(p, 'US');
      }
      if ((prev > 0 && p.prog <= 0 && p.owner === 'RU') || (prev < 0 && p.prog >= 0 && p.owner === 'US')) {
        p.owner = null; refreshFlag(p);
        if (pin) AUDIO.lost();
      }
      // тики звука
      const now = performance.now();
      if (pin && now - G.lastCapTick > 480) { G.lastCapTick = now; AUDIO.capTick((dir > 0) === (P.team === 'RU')); }
    }
    // лёгкое возвращение к нулю, когда никто не рядом и точка ничья
    if (dir === 0 && !p.owner && p.prog !== 0) {
      p.prog = clamp(p.prog - Math.sign(p.prog) * 3 * dt, -100, 100);
    }
  }
}

/* --- билеты/кровотечение --- */
function updateTickets(dt) {
  const ruN = POINTS.filter(p => p.owner === 'RU').length;
  const usN = POINTS.filter(p => p.owner === 'US').length;
  if (ruN > usN && ruN >= 2) tickets.US = Math.max(0, tickets.US - (ruN - 1) * 0.55 * dt);
  if (usN > ruN && usN >= 2) tickets.RU = Math.max(0, tickets.RU - (usN - 1) * 0.55 * dt);
  if (tickets.RU <= 0) endRound('US');
  else if (tickets.US <= 0) endRound('RU');
}

/* ================= HUD ================= */
function updateHUDText() {
  $('tk-ru').textContent = 'RU ' + Math.ceil(tickets.RU);
  $('tk-us').textContent = 'US ' + Math.ceil(tickets.US);
  $('timer').textContent = fmtMMSS(G.time);
  for (const el of document.querySelectorAll('.pt')) {
    const p = POINTS.find(q => q.id === el.dataset.pt);
    el.className = 'pt' + (p.contested ? ' contested' : p.owner ? ' ' + p.owner.toLowerCase() : '');
  }
}
function updateHint() {
  let inP = null;
  for (const p of POINTS) if (P.alive && dist2d(P.pos.x, P.pos.z, p.x, p.z) < p.r) { inP = p; break; }
  const cw = $('cap-wrap');
  if (inP) {
    cw.classList.add('on');
    const frac = inP.owner ? 100 : Math.abs(inP.prog);
    let lab;
    if (inP.contested) {
      lab = 'ТОЧКА ' + inP.id + ' — СПОР';
      $('cap-fill').className = '';
      $('cap-fill').style.width = '50%';
    } else {
      const sign = inP.prog >= 0 ? 'RU' : 'US';
      lab = (inP.owner ? 'УДЕРЖАНИЕ ' : 'ЗАХВАТ ') + inP.id + ' «' + inP.name + '» — ' + Math.round(frac) + '%';
      $('cap-fill').className = inP.owner ? inP.owner.toLowerCase() : sign.toLowerCase();
      $('cap-fill').style.width = frac + '%';
    }
    $('cap-lab').textContent = lab;
    $('hint').textContent = 'ЦЕЛЬ: ЗАХВАТИТЬ И УДЕРЖИВАТЬ ТОЧКИ A · B · C';
  } else {
    cw.classList.remove('on');
    const enemyN = POINTS.filter(p => p.owner && p.owner !== P.team).length;
    $('hint').textContent = enemyN > 0 ? 'ПРОТИВНИК УДЕРЖИВАЕТ ' + enemyN + ' ' + (enemyN === 1 ? 'ТОЧКУ' : 'ТОЧКИ') + ' — ВЫБИТЬ ИХ' : 'ЦЕЛЬ: ЗАХВАТИТЬ И УДЕРЖИВАТЬ ТОЧКИ A · B · C';
  }
}

/* --- миникарта --- */
const mm = $('minimap'), mctx = mm.getContext('2d');
let mmT = 0;
function drawMinimap() {
  const W = mm.width, sc = W / (MAP.half * 2);
  const mx = x => (x + MAP.half) * sc, mz = z => (z + MAP.half) * sc;
  mctx.clearRect(0, 0, W, W);
  mctx.fillStyle = 'rgba(120,104,66,.25)'; mctx.fillRect(0, 0, W, W);
  mctx.fillStyle = 'rgba(40,40,36,.75)';
  for (const c of COLLIDERS) {
    mctx.fillRect(mx(c.x1), mz(c.z1), (c.x2 - c.x1) * sc, (c.z2 - c.z1) * sc);
  }
  for (const p of POINTS) {
    mctx.beginPath(); mctx.arc(mx(p.x), mz(p.z), 7.5, 0, 7);
    mctx.fillStyle = p.owner === 'RU' ? 'rgba(210,60,45,.85)' : p.owner === 'US' ? 'rgba(60,105,210,.85)' : 'rgba(190,190,180,.6)';
    mctx.fill();
    mctx.fillStyle = '#fff'; mctx.font = 'bold 9px monospace'; mctx.textAlign = 'center'; mctx.textBaseline = 'middle';
    mctx.fillText(p.id, mx(p.x), mz(p.z));
  }
  for (const b of BOTS) {
    if (!b.alive) continue;
    const friendly = b.team === P.team;
    if (!friendly && dist2d(b.pos.x, b.pos.z, P.pos.x, P.pos.z) > 95) continue;
    mctx.beginPath(); mctx.arc(mx(b.pos.x), mz(b.pos.z), 2.4, 0, 7);
    mctx.fillStyle = friendly ? '#8fdf6a' : '#ff5340';
    mctx.fill();
  }
  // игрок — стрелка
  if (P.alive) {
    mctx.save();
    mctx.translate(mx(P.pos.x), mz(P.pos.z));
    mctx.rotate(-P.yaw + Math.PI);
    mctx.fillStyle = '#fff';
    mctx.beginPath(); mctx.moveTo(0, -5.5); mctx.lineTo(3.8, 4); mctx.lineTo(-3.8, 4); mctx.closePath(); mctx.fill();
    mctx.restore();
  }
}

/* --- killfeed --- */
function addFeed(killer, killerTeam, victim, weapon) {
  const f = $('feed');
  const div = document.createElement('div');
  div.className = 'fitem' + (killer === 'player' || victim === 'player' ? ' mine' : '');
  const kName = killer === 'player' ? 'ВЫ' : (killer && killer.name ? killer.name : String(killer || '—'));
  const vName = victim === 'player' ? 'ВЫ' : (victim && victim.name ? victim.name : String(victim || '—'));
  const kT = killer === 'player' ? P.team : (killer && killer.team ? killer.team : killerTeam);
  const vT = victim === 'player' ? P.team : (victim && victim.team ? victim.team : (kT === 'RU' ? 'US' : 'RU'));
  div.innerHTML = '<span class="' + (kT === 'RU' ? 'tr' : 'tu') + '">' + kName + '</span> <span class="fw">[' + weapon + ']</span> <span class="' + (vT === 'RU' ? 'tr' : 'tu') + '">' + vName + '</span>';
  f.prepend(div);
  while (f.children.length > 5) f.removeChild(f.lastChild);
  setTimeout(() => div.classList.add('out'), 4200);
  setTimeout(() => { if (div.parentNode) div.parentNode.removeChild(div); }, 5000);
}
function addFeedPoint(p, team) {
  const f = $('feed');
  const div = document.createElement('div');
  div.className = 'fitem';
  div.innerHTML = '<span class="' + (team === 'RU' ? 'tr' : 'tu') + '">' + (team === 'RU' ? 'РОССИЯ' : 'США') + '</span> <span class="fw">захватила точку</span> <b>' + p.id + ' «' + p.name + '»</b>';
  f.prepend(div);
  while (f.children.length > 5) f.removeChild(f.lastChild);
  setTimeout(() => div.classList.add('out'), 4200);
  setTimeout(() => { if (div.parentNode) div.parentNode.removeChild(div); }, 5000);
}
function showHitmark(killLike) {
  const h = $('hitm');
  h.classList.remove('fade'); h.classList.add('show');
  h.querySelectorAll('.hx').forEach(x => x.classList.toggle('k', !!killLike));
  clearTimeout(h._t);
  h._t = setTimeout(() => { h.classList.remove('show'); h.classList.add('fade'); }, 110);
}

/* ================= BODYCAM-ЭФФЕКТЫ ================= */
let grainFrame = 0;
function grainStep() {
  if (++grainFrame % 2) return;
  const g = $('grain'), ctx = g.getContext('2d');
  const id = ctx.createImageData(g.width, g.height);
  const d = id.data;
  for (let i = 0; i < d.length; i += 4) {
    const v = (Math.random() * 255) | 0;
    d[i] = d[i + 1] = d[i + 2] = v; d[i + 3] = 46;
  }
  ctx.putImageData(id, 0, 0);
}
function updateBodycam(dt) {
  G.elapsed += dt;
  $('bc-tc').textContent = 'TC ' + fmtMMSS(G.elapsed);
  battT += dt;
  if (battT > 75 && batt > 15) { battT = 0; batt--; $('bc-battxt').textContent = 'BATT ' + batt + '%'; $('bc-batfill').style.width = batt + '%'; }
}

/* ================= КАМЕРА И VIEWMODEL ================= */
const n1 = t => (Math.sin(t * 1.1) + 0.6 * Math.sin(t * 1.73 + 1.3) + 0.35 * Math.sin(t * 2.9 + 2.1)) / 1.95;
const n2 = t => (Math.sin(t * 1.3 + 0.7) + 0.6 * Math.sin(t * 2.11 + 2.2) + 0.35 * Math.sin(t * 3.3 + 0.4)) / 1.95;
function updateCamera(dt) {
  const t = performance.now() / 1000;
  const speed = Math.hypot(P.vel.x, P.vel.z);
  const moving = clamp(speed / 4.7, 0, 1.4);
  const e = smooth(P.adsT);
  const amp = P.ads ? 0.35 : (P.sprint ? 1.9 : 1.0);
  camera.rotation.order = 'YXZ';
  camera.position.set(
    P.pos.x + Math.sin(P.stance * 0.5) * 0.012 * moving * amp,
    P.pos.y + Math.abs(Math.sin(P.stance)) * 0.045 * moving * amp,
    P.pos.z
  );
  camera.rotation.y = P.yaw + n1(t * 0.9) * 0.0055 * amp;
  camera.rotation.x = P.pitch + n2(t * 1.1) * 0.0045 * amp + Math.abs(Math.sin(P.stance)) * 0.006 * moving * amp;
  camera.rotation.z = n1(t * 0.7) * 0.006 * amp + vmKickRoll * 0.5 + (keys['KeyA'] ? 0.012 : 0) - (keys['KeyD'] ? 0.012 : 0);
  const wantFov = P.ads ? P.weapons[P.wIdx].def.adsFov : (P.sprint && moving > 0.1 ? 80 : 75);
  baseFov = lerp(baseFov, wantFov, clamp(dt * 9, 0, 1));
  camera.fov = baseFov;
  camera.updateProjectionMatrix();
}
function updateVM(dt) {
  const w = P.weapons[P.wIdx];
  const vm = VM[w.key];
  if (!vm) return;
  P.adsT = lerp(P.adsT, P.ads ? 1 : 0, clamp(dt * 11, 0, 1));
  const e = smooth(P.adsT);
  const speed = Math.hypot(P.vel.x, P.vel.z);
  const moving = clamp(speed / 4.7, 0, 1.3);
  const bobA = (1 - e * 0.85);
  const bx = Math.sin(P.stance) * 0.014 * moving * bobA;
  const by = Math.abs(Math.cos(P.stance)) * 0.011 * moving * bobA;
  const sx = clamp(lookVelX, -0.05, 0.05) * 0.6, sy = clamp(lookVelY, -0.05, 0.05) * 0.6;
  const hp = vm.def.hipPos, ap = vm.def.adsPos;
  vm.holder.position.set(
    lerp(hp[0], ap[0], e) + bx + sx,
    lerp(hp[1], ap[1], e) + by + sy + vmKickZ * 0.25,
    lerp(hp[2], ap[2], e) + vmKickZ
  );
  vm.holder.rotation.set(vmKickZ * 1.6 + sy * 1.2 + (w.def.vmPitch || 0), sx * 1.6, vmKickRoll * 1.4);
  vmKickZ = lerp(vmKickZ, 0, clamp(dt * 11, 0, 1));
  vmKickRoll = lerp(vmKickRoll, 0, clamp(dt * 9, 0, 1));
  lookVelX = lerp(lookVelX, 0, clamp(dt * 8, 0, 1));
  lookVelY = lerp(lookVelY, 0, clamp(dt * 8, 0, 1));
}

/* ================= ПОТОК ИГРЫ ================= */
function showDeath(on) {
  $('ov-death').classList.toggle('hidden', !on);
  $('hud').classList.toggle('on', !on ? true : true);
}
function showPause(on) {
  $('ov-pause').classList.toggle('hidden', !on);
}
function resetRound() {
  tickets.RU = 250; tickets.US = 250;
  G.time = 600; G.elapsed = 0;
  for (const p of POINTS) { p.owner = null; p.prog = 0; p.contested = false; refreshFlag(p); }
  P.kills = 0; P.deaths = 0; P.caps = 0;
  $('feed').innerHTML = '';
  batt = 86;
  spawnBots();
  playerSpawn();
  updateHPHUD(); updateAmmoHUD(); updateHUDText();
}
function startGame(fromDebug) {
  AUDIO.init(); AUDIO.resume();
  resetRound();
  G.state = 'play';
  $('ov-menu').classList.add('hidden');
  $('ov-end').classList.add('hidden');
  $('ov-pause').classList.add('hidden');
  $('ov-death').classList.add('hidden');
  $('hud').classList.add('on');
  $('fade').classList.add('on');
  setTimeout(() => $('fade').classList.remove('on'), 380);
  if (!fromDebug) {
    try { renderer.domElement.requestPointerLock && renderer.domElement.requestPointerLock(); } catch (e) { }
  }
  updateHint();
}
function toMenu() {
  G.state = 'menu';
  try { document.exitPointerLock && document.exitPointerLock(); } catch (e) { }
  $('ov-end').classList.add('hidden');
  $('ov-pause').classList.add('hidden');
  $('ov-death').classList.add('hidden');
  $('ov-menu').classList.remove('hidden');
  $('hud').classList.remove('on');
  setADS(false);
  $('scope').classList.add('hidden');
}
function endRound(winner) {
  if (G.state === 'end') return;
  G.state = 'end';
  try { document.exitPointerLock && document.exitPointerLock(); } catch (e) { }
  setADS(false); $('scope').classList.add('hidden');
  const t = $('end-title');
  t.className = winner === 'RU' ? 'ru' : winner === 'US' ? 'us' : 'draw';
  t.textContent = winner === 'RU' ? 'ПОБЕДА РОССИИ' : winner === 'US' ? 'ПОБЕДА США' : 'НИЧЬЯ';
  $('end-sub').textContent = winner === P.team ? 'ВАШ АРМ ОТСТОЯЛ СЕКТОР' : winner === 'draw' ? 'СЕКТОР НЕ ВЗЯТ НИ КЕМ' : 'СЕКТОР ПОТЕРЯН';
  const st = $('end-stats');
  st.innerHTML = '<span>УБИЙСТВ</span><b>' + P.kills + '</b>' +
    '<span>СМЕРТЕЙ</span><b>' + P.deaths + '</b>' +
    '<span>ЗАХВАТОВ</span><b>' + P.caps + '</b>' +
    '<span>БИЛЕТЫ RU/US</span><b>' + Math.ceil(tickets.RU) + ' / ' + Math.ceil(tickets.US) + '</b>';
  $('ov-end').classList.remove('hidden');
  AUDIO.end(winner === P.team);
}
function timeUp() {
  const r = tickets.RU, u = tickets.US;
  endRound(r > u ? 'RU' : u > r ? 'US' : 'draw');
}

/* ================= ВВОД ================= */
document.addEventListener('keydown', e => {
  keys[e.code] = true;
  if (G.state === 'play' && P.alive) {
    if (e.code === 'Space') e.preventDefault(); // не «нажимать» зафокусированную кнопку
    if (e.code === 'KeyR') startReload();
    if (e.code === 'Digit1') switchWeapon(0);
    if (e.code === 'Digit2') switchWeapon(1);
  }
});
document.addEventListener('keyup', e => { keys[e.code] = false; });
document.addEventListener('mousedown', e => {
  if (G.state !== 'play' || !P.alive) return;
  if (document.pointerLockElement !== renderer.domElement) return;
  if (e.button === 0) { P.fireHeld = true; P._clicked = false; if (!P.weapons[P.wIdx].def.auto) { P._clicked = false; } }
  if (e.button === 2) setADS(true);
});
document.addEventListener('mouseup', e => {
  if (e.button === 0) { P.fireHeld = false; P._clicked = false; }
  if (e.button === 2) setADS(false);
});
document.addEventListener('mousemove', e => {
  if (document.pointerLockElement !== renderer.domElement || G.state !== 'play' || !P.alive) return;
  const w = P.weapons[P.wIdx];
  const zoomK = P.ads ? (w.def.scope ? 0.35 : 0.6) : 1;
  const s = 0.0021 * SET.sens * zoomK;
  P.yaw -= e.movementX * s;
  P.pitch -= e.movementY * s;
  P.pitch = clamp(P.pitch, -1.45, 1.45);
  lookVelX = clamp(-e.movementX * 0.0011, -0.05, 0.05);
  lookVelY = clamp(-e.movementY * 0.0011, -0.05, 0.05);
});
document.addEventListener('contextmenu', e => e.preventDefault());
document.addEventListener('wheel', e => {
  if (G.state === 'play' && P.alive) switchWeapon((P.wIdx + 1) % P.weapons.length);
});
document.addEventListener('pointerlockchange', () => {
  const busy = !$('ov-death').classList.contains('hidden') || !$('ov-end').classList.contains('hidden') || !$('ov-menu').classList.contains('hidden');
  if (!document.pointerLockElement && G.state === 'play' && P.alive && !busy) {
    G.state = 'pause';
    showPause(true);
  }
});

/* --- меню --- */
let selSide = 'RU', selCls = 'assault';
function loadoutText() {
  const [a, b] = CLASSES[selSide][selCls];
  $('loadout').innerHTML = 'СНАРЯЖЕНИЕ: <b>' + WPN[a].name + '</b> (' + WPN[a].mode.toLowerCase() + ') • <b>' + WPN[b].name + '</b><br>' +
    'УРОН: ' + WPN[a].dmg + ' / ' + WPN[b].dmg + ' • МАГАЗИН: ' + WPN[a].mag + ' / ' + WPN[b].mag;
}
function refreshMenuSel() {
  $('sel-ru').className = 'opt-btn' + (selSide === 'RU' ? ' sel-ru' : '');
  $('sel-us').className = 'opt-btn' + (selSide === 'US' ? ' sel-us' : '');
  $('cls-assault').className = 'opt-btn' + (selCls === 'assault' ? ' sel' : '');
  $('cls-sniper').className = 'opt-btn' + (selCls === 'sniper' ? ' sel' : '');
  loadoutText();
}
$('sel-ru').onclick = () => { selSide = 'RU'; refreshMenuSel(); };
$('sel-us').onclick = () => { selSide = 'US'; refreshMenuSel(); };
$('cls-assault').onclick = () => { selCls = 'assault'; refreshMenuSel(); };
$('cls-sniper').onclick = () => { selCls = 'sniper'; refreshMenuSel(); };
$('btn-deploy').onclick = () => { setupLoadout(selSide, selCls); startGame(false); };
$('btn-resume').onclick = () => { G.state = 'play'; showPause(false); try { renderer.domElement.requestPointerLock && renderer.domElement.requestPointerLock(); } catch (e) { } };
$('btn-quit').onclick = () => { showPause(false); toMenu(); };
$('btn-again').onclick = () => { $('ov-end').classList.add('hidden'); startGame(false); };
$('btn-menu').onclick = () => toMenu();
function bindSlider(id, id2, get, set, fmt) {
  const a = $(id), b = $(id2);
  a.value = b.value = get();
  const lab = $(id + '-v'), lab2 = $(id2 + '-v');
  const upd = (src) => {
    set(parseFloat(src.value));
    a.value = b.value = src.value;
    lab.textContent = lab2.textContent = fmt();
    SET.save();
  };
  a.oninput = () => upd(a);
  b.oninput = () => upd(b);
  lab.textContent = lab2.textContent = fmt();
}
bindSlider('sens', 'sens2', () => SET.sens * 100, v => { SET.sens = v / 100; }, () => SET.sens.toFixed(1));
bindSlider('vol', 'vol2', () => SET.vol * 100, v => { SET.vol = v / 100; AUDIO.setVol(SET.vol); }, () => Math.round(SET.vol * 100));

/* ================= ГЛАВНЫЙ ЦИКЛ ================= */
let lastT = performance.now(), menuT = 0;
function animate() {
  requestAnimationFrame(animate);
  window.BC && (BC.frames = (BC.frames || 0) + 1);
  const now = performance.now();
  let dt = Math.min(0.05, (now - lastT) / 1000);
  lastT = now;
  if (G.state === 'play') {
    const sdt = dt * G.timeScale;
    movePlayer(sdt);
    updateBots(sdt);
    updatePoints(sdt);
    if (tickets.RU > 0 && tickets.US > 0) updateTickets(sdt);
    if (G.time > 0) { G.time -= sdt; if (G.time <= 0) { G.time = 0; timeUp(); } }
    updateVM(sdt);
    updateCamera(dt);
    updateHUDText();
    updateHint();
    mmT += dt;
    if (mmT > 0.12) { mmT = 0; drawMinimap(); }
    updateBodycam(dt);
    if (!P.alive) {
      P.respawnT -= sdt;
      $('death-count').textContent = 'РЕСПАВН ЧЕРЕЗ ' + Math.max(1, Math.ceil(P.respawnT));
      if (P.respawnT <= 0) playerRespawn();
    }
    NET.tick(); // NET: снапшоты онлайн-режима
  } else if (G.state === 'menu') {
    menuT += dt * 0.06;
    camera.position.set(Math.cos(menuT) * 150, 58 + Math.sin(menuT * 0.7) * 10, Math.sin(menuT) * 150);
    camera.lookAt(0, 2, 0);
  }
  updateParticles(dt);
  updateTracers(dt);
  grainStep();
  renderer.clear();
  renderer.render(scene, camera);
  if (G.state === 'play' || G.state === 'pause' || G.state === 'end') {
    renderer.clearDepth();
    renderer.render(vmScene, vmCam);
  }
}

/* ================= ЗАГРУЗКА И СТАРТ ================= */
function boot() {
  buildMap();
  buildFlags();
  makeParticles();
  makeTracers();
  refreshMenuSel();
  const btn = $('btn-deploy');
  btn.disabled = true; btn.textContent = 'ЗАГРУЗКА МОДЕЛЕЙ…';
  loadGLB('ak74', 'assets/ak74.glb');
  loadGLB('deagle', 'assets/deagle.glb');
  loadGLB('m16', 'assets/m16.glb');
  loadGLB('makarov', 'assets/makarov.glb');
  loadGLB('svd', 'assets/svd.glb');
  loadGLB('m82', 'assets/m82.glb');
  loadGLB('soldier', 'assets/soldier.glb');
  $('bc-build').textContent = 'BUILD ' + BC_BUILD + ' • v' + BC_VERSION;
  const d = new Date();
  $('bc-date').textContent = 'CAM_01 // OP.КАРАКУМ // ' + String(d.getDate()).padStart(2, '0') + '.' + String(d.getMonth() + 1).padStart(2, '0') + '.' + d.getFullYear();
  animate();
}

/* ================= ОТЛАДКИ / ЭКСПОРТ ================= */
window.BC = {
  G, P, BOTS, POINTS, tickets, GLB, NET, SET, WPN, VM, camera, scene,
  debug: {
    start(side, cls) { setupLoadout(side || 'RU', cls || 'assault'); startGame(true); },
    fire() { firePlayer(); },
    reload() { startReload(); },
    teleport(x, z) { P.pos.x = x; P.pos.z = z; P.pos.y = terrainH(x, z) + EYE; },
    setLook(yaw, pitch) { P.yaw = yaw; P.pitch = pitch; },
    aimNearestEnemy() {
      let best = null, bd = 1e9;
      const o = camera.position.clone();
      for (const b of BOTS) {
        if (!b.alive || b.team === P.team) continue;
        const d = dist2d(P.pos.x, P.pos.z, b.pos.x, b.pos.z);
        if (d >= bd) continue;
        const dir = new THREE.Vector3(b.pos.x - o.x, (b.pos.y + 0.95) - o.y, b.pos.z - o.z);
        const dist = dir.length(); dir.normalize();
        rayc.set(o, dir); rayc.far = dist;
        const hits = rayc.intersectObjects(LOS_MESHES, false);
        if (hits.length && hits[0].distance < dist - 0.6) continue; // за укрытием
        bd = d; best = b;
      }
      if (!best) return null;
      const dy = (best.pos.y + 0.95) - (P.pos.y);
      P.yaw = Math.atan2(best.pos.x - P.pos.x, best.pos.z - P.pos.z) + Math.PI;
      P.pitch = Math.atan2(dy, bd);
      return { name: best.name, dist: Math.round(bd) };
    },
    losInfo() {
      const o = camera.position.clone();
      const out = [];
      for (const b of BOTS) {
        if (!b.alive || b.team === P.team) continue;
        const dir = new THREE.Vector3(b.pos.x - o.x, (b.pos.y + 0.95) - o.y, b.pos.z - o.z);
        const dist = dir.length(); dir.normalize();
        rayc.set(o, dir); rayc.far = dist;
        const hits = rayc.intersectObjects(LOS_MESHES, false);
        out.push({ name: b.name, dist: Math.round(dist), blocked: hits.length > 0 && hits[0].distance < dist - 0.6, hitD: hits.length ? Math.round(hits[0].distance) : null, hitObj: hits.length ? hits[0].object.type + '/' + ((hits[0].object.geometry || {}).type || '?') : null });
      }
      return { eye: { x: Math.round(o.x), y: +o.y.toFixed(2), z: Math.round(o.z) }, out };
    },
    damage(n) { damagePlayer(n, 'ТЕСТ', 'TEST'); },
    setAds(v) { if (P.alive) setADS(v); },
    lowq(v) { renderer.setPixelRatio(v ? 0.5 : Math.min(window.devicePixelRatio || 1, 1.5)); },
    clearBots() { for (const b of BOTS) { b.alive = false; b.respawnT = 9999; b.mesh.wrap.visible = false; } },
    setPoint(id, owner) {
      const p = POINTS.find(q => q.id === id);
      if (!p) return;
      p.owner = owner; p.prog = owner === 'RU' ? 100 : owner === 'US' ? -100 : 0;
      p.contested = false; refreshFlag(p);
    },
    endRound(w) { endRound(w); },
    timeScale(t) { G.timeScale = t; },
    rebuildVm(key, flip, roll) {
      const def = WPN[key];
      const src = GLB[key].scene;
      if (src.parent) src.parent.remove(src);
      src.scale.set(1, 1, 1); src.position.set(0, 0, 0); src.rotation.set(0, 0, 0);
      const holder = VM[key].holder;
      const old = holder.children[0];
      holder.remove(old);
      const wrap = normalizeWeapon(src, def.len, flip, roll);
      holder.add(wrap);
      if (VM[key].flash) { holder.remove(VM[key].flash); holder.add(VM[key].flash); }
      return holder.children.length;
    },
    resetPoints() { for (const p of POINTS) { p.owner = null; p.prog = 0; p.contested = false; refreshFlag(p); } },
    state() {
      return {
        state: G.state, hp: Math.round(P.hp), alive: P.alive, team: P.team, cls: P.cls,
        tickets: { RU: Math.ceil(tickets.RU), US: Math.ceil(tickets.US) }, time: Math.round(G.time),
        points: POINTS.map(p => ({ id: p.id, owner: p.owner, prog: Math.round(p.prog) })),
        bots: BOTS.map(b => ({ name: b.name, team: b.team, alive: b.alive, hp: Math.round(b.hp) })),
        pos: { x: Math.round(P.pos.x), y: Math.round(P.pos.y), z: Math.round(P.pos.z) },
        weapon: P.weapons[P.wIdx] ? P.weapons[P.wIdx].key : null, mag: P.weapons[P.wIdx] ? P.weapons[P.wIdx].mag : 0,
        kills: P.kills, deaths: P.deaths,
      };
    },
  }
};
boot();

