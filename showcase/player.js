const gameURL = new URL('./game/index.html', import.meta.url);
const trailerURL = new URL('./assets/trailer.mp4', import.meta.url);

const icon = (paths) => `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${paths}</svg>`;
const expandIcon = icon('<path d="M8 4H4v4m12-4h4v4M4 16v4h4m12-4v4h-4"/>');
const collapseIcon = icon('<path d="M4 8h4V4m8 0v4h4M8 20v-4H4m12 4v-4h4"/>');
const closeIcon = icon('<path d="m6 6 12 12m0-12L6 18"/>');

export function initPlayer() {
  if (document.querySelector('#ct-player')) return;
  const dialog = document.createElement('dialog');
  dialog.id = 'ct-player';
  dialog.className = 'ct-player';
  dialog.setAttribute('aria-labelledby', 'ct-player-title');
  dialog.innerHTML = `
    <div class="ct-player__panel">
      <header class="ct-player__bar">
        <h2 id="ct-player-title"></h2>
        <div class="ct-player__tools">
          <button type="button" class="ct-player__icon" data-player-full aria-label="Enter fullscreen" title="Enter fullscreen">${expandIcon}</button>
          <button type="button" class="ct-player__icon" data-player-close aria-label="Close player" title="Close player" autofocus>${closeIcon}</button>
        </div>
      </header>
      <div class="ct-player__stage">
        <div class="ct-player__media"></div>
        <div class="ct-player__overlay">
          <p class="ct-player__state" role="status"></p>
          <progress class="ct-player__progress" aria-label="Game download progress" max="100"></progress>
          <p class="ct-player__note"></p>
          <button type="button" class="ct-player__action" hidden></button>
        </div>
      </div>
      <footer class="ct-player__keys" aria-label="Game controls">
        <span><kbd>WASD</kbd> Move</span>
        <span><kbd>Mouse</kbd> Look</span>
        <span><kbd>E</kbd> Interact</span>
        <span><kbd>H</kbd> Ask Mote</span>
        <span><kbd>Esc</kbd> Pause</span>
        <span><kbd>F8</kbd> Leave game</span>
      </footer>
    </div>`;
  document.body.append(dialog);

  const select = (selector) => dialog.querySelector(selector);
  const title = select('h2');
  const media = select('.ct-player__media');
  const overlay = select('.ct-player__overlay');
  const status = select('[role="status"]');
  const note = select('.ct-player__note');
  const progress = select('progress');
  const action = select('.ct-player__action');
  const fullscreenButton = select('[data-player-full]');
  const closeButton = select('[data-player-close]');
  let mode;
  let opener;
  let iframe;
  let video;
  let idleTimer;
  let gameReady;

  function removeMedia() {
    window.clearTimeout(idleTimer);
    if (video) {
      video.pause();
      video.removeAttribute('src');
      video.load();
    }
    video = null;
    iframe = null;
    gameReady = false;
    media.replaceChildren();
  }

  function showState(message, detail, actionLabel = '', isLoading = false) {
    overlay.hidden = false;
    status.textContent = message;
    note.textContent = detail;
    note.hidden = !detail;
    progress.hidden = !isLoading;
    action.textContent = actionLabel;
    action.hidden = !actionLabel;
  }

  function offerRetryIfStalled() {
    window.clearTimeout(idleTimer);
    idleTimer = window.setTimeout(() => {
      if (!iframe || gameReady) return;
      showState('Still loading Cindertrail', 'Keep waiting, or restart the download.', 'Retry', true);
    }, 90000);
  }

  function fail(message) {
    removeMedia();
    showState(mode === 'game' ? 'Game unavailable' : 'Trailer unavailable', message, 'Try again');
  }

  function closePlayer() {
    if (dialog.open) dialog.close();
  }

  function leaveWithKeyboard(event) {
    if (event.key !== 'F8' || mode !== 'game') return;
    event.preventDefault();
    event.stopPropagation();
    closePlayer();
  }

  function loadGame() {
    removeMedia();
    progress.removeAttribute('value');
    showState('Loading Cindertrail', 'The game uses a keyboard and mouse.', '', true);
    const frame = document.createElement('iframe');
    frame.title = 'Cindertrail game';
    frame.allow = 'autoplay; fullscreen; gamepad';
    frame.tabIndex = -1;
    frame.addEventListener('load', () => {
      if (frame !== iframe) return;
      const frameDocument = frame.contentDocument;
      if (!frameDocument?.querySelector('canvas')) {
        fail('The game files could not be opened. Check your connection and try again.');
        return;
      }
      frameDocument.addEventListener('keydown', leaveWithKeyboard, true);
    });
    frame.addEventListener('error', () => {
      if (frame === iframe) fail('The game files could not be downloaded. Check your connection and try again.');
    });
    iframe = frame;
    frame.src = gameURL.href;
    media.append(frame);
    offerRetryIfStalled();
  }

  function loadTrailer() {
    removeMedia();
    overlay.hidden = true;
    const clip = document.createElement('video');
    clip.controls = true;
    clip.playsInline = true;
    clip.setAttribute('aria-label', 'Cindertrail concept trailer');
    clip.addEventListener('error', () => {
      if (clip === video) fail('The trailer could not be played. Check your connection and try again.');
    });
    video = clip;
    clip.src = trailerURL.href;
    media.append(clip);
    clip.play().catch(() => { /* Native controls remain available when autoplay is blocked. */ });
  }

  window.addEventListener('message', (event) => {
    if (!iframe || event.source !== iframe.contentWindow || event.origin !== gameURL.origin || !event.data) return;
    const { type, loaded, total, message } = event.data;
    if (type === 'cindertrail:error') {
      fail(typeof message === 'string' && message ? message : 'The game could not start in this browser.');
    } else if (type === 'cindertrail:progress' && !gameReady) {
      offerRetryIfStalled();
      status.textContent = 'Loading Cindertrail';
      action.hidden = true;
      if (Number.isFinite(loaded) && Number.isFinite(total) && total > 0) {
        progress.value = Math.max(0, Math.min(100, 100 * loaded / total));
        note.textContent = progress.value === 100 ? 'Starting the game…' : `${Math.floor(progress.value)}% downloaded`;
      }
    } else if (type === 'cindertrail:ready' && !gameReady) {
      window.clearTimeout(idleTimer);
      gameReady = true;
      overlay.hidden = true;
      iframe.tabIndex = 0;
      iframe.focus();
    }
  });

  // A dialog in the top layer cannot itself enter fullscreen. Promote its panel instead.
  const panel = select('.ct-player__panel');
  function syncPanelFullscreen() {
    const active = document.fullscreenElement === panel;
    const label = active ? 'Exit fullscreen' : 'Enter fullscreen';
    fullscreenButton.setAttribute('aria-label', label);
    fullscreenButton.title = label;
    fullscreenButton.innerHTML = active ? collapseIcon : expandIcon;
  }
  fullscreenButton.hidden = !document.fullscreenEnabled || !panel.requestFullscreen;
  fullscreenButton.addEventListener('click', async () => {
    try {
      if (document.fullscreenElement === panel) await document.exitFullscreen();
      else await panel.requestFullscreen();
    } catch {
      fullscreenButton.hidden = true;
    }
  });
  document.addEventListener('fullscreenchange', syncPanelFullscreen);

  closeButton.addEventListener('click', closePlayer);
  action.addEventListener('click', () => mode === 'game' ? loadGame() : loadTrailer());
  dialog.addEventListener('keydown', leaveWithKeyboard, true);
  dialog.addEventListener('click', (event) => {
    if (event.target === dialog) closePlayer();
  });
  dialog.addEventListener('cancel', (event) => {
    // Escape belongs to the game while its canvas has focus.
    if (gameReady && document.activeElement === iframe) event.preventDefault();
  });
  dialog.addEventListener('close', () => {
    if (document.fullscreenElement === panel) document.exitFullscreen().catch(() => {});
    removeMedia();
    document.documentElement.classList.remove('player-open');
    window.dispatchEvent(new CustomEvent('cindertrail:player', { detail: { open: false, mode } }));
    opener?.focus({ preventScroll: true });
  });

  document.addEventListener('click', (event) => {
    const trigger = event.target.closest?.('[data-play], [data-trailer]');
    if (!trigger || dialog.open) return;
    event.preventDefault();
    mode = trigger.matches('[data-play]') ? 'game' : 'trailer';
    opener = trigger;
    title.textContent = mode === 'game' ? 'Play Cindertrail' : 'Concept trailer';
    select('.ct-player__keys').hidden = mode !== 'game';
    document.documentElement.classList.add('player-open');
    dialog.showModal();
    window.dispatchEvent(new CustomEvent('cindertrail:player', { detail: { open: true, mode } }));
    if (mode === 'trailer') {
      loadTrailer();
    } else if (window.matchMedia('(pointer: coarse) and (hover: none)').matches) {
      showState('Play with a keyboard and mouse', 'Connect both to move, look around and defend the shrine.', 'Start game');
    } else {
      loadGame();
    }
  });
}
