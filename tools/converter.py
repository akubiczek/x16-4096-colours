import sys
import os
import subprocess
import tempfile
import shutil
from PIL import Image
import argparse

Image.MAX_IMAGE_PIXELS = None

def create_12bit_colormap(colormap_path):
    """Creates a 64x64 PNG image containing all 4096 12-bit (R4G4B4) colors."""
    width, height = 64, 64
    img = Image.new('RGB', (width, height))
    pixels = img.load()
    
    colors = []
    # Generate all 4096 R4G4B4 colors
    for r4 in range(16):
        for g4 in range(16):
            for b4 in range(16):
                # Scale 4-bit values (0-15) to 8-bit (0-255) by repeating the bits (e.g., 1101 -> 11011101)
                r8 = (r4 << 4) | r4
                g8 = (g4 << 4) | g4
                b8 = (b4 << 4) | b4
                colors.append((r8, g8, b8))
    
    # Fill the image with the generated colors
    for y in range(height):
        for x in range(width):
            index = y * width + x
            pixels[x, y] = colors[index]
            
    img.save(colormap_path, 'PNG')

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
        run_val = data[i]
        run_len = 1
        # Limit run length to 127 to prevent control byte from becoming $FF
        while run_len < 127 and i + run_len < n and data[i + run_len] == run_val:
            run_len += 1

        if run_len > 1:
            compressed.append(0x80 | (run_len - 1))
            compressed.append(run_val)
            i += run_len
        else:
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

