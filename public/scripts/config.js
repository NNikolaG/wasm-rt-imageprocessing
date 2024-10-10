// DOM Elements
export const elements = {
  sliderWrapper: document.querySelector(".slider-wrapper"),
  canvasHeight: document.querySelector("#canvas-height"),
  canvasConfig: document.querySelector(".canvas-config"),
  slider: document.querySelector("#resolution-slider"),
  canvasWidth: document.querySelector("#canvas-width"),
  themeToggle: document.querySelector(".theme-toggle"),
  asciiToggle: document.querySelector(".ascii-toggle"),
  asciiConfig: document.querySelector(".ascii-config"),
  colorPicker: document.querySelector("#color-picker"),
  lineHeight: document.querySelector("#line-height"),
  invertCheckbox: document.querySelector("#invert"),
  monochrome: document.querySelector("#monochrome"),
  grayscale: document.querySelector("#grayscale"),
  fontSize: document.querySelector("#font-size"),
  canvas: document.querySelector("#canvas"),
  ascii: document.querySelector(".ascii"),
  main: document.querySelector("main"),
};

// WASM Memory
export const memory = new WebAssembly.Memory({
  initial: 25,
});

// Configuration
export const config = {
  defaultResolution: 100,
  aspectRatio: 0.75,
  asciiRation: 0.4,
  fontSizeScale: 20,
  lineHeightScale: 1.2,
  canvas: false,
  ascii: true,
  canvasWidth: 1280,
  inverted: false,
  color: "#000",
  importObject: {
    env: {
      print: (data) => console.log(data),
      printi8: (data) => console.log(data),
      printf16: (data) => console.log(data),
      printu32: (data) => console.log(data),
      printusize: (data) => console.log(data),
      memory: memory,
    },
  },
};

// Canvas context
export const context = elements.canvas.getContext("2d", {
  willReadFrequently: true,
});
