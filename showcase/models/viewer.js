import {
  ACESFilmicToneMapping, AdditiveBlending, CanvasTexture, DirectionalLight, GLTFLoader, Group,
  HemisphereLight, PerspectiveCamera, PointLight, Scene, ShaderMaterial,
  Sprite, SpriteMaterial, WebGLRenderer,
} from '../vendor/three-gltf.min.js';

// The filament and rim follow the game's scripts/hero/sun_surface.gdshader.
function sunSurface() {
  return new ShaderMaterial({
    uniforms: { time: { value: 0 } },
    vertexShader: `
      varying vec3 localPoint, viewNormal, eye;
      void main() {
        vec4 mv = modelViewMatrix * vec4(position, 1.);
        localPoint = normalize(position);
        viewNormal = normalize(normalMatrix * normal);
        eye = -mv.xyz;
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: `
      uniform float time;
      varying vec3 localPoint, viewNormal, eye;
      void main() {
        vec3 p = normalize(localPoint);
        float swirl = sin(p.y * 10. + p.x * 5. + time * .6 + sin(p.z * 9. + p.y * 5. + time * .29) * 2.1);
        float filament = pow(1. - abs(swirl), 3.);
        float rim = pow(1. - max(dot(normalize(viewNormal), normalize(eye)), 0.), 2.);
        vec3 light = mix(vec3(1., .25, .015), vec3(1., .95, .58), clamp(.17 + filament * .72 + rim, 0., 1.));
        gl_FragColor = vec4(light, 1.);
        #include <colorspace_fragment>
      }`,
  });
}

function sunHalo() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const context = canvas.getContext('2d');
  const glow = context.createRadialGradient(64, 64, 0, 64, 64, 64);
  glow.addColorStop(0, 'rgba(255,213,122,.85)');
  glow.addColorStop(.23, 'rgba(255,164,59,.42)');
  glow.addColorStop(.48, 'rgba(255,137,32,.13)');
  glow.addColorStop(1, 'rgba(255,113,25,0)');
  context.fillStyle = glow;
  context.fillRect(0, 0, 128, 128);
  const sprite = new Sprite(new SpriteMaterial({
    map: new CanvasTexture(canvas), blending: AdditiveBlending, depthWrite: false,
  }));
  sprite.position.y = 1.08;
  sprite.scale.set(1.7, 1.7, 1);
  return sprite;
}

export async function createShrineViewer(stage, motion, onContextLost) {
  const canvas = document.createElement('canvas');
  const options = { alpha: true, antialias: true, powerPreference: 'low-power' };
  const context = canvas.getContext('webgl2', options);
  if (!context) throw new Error('WebGL 2 unavailable');
  const renderer = new WebGLRenderer({ canvas, context, ...options });
  renderer.toneMapping = ACESFilmicToneMapping;
  renderer.toneMappingExposure = .95;
  canvas.setAttribute('aria-hidden', 'true');
  let model;
  try {
    model = (await new GLTFLoader().loadAsync(new URL('./sun-shrine.glb', import.meta.url).href)).scene;
  } catch (error) {
    renderer.dispose();
    throw error;
  }

  const scene = new Scene();
  const camera = new PerspectiveCamera(30, 1, .1, 20);
  camera.position.set(0, 1.54, 4.05);
  camera.lookAt(0, .78, 0);
  scene.add(model, new HemisphereLight(0xfff3d9, 0x62818a, 2.1));

  for (const [color, power, x, y, z] of [
    [0xffedc6, 3.4, -3, 5, 3], [0x9bd3e4, 2.8, 2, 3, -3], [0xffc282, 1.6, 3, 1, 2],
  ]) {
    const lamp = new DirectionalLight(color, power);
    lamp.position.set(x, y, z);
    scene.add(lamp);
  }
  const radiance = new PointLight(0xffad4d, 1.15, 2.6);
  radiance.position.y = 1.08;
  model.add(radiance, sunHalo());
  const solar = sunSurface();
  model.getObjectByName('Sun').material = solar;
  const orbits = new Group();
  orbits.position.y = 1.08;
  model.add(orbits);
  const rings = [];
  model.traverse((node) => { if (node.name.startsWith('Orbit_ring_')) rings.push(node); });
  const gimbals = rings.map((ring) => {
    const pivot = new Group();
    orbits.add(pivot);
    pivot.attach(ring);
    return pivot;
  });

  let active = false;
  let lost = false;
  let frame = 0;
  let last = 0;
  let elapsed = 0;
  let pointer = null;
  let lastX = 0;
  let yaw = -.45;
  let wanted = yaw;

  function render(now = 0) {
    frame = 0;
    if (lost) return;
    const dt = last ? Math.min((now - last) / 1000, .05) : 0;
    last = now;
    if (!motion.matches) elapsed += dt;
    yaw += (wanted - yaw) * (motion.matches ? 1 : 1 - Math.exp(-dt * 19));
    const rect = stage.getBoundingClientRect();
    const scrollTilt = motion.matches ? 0 : (rect.top + rect.height / 2 - innerHeight / 2) / innerHeight;
    model.rotation.y = yaw + Math.max(-.15, Math.min(.15, scrollTilt * .19));
    orbits.rotation.y = .6 + elapsed * .16;
    gimbals.forEach((pivot, i) => {
      const phase = elapsed * (.52 + .12 * i) + i * Math.PI * 2 / 3;
      pivot.rotation.x = Math.sin(phase) * .22;
      pivot.rotation.z = Math.cos(phase * .82) * .15;
    });
    solar.uniforms.time.value = elapsed;
    renderer.render(scene, camera);
    if (active && !motion.matches) frame = requestAnimationFrame(render);
  }

  function invalidate() {
    if (active && !lost && !frame) frame = requestAnimationFrame(render);
  }
  function resize() {
    const { width, height } = stage.getBoundingClientRect();
    if (!width || !height) return;
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.5));
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    invalidate();
  }
  function turn(direction) {
    wanted += direction * Math.PI / 6;
    invalidate();
  }

  stage.addEventListener('pointerdown', (event) => {
    if (!event.isPrimary || event.button !== 0) return;
    pointer = event.pointerId;
    lastX = event.clientX;
    stage.setPointerCapture(pointer);
    stage.classList.add('is-dragging');
  });
  stage.addEventListener('pointermove', (event) => {
    if (event.pointerId !== pointer) return;
    wanted += (event.clientX - lastX) * .016;
    lastX = event.clientX;
    invalidate();
  });
  stage.addEventListener('lostpointercapture', () => {
    pointer = null;
    stage.classList.remove('is-dragging');
  });
  stage.addEventListener('keydown', (event) => {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
    event.preventDefault();
    turn(event.key === 'ArrowLeft' ? -1 : 1);
  });
  motion.addEventListener('change', invalidate);
  canvas.addEventListener('webglcontextlost', () => {
    lost = true;
    cancelAnimationFrame(frame);
    onContextLost();
  });
  new ResizeObserver(resize).observe(stage);
  stage.append(canvas);
  resize();
  render();
  return {
    turn,
    setActive(value) {
      active = value;
      if (value) {
        invalidate();
      } else {
        cancelAnimationFrame(frame);
        last = frame = 0;
      }
    },
  };
}
