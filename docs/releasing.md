# Publication des modèles et gazetteers

Ce document décrit la procédure pour publier une nouvelle version des ressources
NER pour le projet go-anon.

## Prérequis

- `gh` (GitHub CLI) installé et authentifié
- Permission de push sur le dépôt `go-anon-resources`
- Les fichiers modèles `.crf.gz` présents dans `models/`
- Les fichiers gazetteers `.txt` dans `gazetteers/<type>/`

## Structure des gazetteers

Les gazetteers sont organisés par type dans des sous-répertoires, avec les
langues encodées dans le nom du fichier :

```
gazetteers/
├── firstnames/              # Type : prénoms
│   ├── fr_prenoms.txt       # langue : fr
│   ├── en_firstnames.txt    # langue : en
│   └── fr_en_es_prenoms.txt # langues : fr, en, es
├── locations/               # Type : lieux
│   ├── fr_communes.txt
│   ├── fr_villes.txt
│   ├── en_cities.txt
│   └── en_countries.txt
└── organizations/           # Type : organisations
    ├── en_companies.txt
    └── en_universities.txt
```

Les codes langue connus sont `fr`, `en`, `es`. Quand plusieurs langues sont
séparées par `_` au début du nom de fichier, le fichier est associé à toutes
ces langues.

## Procédure

### 1. Placer les fichiers

Copier les modèles et gazetteers dans les répertoires correspondants :

```
go-anon-resources/
├── models/
│   ├── fr.crf.gz
│   ├── en.crf.gz
│   └── es.crf.gz
└── gazetteers/
    ├── firstnames/
    │   ├── fr_prenoms.txt
    │   ├── en_firstnames.txt
    │   └── fr_en_es_prenoms.txt
    ├── locations/
    │   ├── fr_communes.txt
    │   ├── fr_villes.txt
    │   ├── en_cities.txt
    │   └── en_countries.txt
    └── organizations/
        ├── en_companies.txt
        └── en_universities.txt
```

### 2. Lancer le script de publication

```bash
cd ~/go-anon-resources
./scripts/publish.sh                     # tag auto : v2026.5.22-a1b2c3d4
# ou explicitement :
./scripts/publish.sh models-v2
```

Le script effectue automatiquement :

- Découverte des gazetteers par parcours récursif de `gazetteers/`
- Extraction du type depuis le nom du répertoire parent
- Extraction des codes langue depuis le préfixe du nom de fichier
- Calcul des SHA-256 et tailles
- Génération du `manifest.json` complet (modèles + gazetteers)
- Création de la release GitHub avec tous les fichiers comme assets
- Mise à jour du manifest local dans `docs/manifest.json`

### 3. Vérifier et pousser le manifest

```bash
git add docs/manifest.json
git commit -m "chore: update manifest for $TAG"
git push origin main
git push origin "$TAG"
```

### 4. Vérifier la publication

- Release GitHub : `https://github.com/bornholm/go-anon-resources/releases/latest`
- Manifest GitHub Pages : `https://bornholm.github.io/go-anon-resources/manifest.json`

## Schéma du manifest

```json
{
  "schema_version": 1,
  "version": "models-v2",
  "published_at": "2026-05-22T10:00:00Z",
  "models": {
    "fr": {
      "url": "https://github.com/bornholm/go-anon-resources/releases/download/models-v2/fr.crf.gz",
      "sha256": "abc123...",
      "size_bytes": 277744297,
      "metadata": {
        "f1": 0.847,
        "corpus": "WikiNER-fr",
        "size_mb": 264.9
      }
    }
  },
  "gazetteers": {
    "fr_prenoms": {
      "url": "https://github.com/bornholm/go-anon-resources/releases/download/models-v2/fr_prenoms.txt",
      "sha256": "9ed1fd9...",
      "size_bytes": 375433,
      "languages": ["fr"],
      "type": "firstnames"
    },
    "fr_en_es_prenoms": {
      "url": "https://github.com/bornholm/go-anon-resources/releases/download/models-v2/fr_en_es_prenoms.txt",
      "sha256": "8df8703...",
      "size_bytes": 2104259,
      "languages": ["fr", "en", "es"],
      "type": "firstnames"
    }
  }
}
```

## URLs des assets

| Asset                      | URL                                                          |
| -------------------------- | ------------------------------------------------------------ |
| Modèle FR                  | `../releases/download/models-vN/fr.crf.gz`                   |
| Modèle EN                  | `../releases/download/models-vN/en.crf.gz`                   |
| Modèle ES                  | `../releases/download/models-vN/es.crf.gz`                   |
| Gazetteer fr_prenoms       | `../releases/download/models-vN/fr_prenoms.txt`              |
| Gazetteer fr_communes      | `../releases/download/models-vN/fr_communes.txt`             |
| Gazetteer fr_villes        | `../releases/download/models-vN/fr_villes.txt`               |
| Gazetteer en_firstnames    | `../releases/download/models-vN/en_firstnames.txt`           |
| Gazetteer en_cities        | `../releases/download/models-vN/en_cities.txt`               |
| Gazetteer en_companies     | `../releases/download/models-vN/en_companies.txt`            |
| Gazetteer en_countries     | `../releases/download/models-vN/en_countries.txt`            |
| Gazetteer en_universities  | `../releases/download/models-vN/en_universities.txt`         |
| Gazetteer fr_en_es_prenoms | `../releases/download/models-vN/fr_en_es_prenoms.txt`        |
| Manifest                   | `https://bornholm.github.io/go-anon-resources/manifest.json` |

## Tags et versions

| Tag                  | Usage                                                      |
| -------------------- | ---------------------------------------------------------- |
| `vYYYY.M.D-<hash_8>` | Auto-généré si aucun tag fourni (recommandé)               |
| `models-vN`          | Tag explicite (alternative)                                |
| `main`               | Branche par défaut, contient le manifest et les gazetteers |

## Notes

- Les modèles ne sont **pas** versionnés dans Git (limite de taille GitHub).
  Ils sont exclus via `.gitignore` et distribués uniquement via GitHub Releases.
- Le manifest est automatiquement déployé sur GitHub Pages via le workflow
  `.github/workflows/pages.yml`.
- Les gazetteers sont versionnés dans Git (fichiers texte < 2 Mo).
- Le type d'un gazetteer est déterminé par le nom du répertoire parent
  (`firstnames`, `locations`, `organizations`).
- Les codes langue sont extraits du préfixe du nom de fichier (ex: `fr_en_es_`
  → langues : fr, en, es).
