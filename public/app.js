// Only needed when the frontend is served from a different origin than the
// backend (see /config.js, sourced from the BASE_URL env var). Empty by
// default, which keeps every request relative to whatever origin served
// this page.
const BASE_URL = ((window.APP_CONFIG && window.APP_CONFIG.baseUrl) || '').replace(/\/+$/, '');

const $ = id => document.getElementById(id);
const esc = (s='') => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt = s => { if (!isFinite(s) || s < 0) return '0:00'; s = Math.floor(s); const m = Math.floor(s/60), ss = s%60; return `${m}:${String(ss).padStart(2,'0')}`; };
const toast = msg => { const t = $('toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toast._t); toast._t = setTimeout(()=>t.classList.remove('show'), 2200); };

// ============ SFX (decorative arcade blips) ============
let sfxCtx;
function sfx(freq=440, dur=0.05, type='square'){
    try {
        sfxCtx = sfxCtx || new (window.AudioContext||window.webkitAudioContext)();
        const o = sfxCtx.createOscillator(), g = sfxCtx.createGain();
        o.type = type; o.frequency.value = freq; g.gain.value = 0.04;
        o.connect(g); g.connect(sfxCtx.destination);
        o.start(); o.stop(sfxCtx.currentTime + dur);
    } catch(e) {}
}

// ============ Stars ============
function initStars(){
    const host = $('stars');
    for (let i=0;i<60;i++){
        const d = document.createElement('div');
        d.className = 'star';
        d.style.left = Math.random()*100+'%';
        d.style.top = Math.random()*100+'%';
        d.style.animationDelay = (Math.random()*2)+'s';
        host.appendChild(d);
    }
}

// ============ Monogram cover art (local files have no album art) ============
const PALETTE = ['var(--pink)','var(--cyan)','var(--yellow)','var(--green)','var(--purple)','var(--orange)'];
function colorFor(id){
    let h = 0;
    for (const ch of String(id)) h = (h*31 + ch.charCodeAt(0)) >>> 0;
    return PALETTE[h % PALETTE.length];
}
function monogramLetter(title){
    const t = (title||'').trim();
    return t ? t[0].toUpperCase() : '?';
}
function monogramHTML(song){
    return `<div class="mono" style="background:${colorFor(song.id)}">${esc(monogramLetter(song.title))}</div>`;
}

// ============ Playback state ============
const audioPlayer = $('audio-player');
let songs = [];
let queue = [];
let history = [];
let currentSong = null;
let shuffleOn = false;
let repeatMode = 0; // 0 off, 1 repeat all, 2 repeat one
let searchQuery = '';
let currentVolume = 0.6;
let lastVolume = 0.6;
audioPlayer.volume = currentVolume;

function findSong(id){ return songs.find(s => s.id === id); }
function pushHistory(song){
    if (!song) return;
    history.unshift(song);
    if (history.length > 10) history.pop();
}
function shuffleArray(arr){
    for (let i = arr.length-1; i > 0; i--){
        const j = Math.floor(Math.random()*(i+1));
        [arr[i], arr[j]] = [arr[j], arr[i]];
    }
}

function setStatusText(text, cls){
    $('np-status-text').textContent = text;
    $('np-status').classList.toggle('paused', cls === 'paused');
}

function startPlayback(song){
    currentSong = song;
    renderNowPlaying();
    renderGrid();
    renderQueue();

    ensureAudioGraph();
    audioPlayer.pause();
    audioPlayer.currentTime = 0;
    audioPlayer.src = BASE_URL + `/api/songs/${encodeURIComponent(song.id)}/play`;
    audioPlayer.load();
    const p = audioPlayer.play();
    if (p) p.catch(err => { console.error('Play error:', err); setStatusText('CLICK PLAY TO START'); });
    sfx(700, 0.05);
}

function playSong(song){
    if (!song) return;
    pushHistory(currentSong);
    const qi = queue.findIndex(s => s.id === song.id);
    if (qi !== -1) queue.splice(qi, 1);
    startPlayback(song);
}

function togglePlay(){
    if (!currentSong) { if (songs.length) playSong(songs[0]); return; }
    if (audioPlayer.paused) { ensureAudioGraph(); audioPlayer.play(); }
    else audioPlayer.pause();
    sfx(600, 0.04);
}

function nextSong(){
    if (repeatMode === 2 && currentSong) { audioPlayer.currentTime = 0; audioPlayer.play(); return; }
    let next = null;
    if (queue.length) {
        const idx = shuffleOn ? Math.floor(Math.random()*queue.length) : 0;
        next = queue.splice(idx, 1)[0];
    } else if (repeatMode === 1 && songs.length) {
        queue = songs.filter(s => !currentSong || s.id !== currentSong.id).slice();
        if (shuffleOn) shuffleArray(queue);
        next = queue.shift();
    }
    if (!next) { setStatusText('QUEUE EMPTY'); return; }
    pushHistory(currentSong);
    startPlayback(next);
}

function previousSong(){
    if (!history.length) return;
    const prev = history.shift();
    if (currentSong) queue.unshift(currentSong);
    startPlayback(prev);
}

function addToQueue(song){
    if (!song) return;
    queue.push(song);
    renderQueue();
    toast('ADDED TO QUEUE: ' + song.title.toUpperCase());
    sfx(900, 0.06);
}

function toggleShuffle(){
    shuffleOn = !shuffleOn;
    $('btn-shuffle').classList.toggle('active', shuffleOn);
    toast(shuffleOn ? 'SHUFFLE ON' : 'SHUFFLE OFF');
    sfx(shuffleOn ? 900 : 500, 0.05);
}
function toggleRepeat(){
    repeatMode = (repeatMode+1) % 3;
    $('btn-repeat').classList.toggle('active', repeatMode > 0);
    toast(['REPEAT OFF','REPEAT ALL','REPEAT ONE'][repeatMode]);
    sfx(700, 0.05);
}
function setVolume(v, syncSlider){
    currentVolume = Math.max(0, Math.min(1, v));
    // Once the element is routed through the Web Audio graph (see
    // ensureAudioGraph), its native .volume no longer affects output —
    // the gain node is the only thing that does, so drive that instead.
    if (gainNode) gainNode.gain.value = currentVolume;
    else audioPlayer.volume = currentVolume;
    if (syncSlider) $('vol').value = Math.round(currentVolume*100);
}
function toggleMute(){
    if (currentVolume > 0) {
        lastVolume = currentVolume;
        setVolume(0, true);
        $('btn-mute').classList.add('active');
    } else {
        setVolume(lastVolume || 0.6, true);
        $('btn-mute').classList.remove('active');
    }
}
$('vol').addEventListener('input', e => setVolume(e.target.value/100));

function updatePlayPauseIcon(){
    $('icon-play').innerHTML = audioPlayer.paused
        ? '<path d="M8 5v14l11-7z"/>'
        : '<path d="M6 5h4v14H6zM14 5h4v14h-4z"/>';
}

// ============ Now playing / progress ============
function renderNowPlaying(){
    if (currentSong) {
        $('cover').innerHTML = monogramHTML(currentSong);
        $('np-title-text').textContent = currentSong.title.toUpperCase();
        $('now-artist').textContent = '> ' + currentSong.artist.toUpperCase();
    } else {
        $('cover').innerHTML = '';
        $('np-title-text').textContent = 'NO TRACK LOADED';
        $('now-artist').textContent = '> PICK A TRACK <';
    }
    setTimeout(() => {
        const wrap = $('np-title-wrap'), span = $('np-title-text');
        wrap.classList.toggle('overflowing', span.scrollWidth > wrap.clientWidth);
    }, 50);
}

audioPlayer.addEventListener('timeupdate', () => {
    if (audioPlayer.duration && isFinite(audioPlayer.duration)) {
        $('progress-bar').style.width = (audioPlayer.currentTime/audioPlayer.duration*100) + '%';
        $('time-current').textContent = fmt(audioPlayer.currentTime);
    }
});
audioPlayer.addEventListener('loadedmetadata', () => { $('time-total').textContent = fmt(audioPlayer.duration); });
audioPlayer.addEventListener('waiting', () => setStatusText('BUFFERING...'));
audioPlayer.addEventListener('playing', () => { setStatusText('PLAYING'); document.body.classList.add('playing'); updatePlayPauseIcon(); });
audioPlayer.addEventListener('pause', () => { setStatusText('PAUSED', 'paused'); document.body.classList.remove('playing'); updatePlayPauseIcon(); });
audioPlayer.addEventListener('ended', nextSong);
audioPlayer.addEventListener('error', () => { setStatusText('ERROR LOADING AUDIO'); toast('PLAYBACK ERROR'); });

// Click/drag to seek
(function(){
    const track = $('progress-track');
    let dragging = false;
    function seek(e){
        if (!audioPlayer.duration || !isFinite(audioPlayer.duration)) return;
        const r = track.getBoundingClientRect();
        const x = Math.min(Math.max(e.clientX - r.left, 0), r.width);
        audioPlayer.currentTime = (x / r.width) * audioPlayer.duration;
    }
    track.addEventListener('mousedown', e => { dragging = true; seek(e); });
    addEventListener('mousemove', e => { if (dragging) seek(e); });
    addEventListener('mouseup', () => dragging = false);
})();

// ============ Live audio visualizer + volume graph ============
// Routing audioPlayer through the Web Audio API (needed for the visualizer)
// means its native .volume stops doing anything — gainNode is the real
// volume control from this point on (see setVolume above).
let audioCtx, analyser, gainNode, freqData, vizBars = [];
function ensureAudioGraph(){
    if (audioCtx) { if (audioCtx.state === 'suspended') audioCtx.resume(); return; }
    try {
        audioCtx = new (window.AudioContext||window.webkitAudioContext)();
        const source = audioCtx.createMediaElementSource(audioPlayer);
        analyser = audioCtx.createAnalyser();
        analyser.fftSize = 128;
        analyser.smoothingTimeConstant = 0.6;
        gainNode = audioCtx.createGain();
        gainNode.gain.value = currentVolume;
        source.connect(analyser);
        analyser.connect(gainNode);
        gainNode.connect(audioCtx.destination);
        freqData = new Uint8Array(analyser.frequencyBinCount);
        audioCtx.resume();
    } catch(e) { console.warn('Visualizer/volume graph unavailable, falling back to native volume:', e); }
}
// Set up the graph on the very first user interaction, so it's already
// running (not racing audioPlayer.src/.load() changes) by the time a song
// is actually played.
addEventListener('pointerdown', ensureAudioGraph, { once: true });
addEventListener('keydown', ensureAudioGraph, { once: true });

function initVisualizerBars(){
    const host = $('visualizer');
    host.innerHTML = '';
    for (let i=0;i<24;i++){ const b = document.createElement('div'); b.className = 'bar'; host.appendChild(b); vizBars.push(b); }
}
function tickVisualizer(){
    requestAnimationFrame(tickVisualizer);
    if (!analyser || audioPlayer.paused || audioCtx.state !== 'running') { vizBars.forEach(b => b.style.height = '10%'); return; }
    analyser.getByteFrequencyData(freqData);
    const step = Math.max(1, Math.floor(freqData.length / vizBars.length));
    vizBars.forEach((b,i) => { b.style.height = Math.max(10, (freqData[i*step]||0)/255*100) + '%'; });
}

// ============ Library ============
function cardHTML(song){
    const isCurrent = currentSong && currentSong.id === song.id;
    return `
      <div class="card ${isCurrent?'current':''}" data-id="${esc(song.id)}">
        <div class="c-cover">${monogramHTML(song)}</div>
        <div class="c-title">${esc(song.title.toUpperCase())}</div>
        <div class="c-artist">${esc(song.artist.toUpperCase())}</div>
        <div class="c-actions">
          <button class="c-play" data-action="play" data-id="${esc(song.id)}">&#9654; PLAY</button>
          <button class="icon-btn" data-action="queue" data-id="${esc(song.id)}" title="Add to queue">+</button>
        </div>
      </div>`;
}
function renderGrid(){
    const q = searchQuery.trim().toLowerCase();
    const filtered = q ? songs.filter(s => s.title.toLowerCase().includes(q) || s.artist.toLowerCase().includes(q)) : songs;
    $('song-count').textContent = filtered.length;
    if (!filtered.length) {
        $('song-list').innerHTML = `<div class="empty" style="grid-column:1/-1">${songs.length ? 'NO MATCHES' : 'NO SONGS FOUND'}</div>`;
        return;
    }
    $('song-list').innerHTML = filtered.map(cardHTML).join('');
    $('song-list').querySelectorAll('.card').forEach(card => {
        card.addEventListener('click', () => playSong(findSong(card.dataset.id)));
    });
    $('song-list').querySelectorAll('[data-action="play"]').forEach(btn => {
        btn.addEventListener('click', e => { e.stopPropagation(); playSong(findSong(btn.dataset.id)); });
    });
    $('song-list').querySelectorAll('[data-action="queue"]').forEach(btn => {
        btn.addEventListener('click', e => { e.stopPropagation(); addToQueue(findSong(btn.dataset.id)); });
    });
}

function rowHTML(song){
    return `
      <div class="song" data-id="${esc(song.id)}">
        <div class="thumb">${monogramHTML(song)}</div>
        <div class="meta"><div class="t">${esc(song.title.toUpperCase())}</div><div class="a">${esc(song.artist.toUpperCase())}</div></div>
      </div>`;
}
function renderQueue(){
    const host = $('panel-queue');
    if (!queue.length) { host.innerHTML = '<div class="empty">QUEUE IS EMPTY</div>'; return; }
    host.innerHTML = queue.map(rowHTML).join('');
    host.querySelectorAll('.song').forEach(row => {
        row.addEventListener('click', () => playSong(findSong(row.dataset.id)));
    });
}

async function loadSongs(){
    $('song-list').innerHTML = '<div class="empty" style="grid-column:1/-1">LOADING...</div>';
    try {
        const res = await fetch(BASE_URL + '/api/songs');
        if (!res.ok) throw new Error('HTTP ' + res.status);
        const data = await res.json();
        songs = data.songs || [];
        renderGrid();
    } catch(e) {
        console.error('Failed to load songs:', e);
        $('song-list').innerHTML = '<div class="empty" style="grid-column:1/-1">FAILED TO LOAD SONGS</div>';
    }
}

$('search').addEventListener('input', e => { searchQuery = e.target.value; renderGrid(); });

// ============ Keyboard shortcuts ============
addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT') { if (e.key === 'Escape') e.target.blur(); return; }
    switch (e.key) {
        case ' ': e.preventDefault(); togglePlay(); break;
        case 'ArrowRight': nextSong(); break;
        case 'ArrowLeft': previousSong(); break;
        case 'ArrowUp': e.preventDefault(); setVolume(currentVolume+0.05, true); break;
        case 'ArrowDown': e.preventDefault(); setVolume(currentVolume-0.05, true); break;
        case 's': case 'S': toggleShuffle(); break;
        case 'r': case 'R': toggleRepeat(); break;
        case 'm': case 'M': toggleMute(); break;
        case '/': e.preventDefault(); $('search').focus(); break;
    }
});

// ============ Boot ============
initStars();
initVisualizerBars();
requestAnimationFrame(tickVisualizer);
updatePlayPauseIcon();
loadSongs();
