export class MemoryManager {
  constructor(memory, wasmExports) {
    this.wasmExports = wasmExports;
    this.memory = memory;
    this.persistentPtr = null;
    this.persistentSize = 0;
    this.views = new Map();
  }

  ensureMemorySize(requiredSize) {
    if (this.persistentPtr === null || this.persistentSize < requiredSize) {
      if (this.persistentPtr !== null) {
        this.wasmExports.free(this.persistentPtr, this.persistentSize);
      }
      this.persistentSize = requiredSize;
      this.persistentPtr = this.wasmExports.alloc(this.persistentSize);
      this.views.clear(); // Clear existing views as they're no longer valid
    }
    return this.persistentPtr;
  }

  getView(name, start, length) {
    const key = `${name}-${start}-${length}`;
    if (!this.views.has(key)) {
      const view = new Uint8Array(
        this.memory.buffer,
        this.persistentPtr + start,
        length,
      );
      this.views.set(key, view);
    }
    return this.views.get(key);
  }

  cleanup() {
    if (this.persistentPtr !== null) {
      this.wasmExports.free(this.persistentPtr, this.persistentSize);
      this.persistentPtr = null;
      this.persistentSize = 0;
      this.views.clear();
    }
  }
}
