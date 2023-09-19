<?php

require_once 'HexRGBUtils.php';

class ColorReducer
{
    const MAX_COMPONENT_VALUE = 15; // 4 bits color
    public readonly int $originColorCount;
    public readonly int $destinationColorCount;
    public readonly array $colorPalette;

    private array $bitmap;
    public array $indexedBitmap;

    public function reduceColors(GdImage $image, int $maxPerLine = 256): GdImage
    {
        $width = imagesx($image);
        $height = imagesy($image);

        $originColors = [];
        $destinationColors = [];
        $divider = 40.3785; //16 for 4096 colors, 40.3785 for 256 colors

        for ($y = 0; $y < $height; $y++) {
            for ($x = 0; $x < $width; $x++) {
                // pixel color at (x, y)
                $rgb = imagecolorat($image, $x, $y);
                $originColors[$rgb] = 1;

                $r = floor((($rgb >> 16) & 0xFF) / $divider);
                $g = floor((($rgb >> 8) & 0xFF) / $divider);
                $b = floor(($rgb & 0xFF) / $divider);

                $index = HexRGBUtils::rgbToHex($r, $g, $b);
                $this->bitmap[$y][$x] = $index;
            }

            $this->reduceLineColors($y, $maxPerLine);

            $destinationColors = array_merge($destinationColors, $this->bitmap[$y]);
        }

        $this->originColorCount = count($originColors);
        unset($originColors);

        $this->destinationColorCount = count(array_unique($destinationColors));

        $this->generateIndexedBitmap($height, $width);

        return $this->bitmapToImage($width, $height, $divider);
    }

    private function reduceLineColors(int $line, int $maxColors)
    {
        $uniqueColors = array_unique($this->bitmap[$line]);
        $colorsCount = count($uniqueColors);

        $maxIterations = 4096;
        $colorsProcessed = [];

        while ($colorsCount > $maxColors) {
            foreach ($uniqueColors as $hexColor) {
                if (in_array($hexColor, $colorsProcessed)) {
                    continue;
                }

                list($r, $g, $b) = HexRGBUtils::hexToRGB($hexColor);

                $colorsReplaced = 0;

                if ($r < self::MAX_COMPONENT_VALUE) {
                    $similarColor = HexRGBUtils::rgbAdd($hexColor, 1, 0, 0);
                    $colorsReplaced = $this->replaceColor($line, color: $similarColor, withColor: $hexColor);
                } elseif ($g < self::MAX_COMPONENT_VALUE) {
                    $similarColor = HexRGBUtils::rgbAdd($hexColor, 0, 1, 0);
                    $colorsReplaced = $this->replaceColor($line, color: $similarColor, withColor: $hexColor);
                } elseif ($b < self::MAX_COMPONENT_VALUE) {
                    $similarColor = HexRGBUtils::rgbAdd($hexColor, 0, 0, 1);
                    $colorsReplaced = $this->replaceColor($line, color: $similarColor, withColor: $hexColor);
                }

                if ($colorsReplaced > 0) {
                    print "Replaced $colorsReplaced occurences of $similarColor with $hexColor at line $line\n";
                    $colorsProcessed[] = $hexColor;
                    break;
                }
            }

            $uniqueColors = array_unique($this->bitmap[$line]);
            $colorsCount = count($uniqueColors);

            $maxIterations--;
            if ($maxIterations == 0) {
                print "Forced stop reducing colors\n";
                $colorsCount = -1; //force stop reducing
            }
        }
    }

    public function outputPalette(): string
    {
        $output = "color_palette:\n.byte ";
        $maxPerLine = 40;
        $index = 0;
        foreach ($this->colorPalette as $hex) {
            $r = substr($hex, 0, 2);
            $g = substr($hex, 3, 1);
            $b = substr($hex, 5, 1);

            $output .= "\${$g}{$b},\${$r},";

            if (++$index == $maxPerLine) {
                $output = substr($output, 0, strlen($output) - 1) . "\n.byte ";
                $index = 0;
            }
        }

        $output = substr($output, 0, strlen($output) - 1);
        if (str_ends_with($output, '.byte')) {
            $output = substr($output, 0, strlen($output) - strlen('.byte'));
        }
        return $output . "\n";
    }

    public function outputBitmap(): string
    {
        $output = "bitmap_data:\n.byte ";
        $maxPerLine = 150;
        $index = 0;
        $flattenedArray = array_merge(...$this->indexedBitmap);

        foreach ($flattenedArray as $key) {

            $hex = str_pad(dechex($key), 2, "0", STR_PAD_LEFT);
            $output .= "\${$hex},";

            if (++$index == $maxPerLine) {
                $output = substr($output, 0, strlen($output) - 1) . "\n.byte ";
                $index = 0;
            }
        }

        $output = substr($output, 0, strlen($output) - 1);
        if (str_ends_with($output, '.byte')) {
            $output = substr($output, 0, strlen($output) - strlen('.byte'));
        }
        return $output . "\n";
    }

    private
    function replaceColor(int $line, string $color, string $withColor): int
    {
        // print "Replacing $color with $withColor\n";
        $replacements = 0;

        for ($i = 0; $i < count($this->bitmap[$line]); $i++) {
            if ($this->bitmap[$line][$i] == $color) {
                $this->bitmap[$line][$i] = $withColor;
                $replacements++;
            }
        }

        return $replacements;
    }

    private
    function bitmapToImage(int $width, int $height, int $divider): GdImage
    {
        $newImage = imagecreatetruecolor($width, $height);
        for ($y = 0; $y < $height; $y++) {
            for ($x = 0; $x < $width; $x++) {
                list($r, $g, $b) = HexRGBUtils::hexToRGB($this->bitmap[$y][$x]);
                imagesetpixel($newImage, $x, $y, imagecolorallocate($newImage, $r * $divider, $g * $divider, $b * $divider));
            }
        }

        return $newImage;
    }

    private
    function generateIndexedBitmap(int $height, int $width): void
    {
        $this->generatePalette($height);

        for ($y = 0; $y < $height; $y++) {
            for ($x = 0; $x < $width; $x++) {
                $colorIndex = array_search($this->bitmap[$y][$x], $this->colorPalette);
                $this->indexedBitmap[$y][$x] = $colorIndex;
            }
        }
    }

    private
    function generatePalette(int $height): void
    {
        $allColors = [];

        for ($y = 0; $y < $height; $y++) {
            $allColors = array_merge($allColors, $this->bitmap[$y]);
        }

        $this->colorPalette = array_values(array_unique($allColors));
    }
}