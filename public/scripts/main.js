const canvas = document.getElementById("canvas");
const context = canvas.getContext("2d");
const asciiHtml = document.querySelector(".ascii");
const memory = new WebAssembly.Memory({
  initial: 25,
}); // Adjust size as needed

async function loadWasm() {
  const response = await fetch("../wasm/imageprocessing.wasm");
  const bytes = await response.arrayBuffer();

  const { instance } = await WebAssembly.instantiate(bytes, {
    env: {
      print: (data) => console.log(data),
      printf16: (data) => console.log(data),
      printu32: (data) => console.log(data),
      printusize: (data) => console.log(data),
      memory: memory,
    },
  });

  return instance.exports;
}

async function startProcessing() {
  const wasmExports = await loadWasm();
  const video = document.createElement("video");

  const stream = await navigator.mediaDevices.getUserMedia({ video: true });
  video.srcObject = stream;
  video.play();

  video.addEventListener("playing", () => {
    processVideoFrames(video, wasmExports);
  });
}

function processVideoFrames(video, wasmExports) {
  const processFrame = () => {
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;
    const stringLength = canvas.width * canvas.height;

    const totalLen = data.length + stringLength;
    const totalPtr = wasmExports.alloc(totalLen);
    const totalMemory = new Uint8Array(memory.buffer, totalPtr, totalLen);

    const imageView = totalMemory.subarray(0, data.length);
    imageView.set(data);

    wasmExports.grayscale(totalPtr, data.length);

    const stringView = totalMemory.subarray(
      data.length,
      data.length + stringLength,
    );

    wasmExports.ascii(
      totalPtr,
      data.length,
      totalPtr + data.length,
      canvas.width,
      canvas.height,
    );

    const stringRepresentation = new TextDecoder().decode(stringView, {
      stream: true,
    });

    asciiHtml.textContent = stringRepresentation;

    wasmExports.free(totalPtr, totalLen);
    requestAnimationFrame(processFrame);
  };

  processFrame();
}

startProcessing().catch((error) => console.log(error));
//
