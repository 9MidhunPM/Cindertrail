import { copyFile, mkdir } from 'node:fs/promises';

const publicRoot = new URL('./public/', import.meta.url);
await Promise.all(['media/', 'fonts/'].map(path => mkdir(new URL(path, publicRoot), { recursive: true })));

const files = [
  ['media/screenshots/exploration.webp', 'media/exploration.webp'],
  ['media/screenshots/shrine-defense.webp', 'media/defense.webp'],
  ['media/Cindertrail_Gameplay.mp4', 'media/gameplay.mp4'],
];
for (const file of [
  'cormorant-garamond-normal-latin.woff2',
  'cormorant-garamond-italic-latin.woff2',
  'dm-sans-normal-latin.woff2',
  'cormorantgaramond-OFL.txt',
  'dmsans-OFL.txt',
]) {
  files.push(['showcase/assets/fonts/' + file, 'fonts/' + file]);
}
await Promise.all(files.map(([source, target]) => copyFile(
  new URL('../' + source, import.meta.url),
  new URL(target, publicRoot),
)));
