#!/bin/bash
# Installation légère de Flutter et du SDK Android pour Debian/Ubuntu, Fedora et Arch Linux (x86_64)
set -euo pipefail

[ "$(id -u)" -ne 0 ] || { echo "Erreur : Ne pas exécuter ce script en tant que root." >&2; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "Erreur : Ce script supporte uniquement l'architecture x86_64." >&2; exit 1; }

CMDLINE_TOOLS_VERSION="14742923"

# Options réseau avec tolérance aux coupures
# Note : la vérification par empreinte SHA-256 est délibérément omise au profit
# de la simplicité du script (téléchargements directs en HTTPS depuis Google).
CURL_CMD=(curl -fSL --retry 3 --connect-timeout 10)

log() { printf '\n==> %s\n' "$*"; }

# Gestion sécurisée des signaux et du répertoire temporaire
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$CACHE_BASE"
TMP_DIR=$(mktemp -d -p "$CACHE_BASE" flutter-setup-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

IS_WSL=false
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

# 1. Dépendances système minimales (Android uniquement)
install_dependencies() {
    log "Installation des dépendances système"
    local common_pkgs=(git curl unzip zip jq)

    if command -v apt-get >/dev/null; then
        local apt_pkgs=("${common_pkgs[@]}" xz-utils openjdk-17-jdk)
        [ "$IS_WSL" = false ] && apt_pkgs+=(android-sdk-platform-tools-common)
        sudo apt-get update -y
        sudo apt-get install -y "${apt_pkgs[@]}"

    elif command -v dnf >/dev/null; then
        sudo dnf install -y "${common_pkgs[@]}" which xz java-17-openjdk-devel

    elif command -v pacman >/dev/null; then
        sudo pacman -S --needed --noconfirm "${common_pkgs[@]}" which xz jdk17-openjdk

    else
        echo "Erreur : Gestionnaire de paquets non supporté (apt, dnf ou pacman requis)." >&2
        exit 1
    fi

    if [ "$IS_WSL" = false ]; then
        local user="${USER:-$(id -un)}"
        for g in plugdev adbusers; do
            getent group "$g" >/dev/null || sudo groupadd "$g"
            sudo usermod -aG "$g" "$user"
        done

        # Règle udev ciblée sur l'interface ADB
        if ! ls /etc/udev/rules.d/*android*.rules /lib/udev/rules.d/*android*.rules /usr/lib/udev/rules.d/*android*.rules >/dev/null 2>&1; then
            sudo mkdir -p /etc/udev/rules.d
            sudo tee /etc/udev/rules.d/51-android.rules >/dev/null <<'EOF'
SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4201:*", TAG+="uaccess"
EOF
        fi
        sudo udevadm control --reload-rules 2>/dev/null && sudo udevadm trigger --subsystem-match=usb 2>/dev/null || true
    fi
}

# 2. Validation stricte de Java 17 (JDK complet requis)
is_java17() {
    [ -n "$1" ] && [ -x "$1/bin/java" ] && [ -x "$1/bin/javac" ] && "$1/bin/java" -version 2>&1 | grep -Eq 'version "17[."]'
}

configure_java() {
    log "Vérification de Java 17"
    for c in ${JAVA_HOME:+"$JAVA_HOME"} /usr/lib/jvm/*17*; do
        [ -d "$c" ] && is_java17 "$c" && { export JAVA_HOME="$c"; break; }
    done

    [ -n "${JAVA_HOME:-}" ] && is_java17 "$JAVA_HOME" || {
        echo "Erreur : Aucun JDK 17 valide n'a été détecté (javac requis)." >&2
        exit 1
    }
    echo "Java 17 sélectionné : $JAVA_HOME"
}

# 3. Installation de Flutter (dernière version stable x64)
install_flutter() {
    if [ -x "$HOME/flutter/bin/flutter" ]; then
        log "SDK Flutter déjà présent dans $HOME/flutter"
        return 0
    fi

    if [ -e "$HOME/flutter" ]; then
        echo "Erreur : $HOME/flutter existe mais n'est pas un SDK Flutter valide." >&2
        echo "Veuillez sauvegarder, renommer ou supprimer ce dossier avant de relancer." >&2
        exit 1
    fi

    log "Recherche de Flutter stable (x64)..."
    local json="$TMP_DIR/releases.json"
    "${CURL_CMD[@]}" -sS -o "$json" \
        https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json

    local archive
    archive=$(jq -r '
        .current_release.stable as $h
        | [.releases[] | select(.channel == "stable" and .hash == $h and (.dart_sdk_arch // "x64") == "x64")][0].archive // empty' "$json")

    [ -n "$archive" ] || {
        echo "Erreur : Archive stable x64 introuvable dans releases_linux.json." >&2
        exit 1
    }

    log "Téléchargement de Flutter ($archive)..."
    "${CURL_CMD[@]}" -# -o "$TMP_DIR/flutter.tar.xz" \
        "https://storage.googleapis.com/flutter_infra_release/releases/$archive"

    tar -xf "$TMP_DIR/flutter.tar.xz" -C "$TMP_DIR"
    mv "$TMP_DIR/flutter" "$HOME/flutter"
}

# 4. Android SDK CLI
install_android_sdk() {
    local sdk_dir="$HOME/Android/Sdk"
    local cmdline_dir="$sdk_dir/cmdline-tools/latest"

    if [ ! -x "$cmdline_dir/bin/sdkmanager" ]; then
        log "Téléchargement des outils Android en ligne de commande"
        local zip_file="$TMP_DIR/cmdline-tools.zip"
        "${CURL_CMD[@]}" -sS -o "$zip_file" "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
        
        mkdir -p "$sdk_dir/cmdline-tools"
        unzip -qo "$zip_file" -d "$TMP_DIR/extracted"
        rm -rf "$cmdline_dir"
        mv "$TMP_DIR/extracted/cmdline-tools" "$cmdline_dir"
    else
        log "Outils Android déjà présents"
    fi

    log "Validation des licences et des composants Android"
    yes 2>/dev/null | "$cmdline_dir/bin/sdkmanager" --licenses >/dev/null || true
    "$cmdline_dir/bin/sdkmanager" "platform-tools" "platforms;android-36" "build-tools;36.0.0"
}

# 5. Raccordement des exécutables et environnement
setup_binaries() {
    log "Configuration des raccourcis dans ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    for t in flutter/bin/flutter flutter/bin/dart Android/Sdk/cmdline-tools/latest/bin/sdkmanager Android/Sdk/platform-tools/adb; do
        ln -sf "$HOME/$t" "$HOME/.local/bin/$(basename "$t")"
    done

    log "Configuration du fichier d'environnement ~/.config/flutter-android-env.sh"
    mkdir -p "$HOME/.config"
    cat << 'EOF' > "$HOME/.config/flutter-android-env.sh"
export ANDROID_HOME="$HOME/Android/Sdk"
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
EOF

    export ANDROID_HOME="$HOME/Android/Sdk"
    export PATH="$HOME/.local/bin:$PATH"

    local rc="$HOME/.bashrc"
    [[ "${SHELL:-}" == *"zsh"* ]] && rc="$HOME/.zshrc"

    if ! grep -qF 'flutter-android-env.sh' "$rc" 2>/dev/null; then
        printf '\n[ -f "$HOME/.config/flutter-android-env.sh" ] && . "$HOME/.config/flutter-android-env.sh"\n' >> "$rc"
    fi
}

# 6. Configuration persistante de Flutter et diagnostic
configure_and_verify() {
    log "Configuration persistante et diagnostic Flutter"
    "$HOME/flutter/bin/flutter" config --android-sdk "$HOME/Android/Sdk" >/dev/null
    "$HOME/flutter/bin/flutter" config --jdk-dir "$JAVA_HOME" >/dev/null
    "$HOME/flutter/bin/flutter" doctor || true
}

final_message() {
    cat <<EOF

==========================================================
INSTALLATION TERMINÉE AVEC SUCCÈS
- Commandes prêtes : flutter, dart, adb, sdkmanager
- Recharger le shell : source ~/.bashrc (ou ~/.zshrc)
- Vérifier l'état : flutter doctor -v

Diagnostic Flutter :
- Les alertes éventuelles sur Chrome ou Linux Desktop sont normales pour un setup Android.
- Toute alerte dans la section 'Android toolchain' est en revanche anormale et doit être résolue.

Optionnel :
- Pour refuser la télémétrie de Google : flutter config --no-analytics
EOF
    if [ "$IS_WSL" = false ]; then
        echo "- Pour utiliser adb en USB, déconnectez-vous puis reconnectez-vous pour activer les droits (groupes plugdev/adbusers)."
    fi
    echo "=========================================================="
}

main() {
    install_dependencies
    configure_java
    install_flutter
    install_android_sdk
    setup_binaries
    configure_and_verify
    final_message
}

main "$@"
