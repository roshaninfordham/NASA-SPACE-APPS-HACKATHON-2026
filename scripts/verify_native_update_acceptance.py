#!/usr/bin/env python3
"""Validate actual signed release bytes through an exported Linux update fixture.

This is an acceptance test, not a production runtime hook. It archives the exact
release source into a disposable project, changes only its baseline version/name
and main-scene wrapper, and exports a native Linux executable. An overridden
transport supplies already-downloaded artifacts at the client's fixed GitHub
URLs; signature, compatibility, staging, activation, mounting and health logic
remain production code. Default restart checks are orchestrated by this script,
so that mode does not validate OS.create_instance, real network transfer, desktop
rendering, a previously shipped installer, or Mac/Windows behavior. Optional
--gui-restart additionally exercises real OS.create_instance under authenticated
Xvfb on Linux; it still does not validate physical GPUs or other platforms.
--live-release replaces the artifact transport with the production HTTPRequest
implementation against fixed GitHub URLs. Only the disposable fixture applies
managed-environment proxy and verified CA settings; TLS verification stays on.

The artificially older baseline uses the target source, so it does not prove
compatibility with historical script-class/UID registries. Future release gates
should additionally test the actual previously shipped installer. This harness
deliberately does not offer a baseline-installer mode until that path is designed.

Example (requires Godot 4.6.3 and its Linux export template, OpenSSL and Git):
    python3 scripts/verify_native_update_acceptance.py \
        --artifacts /tmp/red-veil-downloads --expected-commit <40-hex-commit>
"""
import argparse
from contextlib import contextmanager
import hashlib
import io
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import subprocess
import tarfile
import tempfile
import time
import zipfile
from urllib.parse import urlsplit

from branding import archive_name, supplemental_asset_names

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
ENGINE = "4.6.3"
RUNTIME_CONTRACT = "red-veil-desktop-v1"
VERSION = re.compile(r"(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(?:-alpha\.(0|[1-9][0-9]{0,8}))?")
UPDATE_NAMES = {"update-manifest.json", "update-manifest.sig", "red-veil-content.pck"}


