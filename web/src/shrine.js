import {
  ACESFilmicToneMapping, AdditiveBlending, AnimationMixer, BufferAttribute, BufferGeometry,
  CanvasTexture, CatmullRomCurve3, Color, CylinderGeometry, DirectionalLight, Group, HemisphereLight, Line,
  LineBasicMaterial, Mesh, MeshBasicMaterial, MeshStandardMaterial, OrthographicCamera, PMREMGenerator,
  PointLight, Points, PointsMaterial, PropertyBinding, RingGeometry, Scene, Sprite, SpriteMaterial, Vector3, WebGLRenderer,
} from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import shrineModel from './assets/shrine.glb?url';
import { inspectShrine } from './inspection.js';

const poses = [
  { time: 0, angle: .48, height: .69, zoom: 1.93 },
  { time: 1 / 3, angle: .70, height: .87, zoom: 2.34 },
  { time: 2 / 3, angle: .93, height: .90, zoom: 2.39 },
  { time: 1, angle: 1.25, height: .69, zoom: 2.20 },
];

function clamp(value) {
  return Math.min(1, Math.max(0, value));
}

function lerp(from, to, amount) {
  return from + (to - from) * amount;
}

function addSolarDetail(material, time, heat) {
  material.onBeforeCompile = (shader) => {
    shader.uniforms.solarTime = time;
    shader.uniforms.solarHeat = heat;
    shader.vertexShader = 'varying vec3 vSolar;\n' + shader.vertexShader;
    shader.vertexShader = shader.vertexShader.replace('#include <begin_vertex>',
      '#include <begin_vertex>\nvSolar = position;');
    shader.fragmentShader = 'uniform float solarTime; uniform float solarHeat; varying vec3 vSolar;\n' + shader.fragmentShader;
    shader.fragmentShader = shader.fragmentShader.replace('#include <emissivemap_fragment>', `
      #include <emissivemap_fragment>
      vec3 p = vSolar * 22.0;
      float flow = sin(p.y * 1.6 - solarTime * .6 + cos(p.z * 1.7)) * 1.35;
      float cloud = sin(p.x + flow + cos(p.y)) * sin(p.z + flow);
      cloud += .34 * sin(p.x * 2.9 + p.y * 3.1 + cos(p.z * 2.6 + solarTime));
      cloud += .14 * sin(p.z * 6.3 - p.y * 4.2 + cos(p.x * 3.3));
      vec3 plasma = mix(vec3(.68,.19,.045), vec3(1.2,1.0,.72), smoothstep(-.78,.76,cloud));
      totalEmissiveRadiance *= plasma + solarHeat * .08;
    `);
  };
}

function glowTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 64;
  const context = canvas.getContext('2d');
  const gradient = context.createRadialGradient(32, 32, 1, 32, 32, 32);
  gradient.addColorStop(0, '#fff');
  gradient.addColorStop(.36, '#ffffff9a');
  gradient.addColorStop(1, '#ffffff00');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 64, 64);
  return new CanvasTexture(canvas);
}

function lightStream(glow) {
  const streams = [];
  for (let i = 0; i < 4; i++) {
    const angle = .6 + i * Math.PI / 2;
    const radial = new Vector3(Math.cos(angle), 0, Math.sin(angle));
    const tangent = new Vector3(-radial.z, 0, radial.x);
    const curve = new CatmullRomCurve3([
      radial.clone().multiplyScalar(1.35).add(new Vector3(0,.025,0)),
      radial.clone().multiplyScalar(.86).add(new Vector3(0,.12,0)),
      radial.clone().multiplyScalar(.47).addScaledVector(tangent, .18).add(new Vector3(0,.53,0)),
      new Vector3(0,1.17,0),
    ]);
    const geometry = new BufferGeometry().setFromPoints(curve.getPoints(32));
    const line = new Line(geometry, new LineBasicMaterial({
      color: 0xffa946, transparent: true, blending: AdditiveBlending, depthWrite: false,
    }));
    const particleGeometry = new BufferGeometry();
    particleGeometry.setAttribute('position', new BufferAttribute(new Float32Array(24), 3));
    const points = new Points(particleGeometry, new PointsMaterial({
      color: 0xffc875, map: glow, size: .032, transparent: true, blending: AdditiveBlending, depthWrite: false,
    }));
    points.frustumCulled = false;
    streams.push({ curve, line, points });
  }
  return streams;
}

