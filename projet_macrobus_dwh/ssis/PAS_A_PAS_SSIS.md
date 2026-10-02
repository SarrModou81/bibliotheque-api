# SSIS clic par clic : de `MACROBUS_PROD` vers `MACROBUS_DWH_2`

Point de départ : le projet **MACROBUS_ETL_2** est ouvert dans Visual Studio, et `Package.dtsx` contient
une *Tâche de flux de données* avec une **Source OLE DB** et une **Destination OLE DB** non configurées.

Principe de chaque package de dimension :

```
Source OLE DB (MACROBUS_PROD)
   -> [Recherche du parent]        (seulement pour un flocon : récupère la clé du parent)
   -> Recherche "Existe déjà ?"    (compare avec la dimension du DWH)
        -> sortie SANS correspondance -> Destination OLE DB (MACROBUS_DWH_2)
```
Seules les lignes **nouvelles** sont insérées. On peut donc relancer le package autant de fois que l'on
veut sans créer de doublons.

---

## Étape 0 — Préparer les bases (SSMS, une seule fois)

Dans SSMS, ouvrir puis exécuter (F5) les scripts du dossier `sql/`, **dans cet ordre** :

| Ordre | Script | Résultat |
|---|---|---|
| 1 | `00_MACROBUS_PROD_complet.sql` | Base **MACROBUS_PROD** avec toutes les données (contrôle : 326 commandes, 2 996 lignes) |
| 2 | `01_creation_DWH.sql` | Base **MACROBUS_DWH_2** : tables du flocon **vides**, sauf les lignes « Inconnu » (-1) |
| 3 | `02_procedures_chargement_dimensions.sql` | Procédures, dont `sp_ChargerDimDate` |
| 4 | `03_procedure_chargement_fait.sql` | `sp_ChargerFaitOrders` (chargement du fait) |
| 5 | `06_vues_PowerBI.sql` | Vues pour Power BI |

> ⚠️ N'exécutez **pas** `sp_ChargerToutesDimensions` : ce sont vos packages SSIS qui doivent remplir les dimensions.

**Nom de votre serveur** : c'est celui affiché dans la fenêtre de connexion de SSMS (par exemple `.`,
`localhost`, `DESKTOP-XXXX` ou `DESKTOP-XXXX\SQLEXPRESS`). Notez-le, il servira à l'étape 1.

---

## Étape 1 — Les 2 gestionnaires de connexions (une seule fois pour tout le projet)

1. Dans l'**Explorateur de solutions** (à droite), clic droit sur **Gestionnaires de connexions** →
   **Nouveau gestionnaire de connexions**.
2. Choisir **OLEDB** → **Ajouter…** → **Nouveau…**
3. Fournisseur : *Microsoft OLE DB Driver for SQL Server* (ou *Native OLE DB\SQL Server Native Client 11.0*).
4. Nom du serveur : le nom noté à l'étape 0. Authentification : **Windows**.
5. Base de données : **MACROBUS_PROD** → **Tester la connexion** → OK → OK.
6. Recommencer avec la base **MACROBUS_DWH_2**.
7. Renommer les deux connexions (clic droit → Renommer) en **`CM_PROD`** et **`CM_DWH`**.

Les deux connexions apparaissent maintenant en bas de tous les packages (en gras, car ce sont des
connexions de projet).

---

## Étape 2 — Premier package : `DimProductLine` (votre écran actuel)

Renommer `Package.dtsx` en **`03_DimProductLine.dtsx`** (clic droit → Renommer).

### 2.1 Source OLE DB
1. Double-cliquer sur **Source OLE DB**.
2. Gestionnaire de connexions OLE DB : **CM_PROD**.
3. Mode d'accès aux données : **Commande SQL**, puis coller :
   ```sql
   SELECT CAST(productLine AS NVARCHAR(50))       AS ProductLine,
          CAST(textDescription AS NVARCHAR(4000)) AS TextDescription
   FROM dbo.productlines;
   ```
