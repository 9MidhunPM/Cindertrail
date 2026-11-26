import {
  ACESFilmicToneMapping, AdditiveBlending, AnimationMixer, BufferAttribute, BufferGeometry,
  CatmullRomCurve3, Color, CylinderGeometry, DirectionalLight, HemisphereLight, Line,
  LineBasicMaterial, Mesh, MeshStandardMaterial, OrthographicCamera, PMREMGenerator,
  PointLight, Points, PointsMaterial, PropertyBinding, Scene, Vector3, WebGLRenderer,
} from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const poses = [
  { time: 0, angle: .48, height: .69, zoom: 1.93 },
  { time: 1 / 3, angle: .70, height: .87, zoom: 2.28 },
  { time: 2 / 3, angle: .93, height: .87, zoom: 2.30 },
  { time: 1, angle: 1.25, height: .69, zoom: 2.20 },
];

function clamp(value) {
  return Math.min(1, Math.max(0, value));
}

function lerp(from, to, amount) {
  return from + (to - from) * amount;
}

function addSolarDetail(material) {
  material.onBeforeCompile = (shader) => {
    shader.vertexShader = 'varying vec3 vSolar;\n' + shader.vertexShader;
    shader.vertexShader = shader.vertexShader.replace('#include <begin_vertex>',
      '#include <begin_vertex>\nvSolar = position;');
    shader.fragmentShader = 'varying vec3 vSolar;\n' + shader.fragmentShader;
    shader.fragmentShader = shader.fragmentShader.replace('#include <emissivemap_fragment>', `
      #include <emissivemap_fragment>
      vec3 p = vSolar * 19.0;
      float cloud = sin(p.x + cos(p.y * 1.3)) * sin(p.z + sin(p.y * 1.5));
      cloud += .31 * sin(p.x * 2.9 + p.y * 3.1 + cos(p.z * 2.6));
      totalEmissiveRadiance *= mix(vec3(.71,.49,.22), vec3(1.26,1.08,.87), smoothstep(-.8,.9,cloud));
    `);
  };
}

