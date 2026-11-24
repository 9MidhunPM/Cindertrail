// This iframe owns Godot's GPU, input, and audio lifecycle. Closing it releases all three.
const canvas = document.getElementById('canvas');
const status = document.getElementById('status');

function notify(type, detail = {}) {
  if (window.parent !== window) {
    window.parent.postMessage({ type: `cindertrail:${type}`, ...detail }, location.origin);
  }
}

function fail(message) {
  status.hidden = false;
  status.textContent = message;
  notify('error', { message });
}

function resizeCanvas() {
  // Bound GPU work on high-DPI and fullscreen displays while preserving aspect ratio.
  const scale = Math.min(devicePixelRatio || 1, 1, Math.sqrt(1280 * 720 / (innerWidth * innerHeight)));
  const width = Math.max(1, Math.round(innerWidth * scale));
  const height = Math.max(1, Math.round(innerHeight * scale));
  if (canvas.width !== width) canvas.width = width;
  if (canvas.height !== height) canvas.height = height;
}

async function startGame() {
  if (typeof Engine === 'undefined') {
    throw new Error('The game download is unavailable. Please try again.');
  }
  const missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length) throw new Error(`This game requires ${missing.join(', ')}.`);

  resizeCanvas();
  window.addEventListener('resize', resizeCanvas);
  canvas.addEventListener('webglcontextlost', () => fail('The graphics connection was interrupted. Reopen the game to resume.'));
  const engine = new Engine({
    executable: 'index',
    canvas,
    canvasResizePolicy: 0,
    fileSizes: releaseFiles.sizes,
    focusCanvas: true,
    onProgress(loaded, total) {
      if (total > 0) status.textContent = loaded < total ? `Loading Cindertrail… ${Math.floor(100 * loaded / total)}%` : 'Opening the valley…';
      notify('progress', { loaded, total });
    },
    onExit() { fail('The game has closed. Choose Play to start again.'); },
  });
  await engine.startGame();
  status.hidden = true;
  canvas.focus();
  notify('ready');
}

startGame().catch((error) => fail(error.message || 'The game could not start. Please try again.'));
