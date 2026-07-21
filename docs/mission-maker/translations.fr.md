# Traductions { #translations }

CTLD s'adresse à vos joueurs dans leur propre langue. Chaque message affiché par le script —
entrées du menu F10, appels radio, textes d'état — passe par une couche de traduction : vous
pouvez ainsi choisir la langue dans laquelle tourne votre mission et redéfinir n'importe quelle
chaîne individuelle sans toucher au code de CTLD.

Si vous voulez comprendre les rouages internes (comment `ctld.tr()` résout une chaîne, comment
les traducteurs maintiennent les dictionnaires, comment contribuer une nouvelle langue),
consultez le [guide d'internationalisation](../developer/i18n.md) dans la documentation
développeur. Cette page ne couvre que ce dont un mission maker a besoin.

## Langues disponibles

CTLD est livré avec quatre dictionnaires intégrés :

| Code | Langue |
| --- | --- |
| `en` | Anglais (référence) |
| `fr` | Français |
| `es` | Espagnol |
| `ko` | Coréen |

L'anglais est la référence : il contient toujours toutes les chaînes, il sert donc de repli
chaque fois qu'une traduction manque.

## Choisir la langue

La langue active est sélectionnée en haut de `src/CTLD_i18n.lua`. Décommentez la seule ligne
souhaitée et laissez les autres en commentaire :

```lua
ctld.i18n_lang = "en"
--ctld.i18n_lang = "fr"
--ctld.i18n_lang = "es"
--ctld.i18n_lang = "ko"
```

Une seule ligne doit être active à la fois ; la valeur par défaut est `en`. Ce sélecteur vit
dans son propre fichier, séparé de la logique principale, afin qu'un traducteur non développeur
puisse le modifier sans toucher au moindre script.

## Comment fonctionne le repli

Vous n'avez jamais à vous soucier d'un message vide ou manquant. Si une chaîne est absente ou
vide dans la langue active, CTLD bascule automatiquement, dans l'ordre :

1. le dictionnaire de la langue active,
2. le dictionnaire anglais,
3. le texte anglais lui-même.

Un message n'est **jamais** vide ni `nil`.

## Redéfinir des chaînes spécifiques

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

## Pages liées

- [Configuration](configuration.md) — réglages globaux et capacités par appareil
- [Configuration des zones](zones.md) — zones de troupes, logistique, extraction et waypoint
- [Catalogue des crates](crates-catalogue.md) — les crates que les pilotes peuvent spawn
