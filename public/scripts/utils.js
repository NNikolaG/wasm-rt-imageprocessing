import { elements, config } from "./config.js";

/**
 * Updates canvas dimensions and font size based on resolution
 * @param {number} resolution - The width of the canvas
 */
function updateCanvasAndFontSize(resolution) {
  const width = resolution;
  const height = Math.floor(width * config.asciiRation);
  const fontSize = Math.max(
    1,
    (config.fontSizeScale * (config.defaultResolution / width)).toFixed(2),
  );
  const lineHeight = (fontSize * config.lineHeightScale).toFixed(2);

  // Update canvas
  elements.canvas.width = width;
  elements.canvas.height = height;

  // Update ASCII text styles
  elements.pre.style.fontSize = `${fontSize}px`;
  elements.pre.style.lineHeight = `${lineHeight}px`;

  // Update UI displays
  elements.canvasWidth.textContent = width;
  elements.canvasHeight.textContent = height;
  elements.fontSize.textContent = `${fontSize}px`;
  elements.lineHeight.textContent = `${lineHeight}px`;
}

// Event Listeners
elements.slider.addEventListener("input", () => {
  updateCanvasAndFontSize(parseInt(elements.slider.value, 10));
});

elements.themeToggle.addEventListener("click", toggleTheme);
elements.asciiToggle.addEventListener("click", toggleAsciiMode);

// Initialize with default values
updateCanvasAndFontSize(config.defaultResolution);

/**
 * Toggles between light and dark themes
 */
function toggleTheme() {
  document.body.classList.toggle("dark-theme");
  elements.themeToggle.textContent = document.body.classList.contains(
    "dark-theme",
  )
    ? "Switch to Light Theme"
    : "Switch to Dark Theme";
}

/**
 * Toggles between Canvas and ASCII display
 */
function toggleAsciiMode() {
  const isAsciiMode = elements.canvas.classList.toggle("d-none");
  elements.pre.classList.toggle("d-none");
  elements.asciiInfo.classList.toggle("d-none");
  elements.sliderWrapper.classList.toggle("d-none");

  if (isAsciiMode) {
    elements.asciiToggle.textContent = "Switch to Canvas";
    updateCanvasAndFontSize(parseInt(elements.slider.value, 10));
  } else {
    elements.asciiToggle.textContent = "Switch to ASCII";
    elements.canvas.width = config.maxCanvasWidth;
    elements.canvas.height = config.maxCanvasWidth * config.aspectRatio;
  }
}
