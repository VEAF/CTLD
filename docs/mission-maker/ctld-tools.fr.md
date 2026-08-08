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

### L'outil embarque son propre CTLD { #the-tool-carries-its-own-ctld }

L'exe **embarque le `CTLD.lua` qu'il installe**, construit depuis le commit sur lequel sa release a
été taguée. Il ne télécharge rien et ne se met jamais à jour tout seul : il fonctionne sans réseau,
et le même exe installe toujours le même moteur.

Une nouvelle version de CTLD n'arrive donc dans vos missions que lorsqu'une **release est publiée** —
le travail courant fusionné dans le dépôt ne change rien pour vous. Pour en profiter, retéléchargez
`ctld-tools.exe` depuis la page [Releases](https://github.com/VEAF/CTLD/releases) et réinjectez dans
votre mission ; réinjecter remplace ce que l'outil avait écrit au lieu de le dupliquer.

!!! note "Les *release candidates* ne portent pas le badge *Latest*"
    Tant que la v2 est en release candidate, chaque release est publiée en **pré-version**, et GitHub
    réserve le badge *Latest* aux versions stables. Prenez l'entrée la plus haute de la page Releases.

On peut aussi vous transmettre un **build de développement** : un `ctld-tools.exe` construit à partir
du travail du jour plutôt que d'une release, reconnaissable au commit inscrit dans sa version
(`2.0.0-rc6-a1b2c3d`). N'en prenez un que si quelqu'un vous demande d'essayer quelque chose de
précis : il n'a ni notes de version, ni documentation propre.

## Ouvrir l'outil { #open-it }

**Double-cliquez `ctld-tools.exe`.** Une petite fenêtre console s'ouvre — c'est le serveur local ;
laissez-la ouverte, la fermer quitte l'outil — et votre **navigateur** s'ouvre sur l'application.
Aucune commande à taper.

L'application **démarre sur la configuration par défaut de CTLD** : il n'y a rien à charger avant de
commencer.

(Depuis un terminal vous pouvez aussi lancer `ctld-tools serve`. Le même fichier est aussi un outil
en ligne de commande — utilisé par le build de CTLD — mais en tant que Mission Maker vous n'en aurez
pas besoin.)

## Se repérer { #finding-your-way-around }

Un bandeau en haut montre les trois étapes : **Charger → Régler → Injecter dans la mission**, l'étape
courante étant mise en évidence. L'en-tête indique en permanence quelle configuration est ouverte,
combien de réglages vous avez modifiés, et si votre travail est enregistré.

!!! tip "Interface en français"
    L'interface suit la langue de votre Windows, et un sélecteur **Langue** dans l'en-tête permet de
    basculer entre français et anglais à tout moment — y compris les textes d'aide des réglages.
    Votre choix est mémorisé.

!!! tip "Aide intégrée"
    Le bouton **Aide** de l'en-tête ouvre un guide de l'éditeur dans votre langue : les trois étapes,
    comment lire un réglage, ce que signifie le voyant de validation, et la règle du snapshot complet.
    Il liste aussi **votre** configuration — chaque famille avec ce qu'elle couvre, et chaque tableau
    de données de mission avec le nombre d'entrées qu'il contient. Il est généré depuis la
    configuration ouverte : il décrit donc toujours ce que vous avez réellement sous les yeux.

La colonne de gauche liste les **familles fonctionnelles** de CTLD — Général, Appareils, Caisses,
Troupes, Zones, Embarquement, FOB / FARP, JTAC, Reconnaissance, Système AA, Beacons, Fumigènes,
Mines, Parachute, Poids soldats. Choisissez une famille et vous obtenez **tout** ce qui concerne
cette partie de CTLD au même endroit : ses réglages *et* ses entrées de catalogue, avec une phrase
sous le titre qui indique ce que couvre la famille. Caisses, par exemple, contient les réglages des
caisses *et* la liste des caisses que vous pouvez faire apparaître.

Dans une famille, les réglages sont séparés en **Réglages courants** et une section **Réglages
avancés** qui reste repliée jusqu'à ce que vous en ayez besoin (elle s'ouvre d'elle-même si elle
contient un réglage que vous avez modifié).

**Vous ne savez pas où se trouve un réglage ?** Utilisez le **champ de recherche** : il parcourt
toutes les familles à la fois, par nom ou par description, et indique à quelle famille appartient
chaque résultat.

## Éditer votre configuration { #editing-your-configuration }

Chaque réglage affiche un **nom en langage clair**, son unité quand CTLD la documente (mètres,
kilogrammes, secondes), une courte description, et l'éditeur adapté à son type — un interrupteur pour
on/off, une liste déroulante pour les choix fixes, un champ nombre ou texte sinon. Le **nom technique
du réglage** (celui utilisé dans la documentation CTLD et sur les forums) est affiché à côté en petit.

Les entrées de catalogue — **caisses**, **groupes de troupes**, **capacités des aéronefs** (choisir un
type d'aéronef dans la liste DCS), **zones**, noms des pilotes de transport, poids des véhicules —
s'éditent sous forme de tableaux, en bas de la famille à laquelle elles appartiennent.

### Annuler une modification { #undoing-a-change }

Tout réglage que vous modifiez est marqué **modifié**, et la famille reçoit un compteur dans la
colonne de gauche : vous voyez donc toujours ce que vous avez touché. Une **flèche de
réinitialisation** apparaît à côté d'un réglage modifié et remet la valeur par défaut de CTLD.

Vous préférez repartir de zéro ? **Partir des défauts CTLD**. Pour reprendre une configuration
précédente, utilisez **Ouvrir un fichier de config…** (dialogue de fichier natif). Les deux vous
avertissent d'abord si vous avez des modifications non enregistrées.

### Validation { #validation }

La **validation en direct** s'exécute pendant que vous éditez. Un voyant dans l'en-tête indique
**VALIDE** ou **À VÉRIFIER**, et un panneau au-dessus des réglages liste chaque problème en langage
clair — types d'unités DCS inconnus, poids de caisse en double, etc. Cliquez sur un problème et
l'application saute directement au réglage concerné.

## Enregistrer et utiliser { #saving-and-using-it }

- **Enregistrer sous…** écrit votre configuration dans un fichier (dialogue d'enregistrement natif)
  pour la rouvrir plus tard.
- **Injecter dans la mission…** choisit une mission et y insère votre configuration comme trigger
  MISSION START, prête à jouer. Le bouton reste **désactivé tant qu'une erreur de validation
  subsiste**.

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
CTLD plus ancien, l'outil vous le signale et résume en quoi les défauts actuels diffèrent — réglages
ajoutés, réglages devenus inutiles, valeurs par défaut modifiées — chaque groupe pouvant être déplié
pour le détail. **Rien n'est fusionné** : vos réglages restent exactement tels quels, et vous décidez
de ce que vous mettez à jour avant de ré-injecter.

## Charger à la main (alternative à l'injection) { #loading-it-by-hand-alternative-to-inject }

Si vous préférez ajouter le trigger vous-même, chargez la configuration exactement comme le modèle
écrit à la main :

1. **MISSION START → DO SCRIPT FILE** → votre `CTLD_userConfig.lua`
2. **MISSION START → DO SCRIPT FILE** → `CTLD.lua`

Le trigger de configuration doit venir **avant** le trigger CTLD. Voir
[Configuration](configuration.fr.md) pour la voie Lua manuelle — pleinement supportée pour les
utilisateurs avancés ; `ctld-tools` est la voie recommandée pour la plupart des missions.
