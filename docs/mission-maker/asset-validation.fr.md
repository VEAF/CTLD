# Valider votre config pendant le développement { #validating-your-config-during-development }

CTLD ne vérifie **plus** les noms de types DCS au démarrage de la mission — il ne spawn plus d'objets
sonde cachés (ça gaspillait des ressources et émettait des events de naissance/mort parasites que
votre logique de mission pouvait voir). À la place, une faute de frappe ou un mod manquant se révèle
au **développement** via un script compagnon optionnel.

## Le compagnon asset-check { #the-asset-check-companion }

`CTLD_asset_check.lua` est un outil dev-time optionnel (téléchargez-le depuis les assets de release).
Chargé après CTLD, il examine tout ce que votre mission configure — `spawnableCrates`, parts de
systèmes AA, `loadableGroups`, objets de scènes — et affiche un message :

- **OK** — chaque type DCS configuré est un type stock connu ou un type mod déclaré ; ou
- **WARN** — une liste de types inconnus (faute de frappe probable, ou un mod non déclaré).

C'est une simple lecture : **aucun objet n'est spawné, aucun event n'est émis.**

### Utilisation { #how-to-use-it }

1. Téléchargez `CTLD_asset_check.lua` depuis la [release CTLD](https://github.com/VEAF/CTLD/releases).
2. Dans l'éditeur de mission, ajoutez un déclencheur `DO SCRIPT FILE` au **démarrage de la mission**,
   **après** le déclencheur qui charge `CTLD.lua`.
3. Lancez la mission une fois et lisez le message à l'écran (et `CTLD.log`). Corrigez toute faute
   signalée.
4. **Retirez le déclencheur du compagnon pour la production** — c'est une aide au développement.

### Déclarer les types mod { #declaring-mod-types }

Si votre config utilise légitimement le type DCS d'un mod, indiquez-le à CTLD pour que le compagnon
ne le signale pas — listez le(s) nom(s) exact(s) dans le setting `modTypes` (dans `ctld-tools`, c'est
une liste éditable de noms de type DCS) :

```yaml
advanced:
  modTypes:
  - Your_Mod_Type
  - Another_Mod_Type
```

Tous les *autres* types restent vérifiés, donc une vraie faute de frappe est toujours détectée. (Les
scènes déclarent leurs propres types mod dans `modTypes` sur le modèle de scène — voir
[Scènes & FOB](scenes-fob.md).)

!!! note "Votre responsabilité"
    Le compagnon confirme qu'un *nom* de type est connu ; il ne peut pas confirmer que chaque client
    a bien le mod installé. S'assurer que les mods requis sont présents sur tous les clients reste de
    votre ressort.
