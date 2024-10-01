import { elements, context, memory, config } from "./config.js";
import * as utils from "./utils.js";

async function loadWasm() {
  const response = await fetch("../wasm/imageprocessing.wasm");
  const bytes = await response.arrayBuffer();

  const { instance } = await WebAssembly.instantiate(
    bytes,
    config.importObject,
  );

  return instance.exports;
}

async function startProcessing() {
  const wasmExports = await loadWasm();
  utils.initAndPlay((video) => processVideoFrames(video, wasmExports));
}

function processVideoFrames(video, wasmExports) {
  const processFrame = () => {
    // TODO Refactor processFrame func
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;
    const stringLength = canvas.width * canvas.height;

    const totalLen = data.length + stringLength + 6;
    const totalPtr = wasmExports.alloc(totalLen);
    const totalMemory = new Uint8Array(memory.buffer, totalPtr, totalLen);

    const imageView = totalMemory.subarray(0, data.length);
    imageView.set(data);

    // wasmExports.grayscale(totalPtr, data.length);
    wasmExports.sepia(totalPtr, data.length);

    const stringView = totalMemory.subarray(
      data.length,
      data.length + stringLength,
    );

    // wasmExports.ascii(
    //   totalPtr,
    //   data.length,
    //   totalPtr + data.length,
    //   canvas.width,
    //   config.inverted,
    // );

    if (elements.monochrome.checked) {
      const rgb = utils.hexToRgb(config.color);
      wasmExports.monochrome(totalPtr, data.length, ...rgb);
    }

    if (elements.grayscale.checked || elements.monochrome.checked) {
      imageData.data.set(imageView);
      context.putImageData(imageData, 0, 0);
    }

    const stringRepresentation = new TextDecoder().decode(stringView, {
      stream: true,
    });

    elements.ascii.textContent = stringRepresentation;

    wasmExports.free(totalPtr, totalLen);
    requestAnimationFrame(processFrame);
  };

  processFrame();
}

startProcessing().catch((error) => console.log(error));
//
