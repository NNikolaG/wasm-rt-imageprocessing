/**
 * Class responsible for managing memory allocations and views for WebAssembly modules.
 */
export class MemoryManager {
    constructor(memory, wasmExports) {
        this.wasmExports = wasmExports;
        this.memory = memory;
        this.persistentPtr = null;
        this.persistentSize = 0;
        this.views = new Map();
    }

    /**
     * Ensures that the memory size is at least the given required size.
     * Allocates new memory if the current memory pointer is null or smaller than the required size.
     *
     * @param {number} requiredSize - The minimum size of the memory required.
     * @return {number} - The pointer to the allocated memory.
     */
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

    /**
     * Retrieves a view on the memory buffer.
     *
     * @param {string} name - The name associated with the view.
     * @param {number} start - The start position in the memory buffer.
     * @param {number} length - The length of the view in bytes.
     * @return {Uint8Array} The view corresponding to the specified parameters.
     */
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

    /**
     * Cleans up any allocated resources associated with the class instance.
     *
     * This method releases memory that was allocated through WebAssembly exports
     * by freeing the pointer and resetting related properties. It also clears the views.
     *
     * @return {void} No return value.
     */
    cleanup() {
        if (this.persistentPtr !== null) {
            this.wasmExports.free(this.persistentPtr, this.persistentSize);
            this.persistentPtr = null;
            this.persistentSize = 0;
            this.views.clear();
        }
    }
}
