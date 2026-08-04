#!/bin/bash
#
# publish.sh — Publie une nouvelle version des modèles et gazetteers
# sur GitHub Releases et met à jour le manifest.json dans docs/.
#
# Usage :
#   ./scripts/publish.sh [<tag>]
#
# Exemples :
#   ./scripts/publish.sh              # auto: v2026.5.22-a1b2c3d4
#   ./scripts/publish.sh models-v2    # explicite
#
# Prérequis :
#   - gh (GitHub CLI) installé et authentifié
#   - Les fichiers .crf.gz dans models/ et .txt dans gazetteers/**/
#   - Droit de push sur le dépôt
#
# Structure des gazetteers :
#   gazetteers/<type>/<langs>_<description>.txt
#
#   où <type> = firstnames|locations|organizations
#   et <langs> = un ou plusieurs codes langue (fr, en, es) séparés par _
#   ex: firstnames/fr_prenoms.txt, firstnames/fr_en_es_prenoms.txt

set -euo pipefail

if [ $# -eq 0 ]; then
    TAG="v$(date -u +'%Y.%-m.%-d')-$(git rev-parse --short=8 HEAD)"
    echo "=== Aucun tag fourni, génération automatique : $TAG ==="
elif [ $# -eq 1 ]; then
    TAG="$1"
else
    echo "Usage: $0 [<tag>]"
    echo "Example: $0                 # auto: v2026.5.22-a1b2c3d4"
    echo "Example: $0 models-v2       # explicite"
    exit 1
fi
MODELS_DIR="models"
GAZETTEERS_DIR="gazetteers"
CLUSTERS_DIR="clusters"
DOCS_DIR="docs"
MANIFEST_FILE="${DOCS_DIR}/manifest.json"
MANIFEST_SIG_FILE="${MANIFEST_FILE}.minisig"

# Signature du manifest (minisign). La clé secrète n'est jamais commitée :
# elle est fournie par $GOANON_SIGN_KEY, sinon l'emplacement minisign par défaut
# (~/.minisign/minisign.key). Si minisign ou la clé manquent, la signature est
# ignorée avec avertissement (publication non signée, tolérée pendant la
# transition). Voir docs/releasing.md § « Signature du manifest ».
SIGN_KEY="${GOANON_SIGN_KEY:-$HOME/.minisign/minisign.key}"

# Vérifications préalables
if ! command -v gh &>/dev/null; then
    echo "Erreur : gh (GitHub CLI) n'est pas installé."
    exit 1
fi

if ! [ -d "$MODELS_DIR" ]; then
    echo "Erreur : le répertoire $MODELS_DIR n'existe pas."
    exit 1
fi

MODEL_FILES=($(ls "$MODELS_DIR"/*.crf.gz 2>/dev/null || true))
if [ ${#MODEL_FILES[@]} -eq 0 ]; then
    echo "Erreur : aucun fichier .crf.gz trouvé dans $MODELS_DIR/"
    exit 1
fi

# Découvrir les gazetteers dans l'arborescence <type>/<fichier>
GAZETTEER_FILES=()
while IFS= read -r -d '' f; do
    GAZETTEER_FILES+=("$f")
done < <(find "$GAZETTEERS_DIR" -name '*.txt' -type f -print0)

# Découvrir les Brown clusters : clusters/<lang>.txt
# Absents = release sans clusters, ce qui reste valide : le champ est
# facultatif dans le manifest et un client sans clusters fonctionne.
CLUSTER_FILES=()
while IFS= read -r -d '' f; do
    CLUSTER_FILES+=("$f")
done < <(find "$CLUSTERS_DIR" -name '*.txt' -type f -print0 2>/dev/null)

if [ ${#GAZETTEER_FILES[@]} -eq 0 ]; then
    echo "Erreur : aucun fichier .txt trouvé dans $GAZETTEERS_DIR/"
    exit 1
fi

echo "=== Publication $TAG ==="
echo "Modèles trouvés :"
for f in "${MODEL_FILES[@]}"; do
    echo "  - $(basename "$f") ($(du -h "$f" | cut -f1))"
done
echo "Gazetteers trouvés :"
for f in "${GAZETTEER_FILES[@]}"; do
    echo "  - ${f#$GAZETTEERS_DIR/} ($(du -h "$f" | cut -f1))"
done

if [ ${#CLUSTER_FILES[@]} -eq 0 ]; then
    echo "Brown clusters : aucun (champ facultatif du manifest)"
else
    echo "Brown clusters (${#CLUSTER_FILES[@]}) :"
    for f in "${CLUSTER_FILES[@]}"; do
        echo "  - ${f#$CLUSTERS_DIR/} ($(du -h "$f" | cut -f1))"
    done
fi

# Vérifier que le tag n'existe pas déjà localement
if git rev-parse "$TAG" &>/dev/null 2>&1; then
    echo "Erreur : le tag $TAG existe déjà."
    exit 1
fi

# Codes langue connus
KNOWN_LANGS=("fr" "en" "es")

# Parse un fichier gazetteer depuis son chemin complet
# Retourne "langues|type|nom" où langues = codes séparés par des virgules
gazetteer_info() {
    local path="$1"
    local dir
    dir=$(dirname "$path")
    local type
    type=$(basename "$dir")
    local basename
    basename=$(basename "$path" .txt)

    local IFS='_'
    read -ra parts <<< "$basename"

    local langs=()
    local name_parts=()
    local in_langs=true

    for part in "${parts[@]}"; do
        if [ "$in_langs" = true ]; then
            local found=false
            for kl in "${KNOWN_LANGS[@]}"; do
                if [ "$part" = "$kl" ]; then
                    langs+=("$part")
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                in_langs=false
                name_parts+=("$part")
            fi
        else
            name_parts+=("$part")
        fi
    done

    # Joindre les langues avec des virgules
    local lang_str=""
    if [ ${#langs[@]} -gt 0 ]; then
        lang_str=$(IFS=,; echo "${langs[*]}")
    fi

    # Joindre les parties du nom avec des underscores
    local name_str=""
    if [ ${#name_parts[@]} -gt 0 ]; then
        name_str=$(IFS=_; echo "${name_parts[*]}")
    fi

    echo "${lang_str}|${type}|${name_str}"
}

# Construire la release note
RELEASE_NOTES=$(mktemp)
cat > "$RELEASE_NOTES" <<EOF
## $TAG

Modèles NER et gazetteers pour go-anon.

### Modèles
| Langue | Fichier | Taille | SHA-256 |
|--------|---------|--------|---------|
$(for f in "${MODEL_FILES[@]}"; do
    BASENAME=$(basename "$f")
    SHA=$(sha256sum "$f" | cut -d' ' -f1)
    SIZE=$(du -h "$f" | cut -f1)
    LANG="${BASENAME%.crf.gz}"
    echo "| $LANG | \`$BASENAME\` | $SIZE | \`$SHA\` |"
done)

### Gazetteers
| Fichier | Type | Langues | Taille |
|---------|------|---------|--------|
$(for f in "${GAZETTEER_FILES[@]}"; do
    SHORT="${f#$GAZETTEERS_DIR/}"
    INFO=$(gazetteer_info "$f")
    LANG="${INFO%%|*}"
    REST="${INFO#*|}"
    TYPE="${REST%%|*}"
    SIZE=$(du -h "$f" | cut -f1)
    echo "| \`$SHORT\` | $TYPE | $LANG | $SIZE |"
done)

### Brown clusters
$(if [ ${#CLUSTER_FILES[@]} -eq 0 ]; then
    echo "_Aucun dans cette release._"
else
    echo "| Langue | Fichier | Taille | SHA-256 |"
    echo "|--------|---------|--------|---------|"
    for f in "${CLUSTER_FILES[@]}"; do
        BASENAME=$(basename "$f")
        echo "| ${BASENAME%.txt} | \`clusters_$BASENAME\` | $(du -h "$f" | cut -f1) | \`$(sha256sum "$f" | cut -d" " -f1)\` |"
    done
fi)

Les clusters sont une **feature du modèle** : un modèle entraîné avec eux perd
du rappel s'ils manquent à l'inférence. \`anon-doc -model auto\` les charge
désormais automatiquement.
EOF

echo ""
echo "=== Génération du manifest ==="

# Détecter l'organisation et le dépôt depuis le remote git
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]%.git}"
else
    echo "Attention : impossible de détecter le remote GitHub. Utilisation des valeurs par défaut."
    OWNER="bornholm"
    REPO="go-anon-resources"
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")

BASE_URL="https://github.com/${OWNER}/${REPO}/releases/download/${TAG}"

# Générer le nouveau manifest
MANIFEST_TMP=$(mktemp)
PUBLISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$MANIFEST_TMP" <<JSONEOF
{
  "schema_version": 1,
  "version": "$TAG",
  "published_at": "$PUBLISHED_AT",
  "models": {
JSONEOF

FIRST=true
for f in "${MODEL_FILES[@]}"; do
    BASENAME=$(basename "$f")
    LANG="${BASENAME%.crf.gz}"
    SHA=$(sha256sum "$f" | cut -d' ' -f1)
    SIZE=$(stat -c '%s' "$f")

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$MANIFEST_TMP"
    fi

    cat >> "$MANIFEST_TMP" <<JSONEOF
    "$LANG": {
      "url": "${BASE_URL}/${BASENAME}",
      "sha256": "$SHA",
      "size_bytes": $SIZE
    }
JSONEOF
done

cat >> "$MANIFEST_TMP" <<JSONEOF
  },
  "gazetteers": {
JSONEOF

FIRST=true
for f in "${GAZETTEER_FILES[@]}"; do
    BASENAME=$(basename "$f")
    SHA=$(sha256sum "$f" | cut -d' ' -f1)
    SIZE=$(stat -c '%s' "$f")
    INFO=$(gazetteer_info "$f")

    LANG="${INFO%%|*}"
    REST="${INFO#*|}"
    TYPE="${REST%%|*}"
    NAME="${REST#*|}"

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$MANIFEST_TMP"
    fi

    # Format languages as JSON array
    if [[ "$LANG" == *,* ]]; then
        LANG_JSON="[\"${LANG//,/\", \"}\"]"
    else
        LANG_JSON="[\"$LANG\"]"
    fi

    # Clé = nom complet du fichier sans extension (ex: fr_prenoms, fr_en_es_prenoms)
    KEY="${BASENAME%.txt}"
    cat >> "$MANIFEST_TMP" <<JSONEOF
    "$KEY": {
      "url": "${BASE_URL}/${BASENAME}",
      "sha256": "$SHA",
      "size_bytes": $SIZE,
      "languages": $LANG_JSON,
      "type": "$TYPE"
    }
JSONEOF
done

cat >> "$MANIFEST_TMP" <<JSONEOF
  },
  "clusters": {
JSONEOF

# Les clusters sont indexés par langue : un jeu est lié au corpus qui l'a
# produit et ne se partage pas entre langues, contrairement à une liste de
# villes. Le nom du fichier EST le code de langue.
FIRST=true
for f in "${CLUSTER_FILES[@]}"; do
    BASENAME=$(basename "$f")
    LANG="${BASENAME%.txt}"
    SHA=$(sha256sum "$f" | cut -d' ' -f1)
    SIZE=$(stat -c '%s' "$f")

    if [[ ! "$LANG" =~ ^[a-z]{2}$ ]]; then
        echo "Erreur : $f — le nom doit être un code de langue à deux lettres (ex. clusters/fr.txt)."
        rm -f "$MANIFEST_TMP" "$RELEASE_NOTES"
        exit 1
    fi

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$MANIFEST_TMP"
    fi

    cat >> "$MANIFEST_TMP" <<JSONEOF
    "$LANG": {
      "url": "${BASE_URL}/clusters_${BASENAME}",
      "sha256": "$SHA",
      "size_bytes": $SIZE
    }
JSONEOF
done

cat >> "$MANIFEST_TMP" <<JSONEOF
  }
}
JSONEOF

# Valider le JSON
if ! python3 -m json.tool "$MANIFEST_TMP" > /dev/null 2>&1; then
    echo "Erreur : le manifest généré n'est pas un JSON valide."
    cat "$MANIFEST_TMP"
    rm "$MANIFEST_TMP" "$RELEASE_NOTES"
    exit 1
fi

echo "Manifest JSON valide."

echo ""
echo "=== Création de la release GitHub ==="
echo "Tag : $TAG"

# Les assets d'une release GitHub vivent dans un espace de noms plat : un
# clusters/fr.txt et un gazetteers/locations/fr.txt entreraient en collision.
# Les clusters sont donc copiés sous un nom préfixé, cohérent avec l'URL
# inscrite dans le manifest.
CLUSTER_ASSETS=()
if [ ${#CLUSTER_FILES[@]} -gt 0 ]; then
    CLUSTER_STAGE=$(mktemp -d)
    trap 'rm -rf "$CLUSTER_STAGE"' EXIT
    for f in "${CLUSTER_FILES[@]}"; do
        cp "$f" "$CLUSTER_STAGE/clusters_$(basename "$f")"
        CLUSTER_ASSETS+=("$CLUSTER_STAGE/clusters_$(basename "$f")")
    done
fi

ALL_ASSETS=("${MODEL_FILES[@]}" "${GAZETTEER_FILES[@]}" "${CLUSTER_ASSETS[@]}")
gh release create "$TAG" \
    "${ALL_ASSETS[@]}" \
    --title "$TAG" \
    --notes-file "$RELEASE_NOTES"

echo "✓ Release $TAG créée avec succès."

echo ""
echo "=== Mise à jour du manifest local ==="
cp "$MANIFEST_TMP" "$MANIFEST_FILE"
echo "✓ $MANIFEST_FILE mis à jour."

echo ""
echo "=== Signature du manifest ==="
# On signe les octets EXACTS servis par GitHub Pages ($MANIFEST_FILE), pas le
# fichier temporaire : go-anon vérifie la signature sur le corps brut du
# manifest. Le trusted comment porte le tag et la date (intégrité vérifiée par
# la signature globale minisign, contrôlée côté go-anon).
SIGNED=false
if ! command -v minisign &>/dev/null; then
    echo "⚠ minisign non installé : manifest NON signé."
    echo "  Installe minisign puis re-signe : minisign -S -s <clé> -m $MANIFEST_FILE"
elif [ ! -f "$SIGN_KEY" ]; then
    echo "⚠ clé de signature introuvable ($SIGN_KEY) : manifest NON signé."
    echo "  Génère-la une fois : minisign -G   (puis renseigne la clé publique dans go-anon)"
    echo "  Ou pointe une clé existante : GOANON_SIGN_KEY=/chemin/minisign.key $0 $TAG"
else
    if minisign -S -s "$SIGN_KEY" -m "$MANIFEST_FILE" \
        -c "go-anon-resources manifest" \
        -t "go-anon-resources $TAG signé le $PUBLISHED_AT"; then
        # minisign écrit <fichier>.minisig à côté de la cible.
        echo "✓ $MANIFEST_SIG_FILE généré."
        SIGNED=true
    else
        echo "⚠ échec de la signature : manifest NON signé."
    fi
fi

echo ""
echo "=== Prochaines étapes ==="
echo ""
echo "1. Vérifie le manifest : cat $MANIFEST_FILE"
echo "2. Commit et push (le tag est déjà créé par gh release create) :"
if [ "$SIGNED" = true ]; then
    echo "   git add $MANIFEST_FILE $MANIFEST_SIG_FILE"
else
    echo "   git add $MANIFEST_FILE"
    echo "   (⚠ manifest non signé — go-anon poursuivra avec un avertissement)"
fi
echo "   git commit -m \"chore: update manifest for $TAG\""
echo "   git push origin $BRANCH"
echo ""
echo "3. GitHub Pages servira automatiquement le nouveau manifest à :"
echo "   https://${OWNER}.github.io/${REPO}/manifest.json"
if [ "$SIGNED" = true ]; then
    echo "   et sa signature à :"
    echo "   https://${OWNER}.github.io/${REPO}/manifest.json.minisig"
fi

rm "$MANIFEST_TMP" "$RELEASE_NOTES"
