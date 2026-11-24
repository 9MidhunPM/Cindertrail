import { initPlayer } from './player.js';
import { initFieldGuide } from './field-guide.js';
import { initShrine } from './shrine.js';

initFieldGuide();
initShrine();
initPlayer();

const hero = document.querySelector('.hero');
const motion = matchMedia('(prefers-reduced-motion: reduce)');
const header = document.querySelector('.site-header');
const menu = document.querySelector('.menu-toggle');
const links = [...document.querySelectorAll('.section-nav a')];
const sections = links.map(link => document.querySelector(link.hash));
const navigation = document.querySelector('.section-nav');

function closeMenu() {
  header.classList.remove('menu-open');
  menu.setAttribute('aria-expanded', 'false');
  menu.setAttribute('aria-label', 'Open navigation');
}
menu.addEventListener('click', () => {
  const open = header.classList.toggle('menu-open');
  menu.setAttribute('aria-expanded', String(open));
  menu.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
});
navigation.addEventListener('click', closeMenu);
document.addEventListener('click', event => {
  if (!header.contains(event.target)) closeMenu();
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && header.classList.contains('menu-open')) {
    closeMenu();
    menu.focus();
  }
});
matchMedia('(max-width:650px)').addEventListener('change', closeMenu);

const artButtons = [...hero.querySelectorAll('[data-scene]')];
const pan = hero.querySelector('.scene-pan');
const backgrounds = artButtons.map((button, index) => {
  const img = pan.children[index] || pan.appendChild(document.createElement('img'));
  img.className = 'scene-image' + (index === 0 ? ' current' : '');
  img.alt = '';
  if (index > 0) img.src = button.querySelector('img').src;
  return img;
});
artButtons.forEach((button, index) => button.addEventListener('click', () => {
  artButtons.forEach((option, i) => {
    option.setAttribute('aria-pressed', String(index === i));
    backgrounds[i].classList.toggle('current', index === i);
  });
  hero.querySelector('.scene-counter').textContent = '0' + (index + 1) + ' / 03';
}));

const embers = hero.querySelector('.embers');
for (let i = 0; i < 14; i++) {
  const ember = document.createElement('i');
  ember.style.left = (7 + (i * 17) % 89) + '%';
  ember.style.top = (37 + (i * 13) % 60) + '%';
  ember.style.setProperty('--duration', (6 + i % 4) + 's');
  ember.style.setProperty('--delay', -(i * 1.7) + 's');
  embers.append(ember);
}

const sound = document.querySelector('.sound');
const score = new Audio();
score.loop = true;
score.preload = 'none';
let soundWanted = false;
let playerOpen = false;
function updateSoundButton() {
  sound.setAttribute('aria-pressed', String(soundWanted));
  const label = soundWanted ? 'Mute valley soundtrack' : 'Play valley soundtrack';
  sound.setAttribute('aria-label', label);
  sound.title = label;
  sound.querySelector('.sound-label').textContent = soundWanted ? 'Sound on' : 'Sound off';
}
function syncSound() {
  if (playerOpen || document.hidden || !soundWanted) {
    score.pause();
    return;
  }
  if (!score.src) score.src = new URL('./assets/valley-score.mp3', import.meta.url);
  score.play().catch(error => {
    if (error.name === 'AbortError') return;
    soundWanted = false;
    updateSoundButton();
  });
}
sound.addEventListener('click', () => {
  soundWanted = !soundWanted;
  updateSoundButton();
  syncSound();
});
document.addEventListener('visibilitychange', syncSound);

let visible = true;
let frame = 0;
let needsNav = true;
let aimX = 0;
let aimY = 0;
let x = 0;
let y = 0;
function paint() {
  frame = 0;
  if (needsNav) {
    needsNav = false;
    header.classList.toggle('scrolled', scrollY > 32);
    const at = scrollY + Math.min(innerHeight * .48, 320);
    let active = 0;
    sections.forEach((section, i) => { if (section.offsetTop <= at) active = i; });
    links.forEach((link, i) => {
      if (i === active) link.setAttribute('aria-current', 'location');
      else link.removeAttribute('aria-current');
    });
  }
  if (!visible || motion.matches || playerOpen || document.hidden) return;
  x += (aimX - x) * .1;
  y += (aimY - y) * .1;
  pan.style.setProperty('--mx', x.toFixed(2) + 'px');
  pan.style.setProperty('--my', y.toFixed(2) + 'px');
  pan.style.setProperty('--sy', Math.min(75,scrollY * .16).toFixed(2) + 'px');
  if (Math.abs(aimX - x) + Math.abs(aimY - y) > .12) requestPaint();
}
function requestPaint() { if (!frame) frame = requestAnimationFrame(paint); }
function onScroll() { needsNav = true; requestPaint(); }
window.addEventListener('scroll', onScroll, {passive:true});
window.addEventListener('resize', onScroll);
hero.addEventListener('pointermove', event => {
  if (event.pointerType !== 'mouse' || motion.matches) return;
  aimX = (event.clientX / hero.clientWidth - .5) * 14;
  aimY = ((event.clientY + scrollY) / hero.clientHeight - .5) * 9;
  requestPaint();
});
hero.addEventListener('pointerleave', () => { aimX = aimY = 0; requestPaint(); });
new IntersectionObserver(([entry]) => {
  visible = entry.isIntersecting;
  hero.classList.toggle('out-of-view', !visible);
  if (visible) requestPaint();
}).observe(hero);
const reveal = new IntersectionObserver(entries => {
  for (const entry of entries) {
    if (!entry.isIntersecting) continue;
    entry.target.classList.add('section-enter');
    reveal.unobserve(entry.target);
  }
}, {threshold:.12});
document.querySelectorAll('.guide-heading-row,.guide-tabs,.shrine-copy,.shrine-layout figure').forEach(el => reveal.observe(el));
window.addEventListener('cindertrail:player', ({detail}) => {
  playerOpen = detail.open;
  if (playerOpen) closeMenu();
  syncSound();
  if (!playerOpen) requestPaint();
});
motion.addEventListener('change', requestPaint);
onScroll();
