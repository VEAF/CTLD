# Configurer CTLD avec `ctld-tools` { #configuring-ctld-with-ctld-tools }

`ctld-tools` permet de configurer CTLD **sans écrire de Lua**. C'est une petite **application web
locale** : vous la double-cliquez, elle s'ouvre dans votre navigateur, et vous éditez la
configuration complète de CTLD via des formulaires — chaque réglage et chaque entrée du catalogue
(caisses, groupes de troupes, aéronefs, zones). Vos changements sont validés à votre bureau, avec des
erreurs claires, et injectés directement dans votre mission.

Vous ne cherchez jamais un poids de caisse ni n'éditez de Lua à la main, et les erreurs sont
détectées avant DCS.

## Récupérer l'outil { #get-the-tool }

Téléchargez **`ctld-tools.exe`** depuis la page [GitHub Releases](https://github.com/VEAF/CTLD/releases)
— il est attaché à chaque release. **Ni Python, ni Node, ni dossier `src/` de CTLD requis** : tout
(la configuration par défaut, la liste des types d'unités DCS, l'interface web) est embarqué dans le
fichier unique.

!!! warning "Débloquez d'abord le .exe (Windows)"
    Windows peut bloquer les fichiers `.exe` téléchargés depuis internet. Si l'outil ne démarre pas,
    clic droit sur `ctld-tools.exe` → **Propriétés** → onglet **Général** → cochez **Débloquer** en
    bas → **OK**.

## Ouvrir l'outil { #open-it }

**Double-cliquez `ctld-tools.exe`.** Une petite fenêtre console s'ouvre — c'est le serveur local ;
laissez-la ouverte, la fermer quitte l'outil — et votre **navigateur** s'ouvre sur l'application.
Aucune commande à taper.

(Depuis un terminal vous pouvez aussi lancer `ctld-tools serve`. Le même fichier est aussi un outil
en ligne de commande — utilisé par le build de CTLD — mais en tant que Mission Maker vous n'en aurez
pas besoin.)

## Éditer votre configuration { #editing-your-configuration }

L'application montre la **configuration complète** de CTLD, répartie en deux écrans :

- **Parameters** — *comment CTLD se comporte* : les réglages, regroupés en **familles**
  fonctionnelles (General, Crates, Troops, JTAC, FOB / FARP, AA system, Parachute, …), chacune
  divisée en **Standard** (les courants) et **Advanced**. Chaque champ a le bon éditeur — une case à
  cocher pour on/off, une liste déroulante pour les choix fixes, un champ nombre ou texte sinon — avec
  une courte description en aide.
- **Data** — *ce sur quoi CTLD opère* : le catalogue — **crates**, **troop groups**, **aircraft
  capabilities** (choisir un type d'aéronef dans la liste DCS), **zones**, noms des pilotes de
  transport, poids des véhicules. Ajoutez, éditez et supprimez des entrées via des formulaires.

Partez de **Load defaults** (la configuration d'usine de CTLD) ou **Open…** pour ouvrir une
configuration enregistrée précédemment (une boîte de dialogue de fichier native).

La **validation en direct** s'exécute pendant que vous éditez : types d'unités DCS inconnus, poids de
caisse en double et autres problèmes apparaissent immédiatement, pour ne jamais livrer une config
cassée.

## Enregistrer et utiliser { #saving-and-using-it }

- **Save…** écrit votre configuration dans un fichier (dialogue d'enregistrement natif) pour la
  rouvrir plus tard.
- **Inject to .miz…** choisit une mission et y insère votre configuration comme trigger MISSION
  START, prête à jouer. L'injection est **refusée tant qu'une erreur de validation subsiste**.

L'injection est **idempotente** — ré-injecter met à jour le même trigger au lieu de le dupliquer — et
place le trigger **en premier**, pour qu'il s'exécute avant CTLD.

!!! warning "Sauvegardez votre mission et testez-la dans DCS"
    L'injection modifie la mission directement. Gardez une sauvegarde, et ouvrez le résultat dans DCS
    une fois pour confirmer qu'elle charge et que CTLD prend votre config. L'outil valide la
    structure, mais seul DCS confirme que la mission tourne.

## Le modèle de snapshot complet { #the-complete-snapshot-model }

Votre configuration est un **snapshot complet**, pas une liste de changements : elle **remplace
entièrement** les valeurs par défaut de CTLD. Ce que vous retirez est absent à l'exécution — pas
remis silencieusement au défaut. C'est pourquoi vous partez toujours **des défauts** (ou d'une config
existante) : pour ne rien perdre par accident.

### Quand CTLD est mis à jour { #when-ctld-is-updated }

CTLD estampille une **version** sur sa configuration. Quand vous ouvrez une config écrite pour un
CTLD plus ancien, l'outil affiche un **popup** listant en quoi les défauts actuels diffèrent
(réglages ajoutés, retirés, valeurs changées) pour que vous puissiez vérifier avant de ré-injecter —
jamais de fusion silencieuse.

## Charger à la main (alternative à l'injection) { #loading-it-by-hand-alternative-to-inject }

Si vous préférez ajouter le trigger vous-même, chargez la configuration exactement comme le modèle
écrit à la main :

1. **MISSION START → DO SCRIPT FILE** → votre `CTLD_userConfig.lua`
2. **MISSION START → DO SCRIPT FILE** → `CTLD.lua`

Le trigger de configuration doit venir **avant** le trigger CTLD. Voir
[Configuration](configuration.fr.md) pour la voie Lua manuelle — pleinement supportée pour les
utilisateurs avancés ; `ctld-tools` est la voie recommandée pour la plupart des missions.
