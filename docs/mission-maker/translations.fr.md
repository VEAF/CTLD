# Traductions { #translations }

CTLD s'adresse à vos joueurs dans leur propre langue. Chaque message affiché par le script —
entrées du menu F10, appels radio, textes d'état — passe par une couche de traduction : vous
pouvez ainsi choisir la langue dans laquelle tourne votre mission et redéfinir n'importe quelle
chaîne individuelle sans toucher au code de CTLD.

Si vous voulez comprendre les rouages internes (comment `ctld.tr()` résout une chaîne, comment
les traducteurs maintiennent les dictionnaires, comment contribuer une nouvelle langue),
consultez le [guide d'internationalisation](../developer/i18n.md) dans la documentation
développeur. Cette page ne couvre que ce dont un mission maker a besoin.

## Langues disponibles { #available-languages }

CTLD est livré avec quatre dictionnaires intégrés :

| Code | Langue |
| --- | --- |
| `en` | Anglais (référence) |
| `fr` | Français |
| `es` | Espagnol |
| `ko` | Coréen |

L'anglais est la référence : il contient toujours toutes les chaînes, il sert donc de repli
chaque fois qu'une traduction manque.

## Choisir la langue { #choosing-the-language }

La langue active est le **réglage `i18n_lang`** — définissez-le comme n'importe quel autre réglage,
dans `ctld-tools` ou à la main dans votre instantané de configuration :

```yaml
mm_facing:
  i18n_lang: fr
```

Les valeurs valides sont `en` (le défaut), `fr`, `es` et `ko`. C'est un choix au niveau de la
mission : il s'applique à tous les joueurs du serveur.

!!! note "L'ancien sélecteur fonctionne toujours"
    Les missions plus anciennes choisissaient la langue en éditant le haut de `src/CTLD_i18n.lua`
    (`ctld.i18n_lang = "fr"`), et cela fonctionne encore — CTLD lit d'abord le réglage `i18n_lang`,
    puis retombe sur cette variable globale du module, puis sur `en`. Préférez le réglage : il ne
    demande aucune modification de source et survit à une mise à jour de CTLD.

## Comment fonctionne le repli { #how-fallback-works }

Vous n'avez jamais à vous soucier d'un message vide ou manquant. Si une chaîne est absente ou
vide dans la langue active, CTLD bascule automatiquement, dans l'ordre :

1. le dictionnaire de la langue active,
2. le dictionnaire anglais,
3. le texte anglais lui-même.

Un message n'est **jamais** vide ni `nil`.

## Redéfinir des chaînes spécifiques { #overriding-specific-strings }

Vous pouvez modifier n'importe quelle chaîne depuis votre mission — sans avoir à éditer un
fichier source de CTLD. Déclarez `ctld.i18n_overrides` dans votre `CTLD_userConfig.lua` :

```lua
-- CTLD_userConfig.lua
ctld = ctld or {}

-- Override specific strings, per language
ctld.i18n_overrides = {
    fr = {
        ["Pack Vehicles"] = "Empaqueter vehicules",
        ["Drop Beacon"]   = "Poser balise radio",
    },
    en = {
        ["CTLD Commands"] = "Helicopter Commands",
    },
}
```

La clé de gauche est le texte anglais que CTLD utilise en interne ; la valeur de droite est ce
que voient les joueurs. Les overrides sont appliqués une seule fois au démarrage, par-dessus les
dictionnaires intégrés. Vous pouvez redéfinir n'importe quelle langue indépendamment de celle
qui est active — vous pouvez par exemple ajuster la formulation anglaise tout en faisant tourner
la mission en français.

## Pages liées { #related-pages }

- [Configuration](configuration.md) — réglages globaux et capacités par appareil
- [Configuration des zones](zones.md) — zones de troupes, logistique, extraction et waypoint
- [Catalogue des crates](crates-catalogue.md) — les crates que les pilotes peuvent spawn
