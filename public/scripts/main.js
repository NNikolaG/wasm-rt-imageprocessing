// main.js
import {config, context, elements, memory} from "./config.js";
import {MemoryManager} from "./memory-manager.js";
import * as utils from "./utils.js";

const textDecoder = new TextDecoder("utf-8", {fatal: false, ignoreBOM: true});

WebAssembly.instantiateStreaming(
    fetch("../wasm/imageprocessing.wasm"),
    config.importObject // must include { env: { memory } } since you import_memory=true
).then(({instance}) => {
    utils.initAndPlay((video) => processVideoFrames(video, instance.exports));
});

function processVideoFrames(video, wasm) {
    const mm = new MemoryManager(memory, wasm);

    // Canvas refs (make sure these exist in your config)
    const canvas = context.canvas;
    const width = 1280;
    const height = 960;

    // --- compute buffer layout (once per resolution) ---
    const RGBA_LEN = width * height * 4;
    const STR_LEN = width * height;       // ascii string buffer (1 byte per pixel)
    const BLUR_LEN = RGBA_LEN;             // 1:1 temp for box blur (if used)
    const PADDING = 64;                   // small headroom/alignment

    // Choose whether blur/ascii scratch is reserved up front.
    // (If you prefer strictly-on-demand, you can bump size at runtime too.)
    const NEEDS_BLUR = true;  // reserve scratch ahead of time
    const NEEDS_STRING = true;

    const IMG_OFF = 0;
    const BLUR_OFF = IMG_OFF + RGBA_LEN;
    const STR_OFF = BLUR_OFF + (NEEDS_BLUR ? BLUR_LEN : 0);
    const TOTAL_LEN = STR_OFF + (NEEDS_STRING ? STR_LEN : 0) + PADDING;

    // Ensure region & build persistent views
    mm.ensureMemorySize(TOTAL_LEN);
    let ptr = mm.persistentPtr;

    let imgU8 = mm.getView("imgU8", IMG_OFF, RGBA_LEN, Uint8Array);             // for .set(source)
    let imgCl = mm.getView("imgCl", IMG_OFF, RGBA_LEN, Uint8ClampedArray);       // for ImageData
    let strU8 = mm.getView("strU8", STR_OFF, STR_LEN, Uint8Array);               // ascii target (optional)
    let imageData = new ImageData(imgCl, width, height);                          // no extra copy

    // Rebuild views if buffer identity changes (memory.grow())
    const refreshViewsIfNeeded = () => {
        // ensureMemorySize will clear internal view cache if buffer changed
        mm.ensureMemorySize(TOTAL_LEN);
        ptr = mm.persistentPtr;
        imgU8 = mm.getView("imgU8", IMG_OFF, RGBA_LEN, Uint8Array);
        imgCl = mm.getView("imgCl", IMG_OFF, RGBA_LEN, Uint8ClampedArray);
        strU8 = mm.getView("strU8", STR_OFF, STR_LEN, Uint8Array);
        imageData = new ImageData(imgCl, width, height);
    };

    // FPS widget (optional)
    const fpsCounter = document.getElementById("fps-counter");
    let lastFPSStamp = performance.now();
    let fpsFrames = 0;

    const tickFPS = () => {
        fpsFrames++;
        const now = performance.now();
        if (now - lastFPSStamp >= 1000) {
            if (fpsCounter) fpsCounter.textContent = `FPS: ${fpsFrames}`;
            fpsFrames = 0;
            lastFPSStamp = now;
        }
    };

    let isProcessing = false;

    function processFrame() {
        if (isProcessing) return requestAnimationFrame(processFrame);
        isProcessing = true;

        // 1) Draw current video frame to canvas (source path)
        context.drawImage(video, 0, 0, width, height);
        const src = context.getImageData(0, 0, width, height).data; // unavoidable copy from canvas

        // 2) Bulk copy into WASM memory once
        refreshViewsIfNeeded();     // if memory grew, fix views once
        imgU8.set(src);             // single fast copy

        // 3) Run effects (prefer one pipeline export; here we keep your toggles)
        //    NOTE: pass scratch/string pointers when needed
        if (config.ascii || elements.grayscale.checked) {
            wasm.grayscale(ptr + IMG_OFF, RGBA_LEN);
        }
        if (config.ascii) {
            wasm.ascii(
                ptr + IMG_OFF,
                RGBA_LEN,
                ptr + STR_OFF,          // ascii output buffer
                width,
                config.inverted
            );
        }
        if (elements.monochrome.checked) {
            const [r, g, b] = utils.hexToRgb(config.color);
            wasm.monochrome(ptr + IMG_OFF, RGBA_LEN, r, g, b);
        }
        if (elements.ryo.checked) wasm.ryo(ptr + IMG_OFF, RGBA_LEN);
        if (elements.lix.checked) wasm.lix(ptr + IMG_OFF, RGBA_LEN);
        if (elements.neue.checked) wasm.neue(ptr + IMG_OFF, RGBA_LEN);

        if (elements.sepia.checked) {
            // If you exported sepia_simd_packed, use it; otherwise sepia().
            (wasm.sepia_simd_packed ?? wasm.sepia)(ptr + IMG_OFF, RGBA_LEN);
        }

        if (elements.solarize.checked) {
            (wasm.solarize_simd_packed ?? wasm.solarize)(ptr + IMG_OFF, RGBA_LEN);
        }

        if (elements.blur.checked) {
            wasm.box_blur(
                ptr + IMG_OFF,
                width,
                height,
                config.kernelSize,
                ptr + BLUR_OFF          // scratch buffer same size as image
            );
        }

        if ([...elements.channelIndex].some(el => el.checked)) {
            wasm.channel_shift(
                ptr + IMG_OFF,
                width,
                height,
                config.offset,
                config.channelIndex
            );
        }

        // 🎞️ BATCH 1: VINTAGE & FILM EFFECTS
        if (elements.vignette?.checked) {
            wasm.vignette(
                ptr + IMG_OFF,
                RGBA_LEN,
                width,
                height,
                parseFloat(elements.vignetteIntensity?.value || 0.5)
            );
        }

        if (elements.filmGrain?.checked) {
            wasm.film_grain(
                ptr + IMG_OFF,
                RGBA_LEN,
                parseInt(elements.grainIntensity?.value || 20)
            );
        }

        if (elements.crossProcess?.checked) {
            wasm.cross_process(ptr + IMG_OFF, RGBA_LEN);
        }

        if (elements.lomography?.checked) {
            wasm.lomography(ptr + IMG_OFF, RGBA_LEN);
        }

        // 🌈 BATCH 1: COLOR ADJUSTMENTS
        if (elements.brightnessContrast?.checked) {
            wasm.brightness_contrast(
                ptr + IMG_OFF,
                RGBA_LEN,
                parseInt(elements.brightnessValue?.value || 0),
                parseFloat(elements.contrastValue?.value || 1.0)
            );
        }

        if (elements.saturationFilter?.checked) {
            wasm.saturation(
                ptr + IMG_OFF,
                RGBA_LEN,
                parseFloat(elements.saturationValue?.value || 1.0)
            );
        }

        if (elements.hueShift?.checked) {
            wasm.hue_shift(
                ptr + IMG_OFF,
                RGBA_LEN,
                parseFloat(elements.hueDegrees?.value || 0)
            );
        }

        if (elements.temperatureFilter?.checked) {
            wasm.temperature(
                ptr + IMG_OFF,
                RGBA_LEN,
                parseFloat(elements.temperatureValue?.value || 0)
            );
        }

        // 4) Draw back — no extra JS copy (ImageData already views WASM memory)
        const hasActiveFilters = (
            [...elements.channelIndex].some(el => el.checked) ||
            [...elements.effects].some(el => el.checked) ||
            elements.sepia?.checked || elements.solarize?.checked ||
            elements.blur?.checked || config.ascii || elements.grayscale?.checked ||
            // New Batch 1 filters
            elements.vignette?.checked || elements.filmGrain?.checked ||
            elements.crossProcess?.checked || elements.lomography?.checked ||
            elements.brightnessContrast?.checked || elements.saturationFilter?.checked ||
            elements.hueShift?.checked || elements.temperatureFilter?.checked
        );

        if (hasActiveFilters && config.canvas) {
            context.putImageData(imageData, 0, 0);
        }

        // 5) ASCII text (optional)
        if (config.ascii) {
            const txt = textDecoder.decode(strU8, {stream: false});
            elements.ascii.textContent = txt;
        }

        tickFPS();
        isProcessing = false;
        requestAnimationFrame(processFrame);
    }

    // Cleanup on unload
    window.addEventListener("beforeunload", () => mm.destroy());

    // Kick off
    requestAnimationFrame(processFrame);
}