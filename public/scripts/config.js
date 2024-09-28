// DOM Elements
export const elements = {
  sliderWrapper: document.querySelector(".slider-wrapper"),
  canvasHeight: document.querySelector("#canvas-height"),
  slider: document.querySelector("#resolution-slider"),
  canvasWidth: document.querySelector("#canvas-width"),
  themeToggle: document.querySelector(".theme-toggle"),
  asciiToggle: document.querySelector(".ascii-toggle"),
  lineHeight: document.querySelector("#line-height"),
  asciiInfo: document.querySelector(".ascii-info"),
  fontSize: document.querySelector("#font-size"),
  canvas: document.querySelector("#canvas"),
  ascii: document.querySelector(".ascii"),
  pre: document.querySelector(".ascii"),
  main: document.querySelector("main"),
};

// Configuration
export const config = {
  defaultResolution: 100,
  aspectRatio: 0.75,
  asciiRation: 0.4,
  fontSizeScale: 20,
  lineHeightScale: 1.2,
  maxCanvasWidth: 1280,
};

// Canvas context
export const context = elements.canvas.getContext("2d");
