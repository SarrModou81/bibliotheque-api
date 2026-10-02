# Installer l'environnement pour faire de l'entrepôt de données (Windows)

Pour ce projet, il faut **4 outils**, à installer **dans cet ordre** :

| # | Outil | Rôle dans le projet | Gratuit ? |
|---|-------|---------------------|-----------|
| 1 | **SQL Server Developer** (moteur + Integration Services) | Héberge MACROBUS_PROD et MACROBUS_DWH_XXXX, exécute les packages SSIS | Oui (édition Developer) |
| 2 | **SSMS** (SQL Server Management Studio) | Écrire et exécuter les scripts SQL | Oui |
| 3 | **Visual Studio Community** + extension **SSIS Projects** | Créer le projet SSIS MACROBUS_ETL_XXXX | Oui |
| 4 | **Power BI Desktop** | Créer les visuels (partie B-2) | Oui |

> Configuration minimale conseillée : Windows 10/11 64 bits, 8 Go de RAM (16 Go conseillé), 25 Go d'espace disque libre, compte administrateur sur le PC.
> SSIS et Visual Studio ne fonctionnent **que sous Windows**. Sur un Mac, il faut une machine virtuelle Windows (Parallels, UTM, VirtualBox…).

---

## Étape 1 : installer SQL Server (édition Developer)

