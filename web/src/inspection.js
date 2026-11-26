export function inspectShrine(canvas, wake) {
  const events = new AbortController();
  const state = { yaw: 0, pitch: 0, hoverX: 0, hoverY: 0, hover: false, dragging: false };
  let drag;

  function listen(type, handler) {
    canvas.addEventListener(type, handler, { signal: events.signal });
  }

  function aim(event) {
    if (event.pointerType === 'touch') return;
    const bounds = canvas.getBoundingClientRect();
    state.hoverX = Math.min(1, Math.max(-1, (event.clientX - bounds.left) / bounds.width * 2 - 1));
    state.hoverY = Math.min(1, Math.max(-1, (event.clientY - bounds.top) / bounds.height * 2 - 1));
    state.hover = true;
  }

  listen('pointerdown', (event) => {
    if (!event.isPrimary || event.button !== 0) return;
    drag = { id: event.pointerId, x: event.clientX, y: event.clientY, touch: event.pointerType === 'touch' };
    canvas.setPointerCapture(event.pointerId);
    if (!drag.touch) canvas.focus({ preventScroll: true });
    wake();
  });

  listen('pointermove', (event) => {
    aim(event);
    if (drag?.id === event.pointerId) {
      const dx = event.clientX - drag.x;
      const dy = event.clientY - drag.y;
      if (!state.dragging && Math.max(Math.abs(dx), Math.abs(dy)) < 4) return;
      if (drag.touch && !state.dragging && Math.abs(dx) < Math.abs(dy)) return;
      state.dragging = true;
      canvas.classList.add('dragging');
      state.yaw -= dx * .0105;
      if (!drag.touch) state.pitch = Math.max(-.72, Math.min(.90, state.pitch - dy * .006));
      drag.x = event.clientX;
      drag.y = event.clientY;
    }
    wake();
  });

  function stopDrag(event) {
    if (drag?.id !== event.pointerId) return;
    state.dragging = false;
    drag = undefined;
    canvas.classList.remove('dragging');
    wake();
  }
  listen('pointerup', stopDrag);
  listen('pointercancel', stopDrag);
  listen('lostpointercapture', stopDrag);
  listen('pointerleave', () => {
    state.hover = false;
    wake();
  });

  listen('keydown', (event) => {
    switch (event.key) {
      case 'ArrowLeft': state.yaw -= .24; break;
      case 'ArrowRight': state.yaw += .24; break;
      case 'ArrowUp': state.pitch = Math.min(.90, state.pitch + .16); break;
      case 'ArrowDown': state.pitch = Math.max(-.72, state.pitch - .16); break;
      case 'Home': state.yaw = state.pitch = 0; break;
      default: return;
    }
    event.preventDefault();
    wake();
  });

  return { state, dispose: () => events.abort() };
}
