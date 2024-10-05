import { elements, context, memory, config } from "./config.js";
import { MemoryManager } from "./memory-manager.js";
import * as utils from "./utils.js";

WebAssembly.instantiateStreaming(
  fetch("../wasm/imageprocessing.wasm"),
  config.importObject,
).then((obj) =>
  utils.initAndPlay((video) => processVideoFrames(video, obj.instance.exports)),
);

function processVideoFrames(video, wasmExports) {
  const memoryManager = new MemoryManager(memory, wasmExports);

  const processFrame = () => {
    // TODO Refactor processFrame func
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const { data, width, height } = imageData;

    const stringLength = width * height;
    const totalLen = data.length + stringLength + 6;

    memoryManager.ensureMemorySize(totalLen);

    const imageView = memoryManager.getView("image", 0, data.length);
    imageView.set(data);

    if (config.ascii || elements.grayscale.checked) {
      wasmExports.grayscale(memoryManager.persistentPtr, data.length);
    }
    // wasmExports.sepia(totalPtr, data.length);
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

    if (
      (elements.grayscale.checked || elements.monochrome.checked) &&
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

    requestAnimationFrame(processFrame);
  };

  processFrame();
}

function applyKernel(array, start, kernel, width) {
  const result = [];
  const halfKernel = Math.floor(kernel / 2);
  const rowStart = Math.floor(start / width);
  const colStart = start % width;

  for (let i = -halfKernel; i <= halfKernel; i++) {
    for (let j = -halfKernel; j <= halfKernel; j++) {
      const row = rowStart + i;
      const col = colStart + j;

      // Handle wrapping and bounds
      if (row < 0 || row >= Math.ceil(array.length / width)) continue;
      if (col < 0 || col >= width) continue;

      const index = row * width + col;
      if (index >= 0 && index < array.length) {
        result.push(array[index]);
      }
    }
  }

  return result;
}

// Example usage
const array = [
  7, 3, 15, 1, 9, 12, 2, 6, 14, 11, 5, 0, 8, 13, 4, 10, 15, 7, 2, 9, 1, 11, 6,
  3, 14, 8, 0, 12, 5, 10, 4, 13, 7, 2, 15, 9, 1, 6, 11, 3,
];
const kernel = 5;
const width = 10;
const start = 0;

const result = applyKernel(array, start, kernel, width);
console.log(result);
// return;

// const array = [
//   7, 3, 15, 1, 9, 12, 2, 6, 14, 11, 5, 0, 8, 13, 4, 10, 15, 7, 2, 9, 1, 11, 6,
//   3, 14, 8, 0, 12, 5, 10, 4, 13, 7, 2, 15, 9, 1, 6, 11, 3,
// ];

// const kernel = 3;
// const width = 10;
// const start = 39;

// for (let i = 0; i < kernel; i++) {
//   let v = parseInt(-(kernel / 2)) + i;
//   for (let j = 0; j < kernel; j++) {
//     let h = parseInt(-(kernel / 2)) + j;
//     if (v < 0) {
//       const index = start + h - width;
//       if (index % width === 0 && start % width === width - 1) {
//         continue;
//       } else if (start % width === 0 && index % width === width - 1) {
//         continue;
//       }
//       if (index > 0) console.log(array[index]);
//     } else if (v === 0) {
//       const index = start + h;
//       if (index % width === 0 && start % width === width - 1) {
//         continue;
//       } else if (start % width === 0 && index % width === width - 1) {
//         continue;
//       }
//       if (index >= 0 && index < array.length) console.log(array[index]);
//     } else {
//       const index = start + h + width;
//       if (index % width === 0 && start % width === width - 1) {
//         continue;
//       } else if (start % width === 0 && index % width === width - 1) {
//         continue;
//       }
//       if (index < array.length) console.log(array[index]);
//     }
//   }
// }
// console.log(array);
