import sys
import os
import subprocess
import tempfile
import shutil
from PIL import Image
import argparse

Image.MAX_IMAGE_PIXELS = None

def rle_compress(data: list[int]) -> list[int]:
    """
    Compresses data using the RLE algorithm.
    - Control byte with MSB=1: A run of repeated bytes. The lower 7 bits represent (length-1).
    - Control byte with MSB=0: A run of unique bytes. The lower 7 bits represent (length-1).
    """
    if not data:
        return []

    compressed = []
    i = 0
    n = len(data)
    while i < n:
        # Check for a run of repeated bytes
        run_val = data[i]
        run_len = 1
        while run_len < 128 and i + run_len < n and data[i + run_len] == run_val:
            run_len += 1

        if run_len > 1:
            # We have a run of repetitions
            compressed.append(0x80 | (run_len - 1))
            compressed.append(run_val)
            i += run_len
        else:
            # We have a run of unique bytes (a literal run)
            literal_start = i
            while (i + 1 < n and data[i] != data[i+1]) or \
                  (i + 2 < n and (data[i] != data[i+1] or data[i+1] != data[i+2])):
                i += 1
                if i - literal_start >= 128:
                    break
            
            literal_len = i - literal_start + 1
            compressed.append(literal_len - 1)
            compressed.extend(data[literal_start : literal_start + literal_len])
            i += 1
   
    compressed.append(0xFF) # Add a terminator byte at the end of the stream         
    return compressed


def rgb_to_12bit_6502(r, g, b):
    """Converts an RGB color to the 12-bit 6502 format."""
    r4, g4, b4 = r >> 4, g >> 4, b >> 4
    byte1 = (g4 << 4) | b4
    byte2 = r4
    return byte1, byte2

def process_image(input_path, output_prefix, strip_height, local_colors):
    """Main image processing function."""
    temp_dir = tempfile.mkdtemp()
    try:
        print(f"Using temporary directory: {temp_dir}")
        print("-" * 30)

        # === STEP 1: Smart scaling and centering (ImageMagick) ===
        temp_resized_path = os.path.join(temp_dir, 'resized.png')
        print("Step 1: Scaling, centering, and extending to 320x120 (ImageMagick)...")
        try:
            # 1. Resize with aspect ratio preserved to fit within 320x120.
            # 2. Set a black background.
            # 3. Center the image.
            # 4. Extend the canvas to the exact 320x120 dimensions.
            command = [
                'magick', input_path,
                '-resize', '320x120',
                '-background', 'black',
                '-gravity', 'center',
                '-extent', '320x120',
                temp_resized_path
            ]
            subprocess.run(command, check=True, capture_output=True, text=True)
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print("\nERROR: Failed to execute the 'magick' command.")
            print("Please ensure ImageMagick is installed and accessible in your system's PATH.")
            if isinstance(e, subprocess.CalledProcessError):
                print(f"Error returned by ImageMagick:\n{e.stderr}")
            sys.exit(1)

        # === STEP 2: Palette reduction to 4096 colors (ImageMagick) ===
        temp_quantized_path = os.path.join(temp_dir, 'quantized.png')
        print("Step 2: Reducing to 4096 colors (ImageMagick)...")
        subprocess.run(
            ['magick', temp_resized_path, '-colors', '4096', temp_quantized_path],
            check=True, capture_output=True, text=True
        )

        # === STEP 3: Loading the processed image into Pillow ===
        print("Step 3: Loading the processed image for further handling...")
        img_12bit = Image.open(temp_quantized_path)
        width, height = img_12bit.size
        print(f"Image ready for further processing (dimensions: {width}x{height})")
        print("-" * 30)

        all_pixel_indices = []
        num_strips = (height + strip_height - 1) // strip_height
        palettes_filename = f"{output_prefix}_palettes.s"
        pixels_filename = f"{output_prefix}_pixels.s"

        with open(palettes_filename, 'w') as f_pal:
            f_pal.write(f"; Palettes for image '{input_path}'\n")

            for i in range(num_strips):
                print(f"Processing strip #{i+1}/{num_strips}...")
                y_start = i * strip_height
                y_end = min((i + 1) * strip_height, height)
                strip_box = (0, y_start, width, y_end)
                strip_from_12bit = img_12bit.crop(strip_box)
                local_strip = strip_from_12bit.convert('RGB').quantize(colors=local_colors)
                local_palette_rgb = [tuple(local_strip.getpalette()[j:j+3]) for j in range(0, len(local_strip.getpalette()), 3)]
                f_pal.write(f"\n; Palette for strip #{i+1}, {len(local_palette_rgb)} colors\n")
                f_pal.write(f"strip_{i:03d}_palette:\n")
                output_bytes = [f"${b:02x}" for r,g,b in local_palette_rgb for b in rgb_to_12bit_6502(r,g,b)]
                for chunk_idx in range(0, len(output_bytes), 16):
                    f_pal.write(f"  .byte {','.join(output_bytes[chunk_idx:chunk_idx+16])}\n")
                all_pixel_indices.extend(list(local_strip.getdata()))

        # === NEW STEP: RLE Compression ===
        print("-" * 30)
        print("Compressing image data using RLE...")
        compressed_data = rle_compress(all_pixel_indices)
        original_size = len(all_pixel_indices)
        compressed_size = len(compressed_data)
        ratio = compressed_size / original_size if original_size > 0 else 0
        print(f"Original size: {original_size} bytes")
        print(f"Compressed size: {compressed_size} bytes")
        print(f"Compression ratio: {ratio:.2%}")
        
        print(f"Saving compressed image data to {pixels_filename}...")
        with open(pixels_filename, 'w') as f_pix:
            f_pix.write(f"; Image data for '{input_path}' compressed using RLE\n")
            f_pix.write(f"; Original size: {original_size}B, compressed: {compressed_size}B\n")
            f_pix.write("pixel_data_rle:\n")
            for i in range(0, len(compressed_data), 16):
                chunk = ",".join([f"${val:02x}" for val in compressed_data[i:i+16]])
                f_pix.write(f"  .byte {chunk}\n")
            
        print("\nCompleted successfully!")

    finally:
        print(f"\nCleaning up temporary directory: {temp_dir}")
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Converts an image to a format for the 6502 assembler, using RLE and smart scaling.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    # ... (rest of the parser remains unchanged)
    parser.add_argument("input_file", help="Path to the input image.")
    parser.add_argument("output_prefix", help="Prefix for the output files (e.g., 'my_image').")
    parser.add_argument("--strip-height", type=int, default=8, help="Height of each strip in pixels (default: 8).")
    parser.add_argument("--local-colors", type=int, default=16, help="Number of colors in the local palette of each strip (default: 16).")
    args = parser.parse_args()
    process_image(args.input_file, args.output_prefix, args.strip_height, args.local_colors)