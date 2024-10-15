# Project Documentation: Setup and Run Locally

This document provides instructions on how to set up and run the project locally, including compiling Zig code to WebAssembly (WASM) and integrating with pure JavaScript.

## Prerequisites

Ensure you have the following installed on your system:

1. [Zig](https://zig.guide/getting-started/installation/) (latest version recommended)
2. http-server: a simple HTTP server

## Project Setup

1. Clone the repository or download the project files:
   ```
   git clone https://github.com/NNikolaG/wasm-rt-imageprocessing.git
   cd wasm-rt-imageprocessing
   ```

## Compiling Zig to WebAssembly

1. Navigate to the root directory:

2. Compile the Zig code to WebAssembly:
   ```
   zig build
   ```
[//]: # TODO( Fix zig build )
[//]: # TODO( Add responsive canvas )

Initial zig build will throw error, run it multiple times.

   This will generate a `imageprocessing.wasm` file inside public/wasm.


## Project Structure

```
wasm-rt-imageprocessing/
├── src/
│   └── image_processing.zig       # Zig source for WebAssembly image processing
├── public/
│   ├── scripts/
│   │   ├── main.js                # Main JavaScript to interact with WebAssembly
│   │   ├── config.js              # Configuration settings for the application
│   │   └── utils.js               # Utility functions for handling DOM and rendering
│   │   └── memory-manager.js      # Creating views and managing memory
│   ├── wasm/
│   │   └── imageprocessing.wasm   # Compiled WebAssembly module
│   ├── index.html                 # Entry point of the web interface
│   ├── style.css                  # Styling for the web interface
├── build.zig                      # Zig build script

```

## Running the Project Locally

To run the project locally, you need to serve the files using an HTTP server. You can use Python's built-in `http.server` module for this purpose:

1. Navigate to the `root` directory:

2. Start a simple HTTP server:
      ```
      http-server
      ```

3. Open your web browser and navigate to `http://localhost:8080`.
