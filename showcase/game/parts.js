// Godot consumes a normal streaming response for each large file. Keep a single
// part reader open per file so joining the parts needs no extra game-sized buffer.
async function fetchReleaseFile(file, options) {
  if (!Object.hasOwn(releaseFiles.sizes, file)) return fetch(file, options);
  const size = releaseFiles.sizes[file];
  const count = Math.ceil(size / releaseFiles.chunkBytes);
  let next = 0;
  let reader;
  const stream = new ReadableStream({
    async pull(controller) {
      try {
        while (next < count || reader) {
          if (!reader) {
            const response = await fetch(`${file}.part${String(next++).padStart(2, '0')}`, options);
            if (!response.ok) throw new Error('A game download was interrupted. Please try again.');
            reader = response.body.getReader();
          }
          const { done, value } = await reader.read();
          if (!done) {
            controller.enqueue(value);
            return;
          }
          reader.releaseLock();
          reader = null;
        }
        controller.close();
      } catch (error) {
        controller.error(error);
        fail(error.message || 'The game download was interrupted. Please try again.');
      }
    },
    cancel(reason) { return reader?.cancel(reason); },
  });
  return new Response(stream, { headers: {
    'Content-Length': String(size),
    'Content-Type': file.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream',
  } });
}
