# Mobile distribution without a store listing

**Status: Android export validation exists; a public native mobile release and mobile self-updater do not.** The desktop signed-content updater intentionally remains disabled on Android and iOS. A cross-platform engine supplies compatible builds; it does not remove operating-system installation rules.

## Practical delivery routes

| Platform           | Store-independent route                                                                                                                               | What still applies                                                                                                                                          |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Android            | A signed APK can be downloaded directly from a GitHub Release. A future in-game notice can link directly to that APK rather than the repository page. | Stable package/signing identity, increasing version code, Android installation approval, device compatibility, and applicable developer-verification rules. |
| iPhone/iPad        | The web/PWA version can be opened in Safari and added to the Home Screen without App Store enrollment.                                                | Browser storage, graphics, input and installation behavior must be tested on real devices. A website is not a native IPA.                                   |
| Native iPhone/iPad | Use an Apple-supported signing/provisioning and distribution route.                                                                                   | A generic IPA on GitHub is not universally installable. Apple alternative distribution also has eligibility/signing requirements.                           |

No Play Store listing is required for direct APK delivery. That must not be presented as a guarantee of zero enrollment, warnings, or approval on every Android device or in every region. Google's current [Android developer verification documentation](https://developer.android.com/developer-verification) describes an outside-Play Android Developer Console route, account options/potential fees, a regional protection rollout beginning September 30, 2026 and broader expansion in 2027. The direct-APK route must not be treated as exempt from applicable verification requirements. Check the current requirements for the intended audience before launch. Do not advertise an unsupported security bypass.

Apple's [web distribution documentation](https://developer.apple.com/support/web-distribution-eu/) describes eligibility requirements for its alternative native distribution route. Free personal-device development is not a substitute for unrestricted distribution to all players. Tauri, Godot, Unity, or another framework cannot grant these platform permissions.

## Android work implemented

- `scripts/install_android_tools.py` installs a minimal **Linux build-runner SDK**, with SHA-256-pinned official archives for build-tools 35.0.1, platform 35 revision 2, and stable platform-tools 37.0.1. Initial archive provenance was checked against Google's published repository metadata on November 14, 2026. The script rejects unexpected archive roots, traversal, and symlinks.
- `game/export_presets.android.cfg` is a separate arm64 template. It does not alter the desktop export presets. Godot's prebuilt APK exporter avoids the extra NDK/Gradle source-build toolchain.
- `scripts/build_android.py` exports from an exact committed game-source snapshot in a temporary workspace. It isolates editor settings and player data, uses verified Godot 4.6.3 templates, verifies the APK signature/package/version/ABI, and writes an Android manifest plus checksum.
- `.github/workflows/build-android.yml` is an optional validation build. It uploads an Actions artifact only; it does not publish an APK release or enroll any developer account.
- Eight local tests cover internal/production package separation, version-code bounds, signature/certificate gates, archive traversal, and source isolation.

### Actual internal export evidence

On November 14, 2026, an internal APK was exported from game source `11aefc47c05ec2e1ef2f5448961d72c0ddc8412b` using the new build tools in their uncommitted working state. The build manifest records that distinction.

| Property                  | Verified result                                                    |
| ------------------------- | ------------------------------------------------------------------ |
| Artifact                  | `Red-Veil-0.4.0-alpha.1-INTERNAL-Android-arm64.apk`                |
| Size                      | 27,857,179 bytes                                                   |
| SHA-256                   | `bfc3b2cc3f0b05871d859d49b031735e8b60f7b4891a85f392176753a85f64f2` |
| Package                   | `io.github.roshaninfordham.redveil.internal`                       |
| Version code              | 40001                                                              |
| ABI                       | arm64-v8a                                                          |
| Minimum/target SDK in APK | 24 / 36, as exported from the pinned Godot 4.6.3 template          |
| Signature                 | APK signature schemes v2 and v3 verified by `apksigner`            |
| Local build Java          | OpenJDK 21; the workflow pins JDK 17 following Godot guidance      |

This is **test-only evidence**, not a downloadable production release. Its disposable signing key and distinct `.internal` package protect the intended production identity. The key is not retained for a stable upgrade chain. Do not publish this APK as the permanent app. It has not been installed on an emulator or physical Android device, and no performance, touch, accessibility, or in-app upgrade claim follows from a successful export.