4. Cliquer sur **Aperçu** (7 lignes doivent s'afficher), puis **OK**.

> Les `CAST(... AS NVARCHAR)` évitent l'erreur *« impossible de convertir entre types de données de chaînes
> Unicode et non-Unicode »*.

### 2.2 Recherche « Existe déjà ? »
1. Dans la Boîte à outils SSIS (section *Transformations courantes*), glisser **Recherche** (*Lookup*)
   entre la source et la destination.
2. **Supprimer** la flèche Source → Destination si elle existe, puis relier **Source → Recherche** (flèche bleue).
3. Double-cliquer sur **Recherche** :
   - Page **Général** : Mode de cache : **Cache complet**. *Spécifiez comment gérer les lignes sans entrée
     correspondante* : **Rediriger les lignes vers une sortie sans correspondance**.
   - Page **Connexion** : gestionnaire **CM_DWH**, puis cocher *Utiliser les résultats d'une requête SQL* :
     ```sql
     SELECT ProductLine FROM dbo.DimProductLine;
     ```
   - Page **Colonnes** : faire glisser `ProductLine` (à gauche) sur `ProductLine` (à droite). Une ligne de
     jointure apparaît. Ne cocher aucune colonne en sortie.
   - **OK**.

### 2.3 Destination OLE DB
1. Relier **Recherche → Destination OLE DB**. Dans la fenêtre qui s'ouvre, choisir la sortie
   **Sortie sans correspondance de recherche** (*Lookup No Match Output*).
2. Double-cliquer sur **Destination OLE DB** :
   - Gestionnaire : **CM_DWH**.
   - Mode d'accès : **Table ou vue - chargement rapide**.
   - Table : **[dbo].[DimProductLine]**. Laisser *Conserver l'identité* **décoché**.
   - Page **Mappages** : `ProductLine → ProductLine` et `TextDescription → TextDescription`.
     `KeyDimProductLine` reste sur **<ignorer>**, car elle est générée automatiquement (IDENTITY).
   - **OK**.

### 2.4 Exécuter
1. Cliquer sur **▶ Démarrer**. Les 3 composants passent au vert ✔ et la flèche indique **7 lignes**.
2. Dans SSMS : `SELECT * FROM MACROBUS_DWH_2.dbo.DimProductLine;` affiche 8 lignes (7 + la ligne « Inconnu »).
3. Relancer : **0 ligne** passe, car tout existe déjà. C'est une bonne capture pour le rapport.
4. Arrêter le débogage (■ ou Maj+F5).

---

## Étape 3 — Un flocon : `DimProduct` (avec recherche du parent)

Clic droit sur **Packages SSIS** → **Nouveau package SSIS** → renommer **`04_DimProduct.dtsx`**.
Onglet **Flux de contrôle** : glisser une **Tâche de flux de données**, double-cliquer dessus, puis
construire ce flux :

```
Source OLE DB -> Recherche "Lookup ProductLine" -> Recherche "Existe déjà ?" -> (sans correspondance) Destination
```

1. **Source OLE DB** : connexion **CM_PROD**, Commande SQL :
   ```sql
   SELECT CAST(productCode AS NVARCHAR(15))          AS ProductCode,
          CAST(productName AS NVARCHAR(70))          AS ProductName,
          CAST(productScale AS NVARCHAR(10))         AS ProductScale,
          CAST(productDescription AS NVARCHAR(4000)) AS ProductDescription,
          CAST(quantityInStock AS INT)               AS QuantityInStock,
          buyPrice AS BuyPrice, MSRP,
          CAST(productLine AS NVARCHAR(50))          AS ProductLine
   FROM dbo.products;
   ```
2. **Recherche « Lookup ProductLine »** : elle récupère la clé du parent.
   - Général : Cache complet. Lignes sans correspondance : laisser **Faire échouer le composant**. Si cela
     échoue, c'est que DimProductLine n'a pas été chargée avant.
   - Connexion : CM_DWH → `SELECT KeyDimProductLine, ProductLine FROM dbo.DimProductLine;`
   - Colonnes : relier `ProductLine` ↔ `ProductLine` et **cocher `KeyDimProductLine`**, qui est ajoutée au flux.
3. **Recherche « Existe déjà ? »** (relier depuis la *Sortie de correspondance de recherche* de la
   précédente) :
   - Général : **Rediriger les lignes vers une sortie sans correspondance**.
   - Connexion : CM_DWH → `SELECT ProductCode FROM dbo.DimProduct;`
   - Colonnes : `ProductCode` ↔ `ProductCode`.
4. **Destination OLE DB** (sortie **sans correspondance**) : CM_DWH, chargement rapide, table
   `[dbo].[DimProduct]`. Vérifier dans **Mappages** que **`KeyDimProductLine` est bien mappée** : c'est le
   lien du flocon.
5. ▶ Démarrer : **110 lignes**.

---

## Étape 4 — Tous les packages à créer

Même méthode pour chaque package. Les requêtes « Source » complètes sont dans
**`GUIDE_SSIS.md` § 5** et ont été testées sur MACROBUS_PROD.

| Package | Source (CM_PROD) | Recherche du parent (CM_DWH) | Recherche « Existe déjà ? » : requête et jointure | Lignes |
|---|---|---|---|---|
| `01_DimDate` | *(pas de flux : voir étape 5)* | — | — | 1 461 |
| `02_DimGeographie` | requête Géographie | — | `SELECT City, State, Country FROM dbo.DimGeographie` sur **les 3 colonnes** | 98 |
| `03_DimProductLine` | ✔ fait | — | `ProductLine` | 7 |
| `04_DimProduct` | ✔ fait | `KeyDimProductLine, ProductLine` FROM DimProductLine | `ProductCode` | 110 |
| `05_DimFournisseur` | requête Fournisseur | — | `ProductVendor` | 13 |
| `06_DimContact` | requête Contact | — | `CustomerNumber` | 122 |
| `07_DimCustomers` | requête Customers | `KeyDimContact, CustomerNumber` FROM DimContact | `CustomerNumber` | 122 |
| `08_DimOffice` | requête Office | — | `OfficeCode` | 7 |
| `09_DimCommerciaux` | requête Commerciaux | `KeyDimOffice, OfficeCode` FROM DimOffice | `EmployeeNumber` | 17 |
| `10_DimManagers` | requête Managers | — | `EmployeeNumber` | 6 |
| `11_FaitOrders` | *(procédure stockée : voir étape 5)* | — | — | 2 996 |

Les nombres de lignes sont ceux attendus au premier chargement, hors ligne « Inconnu ».

---

## Étape 5 — Les deux packages « procédure stockée »

### `01_DimDate.dtsx`
Flux de contrôle → glisser une **Tâche d'exécution de requêtes SQL** → double-clic :
- Connection : **CM_DWH**
- SQLStatement : `EXEC dbo.sp_ChargerDimDate @DateDebut = '2003-01-01', @DateFin = '2006-12-31';`

### `11_FaitOrders.dtsx` (exigence A-3 du sujet)
Flux de contrôle → **Tâche d'exécution de requêtes SQL** :
- Connection : **CM_DWH**
- SQLStatement : `EXEC dbo.sp_ChargerFaitOrders;`

Puis, reliée par une flèche verte, une 2ᵉ tâche avec `EXEC dbo.sp_ControleChargement;` pour le contrôle.

---

## Étape 6 — Package maître `00_Master.dtsx`

1. Nouveau package → `00_Master.dtsx`.
2. Pour chaque package, glisser une **Tâche d'exécution de package** → double-clic → page **Package** :
   *ReferenceType* = **Référence de projet**, *PackageNameFromProjectReference* = le package voulu.
3. Relier les tâches avec des **flèches vertes** (succès) dans cet ordre :
   ```
   01_DimDate -> 02_DimGeographie -> 03_DimProductLine -> 04_DimProduct -> 05_DimFournisseur
   -> 06_DimContact -> 07_DimCustomers -> 08_DimOffice -> 09_DimCommerciaux -> 10_DimManagers
   -> 11_FaitOrders
   ```
   Règle : **un parent du flocon avant son enfant**, et **le fait en dernier**.
4. Clic droit sur `00_Master.dtsx` dans l'Explorateur de solutions → **Définir comme objet de démarrage**
   → ▶ Démarrer. Tout doit passer au vert.

## Étape 7 — Vérifier dans SSMS

```sql
USE MACROBUS_DWH_2;
EXEC dbo.sp_ControleChargement;   -- Production = DWH : 2996 lignes, 326 commandes, 9 604 190,61
SELECT * FROM dbo.EtlLog;          -- historique des chargements du fait
```
Lancer ensuite `04_requetes_questions_PRODUCTION.sql` et `05_requetes_questions_DWH.sql` : les résultats
doivent être identiques.

## Recommencer de zéro

Réexécuter `01_creation_DWH.sql`, puis `02`, `03` et `06` (le `01` recrée des tables vides), puis relancer
`00_Master.dtsx`.

## Erreurs fréquentes

| Message | Cause et solution |
|---|---|
| *Unicode et non-Unicode* | La source n'utilise pas les requêtes avec `CAST(... AS NVARCHAR)` : utiliser celles du guide |
| *La recherche n'a trouvé aucune correspondance* (Lookup parent) | Le parent n'est pas chargé : exécuter d'abord DimProductLine, DimContact ou DimOffice |
| *Violation de la contrainte UNIQUE KEY* | La flèche part de la sortie **de correspondance** au lieu de la sortie **sans correspondance** |
| *Échec de la connexion* | Mauvais nom de serveur : reprendre celui de la fenêtre de connexion SSMS |
| La Destination est en rouge avec la mention *mappage* | Ouvrir la page Mappages et vérifier que chaque colonne (sauf la clé IDENTITY) est reliée |
