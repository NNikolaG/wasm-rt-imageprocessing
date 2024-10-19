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

  const processFrame = () => {
    // TODO Refactor processFrame func
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const { data, width, height } = imageData;

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
    } else {
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
      const stringRepresentation = new TextDecoder().decode(stringView, {
        stream: true,
      });

      elements.ascii.textContent = stringRepresentation;
    }

    memoryManager.cleanup();

    requestAnimationFrame(processFrame);
  };

  processFrame();
}
