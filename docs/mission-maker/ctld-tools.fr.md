# Configurer CTLD avec `ctld-tools`

`ctld-tools` permet de configurer CTLD **sans écrire de Lua**. Vous décrivez vos changements — en
désignant crates et groupes de troupes **par leur nom** — et l'outil les valide puis génère le
`CTLD_userConfig.lua` que votre mission charge. Deux façons de l'utiliser : un **éditeur interactif**
(la commande `tui`, recommandée) ou un **flux en ligne de commande** sur un `user-config.yaml`.

Vous n'avez jamais à retrouver le poids d'une crate, et les erreurs sont détectées chez vous (avec
des suggestions) au lieu de l'être dans DCS.

## Récupérer l'outil

Téléchargez **`ctld-tools.exe`** depuis la page [GitHub Releases](https://github.com/VEAF/CTLD/releases)
— il est attaché à chaque release. **Pas besoin de Python ni du dossier `src/` de CTLD** : le
catalogue de référence (crates, groupes de troupes, types d'unités DCS) est **embarqué dans
l'outil**. (Les développeurs peuvent aussi le lancer depuis les sources avec `poetry` ; voir la doc
développeur.)

Placez-le où vous voulez ; lancez-le depuis un terminal dans le dossier de votre mission.

## L'éditeur interactif (`ctld-tools tui`) — recommandé

```
ctld-tools tui                            # ouvre user-config.yaml ici s'il existe, sinon démarre vide
ctld-tools tui --yaml chemin/vers/autre.yaml  # ou pointer un autre fichier
```

Une console plein écran — aucun YAML à écrire, aucune commande à enchaîner :

- **Éditeur structuré** : votre config est présentée par section (**settings**, **crates**,
  **troops**, **arrays**), avec la validation en direct à droite.
- **Ajouter / Retirer / Modifier** : trois boutons pilotent tout. Choisissez l'action, puis le type
  d'objet (crate, groupe de troupes, réglage, réglage-liste), puis remplissez un formulaire guidé.
  **Modifier** fonctionne sur les crates comme sur les groupes de troupes (change un champ, garde le
  reste).
- **Sélecteurs à filtrage instantané** : choisissez le `unit` d'une crate parmi les ~1100 types
  DCS, ou une crate / un groupe de troupes / un **réglage** par nom, en tapant quelques lettres
  plutôt qu'en faisant défiler. Quand vous choisissez un réglage, sa **valeur par défaut est affichée
  et pré-remplie**, vous partez donc de la vraie valeur par défaut. Pour un réglage **vrai/faux**, ou
  à **valeurs prédéfinies** (ex. `JTAC_lock` : all / vehicle / troop), vous **choisissez la valeur
  dans une liste** au lieu de la taper.
- **Modifications non enregistrées** : quitter avec des modifications non sauvegardées demande
  confirmation et rappelle quand vous avez enregistré pour la dernière fois.
- **Validation en direct** : chaque modification est vérifiée immédiatement contre le catalogue
  embarqué, avec erreurs en ligne et suggestions *« vouliez-vous dire … ? »*.
- **Éditer une ligne** : sélectionnez une entrée dans l'arbre et pressez **e** pour rouvrir son
  formulaire pré-rempli — corrigez une erreur (ex. une crate ajoutée sans nom) au lieu de tout
  supprimer et re-saisir.
- **Supprimer une ligne** : sélectionnez une entrée dans l'arbre et pressez **Suppr** pour la retirer
  (avec confirmation) — pratique pour défaire ce que vous venez d'ajouter.
- **Annuler / Rétablir** : **Ctrl+Z** / **Ctrl+Y** parcourent vos modifications.
- **Tout au même endroit** : **Enregistrer** (toujours le même `user-config.yaml`, sans question),
  **Générer** le `CTLD_userConfig.lua` à côté (son nom est imposé — CTLD l'exige), ou **Injecter**
  directement dans un `.miz` (choisissez la mission dans un **navigateur de fichiers** qui ne liste
  que les `.miz`) — depuis le même écran. La génération est refusée tant qu'une erreur subsiste, vous
  ne livrez donc jamais une config cassée.
- **Langue** : l'interface suit la **langue du système** (français ou anglais). Forcez-la avec
  `ctld-tools tui --lang fr` / `--lang en` (ou la variable d'environnement `CTLD_LANG`).

## Le flux en ligne de commande

Si vous préférez les scripts ou un pipeline sans interface, les mêmes opérations sont disponibles en
commandes :

```
ctld-tools gen-user --scaffold --out user-config.yaml   # 1. squelette commenté
#   ... éditez user-config.yaml ...                      # 2. décrivez vos changements
ctld-tools validate  --yaml user-config.yaml             # 3. vérifiez
ctld-tools gen-user  --yaml user-config.yaml --out CTLD_userConfig.lua  # 4. générez
#   ... chargez CTLD_userConfig.lua avant CTLD.lua dans l'éditeur de mission ...  # 5. utilisez
```

Le catalogue embarqué est utilisé par défaut. Les développeurs travaillant dans le dépôt peuvent
ajouter `--src chemin/vers/src` pour résoudre les noms contre un dossier `src/` de CTLD vivant.

## Le format `user-config.yaml`

Quatre sections optionnelles de premier niveau. **N'incluez que ce que vous changez.** Les crates et
groupes de troupes sont désignés **par leur nom**.

### `settings` — valeurs simples

```yaml
settings:
  numberOfTroops: 8
  slingLoad: true
```

### `crates` — ajouter / retirer / modifier

```yaml
crates:
  add:
    - section: Support        # sous-menu F10
      name: Ural Ammo         # libellé affiché dans le menu
      unit: Ural-375          # nom de type DCS (validé)
      side: 1                 # 1=RED, 2=BLUE, omis=les deux
      cratesRequired: 2
      weight_kg: 2000         # masse de la crate en kg (aussi sa clé unique)
  remove:
    - Heavy Tank - Abrams     # par nom — pas de poids à retrouver
  patch:
    - name: Humvee - TOW      # change un champ, garde le reste
      cratesRequired: 3
```

### `troops` — ajouter / retirer / modifier

```yaml
troops:
  add:
    - name: Recon Team
      inf: 3
      jtac: 1
  remove:
    - 5x - Mortar Squad
  patch:
    - name: Standard Group   # change un champ, garde le reste
      inf: 8
```

### `arrays` — ajouter à des réglages de type liste

```yaml
arrays:
  transportPilotNames: [helicargo_custom_1]
  troopZones:
    - [pickzone_north, green, -1, yes, 0]
```

!!! tip "Block ou flow — au choix"
    Tout ce qui précède est en style *block* (indenté, lisible). Vous pouvez aussi écrire le style
    *flow* compact ; c'est le même YAML :
    ```yaml
    crates:
      add:
        - { section: Support, name: Ural Ammo, unit: Ural-375, side: 1, weight_kg: 2000 }
    ```

## Commandes

| Commande | Rôle |
|---|---|
| `tui [--yaml user-config.yaml]` | Lance l'éditeur interactif (recommandé). |
| `gen-user --scaffold --out user-config.yaml` | Écrit un fichier de départ commenté. |
| `validate --yaml user-config.yaml` | Vérifie le fichier ; affiche les constats, code non-zéro en cas d'erreur. |
| `gen-user --yaml user-config.yaml --out CTLD_userConfig.lua` | Compile en Lua (valide d'abord, refuse en cas d'erreur). |
| `inject --miz mission.miz --userconfig CTLD_userConfig.lua [--out out.miz]` | Injecte le Lua généré dans un `.miz` comme trigger MISSION START (optionnel — voir plus bas). |

Toutes les commandes utilisent la référence embarquée par défaut ; ajoutez `--src chemin/vers/src`
(dev uniquement) pour résoudre contre un dossier `src/` de CTLD vivant.

**Ce que la validation vérifie :** chaque `unit` est un vrai type DCS ; une crate que vous
`remove`/`patch` existe (et n'est pas ambiguë) ; une crate `add` — ou dont vous changez le poids par
`patch` — a un `weight_kg` unique ; les groupes de troupes et réglages-listes existent. Un nom
inconnu reçoit une suggestion *« vouliez-vous dire … ? »*.

## Chargement dans l'éditeur de mission

Le `CTLD_userConfig.lua` généré se charge exactement comme le modèle écrit à la main :

1. **MISSION START → DO SCRIPT FILE** → `CTLD_userConfig.lua`
2. **MISSION START → DO SCRIPT FILE** → `CTLD.lua`

Le trigger du user-config doit venir **avant** le trigger CTLD.

### Injection automatique (optionnel)

Plutôt que d'ajouter le trigger à la main, `ctld-tools inject` le pose pour vous — un trigger
MISSION START placé **en premier**, donc exécuté avant votre trigger CTLD. C'est **idempotent**
(ré-injecter met à jour le même trigger au lieu de le dupliquer) :

```
ctld-tools inject --miz MaMission.miz --userconfig CTLD_userConfig.lua --out MaMission.injected.miz
```

!!! warning "Sauvegardez votre mission et testez-la dans DCS"
    L'injection modifie directement les triggers de la mission. **Gardez une sauvegarde** (utilisez
    `--out` pour écrire une copie), et ouvrez le résultat dans DCS une fois pour confirmer qu'il se
    charge et que CTLD prend bien votre config. L'outil valide la structure du fichier, mais seul DCS
    confirme que la mission tourne.

!!! note "Vous préférez écrire le Lua à la main ?"
    C'est toujours possible — voir [Configuration](configuration.md). `ctld-tools` est la voie
    recommandée pour la plupart des missions, mais le modèle Lua reste pleinement pris en charge pour
    les utilisateurs avancés.