## Build an internal validation APK

On a Linux runner with Python 3.11+, JDK 17+, Godot 4.6.3 and its verified export templates installed:

```sh
python3 scripts/install_android_tools.py --sdk-root /path/outside/repository/android-sdk
python3 scripts/build_android.py --sdk-root /path/outside/repository/android-sdk --java-home /path/to/jdk --version-code 40001 --output releases/android-validation
```

The SDK installer is Linux-only. A Mac/Windows developer can use an official Android Studio SDK locally; the build helper still needs platform-specific validation there. Android SDK licenses apply to the build tools. Players do not install this toolchain.

The default build generates a temporary debug identity, labels the app **Red Veil Internal Test**, and deletes its private key with the temporary workspace. Repeated internal builds should not be assumed to upgrade each other. Keep test installs separate from production player data.

## Stable Android app signing — not configured yet

An APK signing key is a different purpose and format from the existing RSA **game-content update** key. The latter must not be repurposed or assumed to satisfy Android app signing. Before publishing a production APK, provision one stable Android keystore on a trusted owner machine, retain an encrypted backup, and configure:

- Encrypted Actions secret `RED_VEIL_ANDROID_KEYSTORE_BASE64`: a single-line base64 encoding of the keystore, uploaded directly through the secure CLI/UI.
- Encrypted Actions secret `RED_VEIL_ANDROID_KEYSTORE_PASSWORD`.
- Repository variable `RED_VEIL_ANDROID_KEY_ALIAS`, default `red-veil`.
- Repository variable `RED_VEIL_ANDROID_CERTIFICATE_SHA256`: the approved app certificate fingerprint, with or without colons.

No production Android key or these secrets were created by the development agents. Never paste private key material or passwords into chat, documentation, issues, or Git. Changing a keystore casually can prevent existing installations from upgrading.

The workflow's `release_signing=true` path fails if its signing setup is missing. It writes the private keystore outside the checkout with restrictive permissions, removes it on normal step exit, and checks the APK's actual certificate against the approved fingerprint. It still produces a validation artifact rather than a public release. A local release-style build additionally requires a clean committed checkout:

```sh
python3 scripts/build_android.py --release --sdk-root /path/to/android-sdk --java-home /path/to/jdk --keystore /secure/path/release.keystore --alias red-veil --expected-certificate-sha256 APPROVED_PUBLIC_FINGERPRINT --version-code NEXT_INTEGER --output releases/android-validation
```

Supply the password through `RED_VEIL_ANDROID_KEYSTORE_PASSWORD`, not a command-line argument. Each real update must preserve the production package ID and approved signing identity and use a strictly larger Android version code. The current helper validates the code's range; a future public release gate must compare it with the previous published APK before distribution.

## Mobile update work still required

A direct-download Android app can check public GitHub release metadata without asking the player to visit the repository. Installing a replacement APK must use a supported Android installation flow and preserve the app's signing identity. The operating system may require user approval and permission for that installation source. Silent arbitrary replacement is not the goal.

The current game does **not** contain a native `PackageInstaller`/file-provider integration or an APK-download update UI. A direct asset link through the system browser can be an interim route, but it must be clearly described as a download/installer flow rather than an in-place silent update.

The desktop PCK package is not a mobile package. Mobile content updates need separately exported textures, a platform/runtime contract, tested startup recovery and process-lifecycle behavior, and the relevant distribution-policy review. Do not remove the platform guard simply because the scripting language is shared.

Before a public Android release: test installation, a same-key higher-version upgrade preserving practice data, rejection of a wrong-key APK, low storage/network failure, touch controls, readability, pause/background/resume behavior, frame pacing, and accessibility on representative physical devices. Native iOS additionally needs a chosen supported distribution route. Background phone notifications require a separate permission/push service; checking when a game opens does not provide them.

## Official references

- [Godot 4.6 Android export instructions](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html), with [versioned documentation source](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/export/exporting_for_android.rst).
- [Android alternative distribution](https://developer.android.com/distribute/marketing-tools/alternative-distribution).
- [Android app signing](https://developer.android.com/studio/publish/app-signing).
- [Android developer verification](https://developer.android.com/developer-verification).
- [Apple alternative web distribution](https://developer.apple.com/support/web-distribution-eu/).

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
