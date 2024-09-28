export const canvas = document.getElementById("canvas");
const pre = document.querySelector(".ascii");
const slider = document.getElementById("resolution-slider");
const canvasWidthEl = document.getElementById("canvas-width");
const canvasHeightEl = document.getElementById("canvas-height");
const fontSizeEl = document.getElementById("font-size");
const lineHeightEl = document.getElementById("line-height");
const themeToggleBtn = document.getElementById("theme-toggle");

function updateCanvasAndFontSize(resolution) {
  const width = resolution;
  const height = Math.floor(width * 0.4).toFixed(2);
  const fontSize = Math.max(1, (20 * (100 / width)).toFixed(2)); // Font size as float
  const lineHeight = (fontSize * 1.2).toFixed(2); // Scale line-height relative to font size

  canvas.width = width;
  canvas.height = height;
  pre.style.fontSize = `${fontSize}px`;
  pre.style.lineHeight = `${lineHeight}px`; // Update line-height

  // Update UI elements to show current values
  canvasWidthEl.textContent = width;
  canvasHeightEl.textContent = height;
  fontSizeEl.textContent = `${fontSize}px`;
  lineHeightEl.textContent = `${lineHeight}px`;

  // Call your function to render the ASCII art here
  // renderAsciiArt();
}

// Event listener for slider input
slider.addEventListener("input", function () {
  const resolution = parseInt(slider.value, 10);
  updateCanvasAndFontSize(resolution);
});

// Initial load with default values
updateCanvasAndFontSize(parseInt(slider.value, 10));

themeToggleBtn.addEventListener("click", function () {
  document.body.classList.toggle("dark-theme");

  if (document.body.classList.contains("light-theme")) {
    themeToggleBtn.textContent = "Switch to Dark Theme";
  } else {
    themeToggleBtn.textContent = "Switch to Light Theme";
  }
});
