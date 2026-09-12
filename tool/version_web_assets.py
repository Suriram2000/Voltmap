"""Give each web release unique JS URLs so returning clients receive updates."""
import hashlib
from pathlib import Path


def version_assets(root: Path) -> None:
    main = root / "main.dart.js"
    bootstrap = root / "flutter_bootstrap.js"
    index = root / "index.html"
    main_bytes = main.read_bytes()
    main_name = f"main.{hashlib.sha256(main_bytes).hexdigest()[:16]}.dart.js"
    bootstrap_text = bootstrap.read_text(encoding="utf-8")
    index_text = index.read_text(encoding="utf-8")
    if "main.dart.js" not in bootstrap_text or 'src="flutter_bootstrap.js"' not in index_text:
        raise ValueError("Flutter web entry points changed; inspect before publishing")
    bootstrap_bytes = bootstrap_text.replace("main.dart.js", main_name).encode("utf-8")
    bootstrap_name = f"flutter_bootstrap.{hashlib.sha256(bootstrap_bytes).hexdigest()[:16]}.js"
    (root / main_name).write_bytes(main_bytes)
    (root / bootstrap_name).write_bytes(bootstrap_bytes)
    # Keep the original paths for clients that still have an older index page.
    bootstrap.write_bytes(bootstrap_bytes)
    index.write_text(index_text.replace('src="flutter_bootstrap.js"',
                                       f'src="{bootstrap_name}"'), encoding="utf-8")
    print(f"Versioned web entry points: {bootstrap_name}, {main_name}")


if __name__ == "__main__":
    version_assets(Path("mobile/build/web"))
