# nvim-colorizer.lua

## Project Overview

`nvim-colorizer.lua` is a high-performance color highlighter for Neovim, written entirely in Lua using LuaJIT. It has **no external dependencies** and is designed for raw speed, allowing for real-time updates as you type. It supports a wide variety of color formats including:

*   **CSS:** RGB, RGBA, HSL, names (e.g., `Blue`), `rgb()`, `rgba()`, `hsl()`, `hsla()`, `oklch()`.
*   **Hex:** `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, `0xAARRGGBB`.
*   **Tailwind:** Supports Tailwind CSS color names.
*   **Sass:** Supports Sass color variables.

The project uses a custom, handwritten parser and a Trie data structure for efficient text matching.

## Architecture

*   **Core Logic (`lua/colorizer/`):**
    *   `buffer.lua`: Handles the logic for highlighting the buffer.
    *   `parser/*.lua`: Contains specific parsers for different color formats (hex, hsl, names, etc.).
    *   `trie.lua` & `matcher.lua`: Implements the Trie data structure for efficient color name matching.
*   **Entry Point (`lua/colorizer.lua`):** Manages setup, configuration, and attaching/detaching from buffers.
*   **Plugin Entry (`plugin/colorizer.lua`):** Standard Neovim plugin entry point.

## Building and Running

This project is a Neovim plugin, so "running" it involves loading it into Neovim. However, there are specific commands for testing and benchmarking.

### Prerequisites

*   **Neovim >= 0.7.0**
*   **`set termguicolors`** must be enabled in Neovim.

### Key Commands (Makefile)

*   **Run Minimal Instance (for manual testing):**
    ```bash
    make minimal
    # OR
    scripts/minimal-colorizer.sh
    ```
    This launches a clean Neovim instance with the plugin loaded, using `test/minimal-colorizer.lua` configuration.

*   **Run Trie Tests:**
    ```bash
    make trie-test
    ```

*   **Run Trie Benchmarks:**
    ```bash
    make trie-benchmark
    ```

*   **Run All Trie Tasks:**
    ```bash
    make trie
    ```

*   **Clean Test Artifacts:**
    ```bash
    make clean
    ```

### Documentation

Documentation is generated using `ldoc`.
*   **Generate Docs:** `scripts/gen_docs.sh`

## Development Conventions

*   **Language:** Lua (LuaJIT compatible).
*   **Formatting:** Uses `stylua`. Configuration is in `.stylua.toml`.
*   **Testing:**
    *   `test/minimal-colorizer.lua`: Used for manual verification.
    *   `test/expect.lua`: Defines expected highlights for testing.
    *   `test/trie/`: Contains specific tests and benchmarks for the Trie implementation.
*   **Style:**
    *   No external dependencies are allowed (stdlib only).
    *   Performance is a primary concern.
