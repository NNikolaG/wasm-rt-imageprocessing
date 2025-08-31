import { config, context, elements, memory } from "./config.js";
import { MemoryManager } from "./memory-manager.js";
import * as utils from "./utils.js";

WebAssembly.instantiateStreaming(
  fetch("../wasm/imageprocessing.wasm"),
  config.importObject,
).then((obj) =>
  utils.initAndPlay((video) => processVideoFrames(video, obj.instance.exports)),
);

/**
 * Processes video frames by applying various effects such as grayscale, sepia, blur, and ASCII conversion
 * using WebAssembly exports and updates the canvas accordingly.
 *
 * @param {HTMLVideoElement} video - The video element whose frames are to be processed.
 * @param {Object} wasmExports - An object containing WebAssembly exported functions for image processing.
 * @return {void}
 */
function processVideoFrames(video, wasmExports) {
  const memoryManager = new MemoryManager(memory, wasmExports);
  
  // Performance optimization variables
  let lastFrameTime = 0;
  let frameCount = 0;
  let isProcessing = false;
  const targetFPS = 60;
  const frameInterval = 1000 / targetFPS;
  
  // FPS tracking variables
  let fpsFrameCount = 0;
  let fpsLastTime = performance.now();
  let currentFPS = 0;
  const fpsCounter = document.getElementById('fps-counter');
  
  // Reusable TextDecoder to avoid creating new instances every frame
  const textDecoder = new TextDecoder('utf-8', { fatal: false, ignoreBOM: true });
  
  // FPS display update
  const updateFPS = () => {
    const now = performance.now();
    const delta = now - fpsLastTime;
    
    if (delta >= 1000) {
      currentFPS = Math.round((fpsFrameCount * 1000) / delta);
      fpsCounter.textContent = `FPS: ${currentFPS}`;
      fpsFrameCount = 0;
      fpsLastTime = now;
    }
  };
  
  // Cleanup memory when page is unloaded
  window.addEventListener('beforeunload', () => {
    memoryManager.destroy();
  });

  const processFrame = (currentTime = performance.now()) => {
    // Prevent overlapping frame processing
    if (isProcessing) {
      requestAnimationFrame(processFrame);
      return;
    }
    
    // Frame rate limiting
    if (currentTime - lastFrameTime < frameInterval) {
      requestAnimationFrame(processFrame);
      return;
    }
    
    isProcessing = true;
    lastFrameTime = currentTime;
    frameCount++;
    fpsFrameCount++;
    updateFPS();
    
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const { data, width, height } = imageData;

    // Check if any effects are active to optimize processing
    const hasEffects = config.ascii || 
      elements.grayscale.checked || 
      elements.monochrome.checked ||
      elements.ryo.checked || 
      elements.lix.checked || 
      elements.neue.checked ||
      elements.sepia.checked || 
      elements.solarize.checked || 
      elements.blur.checked ||
      Array.prototype.some.call(elements.channelIndex, el => el.checked);
    
    // Skip processing if no effects are active and in canvas mode
    if (!hasEffects && config.canvas) {
      isProcessing = false;
      requestAnimationFrame(processFrame);
      return;
    }

    const stringLength = width * height;
    let totalLen = data.length * 2 + stringLength + 6;

    if (elements.blur.checked) {
      totalLen += data.length;
    }

    memoryManager.ensureMemorySize(totalLen);

    const imageView = memoryManager.getView("image", 0, data.length);
    imageView.set(data);

    if (config.ascii || elements.grayscale.checked) {
      wasmExports.grayscale(memoryManager.persistentPtr, data.length);
    }

    let stringView = undefined;
    if (config.ascii) {
      stringView = memoryManager.getView("string", data.length, stringLength);

      wasmExports.ascii(
        memoryManager.persistentPtr,
        data.length,
        memoryManager.persistentPtr + data.length,
        canvas.width,
        config.inverted,
      );
    }

    if (elements.monochrome.checked) {
      const rgb = utils.hexToRgb(config.color);
      wasmExports.monochrome(memoryManager.persistentPtr, data.length, ...rgb);
    }

    if (elements.ryo.checked) {
      wasmExports.ryo(memoryManager.persistentPtr, data.length);
    }

    if (elements.lix.checked) {
      wasmExports.lix(memoryManager.persistentPtr, data.length);
    }

    if (elements.neue.checked) {
      wasmExports.neue(memoryManager.persistentPtr, data.length);
    }

    if (elements.sepia.checked) {
      wasmExports.sepia(memoryManager.persistentPtr, data.length);
    }

    if (elements.solarize.checked) {
      wasmExports.solarize(memoryManager.persistentPtr, data.length);
    }

    if (elements.blur.checked) {
      wasmExports.box_blur(
        memoryManager.persistentPtr,
        canvas.width,
        canvas.height,
        config.kernelSize,
        memoryManager.persistentPtr + data.length,
      );
    }

    if (
      Array.prototype.some.call(
        elements.channelIndex,
        (element) => element.checked,
      )
    ) {
      wasmExports.channel_shift(
        memoryManager.persistentPtr,
        canvas.width,
        canvas.height,
        config.offset,
        config.channelIndex,
      );
    }

    if (
      (Array.prototype.some.call(
        elements.channelIndex,
        (element) => element.checked,
      ) ||
        Array.prototype.some.call(
          elements.effects,
          (element) => element.checked,
        )) &&
      config.canvas
    ) {
      imageData.data.set(imageView);
      context.putImageData(imageData, 0, 0);
    }

    if (config.ascii) {
      // Use the reusable TextDecoder for better performance
      const stringRepresentation = textDecoder.decode(stringView, { stream: false });
      elements.ascii.textContent = stringRepresentation;
    }

    memoryManager.cleanup();
    isProcessing = false;

    requestAnimationFrame(processFrame);
  };

  processFrame();
}
