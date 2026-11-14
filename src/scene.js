import * as THREE from "three";
/** Replaceable presentation adapter. Simulation never imports this module. */
export function createScene(container) {
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: true,
      powerPreference: "low-power",
    });
  } catch {
    container.innerHTML =
      '<div class="scene-fallback"><span>◒</span><p>Red Veil outpost</p><small>Low graphics mode · All mission controls remain available</small></div>';
    return { update() {}, resize() {}, dispose() {} };
  }
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  container.append(renderer.domElement);
  renderer.domElement.setAttribute(
    "aria-label",
    "Three-dimensional Mars outpost with a shelter, laboratory, and solar panels",
  );
  renderer.domElement.setAttribute("role", "img");
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(33, 1, 0.1, 100);
  camera.position.set(13, 12, 18);
  camera.lookAt(0, 0, 0);
  scene.add(new THREE.HemisphereLight(0xffe6ce, 0x61493e, 2.4));
  const sun = new THREE.DirectionalLight(0xffe3ba, 3.1);
  sun.position.set(-8, 14, 5);
  scene.add(sun);
  const group = new THREE.Group();
  scene.add(group);
  const mat = (color, extra = {}) =>
    new THREE.MeshStandardMaterial({ color, roughness: 0.85, ...extra });
  const sand = mat(0xbb7355),
    stone = mat(0xdca47d),
    wall = mat(0xe5dacc),
    metal = mat(0x53646a),
    glass = mat(0x83b3ad, { metalness: 0.35, roughness: 0.25 }),
    blue = mat(0x21485b, { metalness: 0.35 }),
    mint = mat(0xb8efd0, { emissive: 0x42765b, emissiveIntensity: 0.6 });
  function mesh(geo, material, x = 0, y = 0, z = 0, parent = group) {
    const m = new THREE.Mesh(geo, material);
    m.position.set(x, y, z);
    parent.add(m);
    return m;
  }
  function box(w, h, d, m, x, y, z, parent) {
    return mesh(new THREE.BoxGeometry(w, h, d), m, x, y, z, parent);
  }
  const ground = mesh(
    new THREE.CylinderGeometry(7, 6.7, 0.7, 7),
    sand,
    0,
    -0.45,
    0,
  );
  ground.rotation.y = 0.2;
  mesh(
    new THREE.CylinderGeometry(6.55, 6.65, 0.13, 7),
    stone,
    0,
    -0.04,
    0,
  ).rotation.y = 0.2;
  // Modular pressure habitat, external ribs, and a separate regolith-covered refuge.
  const habitat = new THREE.Group();
  group.add(habitat);
  habitat.position.set(-0.9, 0, 0);
  const body = mesh(
    new THREE.CylinderGeometry(1.25, 1.25, 3.3, 20),
    wall,
    0,
    1.25,
    0,
    habitat,
  );
  body.rotation.z = Math.PI / 2;
  for (const x of [-1.3, -0.65, 0, 0.65, 1.3]) {
    const rib = mesh(
      new THREE.TorusGeometry(1.28, 0.045, 6, 24),
      metal,
      x,
      1.25,
      0,
      habitat,
    );
    rib.rotation.y = Math.PI / 2;
  }
  const window = mesh(
    new THREE.CylinderGeometry(0.84, 0.84, 0.08, 24),
    glass,
    1.69,
    1.25,
    0,
    habitat,
  );
  window.rotation.z = Math.PI / 2;
  box(0.08, 1.65, 0.08, wall, 1.75, 1.25, 0, habitat);
  box(0.08, 0.08, 1.65, wall, 1.75, 1.25, 0, habitat);
  box(3.7, 0.18, 2.8, metal, 0, 0.25, 0, habitat);
  for (const x of [-1.3, 1.3])
    for (const z of [-1, 1]) box(0.14, 0.5, 0.14, metal, x, 0.15, z, habitat);
  const refuge = mesh(
    new THREE.SphereGeometry(1.5, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2),
    sand,
    -2.3,
    0,
    -2.7,
  );
  refuge.scale.set(1.35, 1, 1);
  box(1.1, 1, 0.2, metal, -2.3, 0.5, -1.35);
  const refugeDoor = box(0.72, 0.8, 0.22, mint, -2.3, 0.4, -1.22);
  box(1.1, 0.15, 1.5, wall, -2.3, 0.1, -0.9);
  const panels = [];
  for (let i = 0; i < 3; i++)
    for (let j = 0; j < 2; j++) {
      const x = 1.8 + i * 1.4,
        z = -3 + j * 1.8;
      box(0.09, 0.6, 0.09, metal, x, 0.3, z);
      const panel = new THREE.Group();
      panel.position.set(x, 0.66, z);
      panel.rotation.x = -0.22;
      group.add(panel);
      box(1.16, 0.08, 1.48, metal, 0, 0, 0, panel);
      const surface = box(1.08, 0.03, 1.39, blue.clone(), 0, 0.06, 0, panel);
      panels.push(surface);
      for (let k = -1; k <= 1; k++)
        box(0.012, 0.01, 1.39, glass, k * 0.34, 0.08, 0, panel);
      for (let k = -2; k <= 2; k++)
        box(1.08, 0.01, 0.012, glass, 0, 0.08, k * 0.26, panel);
    }
  // Antenna and rover give the outpost a readable human scale.
  box(0.08, 2.7, 0.08, metal, -4.4, 1.35, 0.4);
  const dish = mesh(
    new THREE.SphereGeometry(0.65, 16, 8, 0, Math.PI * 2, 0, 0.4 * Math.PI),
    wall,
    -4.4,
    2.7,
    0.4,
  );
  dish.rotation.z = -0.5;
  box(0.7, 0.4, 1.2, wall, 2.4, 0.6, 2.6);
  box(0.3, 0.3, 0.4, mint, 2.4, 1, 2.6);
  for (const x of [1.95, 2.85])
    for (const z of [2.2, 3]) {
      const wheel = mesh(
        new THREE.CylinderGeometry(0.25, 0.25, 0.18, 8),
        metal,
        x,
        0.3,
        z,
      );
      wheel.rotation.z = Math.PI / 2;
    }
  const astronaut = new THREE.Group();
  group.add(astronaut);
  box(0.25, 0.42, 0.2, wall, 0, 0.52, 0, astronaut);
  mesh(new THREE.SphereGeometry(0.2, 12, 8), wall, 0, 0.87, 0, astronaut);
  box(0.27, 0.13, 0.13, blue, 0, 0.88, 0.14, astronaut);
  for (const x of [-0.09, 0.09])
    box(0.1, 0.26, 0.12, metal, x, 0.19, 0, astronaut);
  for (let i = 0; i < 28; i++) {
    const angle = i * 2.39996,
      r = 4.8 + (i % 4) * 0.38;
    const rock = mesh(
      new THREE.DodecahedronGeometry(0.1 + (i % 3) * 0.07, 0),
      sand,
      Math.cos(angle) * r,
      0.09,
      Math.sin(angle) * r,
    );
    rock.rotation.set(i, i * 0.2, 0);
  }
  const particles = new Float32Array(120 * 3);
  for (let i = 0; i < 120; i++) {
    particles[i * 3] = (Math.sin(i * 81.2) * 0.5 + 0.5) * 16 - 8;
    particles[i * 3 + 1] = (i % 17) * 0.22 + 0.4;
    particles[i * 3 + 2] = Math.cos(i * 23.1) * 7;
  }
  const pg = new THREE.BufferGeometry();
  pg.setAttribute("position", new THREE.BufferAttribute(particles, 3));
  const pm = new THREE.PointsMaterial({
    color: 0xe2ae82,
    size: 0.06,
    transparent: true,
    opacity: 0,
  });
  const dust = new THREE.Points(pg, pm);
  group.add(dust);
  let angle = 0,
    drag = null,
    width = 0,
    height = 0,
    lastFrameKey = "";
  renderer.domElement.addEventListener("pointerdown", (e) => {
    drag = { x: e.clientX, angle };
    renderer.domElement.setPointerCapture(e.pointerId);
  });
  renderer.domElement.addEventListener("pointermove", (e) => {
    if (drag) angle = drag.angle + (e.clientX - drag.x) * 0.005;
  });
  renderer.domElement.addEventListener("pointerup", () => {
    drag = null;
  });
  renderer.domElement.addEventListener("pointercancel", () => {
    drag = null;
  });
  const resize = () => {
    width = container.clientWidth;
    height = container.clientHeight;
    renderer.setSize(width, height);
    camera.aspect = width / height;
    camera.position.set(13, 12, 18).multiplyScalar(width < 500 ? 1.18 : 1);
    camera.updateProjectionMatrix();
  };
  const observer = new ResizeObserver(resize);
  observer.observe(container);
  resize();
  return {
    resize,
    update(state, t, reducedMotion) {
      const frameKey = [
        state.time,
        state.shelter,
        state.eva,
        state.returning,
        state.dust,
        state.cleaning,
        angle,
        width,
        height,
      ].join("|");
      if (frameKey === lastFrameKey) return;
      lastFrameKey = frameKey;
      group.rotation.y = angle;
      sun.intensity = 3.1 - t.storm * 1.6;
      astronaut.position.set(
        state.shelter ? -2.3 : 0.9,
        0,
        state.shelter ? -1.5 : 1.7,
      );
      astronaut.visible = state.eva;
      if (state.returning > 0) {
        const progress = 1 - state.returning / 0.15;
        astronaut.position.set(0.9 - 3.2 * progress, 0, 1.7 - 3.2 * progress);
      }
      refugeDoor.material.emissiveIntensity = state.shelter ? 1.4 : 0.2;
      for (const p of panels) {
        p.material.color
          .set(0x21485b)
          .lerp(new THREE.Color(0xb9825e), state.dust * 0.85);
        p.material.emissive.set(state.cleaning ? 0x285e56 : 0);
        p.material.emissiveIntensity = state.cleaning ? 0.4 : 0;
      }
      pm.opacity = t.storm * 0.55;
      if (!reducedMotion) dust.position.x = ((state.time * 2) % 3) - 1.5;
      renderer.render(scene, camera);
    },
    dispose() {
      observer.disconnect();
      scene.traverse((o) => {
        o.geometry?.dispose();
        if (o.material) {
          for (const m of Array.isArray(o.material) ? o.material : [o.material])
            m.dispose();
        }
      });
      renderer.dispose();
    },
  };
}