export async function mountShrine(story, isCurrent) {
  const stage = story.querySelector('.stage');
  const mount = stage.querySelector('.stage-canvas');
  const callout = stage.querySelector('.component');
  const chapters = Array.from(story.querySelectorAll('.chapter'));
  const renderer = new WebGLRenderer({ alpha: true, antialias: true, powerPreference: 'low-power' });
  const canvas = renderer.domElement;
  const scene = new Scene();
  const camera = new OrthographicCamera(-1, 1, 1, -1, .01, 20);
  const sceneLight = new PointLight(0xff9d3e, 1, 2);
  const glow = glowTexture();
  const halo = new Sprite(new SpriteMaterial({
    map: glow, color: 0xff7c22, transparent: true, blending: AdditiveBlending, depthWrite: false,
  }));
  const seal = new Mesh(new RingGeometry(.64, .649, 48),
    new MeshBasicMaterial({ color: 0xffac4f, transparent: true, blending: AdditiveBlending, depthWrite: false }));
  seal.rotation.x = -Math.PI / 2;
  seal.position.y = -.008;
  scene.add(halo, seal);
  const streams = lightStream(glow);
  streams.forEach(({ line, points }) => scene.add(line, points));
  let lightingMap;
  let mixer;
  let model;
  let animationFrame = 0;
  let inView = false;
  let disposed = false;
  let observer;
  let resize;
  let action;
  let sun;
  let legAnchor;
  let ringAnchor;
  let petalAnchor;
  let solarMaterial;
  let inspection;
  let lastFrame = 0;
  let lastActivity = 0;
  let yaw = 0;
  let pitch = 0;
  const time = { value: 0 };
  const heat = { value: 0 };
  const ringMotion = [];
  const illuminated = new Set();
  const pointer = new Vector3();

  function dispose() {
    if (disposed) return;
    disposed = true;
    cancelAnimationFrame(animationFrame);
    observer?.disconnect();
    resize?.disconnect();
    removeEventListener('scroll', wake);
    document.removeEventListener('visibilitychange', wake);
    inspection?.dispose();
    canvas.removeEventListener('webglcontextlost', onLoss);
    if (model) mixer?.uncacheRoot(model);
    scene.traverse((object) => {
      object.geometry?.dispose();
      if (object.material) {
        for (const material of [object.material].flat()) material.dispose();
      }
    });
    glow.dispose();
    lightingMap?.dispose();
    renderer.dispose();
    canvas.remove();
    callout.hidden = true;
  }

  function onLoss(event) {
    event.preventDefault();
    if (!isCurrent()) return;
    story.dataset.scene = 'static';
    dispose();
  }

  function draw(timestamp) {
    animationFrame = 0;
    if (!inView || disposed || document.hidden) return;
    const width = mount.clientWidth;
    const height = mount.clientHeight;
    if (!width || !height) return;
    if (timestamp - lastFrame < 14) {
      schedule();
      return;
    }
    const elapsed = Math.min(.05, (timestamp - lastFrame) / 1000);
    lastFrame = timestamp;
    time.value = timestamp / 1000;
    const input = inspection.state;
    const response = Math.exp(-Math.max(0, timestamp - lastActivity) / 420);
    const ease = 1 - Math.exp(-elapsed * 13);
    yaw = lerp(yaw, input.yaw + (input.hover && !input.dragging ? input.hoverX * -.16 : 0), ease);
    pitch = lerp(pitch, input.pitch + (input.hover && !input.dragging ? input.hoverY * -.13 : 0), ease);

    const travel = -story.getBoundingClientRect().top;
    const next = chapters.findIndex((chapter) => chapter.offsetTop > travel);
    const index = next === -1 ? poses.length - 2 : Math.max(0, next - 1);
    const from = poses[index];
    const to = poses[index + 1];
    const mix = clamp((travel - chapters[index].offsetTop) /
      (chapters[index + 1].offsetTop - chapters[index].offsetTop));
    const position = lerp(from.time, to.time, mix);
    const angle = lerp(from.angle, to.angle, mix) + yaw;
    const scale = lerp(from.zoom, to.zoom, mix);
    const aspect = width / height;
    const vertical = scale * Math.max(1, .89 / aspect);
    camera.left = -vertical * aspect / 2;
    camera.right = -camera.left;
    camera.top = vertical / 2;
    camera.bottom = -camera.top;
    camera.updateProjectionMatrix();
    camera.position.set(4 * Math.sin(angle), 2.25 + pitch * 2.05, 4 * Math.cos(angle));
    camera.lookAt(0, lerp(from.height, to.height, mix), 0);
    camera.updateMatrixWorld();

    action.time = position * action.getClip().duration;
    mixer.update(0);

    const energy = clamp((position - .43) * 9) * clamp((.89 - position) * 11);
    const pulse = .88 + Math.sin(time.value * 3.2) * .12;
    heat.value = energy + response * .45;
    sun.getWorldPosition(pointer);
    halo.position.copy(pointer);
    halo.scale.setScalar(.69 + energy * .31 + response * .10);
    halo.material.opacity = .24 + energy * .35 * pulse + response * .14;
    seal.material.opacity = energy * (.18 + pulse * .22);
    sceneLight.position.y = pointer.y;
    sceneLight.intensity = lerp(.20, 1.15, energy) + .26 * response;
    solarMaterial.emissiveIntensity = lerp(1.25, 2.45, energy * pulse);
    for (const material of illuminated) material.emissiveIntensity = .45 + energy * pulse * 1.30 + response * .33;
    ringMotion.forEach((ring, index) => {
      ring.rotation.x = Math.sin(time.value * .72 + index * 1.8) * energy * .084;
      ring.rotation.z = Math.cos(time.value * .94 + index * 2.1) * energy * .092;
    });
    streams.forEach(({ curve, line, points }, i) => {
      line.visible = points.visible = energy > 0;
      if (!line.visible) return;
      line.material.opacity = energy * (.21 + pulse * .19);
      points.material.opacity = energy;
      const positions = points.geometry.attributes.position;
      for (let p = 0; p < positions.count; p++) {
        curve.getPoint((time.value * (.44 + .08 * energy) + position * 2.8 + i * .13 + p / positions.count) % 1, pointer);
        positions.setXYZ(p, pointer.x, pointer.y, pointer.z);
      }
      positions.needsUpdate = true;
    });

    let feature;
    if (position >= .13 && position < .24) feature = ['Armor latches', petalAnchor];
    if (position >= .24 && position < .44) feature = ['Folding tripod', legAnchor];
    if (position >= .44 && position < .54) feature = ['Sun cradle', sun];
    if (position >= .54 && position < .82) feature = ['Orbital rings', ringAnchor];

    callout.hidden = !feature;
    if (feature) {
      const [label, node] = feature;
      node.getWorldPosition(pointer);
      pointer.x += .33;
      pointer.project(camera);
      if (callout.firstElementChild.textContent !== label) callout.firstElementChild.textContent = label;
      callout.style.left = Math.min(stage.clientWidth * .86, mount.offsetLeft + width * (.5 + .5 * pointer.x) + 72) + 'px';
      callout.style.top = (stage.clientHeight * .52 - height * pointer.y / 2) + 'px';
    }

    const ratio = Math.min(devicePixelRatio, 1.5);
    if (canvas.width !== Math.floor(width * ratio) || canvas.height !== Math.floor(height * ratio)) {
      renderer.setPixelRatio(ratio);
      renderer.setSize(width, height, false);
    }
    renderer.render(scene, camera);
    if (input.dragging || timestamp - lastActivity < 1650) schedule();
  }

  function schedule() {
    if (!animationFrame && inView && !disposed && !document.hidden) animationFrame = requestAnimationFrame(draw);
  }

  function wake() {
    lastActivity = performance.now();
    schedule();
  }

  try {
    renderer.toneMapping = ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.12;
    renderer.setClearColor(0, 0);
    canvas.addEventListener('webglcontextlost', onLoss);
    const { animations, scene: gltf } = await new GLTFLoader().loadAsync(shrineModel);
    const clip = animations.find(({ name }) => name === 'ShrineCycle');
    model = gltf;
    scene.add(model);
    if (!isCurrent() || disposed || !clip) {
      if (disposed) model.traverse((object) => {
        object.geometry?.dispose();
        if (object.material) for (const material of [object.material].flat()) material.dispose();
      });
      dispose();
      if (isCurrent()) story.dataset.scene = 'static';
      return;
    }
    sun = model.getObjectByName('Sun');
    legAnchor = model.getObjectByName(PropertyBinding.sanitizeNodeName('Leg hinge 1'));
    ringAnchor = model.getObjectByName(PropertyBinding.sanitizeNodeName('Orbital ring 1'));
    petalAnchor = model.getObjectByName(PropertyBinding.sanitizeNodeName('Armor petal 1'));
    if (!sun || !legAnchor || !ringAnchor || !petalAnchor) throw new Error('Incomplete shrine rig');
    solarMaterial = sun.material;
    addSolarDetail(solarMaterial, time, heat);
    model.traverse(object => {
      for (const material of [object.material].flat()) {
        if (material?.name.startsWith('Amber channel')) illuminated.add(material);
      }
    });
    for (let i = 1; i <= 3; i++) {
      const gimbal = model.getObjectByName(PropertyBinding.sanitizeNodeName('Orbital ring ' + i));
      const mount = new Group();
      mount.add(...gimbal.children.slice());
      gimbal.add(mount);
      ringMotion.push(mount);
    }
    mixer = new AnimationMixer(model);
    action = mixer.clipAction(clip).play();
    action.paused = true;

    const environment = new RoomEnvironment();
    const pmrem = new PMREMGenerator(renderer);
    try {
      lightingMap = pmrem.fromScene(environment, .08);
    } finally {
      environment.dispose();
      pmrem.dispose();
    }
    scene.environment = lightingMap.texture;
    scene.environmentIntensity = .29;
    scene.add(new HemisphereLight(0xa4dccc, 0x422611, .78), sceneLight);
    const key = new DirectionalLight(0xffc383, 1.85);
    const rim = new DirectionalLight(0x63d8eb, 2.0);
    key.position.set(2, 3, 5);
    rim.position.set(-2, 3, -4);
    scene.add(key, rim);
    const stone = new MeshStandardMaterial({ color: new Color('#514d3b'), roughness: .95 });
    const plinth = new Mesh(new CylinderGeometry(.83, .87, .07, 12), stone);
    const edge = new Mesh(new CylinderGeometry(.87, .81, .05, 12), stone);
    plinth.position.y = -.045;
    edge.position.y = -.105;
    scene.add(plinth, edge);

    canvas.tabIndex = 0;
    canvas.setAttribute('role', 'img');
    canvas.setAttribute('aria-label', 'Interactive folding sun shrine');
    canvas.setAttribute('aria-describedby', 'shrine-controls');
    inspection = inspectShrine(canvas, wake);
    mount.append(canvas);
    story.dataset.scene = 'live';
    observer = new IntersectionObserver(([entry]) => {
      inView = entry.isIntersecting;
      schedule();
    });
    observer.observe(stage);
    resize = new ResizeObserver(schedule);
    resize.observe(stage);
    addEventListener('scroll', wake, { passive: true });
    document.addEventListener('visibilitychange', wake);
    const bounds = stage.getBoundingClientRect();
    inView = bounds.bottom > 0 && bounds.top < innerHeight;
    schedule();
    return dispose;
  } catch (error) {
    dispose();
    throw error;
  }
}
