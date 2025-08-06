# Beyond256: Hi-Color Image Viewer for Commander X16
This project demonstrates a technique to display images with thousands of colors on a stock Commander X16, overcoming the hardware's limitation of a single 256-color global palette.

The core idea is to rapidly switch color palettes for different horizontal sections of the screen during rendering, creating the illusion of a much richer color depth across the entire image.

## Features
* Displays hi-color images on standard Commander X16 hardware.
* Uses a per-strip palette-switching technique to break the 256-color barrier.
* Automated asset conversion pipeline using Python, Pillow, and ImageMagick.
* Optimized 6502 assembly display routine.
* Includes Run-Length Encoding (RLE) compression for bitmap data to save space.
* Fully automated and modular build process via a Makefile.

## How It Works
The Commander X16's VERA video chip can only hold 256 colors in its palette RAM at any given moment. This is a significant constraint for displaying photorealistic images.

This project circumvents that limitation with a classic demo-scene technique:

1. **Preprocessing:** A Python script first analyzes the source image.
* The image is resized to 320x240 and its global color count is reduced to 4096 (12-bit color).
* The script then divides the image into horizontal strips (e.g., 8 pixels high).
* For each strip, it generates a unique, optimized local palette containing only the colors needed for that specific section (e.g., 16 or 32 colors).
* The bitmap data and palettes are exported as 6502 assembly source files, and the bitmap is compressed using RLE.

1. **Rendering:** The 6502 assembly program performs the display logic.
* Before rendering a strip of scanlines, the program loads the corresponding pre-calculated local palette into VERA's palette RAM.
* It then decompresses and copies the pixel data for that strip into VRAM.
* This process is repeated for every strip down the screen.

By synchronizing the palette updates with the screen refresh, the viewer can display a different set of 256 (or fewer) colors for each section, resulting in a final image composed of thousands of unique colors.

## Project Structure
The project is organized into a clean and logical directory structure:

```
├── assets/         # Original, high-quality source assets (e.g., PNG images)
├── data/           # Generated assembly source files (palettes, bitmap data)
├── src/            # Manually written 6502 assembly source code
├── tools/          # Helper scripts for asset conversion
├── build/          # Compiled binaries and object files (ignored by Git)
└── Makefile        # The main build script for the project
```

## Prerequisites
To build and run this project, you will need the following tools installed:

* cc65 toolchain: Specifically the cl65 compiler/linker.
* make: The build automation tool.
* Python 3: For running the conversion script.
* Pillow: The Python imaging library (pip install Pillow).
* ImageMagick: The command-line image processing toolkit.
* x16emu: The Commander X16 emulator.

## Usage
The entire build process is managed by the Makefile.

1. **Place your source image** inside the assets/images/ directory. Make sure to update the RAW_IMAGE variable in the Makefile if you change the filename.

2. **Convert the assets:** Run the asset conversion pipeline. This will process your image and generate the .s files in the data/ directory.

```
# Use default settings (8px strip height, 16 local colors)
make assets

# Use custom settings
make assets STRIP_HEIGHT=16 LOCAL_COLORS=32
```

3. **Build the project:** Compile the assembly code and link everything into a final .prg file.

```
make
# or
make all
```
The final program will be located at build/demodata.prg.

4. **Build and Run:** To compile and immediately launch the program in the emulator:
```
make run
```

5. **Clean up:** To remove all generated files from the build/ and data/ directories:
```
make clean
```