1. Allez sur <https://www.microsoft.com/fr-fr/sql-server/sql-server-downloads>.
2. Dans la section **Developer**, cliquez sur **Télécharger** (prenez SQL Server 2022 ou la version plus récente proposée).
3. Lancez le fichier téléchargé. Choisissez **Personnalisé (Custom)**, et **pas** « De base ». Le mode « De base » n'installe pas SSIS.
4. Choisissez un dossier de téléchargement du média, puis cliquez sur **Installer**. Le **Centre d'installation SQL Server** s'ouvre.
5. Menu de gauche **Installation**, puis **Nouvelle installation autonome de SQL Server**.
6. Édition : laissez **Developer**, acceptez la licence, puis cliquez sur *Suivant* (ignorez l'avertissement sur le pare-feu).
7. **Sélection des fonctionnalités** (étape importante). Cochez au minimum :
   - ✅ **Services Moteur de base de données** (Database Engine Services)
   - ✅ **Integration Services**
   - (facultatif) Recherche en texte intégral
8. **Configuration de l'instance** : choisissez **Instance par défaut** (MSSQLSERVER). Vous vous connecterez ensuite avec le nom `localhost` ou `.`
9. **Configuration du serveur** : laissez les comptes de service proposés.
10. **Configuration du moteur de base de données** :
    - Mode d'authentification : **Mode mixte** (Windows + SQL Server). Définissez un mot de passe pour `sa` et notez-le.
    - Cliquez sur **Ajouter l'utilisateur actuel** (indispensable, sinon vous n'aurez pas les droits d'administration).
11. Cliquez sur *Suivant*, puis **Installer**. Attendez la fin (10 à 20 min) : toutes les lignes doivent indiquer **Réussite**.

**Vérification** : ouvrez l'application **Services** de Windows (`services.msc`). Les services **SQL Server (MSSQLSERVER)** et **SQL Server Integration Services 16.0** doivent être à l'état *En cours d'exécution*.

---

## Étape 2 : installer SSMS (SQL Server Management Studio)

1. Allez sur <https://learn.microsoft.com/fr-fr/ssms/install/install> (ou cherchez « Télécharger SSMS »).
2. Téléchargez la dernière version de SSMS et lancez l'installeur. Les versions récentes s'installent avec le *Visual Studio Installer*, ce qui est normal.
3. Laissez les options par défaut, cliquez sur **Installer** et redémarrez le PC si on vous le demande.
4. Ouvrez **SSMS**. Dans la fenêtre de connexion :
   - Type de serveur : **Moteur de base de données**
   - Nom du serveur : `localhost` (ou `.\SQLEXPRESS` si vous avez installé Express par erreur)
   - Authentification : **Authentification Windows**
   - Cochez **Faire confiance au certificat du serveur (Trust server certificate)**. Sans cette case, les versions récentes de SSMS affichent une erreur de certificat.
5. Cliquez sur **Se connecter**. Votre serveur apparaît dans l'*Explorateur d'objets*.

---

## Étape 3 : installer Visual Studio et l'extension SSIS

### 3.1 Visual Studio Community

1. Allez sur <https://visualstudio.microsoft.com/fr/downloads/> et téléchargez **Visual Studio Community 2022**.
   L'extension SSIS est conçue pour VS 2022. Si une version plus récente vous est proposée, vérifiez sur la page de l'extension (étape 3.2) qu'elle est bien prise en charge avant de l'installer.
2. Lancez l'installeur. Dans l'onglet **Charges de travail**, cochez :
   - ✅ **Stockage et traitement des données** (Data storage and processing). Cette charge installe SSDT.
3. Cliquez sur **Installer**, puis redémarrez le PC.
4. Au premier lancement, connectez-vous (ou cliquez sur « Pas maintenant ») et choisissez un thème.

### 3.2 Extension « SQL Server Integration Services Projects »

1. **Fermez complètement Visual Studio.**
2. Allez sur le Marketplace : <https://marketplace.visualstudio.com/items?itemName=SSIS.MicrosoftDataToolsIntegrationServices>
   (ou dans VS : **Extensions > Gérer les extensions**, puis cherchez *Integration Services*).
3. Téléchargez et lancez `Microsoft.DataTools.IntegrationServices.exe`, puis suivez l'assistant.
4. Redémarrez Visual Studio.

**Vérification** : dans **Fichier > Nouveau > Projet**, tapez *Integration Services* dans la recherche. Le modèle **Projet Integration Services** doit apparaître.

### 3.3 Créer le projet SSIS du TP

1. **Fichier > Nouveau > Projet > Projet Integration Services**.
2. Nom du projet : **`MACROBUS_ETL_XXXX`** (XXXX = numéro du groupe).
3. Clic droit sur le projet, puis **Propriétés > Propriétés de configuration > Général > TargetServerVersion**. Choisissez la version de votre SQL Server (par ex. *SQL Server 2022*).
4. La suite (construction du package) est détaillée dans **`02_GUIDE_SSIS.md`**.

---

## Étape 4 : installer Power BI Desktop

- Le plus simple : ouvrez le **Microsoft Store**, cherchez **Power BI Desktop** et cliquez sur *Installer*.
- Sinon : <https://www.microsoft.com/fr-fr/power-platform/products/power-bi/desktop>.

---

## Problèmes fréquents

| Symptôme | Solution |
|----------|----------|
| SSMS : *« The certificate chain was issued by an authority that is not trusted »* | Cochez **Trust server certificate** dans la fenêtre de connexion (onglet *Options* ou *Sécurité de connexion*). |
| SSMS : *« Cannot connect to localhost »* | Vérifiez que le service **SQL Server (MSSQLSERVER)** est démarré dans `services.msc`. Si vous avez installé une instance nommée, utilisez `.\NOM_INSTANCE`. |
| Pas de modèle « Projet Integration Services » dans VS | L'extension n'est pas installée ou VS était ouvert pendant son installation. Réinstallez l'extension avec VS fermé. |
| SSIS : *« The product level is insufficient for component… »* à l'exécution | La fonctionnalité **Integration Services** n'a pas été cochée à l'étape 1.7. Relancez l'installation de SQL Server et choisissez **Ajouter des fonctionnalités**. |
| Erreur de connexion OLE DB dans SSIS | Dans le gestionnaire de connexions, utilisez le fournisseur **Microsoft OLE DB Driver for SQL Server** et réglez *Use Encryption* sur **Optional** ou cochez *Trust Server Certificate*. |
| Script 03 ou 04 : *« Invalid object name MACROBUS_PROD.dbo… »* | Exécutez d'abord le script 01. Les deux bases doivent être sur la **même instance**. |
