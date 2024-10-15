// DOM Elements
/**
 * An object containing references to various DOM elements used in the application.
 *
 * Properties:
 * - sliderWrapper: The wrapper element of the slider.
 * - canvasHeight: The info element for displaying the canvas height.
 * - canvasConfig: The container element for canvas configuration options.
 * - slider: The slider element for setting resolution.
 * - canvasWidth: The info element for displaying the canvas width.
 * - themeToggle: The element for toggling the theme.
 * - asciiToggle: The element for toggling ASCII mode.
 * - asciiConfig: The container element for ASCII configuration options.
 * - colorPicker: The input element for picking a color.
 * - lineHeight: The info element for displaying line height.
 * - invertCheckbox: The checkbox for inverting colors.
 * - monochrome: The input element for setting monochrome mode.
 * - grayscale: The input element for setting grayscale mode.
 * - fontSize: The info element for displaying the font size.
 * - canvas: The canvas element where drawing takes place.
 * - ascii: The element displaying ASCII art.
 * - main: The main content container.
 * - channelIndex: A NodeList of elements representing channel indices.
 * - offsetSlider: The slider element for setting the offset.
 */
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
  channelIndex: document.querySelectorAll(".channel-index"),
  offsetSlider: document.querySelector("#offset-slider"),
};

/**
 * Represents a WebAssembly Memory instance with an initial memory allocation.
 *
 * @constant {WebAssembly.Memory} memory
 * @property {number} initial - The initial number of memory pages (with each page being 64KiB).
 *
 * The `memory` object is configured to have an initial allocation of memory which can be used
 * by WebAssembly instances.
 */
export const memory = new WebAssembly.Memory({
  initial: 25,
});

/**
 * Configuration settings for the application.
 *
 * @property {number} defaultResolution - The default resolution setting.
 * @property {number} aspectRatio - The aspect ratio of the display.
 * @property {number} asciiRation - The ratio for ASCII representation.
 * @property {number} fontSizeScale - Scale factor for the font size.
 * @property {number} lineHeightScale - Scale factor for the line height.
 * @property {boolean} canvas - Flag to enable or disable canvas rendering.
 * @property {boolean} ascii - Flag to enable or disable ASCII mode.
 * @property {number} canvasWidth - The width of the canvas.
 * @property {boolean} inverted - Flag to invert colors.
 * @property {string} color - The color setting in hexadecimal format.
 * @property {number} channelIndex - The index of the channel to be displayed.
 * @property {number} offset - The offset value for rendering.
 * @property {Object} importObject - The imported objects for the application.
 * @property {Object} importObject.env - The environment object.
 * @property {function} importObject.env.print - Function to print data to the console.
 * @property {function} importObject.env.printi8 - Function to print 8-bit integer data.
 * @property {function} importObject.env.printf16 - Function to print 16-bit float data.
 * @property {function} importObject.env.printu32 - Function to print 32-bit unsigned integer data.
 * @property {function} importObject.env.printusize - Function to print usize data.
 * @property {WebAssembly.Memory} importObject.env.memory - The memory object for the WebAssembly environment.
 */
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
  channelIndex: 0,
  offset: 25,
  importObject: {
    env: {
      print: (data) => console.log(data),
      memory: memory,
    },
  },
};

/**
 * The `context` variable represents the 2D rendering context for a canvas element. It is used to draw shapes, text, images, and other objects.
 *
 * The context is obtained by calling the `getContext` method on the canvas element with "2d" as the context identifier.
 *
 * An additional option is passed as an object:
 * - `willReadFrequently`: A boolean indicating that the canvas will be read frequently, which might improve performance depending on the user agent.
 */
export const context = elements.canvas.getContext("2d", {
  willReadFrequently: true,
});
