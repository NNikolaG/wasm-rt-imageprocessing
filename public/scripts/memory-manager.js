export class MemoryManager {
    constructor(memory, wasmExports) {
        this.wasmExports = wasmExports;
        this.memory = memory;
        this.bufferRef = memory.buffer; // <— track current buffer
        this.persistentPtr = null;
        this.persistentSize = 0;
        this.views = new Map();
    }

    ensureMemorySize(requiredSize) {
        // Round up persistentSize growth, avoid 0*1.5==0
        const nextSize = Math.max(requiredSize, Math.ceil(this.persistentSize * 1.5));
        if (this.persistentPtr === null || this.persistentSize < requiredSize) {
            if (this.persistentPtr !== null) this.wasmExports.free(this.persistentPtr, this.persistentSize);
            this.persistentSize = nextSize;
            this.persistentPtr = this.wasmExports.alloc(this.persistentSize);
            this.views.clear(); // ptr changed => views invalid
        }
        // Detect memory.grow() by comparing buffer object identity
        if (this.bufferRef !== this.memory.buffer) {
            this.bufferRef = this.memory.buffer;
            this.views.clear(); // buffer changed => all views invalid
        }
        return this.persistentPtr;
    }

    getView(name, start, length, Cls = Uint8Array) {
        // robust cache key: name | start | length | type
        const key = `${name}|${start}|${length}|${Cls.name}`;

        // refresh all views if buffer changed (memory.grow)
        if (this.bufferRef !== this.memory.buffer) {
            this.bufferRef = this.memory.buffer;
            this.views.clear();
        }

        let view = this.views.get(key);
        if (!view) {
            view = new Cls(this.bufferRef, this.persistentPtr + start, length);
            this.views.set(key, view);
        }
        return view;
    }

    destroy() {
        if (this.persistentPtr !== null) {
            this.wasmExports.free(this.persistentPtr, this.persistentSize);
            this.persistentPtr = null;
            this.persistentSize = 0;
        }
        this.views.clear();
    }
}