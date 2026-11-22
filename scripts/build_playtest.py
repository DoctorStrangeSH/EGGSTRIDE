"""Verify EGGSTRIDE and package the Roblox Studio playtest."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "default.project.json"
BUNDLE_NAME = "EGGSTRIDE-Playtest.zip"
PLACE_NAME = "EGGSTRIDE-Playtest.rbxl"


def run(*command):
    subprocess.run(command, cwd=ROOT, check=True)


def mapped_sources(node):
    yield from node.get("filePaths", [])
    for child in node.get("children", []):
        yield from mapped_sources(child)


def build(output):
    output.mkdir(parents=True, exist_ok=True)
    runnable_tests = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "tests").glob("*.luau"))
    sources = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "src").rglob("*.luau"))
    if not runnable_tests or not sources:
        raise RuntimeError("Missing Luau source or test files")
    run("luau", *runnable_tests)
    run("luau-compile", "--null", *sources)

    with tempfile.TemporaryDirectory(dir=output) as staging:
        work = Path(staging)
        sourcemap = work / "sourcemap.json"
        place = work / PLACE_NAME
        run("rojo", "sourcemap", str(PROJECT), "-o", str(sourcemap))
        mapped = {Path(path).as_posix() for path in mapped_sources(json.loads(sourcemap.read_text(encoding="utf-8")))}
        missing = set(sources) - mapped
        if missing:
            raise RuntimeError("Luau scripts missing from the Rojo project: " + ", ".join(sorted(missing)))
        run("rojo", "build", str(PROJECT), "-o", str(place))

        packaged = work / BUNDLE_NAME
        with ZipFile(packaged, "w", compression=ZIP_DEFLATED) as archive:
            archive.write(place, PLACE_NAME)
            for path in [ROOT / "README.md", ROOT / "ROADMAP.md", *sorted((ROOT / "docs").glob("*.md"))]:
                archive.write(path, path.relative_to(ROOT).as_posix())
        with ZipFile(packaged) as archive:
            if archive.testzip() is not None:
                raise RuntimeError("Playtest archive verification failed")
        packaged.replace(output / BUNDLE_NAME)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    build(args.output.resolve())
    print(args.output.resolve() / BUNDLE_NAME)
