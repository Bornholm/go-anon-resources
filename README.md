# go-anon-resources

Modèles NER, gazetteers et Brown clusters pour
[go-anon](https://github.com/bornholm/go-anon).

Les fichiers ne sont pas versionnés. Git ignore `models/`, `gazetteers/` et
`clusters/` ; les versions publiées vivent dans les GitHub Releases.

## Inventaire

`docs/manifest.json` fait autorité sur ce qui existe, pour quelles langues, avec
quelle taille et quelle empreinte. Il est déployé sur GitHub Pages et régénéré à
chaque publication.

```
https://bornholm.github.io/go-anon-resources/manifest.json
```

minisign le signe en Ed25519. go-anon vérifie `manifest.json.minisig` avec une
clé publique embarquée avant d'accorder la moindre confiance aux SHA-256 du
catalogue. La procédure figure dans [docs/releasing.md](docs/releasing.md),
section « Signature du manifest ».

## Organisation des fichiers

```
models/<lang>.crf.gz
gazetteers/<type>/<langs>_<description>.txt
clusters/<lang>.txt
```

Pour un gazetteer, le répertoire porte le type (`firstnames`, `locations`,
`organizations`) et le préfixe du nom de fichier porte les langues.
`fr_en_es_prenoms.txt` couvre donc le français, l'anglais et l'espagnol, et
go-anon le traite comme une liste de prénoms.

Pour un jeu de clusters, le nom de fichier est le seul code de langue. Un jeu
dépend du corpus qui l'a produit et ne se partage pas entre langues.

## Utilisation

go-anon télécharge ce dont il a besoin et le met en cache dans
`os.UserCacheDir()/go-anon/models`.

```bash
# Le modèle entraîne ses gazetteers et ses clusters avec lui
anon-doc -model auto -lang fr -input doc.docx -output out.docx

# Serveur, toutes langues disponibles
server -models auto -gazetteers auto
```

Quand plusieurs listes du même type couvrent une langue, go-anon retient la plus
spécifique, pas la plus grosse. Une liste dédiée à une langue l'emporte donc sur
une liste multilingue même si celle-ci contient davantage d'entrées. Une liste
multilingue est souvent un export brut, une liste dédiée a été nettoyée pour sa
langue.

## Publier

[docs/releasing.md](docs/releasing.md) décrit la procédure et les règles
d'hygiène. Trois points méritent d'être rappelés ici, parce qu'ils ont déjà
coûté cher.

Un gazetteer se présente en un terme par ligne, en minuscules, accents
conservés. Ni en-tête, ni colonne annexe. Le chargeur de go-anon prend la ligne
comme clé de recherche, donc un CSV publié tel quel produit des entrées
introuvables et une liste qui paraît énorme sans jamais reconnaître personne.

Filtrez les entrées rares. Les listes d'état civil sont dominées par le bruit de
saisie, qui n'apporte aucun rappel mesurable et coûte beaucoup de précision.
`releasing.md` donne le seuil retenu et la mesure qui le justifie.

Publiez pour une langue les clusters qui ont servi à entraîner son modèle, et
pas un autre jeu. Les clusters sont une feature du CRF. Un fichier différent de
celui de l'entraînement ne manque pas, il ment, et le modèle reçoit des
identifiants qui ne correspondent pas aux poids qu'il a appris. La panne est
silencieuse et bien plus pénible à diagnostiquer que l'absence pure et simple.

Après chaque publication, réévaluez avec `eval` côté go-anon en passant les
mêmes ressources qu'à l'entraînement. C'est la seule façon de voir qu'une liste
dégrade le modèle qu'elle est censée aider.
