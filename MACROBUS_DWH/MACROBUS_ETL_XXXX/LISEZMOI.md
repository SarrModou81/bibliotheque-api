# Projet SSIS MACROBUS_ETL_XXXX

Ce dossier contient le package **`Chargement_DWH.dtsx`** :

```
SEQ Dimensions niveau 1  (8 tâches Exécuter SQL en parallèle)
   DimProductLine · DimFournisseur · DimContact · DimOffice
   DimCommerciaux · DimManagers · DimGeographieOffice · DimGeographieClient
        │ succès
SEQ Dimensions niveau 2 flocon  (lookup de la dimension parente)
   DimProduct · DimCustomers · DimEmployees
        │ succès
SQL Charger FaitOrders  →  EXEC dbo.ps_ChargerFaitOrders
```

## Mise en place (5 minutes)
1. Dans SSMS, exécutez les scripts `01`, `02`, `03` et `04`. Le package appelle les procédures créées par les scripts 03 et 04.
2. Dans Visual Studio : **Fichier > Nouveau > Projet > Projet Integration Services**, et nommez-le **`MACROBUS_ETL_XXXX`**.
3. Dans l'Explorateur de solutions, supprimez le `Package.dtsx` vide. Faites ensuite un clic droit sur **Packages SSIS**, puis **Ajouter un package existant…**, choisissez *Système de fichiers* et sélectionnez `Chargement_DWH.dtsx`.
4. Ouvrez le package. Si les tâches sont empilées les unes sur les autres, utilisez le menu **Format > Disposition automatique > Diagramme**.
5. Double-cliquez sur le gestionnaire de connexions **CM_DWH** et vérifiez le serveur (`localhost`) et la base (`MACROBUS_DWH_XXXX`, avec votre numéro de groupe).
6. Lancez le package avec **F5** : toutes les tâches doivent passer au vert. Vérifiez ensuite dans SSMS :
   `SELECT COUNT(*) FROM MACROBUS_DWH_XXXX.dbo.FaitOrders;  -- 2996`

La connexion utilise le fournisseur `SQLOLEDB`, intégré à Windows, donc rien à installer. Vous pouvez le remplacer par *Microsoft OLE DB Driver for SQL Server* dans l'éditeur de connexion.

Pour une version avec **Data Flows** (Source, Lookup, Destination), suivez `docs/02_GUIDE_SSIS.md`.

**À rendre** : le dossier complet du projet créé dans Visual Studio (`.sln`, `.dtproj` et `.dtsx`), zippé.
