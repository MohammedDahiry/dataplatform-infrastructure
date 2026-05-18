# Rapport PFE — Cloud Data Platform

Rapport LaTeX généré pour la soutenance (structure calquée sur le modèle ENSA Safi / rapport de référence).

## Compilation

```bash
cd rapport
# Installer (une fois) : texlive-full ou texlive-lang-french + biber
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
```

Ou avec `latexmk` :

```bash
latexmk -pdf -interaction=nonstopmode main.tex
```

## Personnalisation urgente

1. **`preamble.tex`** : noms encadrants, jury, dates, école.
2. **`front/title.tex`** : titre exact, période de stage.
3. **Images** : placer logos dans `rapport/images/` (sevenapp, eqdom, captures démo).
4. **Figures manquantes** : les fichiers `\includegraphics` pointent vers `images/` — ajoutez captures ou commentez les `\includegraphics` temporairement.

## État du projet dans le rapport

Le chapitre 5 distingue **livré dans le dépôt** vs **validation en environnement réel** (honnête pour une soutenance proche).
