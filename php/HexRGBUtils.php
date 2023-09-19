<?php

class HexRGBUtils
{
    public static function rgbToHex(int $r, int $g, int $b): string
    {
        return str_pad(dechex($r), 2, "0", STR_PAD_LEFT) . str_pad(dechex($g), 2, "0", STR_PAD_LEFT) . str_pad(dechex($b), 2, "0", STR_PAD_LEFT);
    }

    public static function hexToRGB(string $hex): array
    {
        $r = substr($hex, 0, 2);
        $g = substr($hex, 2, 2);
        $b = substr($hex, 4, 2);

        return [hexdec($r), hexdec($g), hexdec($b)];
    }

    public static function rgbAdd(string $rgb, int $rElement, int $gElement, int $bElement): string
    {
        list($r, $g, $b) = self::hexToRGB($rgb);
        $r += $rElement;
        $g += $gElement;
        $b += $bElement;

        return self::rgbToHex($r, $g, $b);
    }
}