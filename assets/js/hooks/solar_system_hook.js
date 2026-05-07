/**
 * SolarSystemHook — Isometric solar system renderer using PixiJS.
 *
 * Visual design targets the look in the reference image:
 *  - Large glowing star with corona and flare spikes
 *  - Tilted elliptical orbit rings (isometric perspective)
 *  - Planets as detailed fake-3D spheres:
 *      rocky / lava / desert / ocean / ice / gas_giant — each with surface detail
 *  - Gas giants have Saturn-style ring system
 *  - Dense asteroid belts: 70+ particles in a multi-layer band
 *  - Green hyperlane exit streaks at screen corners
 *  - Dark-box nameplates below owned/colonised planets
 *  - Planets distributed via golden angle (orbit-based), not region
 *  - Orbit step is dynamic so all orbits fit the canvas
 *
 * data-planets — JSON array of:
 *   { orbit, region, name, planet_id, is_own, occupied, player, slot_type, planet_subtype }
 * data-bg — background image URL (optional)
 * data-hyperlanes — number of hyperlane exits to draw (default 4)
 */

import * as PIXI from "pixi.js";

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const TILT        = 0.36;           // vertical squish: ry = rx * TILT
const ORBIT_BASE  = 90;             // first orbit radius (px)
const STAR_R      = 36;             // star body radius
const GOLDEN_ANG  = 2.399963229;    // ~137.508 deg, produces even spread
const TAU         = Math.PI * 2;

const RADII = {
  gas_giant: 19, ice: 13, ocean: 13, lava: 11, desert: 10, rocky: 9, default: 10,
};

// Per-subtype palette: base colour, dark side, atmosphere, band detail
const STYLE = {
  rocky:     { base: 0x9B8365, dark: 0x4A3C28, atmo: 0xBBA985, band: 0x7B6348 },
  lava:      { base: 0xDD4400, dark: 0x771800, atmo: 0xFF7733, band: 0xAA3311 },
  desert:    { base: 0xD4A854, dark: 0x8A6024, atmo: 0xF0CC74, band: 0xB48844 },
  ocean:     { base: 0x1A6ED8, dark: 0x0A2870, atmo: 0x50AEFF, band: 0x2888F0 },
  ice:       { base: 0xD0EEFF, dark: 0x6898C0, atmo: 0xF0FCFF, band: 0xB0D8F0 },
  gas_giant: { base: 0xEA9E5E, dark: 0x7A3C18, atmo: 0xFFCC88, band: 0xCC7844 },
  default:   { base: 0x708090, dark: 0x384050, atmo: 0x9090A0, band: 0x607070 },
};

// ─────────────────────────────────────────────────────────────────────────────
// Geometry helpers
// ─────────────────────────────────────────────────────────────────────────────
function orbitRx(orbit, step) { return ORBIT_BASE + (orbit - 1) * step; }
function orbitRy(rx)           { return rx * TILT; }

/** Golden-angle distribution — each orbit rotates ~137.5 deg from the last. */
function orbitAngle(orbit) { return -(Math.PI * 0.42) + (orbit - 1) * GOLDEN_ANG; }

function planetXY(orbit, step, cx, cy) {
  const rx = orbitRx(orbit, step);
  const a  = orbitAngle(orbit);
  return { x: cx + rx * Math.cos(a), y: cy + orbitRy(rx) * Math.sin(a) };
}

function pRad(sub)   { return RADII[sub] ?? RADII.default;  }
function pStyle(sub) { return STYLE[sub] ?? STYLE.default;  }

/** Deterministic pseudo-random in [0, 1) seeded by integer n. */
function rng(n) {
  const s = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - Math.floor(s);
}

