const chevron = (direction) => `<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="${direction === 'left' ? 'm12 5-5 5 5 5' : 'm8 5 5 5-5 5'}" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`;

export function initShrine() {
  const section = document.querySelector('#shrine');
  if (!section || section.querySelector('.shrine-layout')) return;

  section.setAttribute('aria-labelledby', 'shrine-title');
  section.innerHTML = `
    <div class="shrine-layout">
      <div class="shrine-copy">
        <h2 id="shrine-title">The sun shrine</h2>
        <p>A miniature sun rests inside three bronze rings. Carry it through the valley, unfold its tripod at a camp, and defend it while it draws enough light to bring back dawn.</p>
      </div>
      <figure class="shrine-figure">
        <div class="shrine-stage" role="group" aria-label="3D sun shrine" aria-describedby="shrine-hint">
          <img class="shrine-poster" src="./models/sun-shrine.webp" loading="lazy" decoding="async" alt="A miniature sun suspended in bronze rings above three folding legs." width="720" height="600">
        </div>
        <figcaption class="shrine-caption">
          <button type="button" data-turn="-1" aria-label="Rotate shrine left" hidden>${chevron('left')}</button>
          <span id="shrine-hint">Deployed shrine</span>
          <button type="button" data-turn="1" aria-label="Rotate shrine right" hidden>${chevron('right')}</button>
        </figcaption>
      </figure>
    </div>`;

  const stage = section.querySelector('.shrine-stage');
  const caption = section.querySelector('#shrine-hint');
  const controls = section.querySelectorAll('[data-turn]');
  const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let scene;
  let pending = false;
  let inView = false;
  let playerOpen = document.documentElement.classList.contains('player-open');

  function sync() {
    if (scene) scene.setActive(inView && !document.hidden && !playerOpen);
  }

  function showPoster() {
    stage.classList.remove('shrine-live');
    stage.removeAttribute('tabindex');
    caption.textContent = 'Deployed shrine';
    controls.forEach((button) => { button.hidden = true; });
  }

  async function loadViewer() {
    if (pending || playerOpen) return;
    pending = true;
    try {
      const { createShrineViewer } = await import('./models/viewer.js');
      scene = await createShrineViewer(stage, motion, showPoster);
      stage.classList.add('shrine-live');
      stage.tabIndex = 0;
      caption.textContent = 'Drag to rotate';
      stage.setAttribute('aria-label', '3D sun shrine. Use the left and right arrow keys to rotate.');
      controls.forEach((button) => {
        button.hidden = false;
        button.addEventListener('click', () => scene.turn(Number(button.dataset.turn)));
      });
      sync();
    } catch {
      showPoster();
    }
  }

  const observer = new IntersectionObserver(([entry]) => {
    inView = entry.isIntersecting;
    if (inView) loadViewer();
    sync();
  });
  observer.observe(stage);
  document.addEventListener('visibilitychange', sync);
  window.addEventListener('cindertrail:player', ({ detail }) => {
    playerOpen = detail.open;
    if (!playerOpen && inView) loadViewer();
    sync();
  });
}
