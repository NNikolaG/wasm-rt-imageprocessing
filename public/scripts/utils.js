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
  elements.ascii.style.fontSize = `${fontSize}px`;
  elements.ascii.style.lineHeight = `${lineHeight}px`;

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
elements.invertCheckbox.addEventListener("change", function () {
  config.inverted = this.checked;
});
elements.colorPicker.addEventListener("change", function () {
  config.color = elements.colorPicker.value;
  elements.ascii.style.color = elements.colorPicker.value;
});

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
  elements.ascii.classList.toggle("d-none");
  elements.asciiConfig.classList.toggle("d-none");

  if (isAsciiMode) {
    elements.asciiToggle.textContent = "Switch to Canvas";
    updateCanvasAndFontSize(parseInt(elements.slider.value, 10));
  } else {
    elements.asciiToggle.textContent = "Switch to ASCII";
    elements.canvas.width = config.canvasWidth;
    elements.canvas.height = config.canvasWidth * config.aspectRatio;
  }
}

export async function initAndPlay(callback) {
  const video = document.createElement("video");

  const stream = await navigator.mediaDevices.getUserMedia({ video: true });
  video.srcObject = stream;
  video.play();

  video.addEventListener("playing", () => {
    callback(video);
  });
}
