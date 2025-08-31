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
            // Allocate with some buffer to reduce frequent reallocations
            this.persistentSize = Math.max(requiredSize, this.persistentSize * 1.5);
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
     * Cleans up views but keeps memory allocated for performance.
     * Memory is only freed when explicitly calling destroy() or when reallocating.
     *
     * @return {void} No return value.
     */
    cleanup() {
        // Only clear views, keep memory allocated for next frame
        // Memory will be reused efficiently without constant alloc/free
    }

    /**
     * Completely destroys the memory manager, freeing all allocated memory.
     * Call this when the application shuts down or memory manager is no longer needed.
     *
     * @return {void} No return value.
     */
    destroy() {
        if (this.persistentPtr !== null) {
            this.wasmExports.free(this.persistentPtr, this.persistentSize);
            this.persistentPtr = null;
            this.persistentSize = 0;
            this.views.clear();
        }
    }
}