def run(*arguments, cwd=None, env=None, timeout=180):
    result = subprocess.run(arguments, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "\nERROR:" in result.stdout:
        raise ValueError(f"Command failed: {arguments[0]}\n{result.stdout[-12000:]}")
    return result.stdout


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def previous_version(target):
    match = VERSION.fullmatch(target)
    if match is None:
        raise ValueError("Unsupported release version")
    major, minor, patch = map(int, match.group(1, 2, 3))
    alpha = match.group(4)
    if alpha is None:
        return f"{major}.{minor}.{patch}-alpha.0"
    if int(alpha) > 0:
        return f"{major}.{minor}.{patch}-alpha.{int(alpha) - 1}"
    if patch > 0:
        return f"{major}.{minor}.{patch - 1}"
    if minor > 0:
        return f"{major}.{minor - 1}.0"
    if major > 0:
        return f"{major - 1}.0.0"
    raise ValueError("Cannot derive an older supported fixture version")


def validate_artifacts(folder, expected_commit):
    if not re.fullmatch(r"[0-9a-f]{40}", expected_commit):
        raise ValueError("An exact expected source commit is required")
    release_path = folder / "release-manifest.json"
    if release_path.stat().st_size > 65536:
        raise ValueError("Release manifest is unexpectedly large")
    release = json.loads(release_path.read_text())
    version = release.get("version", "")
    if not isinstance(version, str) or VERSION.fullmatch(version) is None:
        raise ValueError("Invalid release version")
    if release.get("commit") != expected_commit or release.get("signed_content_updates") is not True:
        raise ValueError("Artifacts are not the expected signed source build")
    if release.get("engine") != "Godot " + ENGINE:
        raise ValueError("Unexpected release engine")
    expected = {archive_name(version, platform) for platform in ["macOS-universal", "Windows-x64", "Linux-x64", "Web"]} | UPDATE_NAMES | supplemental_asset_names(version)
    entries = release.get("assets")
    if not isinstance(entries, list) or len(entries) != len(expected):
        raise ValueError("Unexpected release asset list")
    names = [entry.get("name") for entry in entries if isinstance(entry, dict)]
    if len(names) != len(expected) or set(names) != expected:
        raise ValueError("Missing, duplicate, or unexpected release assets")
    expected_checksums = []
    for entry in entries:
        path = folder / entry["name"]
        if path.is_symlink() or not path.is_file() or path.stat().st_size != entry.get("bytes") or digest(path) != entry.get("sha256"):
            raise ValueError("Release artifact size/hash mismatch: " + entry["name"])
        expected_checksums.append(f"{entry['sha256']}  {entry['name']}")
        if path.suffix == ".zip":
            with zipfile.ZipFile(path) as archive:
                if archive.testzip() is not None:
                    raise ValueError("Corrupt archive: " + path.name)
    checksums = (folder / "SHA256SUMS.txt").read_text().splitlines()
    if len(checksums) != len(expected_checksums) or set(checksums) != set(expected_checksums):
        raise ValueError("Checksum file does not match the release manifest")
    return release


def source_fixture(workspace, commit):
    output = subprocess.check_output(["git", "archive", "--format=tar", commit, "game"], cwd=ROOT)
    source = workspace / "source"
    source.mkdir()
    with tarfile.open(fileobj=io.BytesIO(output), mode="r:") as archive:
        for member in archive.getmembers():
            path = Path(member.name)
            if path.is_absolute() or ".." in path.parts or path.parts[0] != "game" or not (member.isfile() or member.isdir()):
                raise ValueError("Unexpected entry in source archive")
        archive.extractall(source, filter="data")
    return source / "game"


def verify_signature(folder, public_key, release):
    raw = folder / "update-manifest.json"
    signature = folder / "update-manifest.sig"
    if not 0 < raw.stat().st_size <= 32768 or not 256 <= signature.stat().st_size <= 1024:
        raise ValueError("Invalid signed manifest/signature size")
    run("openssl", "dgst", "-sha256", "-verify", str(public_key), "-signature", str(signature), str(raw))
    manifest = json.loads(raw.read_text())
    pack = folder / "red-veil-content.pck"
    expected = {"schema": 1, "repository": REPOSITORY, "version": release["version"], "engine": ENGINE, "runtime_contract": RUNTIME_CONTRACT, "pack_file": pack.name, "pack_bytes": pack.stat().st_size, "pack_sha256": digest(pack), "source_commit": release["commit"]}
    if manifest != expected or not 0 < manifest["pack_bytes"] <= 128 * 1024 * 1024:
        raise ValueError("Signed update manifest does not match the exact release")
    return manifest


def write_transport(project, folder, version, live_release=False):
    scene = project / "main.tscn"
    content = scene.read_text()
    entries = [name for name in ("res://scripts/game.gd", "res://scripts/journey_game.gd") if f'path="{name}"' in content]
    if len(entries) != 1:
        raise ValueError("Source main scene contract changed; review acceptance wrapper")
    entry = entries[0]
    journey = entry == "res://scripts/journey_game.gd"
    metadata = [{"draft": False, "prerelease": "-alpha." in version, "tag_name": "v" + version, "assets": [{"name": name, "browser_download_url": f"https://github.com/{REPOSITORY}/releases/download/v{version}/{name}"} for name in sorted(UPDATE_NAMES)]}]
    (project / "acceptance_transport.gd").write_text('''extends "res://updater/client.gd"
# Test transport exists only in a disposable fixture export, never in the game.
const ARTIFACT_DIRECTORY = __DIRECTORY__
const TARGET_VERSION = __VERSION__
const METADATA_JSON = __METADATA__
const LIVE_RELEASE = __LIVE__
var requests: Array[String] = []
func _ready() -> void:
    if LIVE_RELEASE: child_entered_tree.connect(_configure_live_request)
func _configure_live_request(child: Node) -> void:
    if not child is HTTPRequest: return
    var proxy := OS.get_environment("RED_VEIL_PROXY_HOST")
    if not proxy.is_empty():
        var port := int(OS.get_environment("RED_VEIL_PROXY_PORT"))
        child.set_http_proxy(proxy, port)
        child.set_https_proxy(proxy, port)
    var ca_path := OS.get_environment("RED_VEIL_NETWORK_CA")
    if not ca_path.is_empty():
        var certificate := X509Certificate.new()
        if certificate.load(ca_path) != OK:
            push_error("Fixture could not load the explicitly trusted CA bundle")
            get_tree().quit(1)
            return
        child.set_tls_options(TLSOptions.client(certificate))
func _fetch(url: String, limit: int, download_path: String = "") -> Dictionary:
    await get_tree().process_frame
    requests.append(url)
    if LIVE_RELEASE:
        var allowed := [RELEASES_URL]
        for filename in ["update-manifest.json", "update-manifest.sig", "red-veil-content.pck"]:
            allowed.append(Verifier.asset_url(TARGET_VERSION, filename))
        if url not in allowed: return {"ok": false, "error": "unexpected_live_release"}
        var response: Dictionary = await super._fetch(url, limit, download_path)
        var size := 0
        if download_path.is_empty(): size = response.get("body", PackedByteArray()).size()
        elif FileAccess.file_exists(download_path):
            var file := FileAccess.open(download_path, FileAccess.READ)
            if file: size = file.get_length()
        print("ACCEPTANCE_LIVE_RESPONSE=", JSON.stringify({"url": url, "ok": response.get("ok", false), "code": response.get("code", 0), "bytes": size}))
        return response
    if url == RELEASES_URL:
        var bytes := METADATA_JSON.to_utf8_buffer()
        return {"ok": bytes.size() <= limit and download_path.is_empty(), "body": bytes}
    for filename in ["update-manifest.json", "update-manifest.sig", "red-veil-content.pck"]:
        if url != Verifier.asset_url(TARGET_VERSION, filename): continue
        var source := ARTIFACT_DIRECTORY.path_join(filename)
        var file := FileAccess.open(source, FileAccess.READ)
        if file == null or file.get_length() > limit: return {"ok": false, "error": "fixture_size"}
        if not download_path.is_empty():
            file.close()
            if filename != "red-veil-content.pck": return {"ok": false, "error": "fixture_path"}
            return {"ok": DirAccess.copy_absolute(source, download_path) == OK, "body": PackedByteArray()}
        if filename == "red-veil-content.pck": return {"ok": false, "error": "fixture_path"}
        return {"ok": true, "body": file.get_buffer(file.get_length())}
    return {"ok": false, "error": "unexpected_fixture_url"}
'''.replace("__DIRECTORY__", json.dumps(str(folder))).replace("__VERSION__", json.dumps(version)).replace("__METADATA__", json.dumps(json.dumps(metadata))).replace("__LIVE__", "true" if live_release else "false"))
    (project / "acceptance_main.gd").write_text('''extends "__ENTRY__"
const FixtureClient = preload("res://acceptance_transport.gd")
func _ready() -> void:
    var bootstrap := get_node("/root/Updates")
    print("ACCEPTANCE_FIXTURE_WRAPPER=", bootstrap.running_version)
    print("ACCEPTANCE_FIXTURE_NOTICE=", bootstrap.startup_notice)
__BEFORE_READY__    await super._ready()
    if "--smoke-test" in OS.get_cmdline_user_args(): return
__SAFE_MENU__
    if is_instance_valid(update_client):
        update_client.get_parent().remove_child(update_client)
        update_client.queue_free()
    var client := FixtureClient.new()
    client.name = "Client"
    client.configure(bootstrap.store, bootstrap.running_version, "user://updates/acceptance-incoming")
    bootstrap.add_child(client)
    update_client = client
    client.changed.connect(__REFRESH__)
    await client.check_for_updates(true)
    if not client.can_install() or client.available_version != FixtureClient.TARGET_VERSION:
        push_error("Fixture did not discover an installable signed update: " + client.message)
        get_tree().quit(1)
        return
    await get_tree().process_frame
    await get_tree().process_frame
    if not (__NOTIFICATION__):
        push_error("Fixture discovered an update without showing the game notification")
        get_tree().quit(1)
        return
    await client.install_update()
    if not client.ready_to_restart or client.status != "ready" or client.requests.size() != 4:
        push_error("Fixture failed to activate the exact release: " + client.message)
        get_tree().quit(1)
        return
    print("ACCEPTANCE_INSTALL_READY=", client.available_version)
    print("ACCEPTANCE_USER_DIR=", OS.get_user_data_dir())
    print("ACCEPTANCE_REQUESTS=", JSON.stringify(client.requests))
    if OS.get_environment("RED_VEIL_ACCEPTANCE_GUI_RESTART") == "1":
        if not client.restart_game():
            push_error("Actual native restart could not be started: " + client.message)
            get_tree().quit(1)
            return
        print("ACCEPTANCE_REAL_RESTART=true")
        return
    get_tree().quit()
'''.replace("__ENTRY__", entry)
        .replace("__BEFORE_READY__", "    online_sources_enabled = false\n" if journey else "")
        .replace("__SAFE_MENU__", "    show_preparation()\n" if journey else "")
        .replace("__REFRESH__", "_refresh_updates" if journey else "refresh_update_notice")
        .replace("__NOTIFICATION__", 'is_instance_valid(modal) and modal_kind == "update-offer"' if journey else "update_notice.visible"))
    scene.write_text(content.replace(f'path="{entry}"', 'path="res://acceptance_main.gd"'))


@contextmanager
def workspace_at(keep):
    if keep:
        path = keep.expanduser().resolve()
        if path.is_relative_to(ROOT):
            raise ValueError("Acceptance workspace must be outside the repository")
        path.mkdir(parents=True, exist_ok=False)
        yield path
    else:
        with tempfile.TemporaryDirectory(prefix="red-veil-native-update-") as temporary:
            yield Path(temporary)



def owned_processes(binary, marker):
    """Find only this fixture's processes, checking executable and unique environment."""
    found = {}
    expected = binary.resolve()
    identity = ("RED_VEIL_ACCEPTANCE_RUN=" + marker).encode()
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if (entry / "exe").resolve(strict=True) != expected:
                continue
            if identity not in (entry / "environ").read_bytes().split(b"\0"):
                continue
            # Start ticks distinguish a recorded process from later PID reuse.
            fields = (entry / "stat").read_text().rsplit(") ", 1)[1].split()
            found[int(entry.name)] = fields[19]
        except (OSError, IndexError):
            continue
    return found


def terminate_owned(binary, marker):
    recorded = owned_processes(binary, marker)
    for sig, timeout in ((signal.SIGTERM, 5), (signal.SIGKILL, 2)):
        current = owned_processes(binary, marker)
        for pid, started in recorded.items():
            if current.get(pid) == started:
                try:
                    os.kill(pid, sig)
                except ProcessLookupError:
                    pass
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline and owned_processes(binary, marker):
            time.sleep(0.05)
        if not owned_processes(binary, marker):
            return
    raise ValueError("An owned acceptance process could not be stopped")


@contextmanager
def private_display(workspace, executable, base_env):
    xvfb = str(executable.expanduser().resolve()) if executable else shutil.which("Xvfb")
    xauth = shutil.which("xauth")
    if not xvfb or not Path(xvfb).is_file() or not xauth:
        raise ValueError("--gui-restart requires Xvfb and xauth; pass --xvfb for a user-local installation")
    folder = workspace / "private-display"
    folder.mkdir(mode=0o700)
    authority = folder / "Xauthority"
    authority.touch(mode=0o600)
    runtime = folder / "runtime"
    runtime.mkdir(mode=0o700)
    audio = folder / "asound.conf"
    audio.write_text("pcm.!default { type null }\n")
    process = None
    log = (workspace / "logs/xvfb.log").open("ab")
    try:
        for attempt in range(10):
            display = secrets.randbelow(900) + 100
            socket = Path(f"/tmp/.X11-unix/X{display}")
            if socket.exists() or Path(f"/tmp/.X{display}-lock").exists():
                continue
            run(xauth, "-f", str(authority), "add", f":{display}", ".", secrets.token_hex(16), env=base_env)
            process = subprocess.Popen([xvfb, f":{display}", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-auth", str(authority), "-noreset", "-fp", "built-ins"], stdout=log, stderr=subprocess.STDOUT, start_new_session=True, env=base_env)
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline and process.poll() is None and not socket.exists():
                time.sleep(0.05)
            if process.poll() is None and socket.exists():
                env = base_env | {"DISPLAY": f":{display}", "XAUTHORITY": str(authority), "XDG_RUNTIME_DIR": str(runtime), "LIBGL_ALWAYS_SOFTWARE": "1", "ALSA_CONFIG_PATH": str(audio)}
                yield env
                return
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=5)
            process = None
        raise ValueError("Could not start a private authenticated Xvfb display; see xvfb.log")
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        log.close()


def verify_gui_restart(workspace, binary, headless_user_dir, version, base_env, xvfb, live_release=False):
    """Exercise the actual restart method without changing signed game content."""
    marker = secrets.token_hex(16)
    gui_data = workspace / "gui-userdata"
    relative_profile = headless_user_dir.relative_to(workspace / "userdata")
    profile = gui_data / relative_profile
    # Suppress unrelated automatic background checks using the ordinary cached
    # check timestamp. The fixture's explicit update uses its own transport/cache.
    checked = profile / "updates/incoming/last-check.json"
    checked.parent.mkdir(parents=True)
    checked.write_text(json.dumps({"checked_at": int(time.time())}))
    journal_path = profile / "updates/state.json"
    env = base_env | {"XDG_DATA_HOME": str(gui_data), "RED_VEIL_ACCEPTANCE_RUN": marker, "RED_VEIL_ACCEPTANCE_GUI_RESTART": "1"}
    log_path = workspace / "logs/actual-gui-restart.log"
    parent = None
    restarted = None
    with private_display(workspace, xvfb, env) as display_env:
        try:
            with log_path.open("w") as log:
                parent = subprocess.Popen([str(binary)], cwd=workspace, env=display_env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                deadline = time.monotonic() + (420 if live_release else 90)
                stable_since = None
                while time.monotonic() < deadline:
                    code = parent.poll()
                    if code is not None and code != 0:
                        raise ValueError("GUI baseline fixture failed; see actual-gui-restart.log")
                    processes = owned_processes(binary, marker)
                    children = [pid for pid in processes if pid != parent.pid]
                    try:
                        journal = json.loads(journal_path.read_text())
                    except (OSError, json.JSONDecodeError):
                        journal = {}
                    healthy = journal.get("active") == version and journal.get("status") == "healthy" and journal.get("pid") == 0 and not journal.get("token")
                    if code == 0 and len(children) == 1 and healthy:
                        restarted = children[0]
                        command = Path(f"/proc/{restarted}/cmdline").read_bytes().split(b"\0")
                        if b"--headless" in command or b"--smoke-test" in command:
                            raise ValueError("Native automatic restart unexpectedly inherited headless/test flags")
                        stable_since = time.monotonic() if stable_since is None else stable_since
                        if time.monotonic() - stable_since >= 3:
                            break
                    else:
                        stable_since = None
                    time.sleep(0.1)
                else:
                    raise ValueError("Native GUI restart did not reach a stable healthy new process; see actual-gui-restart.log")
            output = log_path.read_text()
            if "SCRIPT ERROR:" in output or "ACCEPTANCE_REAL_RESTART=true" not in output or output.count("ACCEPTANCE_FIXTURE_WRAPPER=") != 1 or "OpenGL" not in output:
                raise ValueError("GUI restart evidence is incomplete or contains a script error; see actual-gui-restart.log")
            print("PASS: actual-OS-create-instance-GUI-restart", flush=True)
            diagnostics = sorted(set(line for line in output.splitlines() if line.startswith("WARNING:")))
            diagnostics.extend("Xvfb: " + line for line in (workspace / "logs/xvfb.log").read_text().splitlines() if "ERROR:" in line)
            renderer = next((line for line in output.splitlines() if line.startswith("OpenGL API")), "OpenGL startup logged")
            return {"status": "passed", "backend": "X11 on authenticated Xvfb", "renderer": renderer, "diagnostics": diagnostics[:20], "original_pid": parent.pid, "restarted_pid": restarted, "new_version": version, "health": "new process remained alive with healthy activation journal for three seconds", "scope": "Linux only; exact signed production pack; no production test hooks; " + ("live GitHub transfer with fixture network configuration" if live_release else "local artifact update transport")}
        finally:
            terminate_owned(binary, marker)
            if parent is not None:
                parent.wait(timeout=5)



def live_network_environment():
    """Expose no proxy credentials and never weaken certificate verification."""
    environment = {"RED_VEIL_PROXY_HOST": "", "RED_VEIL_PROXY_PORT": "0", "RED_VEIL_NETWORK_CA": ""}
    proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy") or ""
    if proxy:
        parsed = urlsplit(proxy)
        if parsed.scheme != "http" or not parsed.hostname or parsed.username is not None or parsed.password is not None or parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
            raise ValueError("Live fixture supports only an HTTP CONNECT proxy without embedded credentials")
        environment["RED_VEIL_PROXY_HOST"] = parsed.hostname
        environment["RED_VEIL_PROXY_PORT"] = str(parsed.port or 80)
    certificate = os.environ.get("SSL_CERT_FILE") or os.environ.get("REQUESTS_CA_BUNDLE") or ""
    if certificate:
        path = Path(certificate).expanduser().resolve()
        if not path.is_file():
            raise ValueError("Configured live-fixture CA bundle is unavailable")
        environment["RED_VEIL_NETWORK_CA"] = str(path)
    return environment


def accept(args):
    if os.name != "posix" or not Path("/proc").is_dir():
        raise ValueError("This acceptance harness currently requires Linux")
    artifacts = args.artifacts.expanduser().resolve()
    release = validate_artifacts(artifacts, args.expected_commit)
    version = release["version"]
    baseline = previous_version(version)
    installed_engine = run("godot", "--version").strip()
    if not installed_engine.startswith(ENGINE + "."):
        raise ValueError("The fixture exporter must match the release engine")
    with workspace_at(args.keep_workspace) as workspace:
        project = source_fixture(workspace, args.expected_commit)
        public_key = project / "updater/public_key.pem"
        if args.public_key:
            expected = run("openssl", "pkey", "-pubin", "-in", str(public_key), "-pubout")
            supplied = run("openssl", "pkey", "-pubin", "-in", str(args.public_key), "-pubout")
            if supplied != expected:
                raise ValueError("Supplied public key differs from the exact source trust root")
        manifest = verify_signature(artifacts, public_key, release)
        settings = project / "project.godot"
        content = settings.read_text()
        if f'config/version="{version}"' not in content:
            raise ValueError("Exact release source has a different application version")
        content = content.replace(f'config/version="{version}"', f'config/version="{baseline}"')
        content = re.sub(r'^config/name="[^"]*"$', 'config/name="Red Veil Native Update Acceptance"', content, flags=re.MULTILINE)
        settings.write_text(content)
        write_transport(project, artifacts, version, args.live_release)
        # Isolate runtime/editor data while reusing the already verified, read-only
        # engine templates. Godot resolves template locations through XDG_DATA_HOME.
        candidates = [Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))), Path.home() / ".local/share"]
        templates = next((base / "godot/export_templates" / (ENGINE + ".stable") for base in candidates if (base / "godot/export_templates" / (ENGINE + ".stable") / "linux_release.x86_64").is_file()), None)
        if templates is None:
            raise ValueError("Godot Linux export templates are not installed in the current/default data directory")
        isolated_templates = workspace / "userdata/godot/export_templates" / (ENGINE + ".stable")
        isolated_templates.mkdir(parents=True)
        for name in ("linux_debug.x86_64", "linux_release.x86_64"):
            source = templates / name
            if not source.is_file():
                raise ValueError("Missing Linux export template: " + name)
            (isolated_templates / name).symlink_to(source.resolve())
        env = {key: value for key, value in os.environ.items() if key not in {"GH_TOKEN", "GITHUB_TOKEN", "RED_VEIL_UPDATE_SIGNING_KEY"}} | {"XDG_DATA_HOME": str(workspace / "userdata")}
        if args.live_release: env.update(live_network_environment())
        (workspace / "logs").mkdir()

        def phase(name, *command, timeout=180):
            output = run(*command, cwd=workspace, env=env, timeout=timeout)
            (workspace / "logs" / f"{name}.log").write_text(output)
            print("PASS:", name, flush=True)
            return output

        phase("import-disposable-exact-source", "godot", "--headless", "--path", str(project), "--editor", "--import")
        binary = workspace / "Red-Veil-Acceptance.x86_64"
        phase("export-real-Linux-baseline-fixture", "godot", "--headless", "--path", str(project), "--export-release", "Linux", str(binary))
        binary.chmod(0o755)
        first = phase("discover-verify-stage-and-activate", str(binary), "--headless", timeout=420 if args.live_release else 90)
        if f"ACCEPTANCE_INSTALL_READY={version}" not in first or f"ACCEPTANCE_FIXTURE_WRAPPER={baseline}" not in first:
            raise ValueError("Native fixture did not install the intended version")
        user_dir = Path(next(line.removeprefix("ACCEPTANCE_USER_DIR=") for line in first.splitlines() if line.startswith("ACCEPTANCE_USER_DIR=")))
        if not user_dir.resolve().is_relative_to(workspace):
            raise ValueError("Acceptance runtime escaped its isolated user-data directory")
        journal_path = user_dir / "updates/state.json"
        journal = json.loads(journal_path.read_text())
        if journal["status"] != "ready" or journal["active"] != version:
            raise ValueError("First run did not leave a ready activation record")
        for name in ("restart-mount-production-content-and-acknowledge", "repeat-healthy-production-start"):
            output = phase(name, str(binary), "--headless", "--", "--smoke-test", timeout=90)
            if f"RED_VEIL_SCENE_READY version={version} " not in output or "ACCEPTANCE_FIXTURE_WRAPPER=" in output:
                raise ValueError("Signed release did not replace the fixture main scene and run at the new version")
            journal = json.loads(journal_path.read_text())
            if journal["status"] != "healthy" or journal["active"] != version or journal["pid"] != 0 or journal["token"]:
                raise ValueError("Production game did not acknowledge its startup trial")
        installed_pack = user_dir / "updates/slots" / version / "red-veil-content.pck"
        if digest(installed_pack) != manifest["pack_sha256"]:
            raise ValueError("Activated content differs from the signed release")
        for name in UPDATE_NAMES:
            if digest(installed_pack.parent / name) != digest(artifacts / name):
                raise ValueError("Installed live/local update bytes differ from the independently verified artifact: " + name)
        with installed_pack.open("r+b") as pack:
            pack.seek(-1, os.SEEK_END)
            byte = pack.read(1)
            pack.seek(-1, os.SEEK_END)
            pack.write(bytes([byte[0] ^ 1]))
            pack.flush()
            os.fsync(pack.fileno())
        restored = phase("same-size-tampering-restores-bundled-fixture", str(binary), "--headless", "--", "--smoke-test", timeout=90)
        if f"RED_VEIL_SCENE_READY version={baseline} " not in restored or f"ACCEPTANCE_FIXTURE_WRAPPER={baseline}" not in restored or "could not be verified" not in restored:
            raise ValueError("Tampered content did not recover the previous bundled baseline")
        journal = json.loads(journal_path.read_text())
        if journal["status"] != "healthy" or journal["active"]:
            raise ValueError("Recovery left a pending/active invalid update")
        result = {"status": "passed", "platform": "Linux x64, headless", "baseline_version": baseline, "baseline_kind": "disposable exact-source fixture; not a previously shipped installer", "target_version": version, "source_commit": args.expected_commit, "runtime_contract": manifest["runtime_contract"], "pack_sha256": manifest["pack_sha256"], "transport": "fixed GitHub URL mapping to exact downloaded artifact bytes; no live HTTP transfer", "checks": ["all release artifact hashes and ZIP integrity", "real signature against exact-source installer key", "exported native update notification, discovery, signature verification, staging and activation", "production PCK replaces fixture main scene", "production startup health acknowledgment and persistent second boot", "same-size installed-pack tampering restores bundled baseline"], "not_verified": ["OS.create_instance automatic relaunch", "real HTTP download in this harness", "graphical rendering", "physical Mac or Windows", "upgrade from a previously shipped installer"]}
        if args.live_release:
            result["transport"] = "production HTTPRequest against fixed public GitHub URLs; fixture-only proxy/verified CA configuration"
            result["not_verified"].remove("real HTTP download in this harness")
            result["checks"].append("real GitHub metadata, signed manifest, signature and content download match independently verified artifacts")
            result["live_http_responses"] = [json.loads(line.removeprefix("ACCEPTANCE_LIVE_RESPONSE=")) for line in first.splitlines() if line.startswith("ACCEPTANCE_LIVE_RESPONSE=")]
            if len(result["live_http_responses"]) != 4 or any(not response["ok"] or response["code"] != 200 for response in result["live_http_responses"]):
                raise ValueError("Live transfer did not produce four successful production HTTP responses")
        if args.gui_restart:
            result["gui_restart"] = verify_gui_restart(workspace, binary, user_dir, version, env, args.xvfb, args.live_release)
            result["platform"] = "Linux x64, headless plus authenticated Xvfb"
            result["checks"].append("actual OS.create_instance relaunch into healthy production content under Xvfb")
            result["not_verified"] = [item for item in result["not_verified"] if item not in {"OS.create_instance automatic relaunch", "graphical rendering"}]
            result["not_verified"].extend(["physical GPU rendering and visual quality", "audio device behavior"])
        if args.keep_workspace:
            result["workspace"] = str(workspace)
            (workspace / "acceptance-result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, indent=2), flush=True)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--artifacts", required=True, type=Path, help="Flat downloaded release artifact directory")
    parser.add_argument("--expected-commit", required=True, help="Exact source commit expected in both manifests")
    parser.add_argument("--public-key", type=Path, help="Optional independently supplied public key, checked against exact source")
    parser.add_argument("--live-release", action="store_true", help="Use production HTTPRequest to download the exact public GitHub release")
    parser.add_argument("--gui-restart", action="store_true", help="Additionally test real native automatic relaunch under authenticated Xvfb")
    parser.add_argument("--xvfb", type=Path, help="Path to Xvfb for --gui-restart; defaults to PATH lookup")
    parser.add_argument("--keep-workspace", type=Path, help="Keep fixture exports/logs at this NEW path outside the repository")
    args = parser.parse_args()
    try:
        accept(args)
    except (ValueError, OSError, KeyError, StopIteration, subprocess.SubprocessError, tarfile.TarError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
