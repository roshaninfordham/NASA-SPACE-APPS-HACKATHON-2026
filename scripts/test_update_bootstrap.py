#!/usr/bin/env python3
"""Test signed content activation and recovery in disposable Godot projects."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def command(*args, cwd=None, env=None, allow_engine_error=False):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=40)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or (not allow_engine_error and "\nERROR:" in result.stdout):
        raise AssertionError(result.stdout)
    return result.stdout


def write_manifest(folder, key, version):
    pack = folder / "red-veil-content.pck"
    data = {"schema": 1, "repository": "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026", "version": version, "engine": "4.6.3", "runtime_contract": "red-veil-desktop-v1", "pack_file": pack.name, "pack_bytes": pack.stat().st_size, "pack_sha256": hashlib.sha256(pack.read_bytes()).hexdigest(), "source_commit": "a" * 40}
    manifest = folder / "update-manifest.json"
    manifest.write_text(json.dumps(data, sort_keys=True) + "\n")
    command("openssl", "dgst", "-sha256", "-sign", str(key), "-out", str(folder / "update-manifest.sig"), str(manifest))


def main():
    with tempfile.TemporaryDirectory(prefix="red-veil-boot-test-") as temporary:
        folder = Path(temporary)
        key = folder / "private.pem"
        command("openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072", "-out", str(key))
        command("openssl", "pkey", "-in", str(key), "-pubout", "-out", str(folder / "public.pem"))
        other_key = folder / "other-private.pem"
        command("openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072", "-out", str(other_key))
        command("openssl", "pkey", "-in", str(other_key), "-pubout", "-out", str(folder / "other-public.pem"))
        project = folder / "project"
        (project / "updater").mkdir(parents=True)
        (project / "tests").mkdir()
        for name in ("verifier.gd", "store.gd", "bootstrap.gd"):
            shutil.copyfile(ROOT / "game/updater" / name, project / "updater" / name)
        shutil.copyfile(folder / "public.pem", project / "updater/public_key.pem")
        shutil.copyfile(ROOT / "game/tests/update_store_test.gd", project / "tests/update_store_test.gd")
        (project / "project.godot").write_text('''config_version=5
[application]
config/name="RedVeilUpdateTest"
config/version="0.3.0-alpha.1"
config/use_custom_user_dir=true
config/custom_user_dir_name="red-veil-update-test"
run/main_scene="res://main.tscn"
[autoload]
Updates="*res://updater/bootstrap.gd"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
        (project / "marker.gd").write_text('extends RefCounted\nconst ID = "base"\n')
        (project / "main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Main" type="Node"]\nscript = ExtResource("1")\n')
        (project / "main.gd").write_text('''extends Node
const Marker = preload("res://marker.gd")
func _ready():
    print("BOOT_MARKER=", Marker.ID, " VERSION=", Updates.running_version)
    print("BOOT_NOTICE=", Updates.startup_notice)
    var mode = OS.get_environment("RED_VEIL_BOOT_TEST_MODE")
    if mode == "verify-followup":
        var folder = OS.get_environment("RED_VEIL_UPDATE_TEST_DIR").path_join("b")
        var result = Updates.store.validate_manifest(FileAccess.get_file_as_bytes(folder.path_join("update-manifest.json")), FileAccess.get_file_as_bytes(folder.path_join("update-manifest.sig")), Updates.running_version)
        print("PINNED_KEY_STILL_VALID=", result.ok)
    if mode != "no-ack": Updates.mark_healthy()
    get_tree().quit()
''')
        env = os.environ | {"XDG_DATA_HOME": str(folder / "userdata"), "RED_VEIL_UPDATE_TEST_DIR": str(folder)}
        for name, version in (("a", "0.3.1-alpha.1"), ("b", "0.3.2-alpha.1")):
            target = folder / name
            target.mkdir()
            (target / "future_helper.gd").write_text(f'class_name FutureHelper\nextends RefCounted\nconst ID = "{name}"\n')
            (target / "marker.gd").write_text('extends RefCounted\nconst Helper = preload("res://future_helper.gd")\nconst ID = Helper.ID\n')
            script = project / "make_pack.gd"
            script.write_text('extends SceneTree\nfunc _initialize():\n\tvar pack := PCKPacker.new()\n' +
                              f'\tassert(pack.pck_start({json.dumps(str(target / "red-veil-content.pck"))}) == OK)\n' +
                              f'\tassert(pack.add_file("res://marker.gd", {json.dumps(str(target / "marker.gd"))}) == OK)\n' +
                              f'\tassert(pack.add_file("res://future_helper.gd", {json.dumps(str(target / "future_helper.gd"))}) == OK)\n' +
                              f'\tassert(pack.add_file("res://updater/public_key.pem", {json.dumps(str(folder / "other-public.pem"))}) == OK)\n' +
                              '\tassert(pack.flush() == OK)\n\tquit()\n')
            command("godot", "--headless", "--path", str(project), "--script", "res://make_pack.gd", env=env)
            write_manifest(target, key, version)
        broken = folder / "broken"
        broken.mkdir()
        (broken / "red-veil-content.pck").write_bytes(b"A signed file that is deliberately not a valid resource pack.")
        write_manifest(broken, key, "0.3.3-alpha.1")
        print(command("godot", "--headless", "--path", str(project), "--script", "res://tests/update_store_test.gd", env=env))

        def boot(mode="healthy", allow_engine_error=False):
            return command("godot", "--headless", "--path", str(project), env=env | {"RED_VEIL_BOOT_TEST_MODE": mode}, allow_engine_error=allow_engine_error)

        def install(name, current, production=False):
            source = folder / name
            script = project / "install.gd"
            script.write_text('''extends SceneTree
const Store = preload("res://updater/store.gd")
func _initialize():
    var key = CryptoKey.new()
    assert(key.load("res://updater/public_key.pem", true) == OK)
    var storage = "user://development-updates" if OS.has_feature("editor") else "user://updates"
    var store = Store.new(storage, "0.3.0-alpha.1", key)
''' + f'    var folder = {json.dumps(str(source))}\n' +
                              f'    var result = store.stage(FileAccess.get_file_as_bytes(folder.path_join("update-manifest.json")), FileAccess.get_file_as_bytes(folder.path_join("update-manifest.sig")), folder.path_join("red-veil-content.pck"), {json.dumps(current)})\n' +
                              '    assert(result.ok, str(result))\n    assert(store.activate(result.version).ok)\n    print("INSTALL_OK")\n    quit()\n')
            if production:
                script.write_text(script.read_text().replace('"user://development-updates" if OS.has_feature("editor") else "user://updates"', '"user://updates"'))
            output = command("godot", "--headless", "--path", str(project), "--script", "res://install.gd", env=env)
            assert "INSTALL_OK" in output, output

        assert "BOOT_MARKER=base VERSION=0.3.0-alpha.1" in boot()
        install("a", "0.3.0-alpha.1", production=True)
        assert "BOOT_MARKER=base VERSION=0.3.0-alpha.1" in boot()
        print("PASS: source preview cannot mount the production update cache")
        install("a", "0.3.0-alpha.1")
        trial = boot("no-ack")
        assert "BOOT_MARKER=a VERSION=0.3.1-alpha.1" in trial, trial
        restored = boot()
        assert "BOOT_MARKER=base VERSION=0.3.0-alpha.1" in restored and "did not finish starting" in restored, restored
        print("PASS: real resource pack and new explicitly preloaded script mount before main scene; unacknowledged boot restores bundled version")
        install("a", "0.3.0-alpha.1")
        healthy = boot("verify-followup")
        assert "BOOT_MARKER=a VERSION=0.3.1-alpha.1" in healthy and "PINNED_KEY_STILL_VALID=true" in healthy, healthy
        assert "BOOT_MARKER=a VERSION=0.3.1-alpha.1" in boot()
        print("PASS: cached baseline key stays pinned despite a pack replacing the public-key resource")
        install("b", "0.3.1-alpha.1")
        assert "BOOT_MARKER=b VERSION=0.3.2-alpha.1" in boot("no-ack")
        restored = boot()
        assert "BOOT_MARKER=a VERSION=0.3.1-alpha.1" in restored, restored
        print("PASS: failed later startup restores the last healthy signed pack")
        install("broken", "0.3.1-alpha.1")
        restored = boot(allow_engine_error=True)
        assert "BOOT_MARKER=a VERSION=0.3.1-alpha.1" in restored and "could not open" in restored, restored
        print("PASS: valid signature on invalid PCK cannot replace a working game")
        install("b", "0.3.1-alpha.1")
        assert "BOOT_MARKER=b VERSION=0.3.2-alpha.1" in boot()
        # The OS-independent location is reported by Godot, not guessed from XDG layout.
        locate = project / "locate.gd"
        locate.write_text('extends SceneTree\nfunc _initialize():\n\tprint("USER_DIR=", OS.get_user_data_dir())\n\tquit()\n')
        output = command("godot", "--headless", "--path", str(project), "--script", "res://locate.gd", env=env)
        user_dir = Path(next(line.removeprefix("USER_DIR=") for line in output.splitlines() if line.startswith("USER_DIR=")))
        assert user_dir.is_relative_to(folder)
        pack = user_dir / "development-updates/slots/0.3.2-alpha.1/red-veil-content.pck"
        raw = pack.read_bytes()
        pack.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
        restored = boot()
        assert "BOOT_MARKER=a VERSION=0.3.1-alpha.1" in restored and "could not be verified" in restored, restored
        print("PASS: same-size disk tampering is rechecked on every process startup")
        configured = (project / "project.godot").read_text().replace('config/version="0.3.0-alpha.1"', 'config/version="0.4.0-alpha.1"')
        (project / "project.godot").write_text(configured)
        assert "BOOT_MARKER=base VERSION=0.4.0-alpha.1" in boot()
        print("PASS: newer bundled installer outranks all older cached content")


if __name__ == "__main__":
    main()