def process_image(input_path, output_prefix, strip_height, local_colors, no_rle):
    """Main image processing function."""
    temp_dir = tempfile.mkdtemp()
    strips_output_dir = os.path.join("build", "temp")

    try:
        print(f"Using temporary directory for intermediate files: {temp_dir}")
        print(f"Saving final strips to: {strips_output_dir}")
        os.makedirs(strips_output_dir, exist_ok=True)
        print("-" * 30)

        # === STEP 1: Smart scaling and centering (ImageMagick) ===
        temp_resized_path = os.path.join(temp_dir, 'resized.png')
        print("Step 1: Scaling, centering, and extending to 320x240 (ImageMagick)...")
        try:
            command = [
                'magick', input_path,
                '-resize', '320x240',
                '-background', 'black',
                '-gravity', 'center',
                '-extent', '320x240',
                temp_resized_path
            ]
            subprocess.run(command, check=True, capture_output=True, text=True)
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print("\nERROR: Failed to execute the 'magick' command.")
            print("Please ensure ImageMagick is installed and accessible in your system's PATH.")
            if isinstance(e, subprocess.CalledProcessError):
                print(f"Error returned by ImageMagick:\n{e.stderr}")
            sys.exit(1)

        # === NEW STEP 2: Create a 12-bit (4096 color) master palette ===
        colormap_path = os.path.join(temp_dir, 'colormap.png')
        print("Step 2: Creating 12-bit (4096 color) master palette...")
        create_12bit_colormap(colormap_path)

        # === NEW STEP 3: Remap source image to the 12-bit palette (ImageMagick) ===
        temp_remapped_path = os.path.join(temp_dir, 'remapped.png')
        print("Step 3: Remapping source image to 12-bit palette (ImageMagick)...")
        subprocess.run(
            ['magick', temp_resized_path, '-remap', colormap_path, temp_remapped_path],
            check=True, capture_output=True, text=True
        )

        # === STEP 4: Loading the remapped image into Pillow ===
        print("Step 4: Loading the remapped image for further handling...")
        img_12bit = Image.open(temp_remapped_path)
        width, height = img_12bit.size
        print(f"Image ready for further processing (dimensions: {width}x{height})")
        print("-" * 30)

        all_pixel_indices = []
        processed_strips_for_saving = []
        num_strips = (height + strip_height - 1) // strip_height
        palettes_filename = f"{output_prefix}_palettes.s"
        pixels_filename = f"{output_prefix}_pixels.s"

        with open(palettes_filename, 'w') as f_pal:
            f_pal.write(f"; Palettes for image '{input_path}'\n\n")
            f_pal.write(f"NUMBER_OF_PALETTES = {num_strips}\n")
            f_pal.write(f"NUMBER_OF_COLORS = {local_colors}\n\n")
            f_pal.write(f"palette_data_start:\n")

            for i in range(num_strips):
                print(f"Processing strip #{i+1}/{num_strips}...")
                y_start = i * strip_height
                y_end = min((i + 1) * strip_height, height)
                strip_box = (0, y_start, width, y_end)
                strip_from_12bit = img_12bit.crop(strip_box)

                # === CORRECTED QUANTIZATION LOGIC ===
                rgb_strip = strip_from_12bit.convert('RGB')
                unique_colors = sorted(list(set(rgb_strip.getdata())))

                if len(unique_colors) > local_colors:
                    print(f"  -> Strip has {len(unique_colors)} colors, reducing to {local_colors}.")
                    local_strip = rgb_strip.quantize(colors=local_colors)
                else:
                    print(f"  -> Strip has {len(unique_colors)} colors, using them directly.")
                    palette_img = Image.new('P', (1, 1))
                    palette_data = [component for color in unique_colors for component in color]
                    
                    padding_needed = (local_colors - len(unique_colors))
                    palette_data.extend([0, 0, 0] * padding_needed)
                    
                    palette_img.putpalette(palette_data)
                    local_strip = rgb_strip.quantize(palette=palette_img)

                strip_output_path = os.path.join(strips_output_dir, f"strip_{i:03d}.png")
                local_strip.save(strip_output_path, "PNG")
                print(f"  -> Saved debug strip to {strip_output_path}")

                processed_strips_for_saving.append(local_strip)

                local_palette_rgb = [tuple(local_strip.getpalette()[j:j+3]) for j in range(0, len(local_strip.getpalette()), 3)]
                f_pal.write(f"\n; Palette for strip #{i+1}, {len(unique_colors)} unique colors\n")
                f_pal.write(f"strip_{i:03d}_palette:\n")
                output_bytes = [f"${b:02x}" for r,g,b in local_palette_rgb for b in rgb_to_12bit_6502(r,g,b)]
                for chunk_idx in range(0, len(output_bytes), 16):
                    f_pal.write(f"  .byte {','.join(output_bytes[chunk_idx:chunk_idx+16])}\n")
                all_pixel_indices.extend(list(local_strip.getdata()))

        # === NEW STEP: Stitch and save the final 12-bit image ===
        print("-" * 30)
        print("Creating final composite image for debugging...")
        final_composite_image = Image.new('RGB', (width, height))
        current_y = 0
        for strip in processed_strips_for_saving:
            # Convert strip to RGB before pasting to preserve its unique colors
            final_composite_image.paste(strip.convert('RGB'), (0, current_y))
            current_y += strip.height
        
        final_image_path = os.path.join(strips_output_dir, "result_12bit.png")
        final_composite_image.save(final_image_path, "PNG")
        print(f"Saved final composite image to {final_image_path}")

        # === STEP 5: Handle pixel data (compress or save raw) ===
        print("-" * 30)
        if not no_rle:
            print("Compressing image data using RLE...")
            output_data = rle_compress(all_pixel_indices)
            data_label = "pixel_data_rle"
            header_comment = f"; Image data for '{input_path}' compressed using RLE\n"
        else:
            print("Saving raw (uncompressed) image data...")
            output_data = all_pixel_indices
            data_label = "pixel_data_raw"
            header_comment = f"; Raw image data for '{input_path}'\n"
        
        print(f"Saving image data to {pixels_filename}...")
        with open(pixels_filename, 'w') as f_pix:
            f_pix.write(header_comment)
            f_pix.write(f"image_data_size = {len(output_data)}\n")
            f_pix.write(f"{data_label}:\n")
            for i in range(0, len(output_data), 16):
                chunk = ",".join([f"${val:02x}" for val in output_data[i:i+16]])
                f_pix.write(f"  .byte {chunk}\n")
            
        print("\nCompleted successfully!")

    finally:
        print(f"\nCleaning up intermediate files directory: {temp_dir}")
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Converts an image to a format for the 6502 assembler, using RLE and smart scaling.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("input_file", help="Path to the input image.")
    parser.add_argument("output_prefix", help="Prefix for the output files (e.g., 'my_image').")
    parser.add_argument("--strip-height", type=int, default=8, help="Height of each strip in pixels (default: 8).")
    parser.add_argument("--local-colors", type=int, default=16, help="Number of colors in the local palette of each strip (default: 16).")
    parser.add_argument("--no-rle", action="store_true", help="Disable RLE compression and save raw pixel data.")
    
    args = parser.parse_args()
    process_image(args.input_file, args.output_prefix, args.strip_height, args.local_colors, args.no_rle)
