#!/bin/bash
# Optional one-time installation for the explicitly consented, ad-hoc-signed
# macOS download. This never signs an app or changes system Gatekeeper policy.
set -euo pipefail

APP_NAME='KŌMAKU- Dust and Radiation.app'
APP_NAME_NFD='KŌMAKU- Dust and Radiation.app'
DISPLAY_NAME='KŌMAKU: Dust & Radiation'
EXPECTED_IDENTIFIER='io.github.roshaninfordham.redveil'
SCRIPT_DIRECTORY="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_APP="$SCRIPT_DIRECTORY/$APP_NAME"
INSTALL_DIRECTORY="$HOME/Applications"
DESTINATION="$INSTALL_DIRECTORY/$APP_NAME"
STAGING=''
BACKUP=''
INSTALL_COMPLETE=0

pause_before_exit() {
    if [ -t 0 ]; then
        printf '\nPress Return to close this installer. '
        read -r _answer || true
    fi
}

cleanup() {
    local result=$?
    trap - EXIT
    # A failed replacement restores the previous app if its slot is empty.
    if [ "$INSTALL_COMPLETE" -eq 0 ] && [ -n "$BACKUP" ] && [ -d "$BACKUP/$APP_NAME" ] && [ ! -e "$DESTINATION" ] && [ ! -L "$DESTINATION" ]; then
        /bin/mv "$BACKUP/$APP_NAME" "$DESTINATION" || printf '\nPrevious app is preserved at: %s\n' "$BACKUP/$APP_NAME" >&2
    fi
    if [ -n "$STAGING" ] && [ -d "$STAGING" ] && [ ! -L "$STAGING" ]; then
        /bin/rm -rf -- "$STAGING"
    fi
    if [ "$result" -ne 0 ]; then
        printf '\nInstallation stopped. Your existing app has not been deleted.\n' >&2
    fi
    pause_before_exit
    exit "$result"
}
trap cleanup EXIT

fail() {
    printf '\n%s\n' "$1" >&2
    exit 1
}

verify_app() {
    local app="$1"
    [ -d "$app" ] && [ ! -L "$app" ] || fail "Expected a real application folder: $app"
    # This exported game has no symlinks. Refuse any before copying or applying
    # an app-only quarantine change; never follow links outside the bundle.
    [ -z "$(/usr/bin/find "$app" -type l -print -quit)" ] || fail 'Application contains unexpected symbolic links. Download a fresh official ZIP.'
    local identifier
    identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" || fail 'Application metadata could not be read.'
    [ "$identifier" = "$EXPECTED_IDENTIFIER" ] || fail 'Application identifier does not match KŌMAKU.'
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$app" || fail 'Application integrity verification failed. Do not bypass this error; download the corrected release.'
}

check_not_running() {
    local pid executable
    while read -r pid executable; do
        case "$executable" in
            "$DESTINATION/"*|"$SOURCE_APP/"*|*"$APP_NAME/Contents/MacOS/"*|*"$APP_NAME_NFD/Contents/MacOS/"*|*"Shield Protocol.app/Contents/MacOS/"*)
                fail 'KŌMAKU is running. Quit the game, then run this installer again.'
                ;;
        esac
    done < <(/bin/ps -axo pid=,comm=)
}

[ "$(/usr/bin/uname -s)" = Darwin ] || fail 'This installer runs on macOS only.'
[ ! -L "${BASH_SOURCE[0]}" ] || fail 'Run the installer directly from the extracted download, not a symbolic link.'
printf '%s — verified local installation\n\n' "$DISPLAY_NAME"
printf 'Checking the app beside this installer…\n'
verify_app "$SOURCE_APP"
check_not_running
[ ! -L "$INSTALL_DIRECTORY" ] || fail '~/Applications is a symbolic link. Choose a regular local Applications folder before installing.'
[ ! -L "$DESTINATION" ] || fail 'The destination app is a symbolic link. Move that link before installing.'
if [ -e "$DESTINATION" ] && [ ! -d "$DESTINATION" ]; then
    fail 'A non-folder item already occupies the application destination.'
fi

# A local ad-hoc signature proves that the bundle is internally consistent,
# not that Apple or this installer has authenticated the publisher.
if ! /usr/bin/osascript - "$DESTINATION" "$DISPLAY_NAME" <<'APPLESCRIPT'
on run arguments
    set targetPath to item 1 of arguments
    set gameName to item 2 of arguments
    display dialog ("Install " & gameName & "?") & return & return & "This build is not Apple-notarized. Its local signature verifies file integrity, not publisher identity. Continue only if you trust the source of this download." & return & return & "This will copy the verified app to:" & return & targetPath & return & return & "It will remove the download quarantine flag only from that copied app, allowing it to open without Apple's downloaded-app approval. Your Mac's global security settings remain unchanged. An existing app will be kept as a backup." buttons {"Cancel", "Install trusted download"} default button "Cancel" cancel button "Cancel" with icon caution
end run
APPLESCRIPT
then
    printf '\nInstallation cancelled. No application was installed or unblocked.\n'
    exit 0
fi

/bin/mkdir -p "$INSTALL_DIRECTORY"
[ -d "$INSTALL_DIRECTORY" ] && [ ! -L "$INSTALL_DIRECTORY" ] || fail 'The installation directory changed. Run the installer again.'
STAGING="$(/usr/bin/mktemp -d "$INSTALL_DIRECTORY/.komaku-install.XXXXXX")"
STAGED_APP="$STAGING/$APP_NAME"
/usr/bin/ditto "$SOURCE_APP" "$STAGED_APP"
verify_app "$STAGED_APP"

# xattr can return an error when no quarantine flag exists. Inspect afterwards
# to distinguish an absent attribute from a failed attempt to remove one.
/usr/bin/xattr -dr com.apple.quarantine "$STAGED_APP" 2>/dev/null || true
ATTRIBUTES="$(/usr/bin/xattr -lr "$STAGED_APP")" || fail 'Could not verify application quarantine attributes.'
case "$ATTRIBUTES" in
    *com.apple.quarantine*) fail 'Could not remove the quarantine flag from the verified copy.' ;;
esac
verify_app "$STAGED_APP"
check_not_running
[ ! -L "$INSTALL_DIRECTORY" ] && [ ! -L "$DESTINATION" ] || fail 'The application destination changed during installation.'
if [ -e "$DESTINATION" ]; then
    [ -d "$DESTINATION" ] || fail 'The destination changed during installation.'
    BACKUP="$(/usr/bin/mktemp -d "$INSTALL_DIRECTORY/.komaku-previous.XXXXXX")"
    /bin/mv "$DESTINATION" "$BACKUP/$APP_NAME"
fi
# The staging folder and destination share a filesystem, so the final move
# renames a complete verified bundle instead of exposing a partial copy.
/bin/mv "$STAGED_APP" "$DESTINATION"
INSTALL_COMPLETE=1
printf '\nInstalled: %s\n' "$DESTINATION"
if [ -n "$BACKUP" ]; then
    printf 'Previous version preserved at: %s\n' "$BACKUP/$APP_NAME"
fi
printf 'Opening the game…\n'
/usr/bin/open "$DESTINATION" || fail 'The app was installed but macOS did not open it. Open it from your Applications folder and report the exact error.'
