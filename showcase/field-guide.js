const chapters = [
  {
    tab: "Exploration",
    title: "Explore the valley",
    description: "Carry the sun through the Flooded Grove. Beyond its stone causeway, branching trails lead to hidden supplies and six camps where the shrine can draw energy.",
    image: "grove.webp",
    alt: "A traveler with a glowing bronze shrine crosses a broken causeway over turquoise water.",
    screenshot: "exploration.webp",
    screenshotAlt: "In-game view from behind the traveler approaching the Grove’s arches under a crescent moon.",
    place: "Flooded Grove",
    medium: "Concept art",
    inputs: [["WASD", "Move"], ["M", "Open map"]],
  },
  {
    tab: "Shrine defense",
    title: "Hold the shrine",
    description: "Unfold your shrine at a camp and place defenses along the lanes. Each wave buys the sun more time to recharge. Pack up when the ground is spent, or when staying costs too much.",
    image: "defense.webp",
    alt: "Defensive towers ring the golden sun shrine on a flooded stone platform.",
    screenshot: "shrine-defense.webp",
    screenshotAlt: "In-game tactical view of Grove paths and towers surrounding the deployed sun shrine.",
    place: "Grove defense",
    medium: "Concept art",
    inputs: [["E", "Deploy"], ["T", "Start defense"]],
  },
  {
    tab: "Vesper",
    title: "Face the Colossus",
    description: "A fully restored sun opens the way to the summit. Read Vesper’s charge, circle to its glowing shoulder and strike while the giant braces to expose its chest.",
    image: "vesper.webp",
    alt: "The enormous armored Vesper stands beneath a ruined stone ring in the moonlight.",
    screenshot: "vesper-fight.webp",
    screenshotAlt: "In-game view of the traveler battling Vesper at the summit, with its exposed chest illuminated.",
    place: "Vesper Colossus",
    medium: "Prologue illustration",
    inputs: [["Shift", "Dash"], ["F", "Strike"]],
  },
  {
    tab: "Sunrise",
    title: "Bring back the dawn",
    description: "After Vesper falls, approach the beacon’s cradle. Deliver the sun you have protected since the Grove and watch morning return to the valley.",
    image: "sunrise.webp",
    alt: "The traveler watches the sun glow in its bronze cradle as the valley fills with dawn light.",
    screenshot: "sunrise.webp",
    screenshotAlt: "In-game sunrise over the restored sun in the bronze beacon on its stone platform.",
    place: "Hilltop beacon",
    medium: "Concept art",
    inputs: [["E", "Deliver the sun"]],
  },
];

const arrow = (direction) => `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true" focusable="false"><g transform="${direction < 0 ? "translate(24 0) scale(-1 1)" : ""}"><path d="M4.5 12h14.25m-6-6 6 6-6 6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></g></svg>`;

function renderChapter(chapter, index) {
  return `<div class="guide-chapter" role="tabpanel" id="guide-chapter-${index}" aria-labelledby="guide-tab-${index}" tabindex="0" ${index ? "hidden" : ""}>
    <figure class="guide-figure">
      <div class="guide-picture"><img src="./assets/${chapter.image}" alt="${chapter.alt}" width="1400" height="788" loading="lazy" decoding="async"></div>
      <figcaption>
        <span class="guide-credit"><span>${chapter.place}</span><span class="guide-medium">${chapter.medium}</span></span>
        <span class="guide-media-switch" role="group" aria-label="Image source">
          <button type="button" data-view="artwork" aria-pressed="true">Artwork</button>
          <button type="button" data-view="gameplay" aria-pressed="false">Gameplay</button>
        </span>
      </figcaption>
    </figure>
    <div class="guide-details">
      <h3>${chapter.title}</h3>
      <p>${chapter.description}</p>
      <ul class="guide-inputs" aria-label="Game controls">${chapter.inputs.map(([key, action]) => `<li><kbd>${key}</kbd> ${action}</li>`).join("")}</ul>
    </div>
  </div>`;
}

export function initFieldGuide() {
  const section = document.getElementById("field-guide");
  if (!section || section.querySelector(".guide-inner")) return;

  section.setAttribute("aria-labelledby", "guide-heading");
  section.innerHTML = `<div class="guide-inner">
    <div class="guide-heading-row">
      <h2 id="guide-heading">Field guide</h2>
      <div class="guide-paging">
        <span class="guide-count" aria-hidden="true"><span>01</span> / 04</span>
        <button class="guide-arrow" type="button" data-guide-prev aria-label="Previous chapter">${arrow(-1)}</button>
        <button class="guide-arrow" type="button" data-guide-next aria-label="Next chapter">${arrow(1)}</button>
      </div>
    </div>
    <div class="guide-tabs" role="tablist" aria-label="Field guide chapters">${chapters.map((chapter, index) => `<button type="button" role="tab" id="guide-tab-${index}" aria-controls="guide-chapter-${index}" aria-selected="${index === 0}" tabindex="${index === 0 ? 0 : -1}">${chapter.tab}</button>`).join("")}</div>
    ${chapters.map(renderChapter).join("")}
    <div class="guide-announcement" role="status"></div>
  </div>`;

  const tabs = [...section.querySelectorAll('[role="tab"]')];
  const panels = [...section.querySelectorAll('[role="tabpanel"]')];
  const counter = section.querySelector(".guide-count span");
  const announcement = section.querySelector(".guide-announcement");
  let active = 0;
  let view = "artwork";

  function showMedia(index) {
    const chapter = chapters[index];
    const panel = panels[index];
    const image = panel.querySelector("img");
    const isGameplay = view === "gameplay";
    const source = isGameplay ? `./assets/gameplay/${chapter.screenshot}` : `./assets/${chapter.image}`;
    if (image.getAttribute("src") !== source) {
      image.src = source;
      image.alt = isGameplay ? chapter.screenshotAlt : chapter.alt;
    }
    panel.querySelector(".guide-medium").textContent = isGameplay ? "In-game capture" : chapter.medium;
    panel.querySelectorAll("[data-view]").forEach(button => {
      button.setAttribute("aria-pressed", String(button.dataset.view === view));
    });
  }

  function select(index, { focusTab = false, announce = false } = {}) {
    active = (index + chapters.length) % chapters.length;
    showMedia(active);
    tabs.forEach((tab, i) => {
      tab.setAttribute("aria-selected", String(i === active));
      tab.tabIndex = i === active ? 0 : -1;
      panels[i].hidden = i !== active;
    });
    counter.textContent = String(active + 1).padStart(2, "0");
    announcement.textContent = announce ? chapters[active].title : "";
    if (focusTab) tabs[active].focus();
  }

  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => select(index));
    tab.addEventListener("keydown", (event) => {
      const destination = { ArrowLeft: active - 1, ArrowRight: active + 1, Home: 0, End: chapters.length - 1 }[event.key];
      if (destination === undefined) return;
      event.preventDefault();
      select(destination, { focusTab: true });
    });
  });
  section.querySelector("[data-guide-prev]").addEventListener("click", () => select(active - 1, { announce: true }));
  section.querySelector("[data-guide-next]").addEventListener("click", () => select(active + 1, { announce: true }));
  section.querySelectorAll("[data-view]").forEach(button => {
    button.addEventListener("click", () => {
      view = button.dataset.view;
      showMedia(active);
    });
  });
}