function lightStream() {
  const streams = [];
  for (let i = 0; i < 3; i++) {
    const angle = .6 + i * Math.PI * 2 / 3;
    const radial = new Vector3(Math.cos(angle), 0, Math.sin(angle));
    const tangent = new Vector3(-radial.z, 0, radial.x);
    const curve = new CatmullRomCurve3([
      radial.clone().multiplyScalar(1.35).add(new Vector3(0,.025,0)),
      radial.clone().multiplyScalar(.86).add(new Vector3(0,.12,0)),
      radial.clone().multiplyScalar(.47).addScaledVector(tangent, .18).add(new Vector3(0,.53,0)),
      new Vector3(0,1.08,0),
    ]);
    const geometry = new BufferGeometry().setFromPoints(curve.getPoints(32));
    const line = new Line(geometry, new LineBasicMaterial({
      color: 0xffa946, transparent: true, blending: AdditiveBlending, depthWrite: false,
    }));
    const particleGeometry = new BufferGeometry();
    particleGeometry.setAttribute('position', new BufferAttribute(new Float32Array(15), 3));
    const points = new Points(particleGeometry, new PointsMaterial({
      color: 0xffc875, size: .022, transparent: true, blending: AdditiveBlending, depthWrite: false,
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
  const sceneLight = new PointLight(0xff9d3e, 4.4, 2);
  const streams = lightStream();
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
  let solarMaterial;
  const pointer = new Vector3();

  function dispose() {
    if (disposed) return;
    disposed = true;
    cancelAnimationFrame(animationFrame);
    observer?.disconnect();
    resize?.disconnect();
    removeEventListener('scroll', schedule);
    document.removeEventListener('visibilitychange', schedule);
    canvas.removeEventListener('webglcontextlost', onLoss);
    if (model) mixer?.uncacheRoot(model);
    scene.traverse((object) => {
      object.geometry?.dispose();
      if (object.material) {
        for (const material of [object.material].flat()) material.dispose();
      }
    });
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

  function draw() {
    animationFrame = 0;
    if (!inView || disposed || document.hidden) return;
    const width = mount.clientWidth;
    const height = mount.clientHeight;
    if (!width || !height) return;

    const travel = -story.getBoundingClientRect().top;
    const next = chapters.findIndex((chapter) => chapter.offsetTop > travel);
    const index = next === -1 ? poses.length - 2 : Math.max(0, next - 1);
    const from = poses[index];
    const to = poses[index + 1];
    const mix = clamp((travel - chapters[index].offsetTop) /
      (chapters[index + 1].offsetTop - chapters[index].offsetTop));
    const position = lerp(from.time, to.time, mix);
    const angle = lerp(from.angle, to.angle, mix);
    const scale = lerp(from.zoom, to.zoom, mix);
    const aspect = width / height;
    const vertical = scale * Math.max(1, .89 / aspect);
    camera.left = -vertical * aspect / 2;
    camera.right = -camera.left;
    camera.top = vertical / 2;
    camera.bottom = -camera.top;
    camera.updateProjectionMatrix();
    camera.position.set(4 * Math.sin(angle), 2.25, 4 * Math.cos(angle));
    camera.lookAt(0, lerp(from.height, to.height, mix), 0);
    camera.updateMatrixWorld();

    action.time = position * action.getClip().duration;
    mixer.update(0);

    const energy = clamp((position - .49) * 12) * clamp((.88 - position) * 12);
    sceneLight.position.y = sun.getWorldPosition(pointer).y;
    sceneLight.intensity = lerp(.25, 1.35, energy);
    solarMaterial.emissiveIntensity = lerp(1.35, 2.6, energy);
    streams.forEach(({ curve, line, points }, i) => {
      line.visible = points.visible = energy > 0;
      if (!line.visible) return;
      line.material.opacity = energy * .39;
      points.material.opacity = energy;
      const positions = points.geometry.attributes.position;
      for (let p = 0; p < positions.count; p++) {
        curve.getPoint((position * 13 + i * .13 + p / positions.count) % 1, pointer);
        positions.setXYZ(p, pointer.x, pointer.y, pointer.z);
      }
      positions.needsUpdate = true;
    });

    const label = position >= .54 && position < .76 ? 'Orbital rings' :
      position >= .25 && position < .44 ? 'Folding tripod' : '';
    callout.hidden = !label;
    if (label) {
      const node = label === 'Orbital rings' ? ringAnchor : legAnchor;
      node.getWorldPosition(pointer);
      pointer.x += .33;
      pointer.project(camera);
      callout.firstElementChild.textContent = label;
      callout.style.left = Math.min(stage.clientWidth * .86, mount.offsetLeft + width * (.5 + .5 * pointer.x) + 72) + 'px';
      callout.style.top = (stage.clientHeight * .52 - height * pointer.y / 2) + 'px';
    }

    const ratio = Math.min(devicePixelRatio, 1.5);
    if (canvas.width !== Math.floor(width * ratio) || canvas.height !== Math.floor(height * ratio)) {
      renderer.setPixelRatio(ratio);
      renderer.setSize(width, height, false);
    }
    renderer.render(scene, camera);
  }

  function schedule() {
    if (!animationFrame && inView && !disposed) animationFrame = requestAnimationFrame(draw);
  }

  try {
    renderer.toneMapping = ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.12;
    renderer.setClearColor(0, 0);
    canvas.addEventListener('webglcontextlost', onLoss);
    const { animations, scene: gltf } = await new GLTFLoader().loadAsync('/shrine/shrine.glb');
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
    if (!sun || !legAnchor || !ringAnchor) throw new Error('Incomplete shrine rig');
    solarMaterial = sun.material;
    addSolarDetail(solarMaterial);
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

    mount.append(canvas);
    story.dataset.scene = 'live';
    observer = new IntersectionObserver(([entry]) => {
      inView = entry.isIntersecting;
      schedule();
    });
    observer.observe(story);
    resize = new ResizeObserver(schedule);
    resize.observe(stage);
    addEventListener('scroll', schedule, { passive: true });
    document.addEventListener('visibilitychange', schedule);
    const bounds = stage.getBoundingClientRect();
    inView = bounds.bottom > 0 && bounds.top < innerHeight;
    schedule();
    return dispose;
  } catch (error) {
    dispose();
    throw error;
  }
}
