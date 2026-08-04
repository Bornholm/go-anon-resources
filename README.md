# go-anon-resources

Ressources pré-entraînées pour [go-anon](https://github.com/bornholm/go-anon) :
modèles NER (CRF), gazetteers et Brown clusters.

## Contenu

```
├── models/
│   ├── fr.crf.gz    Modèle français   (265 Mo, F1: 0.824)
│   ├── en.crf.gz    Modèle anglais    (293 Mo, F1: 0.888)
│   └── es.crf.gz    Modèle espagnol   (214 Mo, F1: 0.938)
├── gazetteers/
│   ├── firstnames/
│   │   ├── fr_prenoms.txt         Prénoms français
│   │   ├── en_firstnames.txt      Prénoms anglais
│   │   └── fr_en_es_prenoms.txt   Prénoms européens (fr, en, es)
│   ├── locations/
│   │   ├── fr_communes.txt        Communes françaises
│   │   ├── fr_villes.txt          Villes françaises
│   │   ├── en_cities.txt          Villes anglophones
│   │   └── en_countries.txt       Pays (anglais)
│   └── organizations/
│       ├── en_companies.txt       Entreprises mondiales
│       └── en_universities.txt    Universités mondiales
├── clusters/
│   ├── fr.txt       Brown clusters français
│   └── en.txt       Brown clusters anglais
├── docs/
│   ├── manifest.json         Catalogue des ressources (GitHub Pages)
│   ├── manifest.json.minisig Signature Ed25519 du manifest (authenticité)
│   └── releasing.md          Guide de publication
└── scripts/
    └── publish.sh            Script de publication
```

Les gazetteers sont organisés par type (`firstnames`, `locations`,
`organizations`). Les langues sont encodées dans le préfixe du nom de fichier
(ex: `fr_en_es_prenoms.txt` → langues fr, en, es).

Les **Brown clusters** sont nommés par le seul code de langue (`clusters/fr.txt`),
car un jeu de clusters est lié au corpus qui l'a produit et ne se partage pas
entre langues. Ils doivent être **ceux utilisés à l'entraînement du modèle de la
même langue** : en publier d'autres reproduirait le défaut qu'ils corrigent —
une feature que le modèle attend et qui ne se comporte pas comme à
l'entraînement.

## Utilisation

Les modèles et gazetteers sont téléchargeables automatiquement par go-anon :

```bash
# Téléchargement automatique du modèle, des gazetteers et des clusters
anon-doc -model auto -lang fr -input doc.docx -output out.docx

# Serveur avec toutes les ressources
server -models auto -gazetteers auto
```

## Manifest

Le fichier `docs/manifest.json` est déployé sur GitHub Pages et sert de
catalogue pour le téléchargement automatique. Il référence les assets
publiés sur GitHub Releases.

```
https://bornholm.github.io/go-anon-resources/manifest.json
```

Le manifest est **signé** (Ed25519, format minisign) : go-anon vérifie
`manifest.json.minisig` avec une clé publique embarquée avant de faire confiance
aux SHA-256 qu'il contient. Voir [docs/releasing.md](docs/releasing.md) §
« Signature du manifest ».

## Publication

Voir [docs/releasing.md](docs/releasing.md) pour la procédure
de publication d'une nouvelle version.
