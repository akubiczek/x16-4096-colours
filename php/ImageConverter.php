<?php
require_once 'ColorReducer.php';

$imageName = $argv[1];
$image = imagecreatefrompng($imageName);

$colorReducer = new ColorReducer();
$imageReduced = $colorReducer->reduceColors($image, maxPerLine: 128);
imagepng($imageReduced, 'image_reduced.png');

print "Number of unique colors at origin: " . $colorReducer->originColorCount . "\n";
print "Number of unique colors at destination: " . count($colorReducer->colorPalette) . "\n";

file_put_contents('palette.inc.asm', $colorReducer->outputPalette());
file_put_contents('bitmap.inc.asm', $colorReducer->outputBitmap());

exit();


