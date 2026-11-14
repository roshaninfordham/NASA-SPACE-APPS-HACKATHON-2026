#!/usr/bin/env python3
"""Build an isolated Android APK; never publish or enable mobile self-updates."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ENGINE = "4.6.3"
BRAND = json.loads((ROOT / "game/data/brand.json").read_text())
PRODUCTION_ID = "io.github.roshaninfordham.redveil"
INTERNAL_ID = PRODUCTION_ID + ".internal"


def run(arguments, env=None, redact=()):
    result = subprocess.run([str(value) for value in arguments], cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = result.stdout
    for value in redact:
        if value:
            output = output.replace(value, "[redacted]")
    if result.returncode or "SCRIPT ERROR:" in output or "\nERROR:" in output:
        raise ValueError(output[-8000:])
    return output


def config_string(value):
    return json.dumps(str(value), ensure_ascii=False)


def configure_preset(template, version, code, release):
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-alpha\.\d+)?", version):
        raise ValueError("Invalid game version")
    if not 1 <= code <= 2100000000:
        raise ValueError("Android version code must be 1..2100000000 and increase for every upgrade")
    package = PRODUCTION_ID if release else INTERNAL_ID
    name = BRAND["display_name"] if release else BRAND["display_name"] + " Internal Test"
    values = {"version/code": str(code), "version/name": config_string(version if release else version + "-internal"), "package/unique_name": config_string(package), "package/name": config_string(name)}
    for field, value in values.items():
        template, count = re.subn(r"^" + re.escape(field) + r"=.*$", lambda _: field + "=" + value, template, flags=re.MULTILINE)
        if count != 1:
            raise ValueError(f"Android preset must define {field} exactly once")
    return template


def source_project(destination, revision):
    raw = subprocess.check_output(["git", "archive", "--format=zip", revision, "game"], cwd=ROOT)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        for member in archive.infolist():
            path = PurePosixPath(member.filename)
            if path.is_absolute() or ".." in path.parts or not path.parts or path.parts[0] != "game":
                raise ValueError("Unexpected source archive path")
        archive.extractall(destination)
    return destination / "game"


def signed_identity(apksigner, apk, env):
    output = run([apksigner, "verify", "--verbose", "--print-certs", apk], env=env)
    match = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)", output)
    if not match or len(match[1]) != 64:
        raise ValueError("APK signature certificate was not verified")
    return match[1].lower()


def verify_certificate_identity(actual, expected):
    normalized = expected.replace(":", "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", normalized):
        raise ValueError("Release APK requires the approved Android certificate SHA-256 fingerprint")
    if actual != normalized:
        raise ValueError("APK signer differs from the approved Android app identity; refusing this build")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", required=True, type=Path)
    parser.add_argument("--java-home", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--release", action="store_true", help="Require a stable owner keystore; never generates one")
    parser.add_argument("--keystore", type=Path)
    parser.add_argument("--alias", default="red-veil")
    parser.add_argument("--expected-certificate-sha256", default="")
    parser.add_argument("--templates", type=Path, default=Path.home() / ".local/share/godot/export_templates" / f"{ENGINE}.stable")
    args = parser.parse_args()
    os.umask(0o077)
    try:
        sdk, java = args.sdk_root.expanduser().resolve(), args.java_home.expanduser().resolve()
        for tool in [sdk / "platform-tools/adb", sdk / "build-tools/35.0.1/apksigner", sdk / "build-tools/35.0.1/zipalign", java / "bin/java", java / "bin/keytool"]:
            if not tool.is_file():
                raise ValueError(f"Required build tool is missing: {tool}")
        source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
        if args.release and dirty:
            raise ValueError("Production APK builds require a clean committed checkout")
        password = os.environ.get("RED_VEIL_ANDROID_KEYSTORE_PASSWORD", "")
        if args.release:
            if not re.fullmatch(r"[0-9a-fA-F:]{64,95}", args.expected_certificate_sha256):
                raise ValueError("Release APK requires --expected-certificate-sha256 from the approved Android app certificate")
            if not args.keystore or not password:
                raise ValueError("Release APK requires --keystore and RED_VEIL_ANDROID_KEYSTORE_PASSWORD")
            keystore = args.keystore.expanduser().resolve()
            if keystore.is_relative_to(ROOT) or not keystore.is_file():
                raise ValueError("Release keystore must exist outside the repository")
        output = args.output.expanduser().resolve()
        output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="red-veil-android-build-") as temporary:
            work = Path(temporary)
            project = source_project(work, source)
            version = re.search(r'^config/version="([^"]+)"$', (project / "project.godot").read_text(), re.MULTILINE)
            if not version:
                raise ValueError("Game source has no explicit version")
            version = version[1]
            preset = configure_preset((ROOT / "game/export_presets.android.cfg").read_text(), version, args.version_code, args.release)
            (project / "export_presets.cfg").write_text(preset)
            data, config = work / "data", work / "config"
            templates = data / "godot/export_templates" / f"{ENGINE}.stable"
            templates.mkdir(parents=True)
            for name in ["android_debug.apk", "android_release.apk"]:
                path = args.templates.expanduser().resolve() / name
                if not path.is_file():
                    raise ValueError("Install verified Godot export templates before Android export")
                (templates / name).symlink_to(path)
            settings = config / "godot/editor_settings-4.6.tres"
            settings.parent.mkdir(parents=True)
            settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = ' + config_string(sdk) + '\nexport/android/java_sdk_path = ' + config_string(java) + '\n')
            env = os.environ.copy()
            env.pop("RED_VEIL_ANDROID_KEYSTORE_PASSWORD", None)
            env.pop("RED_VEIL_ANDROID_KEYSTORE_BASE64", None)
            env.update({"XDG_DATA_HOME": str(data), "XDG_CONFIG_HOME": str(config), "JAVA_HOME": str(java), "ANDROID_HOME": str(sdk)})
            if args.release:
                env.update({"GODOT_ANDROID_KEYSTORE_RELEASE_PATH": str(keystore), "GODOT_ANDROID_KEYSTORE_RELEASE_USER": args.alias, "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": password})
            else:
                keystore = work / "internal-test.keystore"
                run([java / "bin/keytool", "-genkeypair", "-keystore", keystore, "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey", "-keyalg", "RSA", "-keysize", "3072", "-validity", "30", "-dname", "CN=KOMAKU Internal Test,O=Team Roshan Xingbo,C=US"], env=env)
                env.update({"GODOT_ANDROID_KEYSTORE_DEBUG_PATH": str(keystore), "GODOT_ANDROID_KEYSTORE_DEBUG_USER": "androiddebugkey", "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD": "android"})
            run(["godot", "--headless", "--path", project, "--editor", "--import"], env=env, redact=[password])
            apk = output / (f"{BRAND['package_stem']}-{version}-Android-arm64.apk" if args.release else f"{BRAND['package_stem']}-{version}-INTERNAL-Android-arm64.apk")
            run(["godot", "--headless", "--path", project, "--export-release" if args.release else "--export-debug", "Android", apk], env=env, redact=[password])
            fingerprint = signed_identity(sdk / "build-tools/35.0.1/apksigner", apk, env)
            if args.release:
                try:
                    verify_certificate_identity(fingerprint, args.expected_certificate_sha256)
                except ValueError:
                    apk.unlink(missing_ok=True)
                    raise
            badging = run([sdk / "build-tools/35.0.1/aapt", "dump", "badging", apk], env=env)
            package_id = PRODUCTION_ID if args.release else INTERNAL_ID
            if f"name='{package_id}'" not in badging or f"versionCode='{args.version_code}'" not in badging or "native-code: 'arm64-v8a'" not in badging:
                raise ValueError("APK package identity, version code, or ABI differs from requested export")
            with apk.open("rb") as file:
                digest = hashlib.file_digest(file, "sha256").hexdigest()
            manifest = {"version": version, "version_code": args.version_code, "package": package_id, "source_commit": source, "build_tools_working_tree_dirty": dirty, "engine": ENGINE, "min_sdk": int(re.search(r"sdkVersion:\s*'([0-9]+)'", badging)[1]), "target_sdk": int(re.search(r"targetSdkVersion:\s*'([0-9]+)'", badging)[1]), "artifact": apk.name, "bytes": apk.stat().st_size, "sha256": digest, "certificate_sha256": fingerprint, "internal_only": not args.release, "verified": ["APK export", "APK signature", "package identity", "version code", "arm64 ABI"], "not_verified": ["physical Android launch", "touch usability", "frame pacing", "APK upgrade over prior signed build", "in-app installation", "Android developer verification eligibility"], "updater": "Desktop content updater remains disabled on Android; this build does not add APK installation logic."}
            (output / "android-build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            (output / "SHA256SUMS-Android.txt").write_text(f"{digest}  {apk.name}\n")
            print(json.dumps(manifest, indent=2))
            if not args.release:
                print("INTERNAL TEST ONLY: disposable signing key; do not publish as a stable install/update identity.")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
