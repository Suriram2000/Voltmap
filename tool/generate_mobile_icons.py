"""Generate VoltMapEV Android and iOS icons from the canonical web icon."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "mobile" / "web" / "icons" / "icon-512.png"


def save_square(source: Image.Image, destination: Path, size: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    resized = source.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(destination, format="PNG", optimize=True)


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    android_res = ROOT / "mobile" / "android" / "app" / "src" / "main" / "res"
    for directory, size in android_sizes.items():
        save_square(source, android_res / directory / "ic_launcher.png", size)
    save_square(source, android_res / "drawable-nodpi" / "launch_image.png", 320)

    ios_icon_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    ios_icons = (
        ROOT
        / "mobile"
        / "ios"
        / "Runner"
        / "Assets.xcassets"
        / "AppIcon.appiconset"
    )
    for filename, size in ios_icon_sizes.items():
        save_square(source, ios_icons / filename, size)

    ios_launch = (
        ROOT
        / "mobile"
        / "ios"
        / "Runner"
        / "Assets.xcassets"
        / "LaunchImage.imageset"
    )
    for filename, size in {
        "LaunchImage.png": 168,
        "LaunchImage@2x.png": 336,
        "LaunchImage@3x.png": 504,
    }.items():
        save_square(source, ios_launch / filename, size)

    print("Generated VoltMapEV Android and iOS icon assets.")


if __name__ == "__main__":
    main()
