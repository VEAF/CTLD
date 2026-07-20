# Configurer CTLD avec `ctld-tools`

`ctld-tools` est un petit outil en ligne de commande qui permet de configurer CTLD **sans écrire de
Lua**. Vous décrivez vos changements dans un court **`user-config.yaml`** — en désignant crates et
groupes de troupes **par leur nom** — et l'outil valide le fichier puis génère le
`CTLD_userConfig.lua` que votre mission charge.

Vous n'avez jamais à retrouver le poids d'une crate, et les erreurs sont détectées chez vous (avec
des suggestions) au lieu de l'être dans DCS.

## Récupérer l'outil

Téléchargez **`ctld-tools.exe`** depuis la page [GitHub Releases](https://github.com/VEAF/CTLD/releases)
— il est attaché à chaque release. Pas besoin de Python. (Les développeurs peuvent aussi le lancer
depuis les sources avec `poetry` ; voir la doc développeur.)

Placez-le où vous voulez ; lancez-le depuis un terminal dans le dossier de votre mission.

## Le flux de travail

```
ctld-tools gen-user --scaffold --out user-config.yaml          # 1. squelette commenté
#   ... éditez user-config.yaml ...                            # 2. décrivez vos changements
ctld-tools validate  --yaml user-config.yaml --src chemin/vers/src # 3. vérifiez
ctld-tools gen-user  --yaml user-config.yaml --src chemin/vers/src --out CTLD_userConfig.lua  # 4. générez
#   ... chargez CTLD_userConfig.lua avant CTLD.lua dans l'éditeur de mission ...  # 5. utilisez
```

`--src` pointe vers le dossier `src/` de CTLD (le catalogue de référence) : l'outil le lit pour
résoudre les noms et savoir quelles crates, groupes de troupes et types d'unités DCS existent.

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

### `troops` — ajouter / retirer

```yaml
troops:
  add:
    - name: Recon Team
      inf: 3
      jtac: 1
  remove:
    - 5x - Mortar Squad
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
| `gen-user --scaffold --out user-config.yaml` | Écrit un fichier de départ commenté. |
| `validate --yaml user-config.yaml --src src` | Vérifie le fichier ; affiche les constats, code non-zéro en cas d'erreur. |
| `gen-user --yaml user-config.yaml --src src --out CTLD_userConfig.lua` | Compile en Lua (valide d'abord, refuse en cas d'erreur). |
| `inject --miz mission.miz --userconfig CTLD_userConfig.lua [--out out.miz]` | Injecte le Lua généré dans un `.miz` comme trigger MISSION START (optionnel — voir plus bas). |

**Ce que la validation vérifie :** chaque `unit` est un vrai type DCS ; une crate que vous
`remove`/`patch` existe (et n'est pas ambiguë) ; une crate `add` a un `weight_kg` unique ; les
groupes de troupes et réglages-listes existent. Un nom inconnu reçoit une suggestion *« vouliez-vous
dire … ? »*.

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
