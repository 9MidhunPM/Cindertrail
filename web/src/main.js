const story = document.querySelector('.story');
const motion = matchMedia('(prefers-reduced-motion: reduce)');
let generation = 0;
let disposeScene;

async function setMotion() {
  const request = ++generation;
  disposeScene?.();
  disposeScene = undefined;
  story.dataset.scene = 'static';

  if (motion.matches || !window.WebGL2RenderingContext) return;
  story.dataset.scene = 'loading';

  try {
    const { mountShrine } = await import('./shrine.js');
    if (request !== generation) return;
    const dispose = await mountShrine(story, () => request === generation);
    if (request !== generation) dispose?.();
    else disposeScene = dispose;
  } catch {
    if (request === generation) story.dataset.scene = 'static';
  }
}

motion.addEventListener('change', setMotion);
addEventListener('pagehide', () => {
  generation++;
  disposeScene?.();
  disposeScene = undefined;
});
addEventListener('pageshow', (event) => {
  if (event.persisted) setMotion();
});
setMotion();

const watch = document.querySelector('#watch');
watch.addEventListener('click', (event) => {
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
  event.preventDefault();

  const slot = document.querySelector('#video-slot');
  let video = slot.querySelector('video');
  if (!video) {
    video = document.createElement('video');
    video.controls = true;
    video.playsInline = true;
    video.setAttribute('aria-label', 'Cindertrail gameplay capture');
    video.poster = '/media/defense.webp';
    video.src = watch.href;
    slot.append(video);
  }
  video.focus();
  video.play().catch(() => {});
});