// ─────────────────────────────────────────────────────────────────────────────
// Star
// ─────────────────────────────────────────────────────────────────────────────
function drawStar(g, cx, cy) {
  // Corona (outer to inner)
  [[STAR_R * 6.0, 0.022], [STAR_R * 4.5, 0.048], [STAR_R * 3.3, 0.095],
   [STAR_R * 2.3, 0.17],  [STAR_R * 1.75, 0.28]].forEach(([r, a]) => {
    g.beginFill(0xFF9900, a); g.drawCircle(cx, cy, r); g.endFill();
  });
  // Main body
  g.beginFill(0xFFDD55, 1);   g.drawCircle(cx, cy, STAR_R); g.endFill();
  // Limb darkening
  g.beginFill(0xDD7700, 0.20); g.drawCircle(cx + STAR_R * 0.13, cy + STAR_R * 0.13, STAR_R * 0.78); g.endFill();
  // Highlights
  g.beginFill(0xFFFFAA, 0.60); g.drawCircle(cx - STAR_R * 0.30, cy - STAR_R * 0.30, STAR_R * 0.35); g.endFill();
  g.beginFill(0xFFFFCC, 0.25); g.drawCircle(cx - STAR_R * 0.10, cy - STAR_R * 0.42, STAR_R * 0.18); g.endFill();
  // Flare spikes (8-pointed)
  g.lineStyle(1.5, 0xFFEE55, 0.25);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * TAU;
    g.moveTo(cx + Math.cos(a) * STAR_R * 1.10, cy + Math.sin(a) * STAR_R * 1.10);
    g.lineTo(cx + Math.cos(a) * STAR_R * 1.90, cy + Math.sin(a) * STAR_R * 1.90);
  }
  g.lineStyle(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Planet
// ─────────────────────────────────────────────────────────────────────────────
function drawPlanet(g, x, y, subtype, isOwn, occupied) {
  const r      = pRad(subtype);
  const s      = pStyle(subtype);
  const isGas   = subtype === "gas_giant";
  const isIce   = subtype === "ice";
  const isOcean = subtype === "ocean";
  const isLava  = subtype === "lava";
  const isDes   = subtype === "desert";

  // Ownership glow
  if (isOwn) {
    g.beginFill(0x22DDFF, 0.045); g.drawCircle(x, y, r * 4.5); g.endFill();
    g.beginFill(0x22DDFF, 0.110); g.drawCircle(x, y, r * 2.8); g.endFill();
  } else if (occupied) {
    g.beginFill(0xFF6622, 0.040); g.drawCircle(x, y, r * 4.0); g.endFill();
    g.beginFill(0xFF6622, 0.090); g.drawCircle(x, y, r * 2.4); g.endFill();
  }

  // Atmosphere fringe
  if (isOcean || isGas || isIce) {
    g.beginFill(s.atmo, 0.13); g.drawCircle(x, y, r + 3.5); g.endFill();
  }

  // Gas giant rings (behind sphere)
  if (isGas) {
    const rX = r * 2.7, rY = r * 0.52;
    g.lineStyle(9,   0x443322, 0.40); g.drawEllipse(x, y, rX, rY);
    g.lineStyle(5.5, 0xBB9955, 0.58); g.drawEllipse(x, y, rX, rY);
    g.lineStyle(3.0, 0xDDCC88, 0.38); g.drawEllipse(x, y, rX * 0.76, rY * 0.76);
    g.lineStyle(1.5, 0xEEDDAA, 0.22); g.drawEllipse(x, y, rX * 0.55, rY * 0.55);
    g.lineStyle(0);
  }

  // Shadow hemisphere
  g.beginFill(s.dark, 0.78); g.drawCircle(x + r * 0.20, y + r * 0.14, r); g.endFill();
  // Main body
  g.beginFill(s.base, 1);   g.drawCircle(x, y, r); g.endFill();

  // Surface detail per type
  if (isGas) {
    for (let b = 0; b < 5; b++) {
      const by = y - r * 0.60 + b * r * 0.30;
      const hw = r * Math.sqrt(Math.max(0, 1 - Math.pow((by - y) / r, 2)));
      g.beginFill(b % 2 === 0 ? s.band : s.atmo, 0.28);
      g.drawRect(x - hw, by - r * 0.09, hw * 2, r * 0.19); g.endFill();
    }
    // Great spot
    g.beginFill(0xFFAA66, 0.35); g.drawEllipse(x + r * 0.3, y + r * 0.22, r * 0.22, r * 0.12); g.endFill();
  } else if (isOcean) {
    g.beginFill(0x258B22, 0.58); g.drawCircle(x - r * 0.22, y - r * 0.08, r * 0.40); g.endFill();
    g.beginFill(0x2B9E2B, 0.48); g.drawCircle(x + r * 0.32, y + r * 0.28, r * 0.24); g.endFill();
    g.beginFill(0x1D7A1D, 0.35); g.drawCircle(x - r * 0.05, y + r * 0.42, r * 0.18); g.endFill();
    g.beginFill(0xFFFFFF, 0.18); g.drawEllipse(x + r * 0.08, y - r * 0.62, r * 0.58, r * 0.14); g.endFill();
  } else if (isIce) {
    g.beginFill(0xEEF8FF, 0.72); g.drawEllipse(x, y - r * 0.70, r * 0.62, r * 0.24); g.endFill();
    g.beginFill(0xEEF8FF, 0.45); g.drawEllipse(x, y + r * 0.72, r * 0.50, r * 0.20); g.endFill();
    g.lineStyle(0.7, s.band, 0.42);
    g.moveTo(x - r * 0.38, y - r * 0.10); g.lineTo(x + r * 0.22, y + r * 0.38);
    g.moveTo(x + r * 0.10, y - r * 0.48); g.lineTo(x - r * 0.28, y + r * 0.22);
    g.lineStyle(0);
  } else if (isLava) {
    g.lineStyle(1.0, 0xFF5500, 0.78);
    g.moveTo(x - r * 0.45, y + r * 0.18); g.lineTo(x + r * 0.08, y - r * 0.10); g.lineTo(x + r * 0.38, y + r * 0.42);
    g.moveTo(x - r * 0.08, y - r * 0.45); g.lineTo(x + r * 0.28, y + r * 0.18);
    g.lineStyle(0.7, 0xFF8833, 0.52);
    g.moveTo(x - r * 0.32, y - r * 0.22); g.lineTo(x + r * 0.08, y + r * 0.32);
    g.lineStyle(0);
    g.beginFill(0xFF6600, 0.35); g.drawCircle(x + r * 0.18, y + r * 0.22, r * 0.18); g.endFill();
    g.beginFill(0xFF9900, 0.25); g.drawCircle(x - r * 0.25, y - r * 0.10, r * 0.10); g.endFill();
  } else if (isDes) {
    g.lineStyle(0.8, s.dark, 0.30);
    for (let d = -1; d <= 1; d++) {
      g.drawEllipse(x + d * r * 0.18, y + d * r * 0.20, r * 0.78, r * 0.22);
    }
    g.lineStyle(0.6, s.dark, 0.28); g.drawCircle(x + r * 0.30, y - r * 0.32, r * 0.20); g.lineStyle(0);
  } else {
    // rocky — craters
    g.lineStyle(0.7, s.dark, 0.32);
    g.drawCircle(x - r * 0.25, y + r * 0.20, r * 0.20);
    g.drawCircle(x + r * 0.28, y - r * 0.28, r * 0.14);
    g.lineStyle(0);
  }

  // Specular highlight
  g.beginFill(0xFFFFFF, 0.30); g.drawCircle(x - r * 0.30, y - r * 0.28, r * 0.30); g.endFill();
  g.beginFill(s.atmo, 0.16);   g.drawCircle(x - r * 0.06, y - r * 0.06, r * 0.54); g.endFill();

  // Own-planet ring
  if (isOwn) {
    g.lineStyle(1.5, 0x22DDFF, 0.92); g.drawCircle(x, y, r + 2.5); g.lineStyle(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Asteroid belt
// ─────────────────────────────────────────────────────────────────────────────
function drawAsteroidBelt(g, orbit, step, cx, cy) {
  const rx = orbitRx(orbit, step);
  const ry = orbitRy(rx);
  // Background glow bands
  g.lineStyle(22, 0x5A4A30, 0.06); g.drawEllipse(cx, cy, rx, ry);
  g.lineStyle(12, 0x7B6040, 0.13); g.drawEllipse(cx, cy, rx, ry);
  g.lineStyle(5,  0xAA9055, 0.22); g.drawEllipse(cx, cy, rx, ry);
  g.lineStyle(0);
  // Rock particles
  const SHADES = [0xAA8855, 0xBB9966, 0x998844, 0xCC9966, 0x887755, 0xDDBB88, 0x776640];
  for (let i = 0; i < 72; i++) {
    const frac   = i / 72;
    const angle  = frac * TAU;
    const r1     = rng(orbit * 1000 + i);
    const r2     = rng(orbit * 1000 + i + 500);
    const r3     = rng(orbit * 1000 + i + 750);
    const r4     = rng(orbit * 1000 + i + 999);
    const spread = (r1 - 0.5) * 18;
    const radMod = 1 + (r2 - 0.5) * 0.24;
    const px = cx + (rx * radMod + spread * 0.82) * Math.cos(angle);
    const py = cy + (ry * radMod + spread * 0.32) * Math.sin(angle);
    const sz = 0.9 + r3 * 3.2;
    const col = SHADES[Math.floor(r2 * SHADES.length)];
    g.beginFill(col, r4 > 0.87 ? 0.75 : 0.50 + r1 * 0.40);
    g.drawCircle(px, py, r4 > 0.87 ? sz * 1.6 : sz);
    g.endFill();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hyperlane exit streaks
// ─────────────────────────────────────────────────────────────────────────────
function drawHyperlaneExits(g, cx, cy, W, H, count) {
  const EXITS = [
    { dx: -1, dy: -1 }, { dx: 1, dy: -1 },
    { dx: -1, dy:  1 }, { dx: 1, dy:  1 },
  ];
  const len = 90;
  for (let i = 0; i < Math.min(count, 4); i++) {
    const { dx, dy } = EXITS[i];
    const a = Math.atan2(dy, dx);
    const ex = cx + dx * W * 0.44;
    const ey = cy + dy * H * 0.40;
    const cos = Math.cos(a), sin = Math.sin(a);
    g.lineStyle(3.0, 0x22FF88, 0.55);
    g.moveTo(ex - cos * len, ey - sin * len); g.lineTo(ex + cos * len, ey + sin * len);
    g.lineStyle(6.0, 0x44FFAA, 0.10);
    g.moveTo(ex - cos * len, ey - sin * len); g.lineTo(ex + cos * len, ey + sin * len);
    g.lineStyle(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveView Hook
// ─────────────────────────────────────────────────────────────────────────────
const SolarSystemHook = {
  mounted()   { this._init(); },
  updated()   {
    const d = this.el.dataset.planets;
    if (d !== this._lastData) { this._lastData = d; this._rebuild(); }
  },
  destroyed() { this._cleanup(); },

  _init() {
    this._lastData = this.el.dataset.planets;
    const wrapper  = this.el;
    const W = wrapper.clientWidth  || 900;
    const H = wrapper.clientHeight || 560;

    this._app = new PIXI.Application({
      width: W, height: H,
      backgroundColor: 0x040a14,
      antialias: true,
      resolution: window.devicePixelRatio || 1,
      autoDensity: true,
    });

    const mount = wrapper.querySelector("#pixi-mount");
    if (mount) mount.appendChild(this._app.view);
    this._overlay = wrapper.querySelector("#nameplate-overlay");

    const bgUrl = this.el.dataset.bg;
    if (bgUrl) {
      const bg = PIXI.Sprite.from(bgUrl);
      bg.width = W; bg.height = H; bg.alpha = 0.42;
      this._app.stage.addChild(bg);
    }

    this._W = W; this._H = H;
    this._cx = W / 2; this._cy = H / 2;
    this._rebuild();
  },

  _cleanup() {
    if (this._app) {
      this._app.destroy(true, { children: true, texture: true, baseTexture: true });
      this._app = null;
    }
    if (this._overlay) this._overlay.innerHTML = "";
  },

  _rebuild() {
    if (!this._app) return;
    while (this._app.stage.children.length > 1) this._app.stage.removeChildAt(1);
    if (this._overlay) this._overlay.innerHTML = "";

    const planets = JSON.parse(this._lastData || "[]");
    const cx = this._cx, cy = this._cy;
    const W  = this._W,  H  = this._H;

    // Dynamic orbit step: scale so max orbit fits ~88% of half-width
    const allOrbits = [...new Set(planets.map(p => p.orbit))].sort((a, b) => a - b);
    const maxOrbit  = allOrbits[allOrbits.length - 1] || 1;
    const maxRx     = Math.min(cx * 0.87, (cy / TILT) * 0.80);
    const step      = allOrbits.length > 1
      ? Math.max(28, (maxRx - ORBIT_BASE) / (maxOrbit - 1))
      : 55;

    const g = new PIXI.Graphics();
    this._app.stage.addChild(g);

    // Orbit rings
    allOrbits.forEach(orbit => {
      const rx = orbitRx(orbit, step);
      g.lineStyle(0.9, 0x3a6080, 0.28);
      g.drawEllipse(cx, cy, rx, orbitRy(rx));
    });
    g.lineStyle(0);

    // Hyperlane exits
    const hlCount = parseInt(this.el.dataset.hyperlanes || "4", 10);
    drawHyperlaneExits(g, cx, cy, W, H, hlCount);

    // Asteroid belts (drawn before star so rocks appear behind it)
    planets.filter(p => p.slot_type === "asteroid_ring")
           .forEach(p => drawAsteroidBelt(g, p.orbit, step, cx, cy));

    // Star
    drawStar(g, cx, cy);

    // Planets — sort so "far side" (sin > 0) rendered first, appearing behind
    const slots  = planets.filter(p => p.slot_type !== "asteroid_ring");
    const sorted = [...slots].sort(
      (a, b) => Math.sin(orbitAngle(a.orbit)) - Math.sin(orbitAngle(b.orbit))
    );

    sorted.forEach(p => {
      const { x, y } = planetXY(p.orbit, step, cx, cy);
      drawPlanet(g, x, y, p.planet_subtype, p.is_own, p.occupied);
      this._nameplate(p, x, y);
    });

    // Invisible hit-areas for click detection
    sorted.forEach(p => {
      const { x, y } = planetXY(p.orbit, step, cx, cy);
      const r   = pRad(p.planet_subtype);
      const hit = new PIXI.Graphics();
      hit.beginFill(0xFFFFFF, 0.001);
      hit.drawCircle(x, y, Math.max(r * 2.5, 20));
      hit.endFill();
      hit.interactive = true;
      hit.buttonMode  = true;
      hit.cursor      = "pointer";
      hit.on("pointerdown", () => {
        this.pushEvent("planet_selected", {
          orbit: p.orbit, region: p.region, planet_id: p.planet_id,
        });
      });
      this._app.stage.addChild(hit);
    });
  },

  _nameplate(planet, x, y) {
    if (!this._overlay) return;
    let label = "", color = "";
    if (planet.is_own) {
      label = planet.name || "Your Planet"; color = "#4ade80";
    } else if (planet.occupied && planet.player) {
      label = planet.name || planet.player;  color = "#fb923c";
    } else if (planet.occupied) {
      label = "Colonised";                   color = "#fb923c";
    } else {
      return; // uninhabited — no nameplate
    }
    const r  = pRad(planet.planet_subtype);
    const el = document.createElement("div");
    el.style.cssText = [
      "position:absolute",
      `left:${x}px`,
      `top:${y + r + 11}px`,
      "transform:translateX(-50%)",
      "font-size:9px",
      "font-weight:700",
      "letter-spacing:0.07em",
      "text-transform:uppercase",
      `color:${color}`,
      "background:rgba(4,10,22,0.84)",
      "border:1px solid rgba(100,160,210,0.32)",
      "padding:2px 7px",
      "border-radius:2px",
      "white-space:nowrap",
      "pointer-events:none",
    ].join(";");
    el.textContent = label;
    this._overlay.appendChild(el);
  },
};

export default SolarSystemHook;