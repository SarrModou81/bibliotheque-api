# Guide SSIS — projet `MACROBUS_ETL_2`

Outils : **Visual Studio 2019 ou 2022** + extension **SQL Server Integration Services Projects**
(Extensions → Gérer les extensions → « SQL Server Integration Services Projects »).

Pré-requis : les scripts `01`, `02`, `03` ont été exécutés (tables, procédures et synonymes existent).

---

## 1. Créer le projet

1. *Fichier → Nouveau → Projet → **Integration Services Project***.
2. Nom : **`MACROBUS_ETL_2`**.
3. Supprimer `Package.dtsx` (ou le renommer `00_Master.dtsx`).

## 2. Gestionnaires de connexion de **projet** (partagés par tous les packages)

Dans l'Explorateur de solutions : clic droit sur **Connection Managers → Nouveau gestionnaire de connexions → OLEDB**.

| Nom | Serveur | Base |
|---|---|---|
| `CM_MACROBUS_PROD` | votre serveur (ex. `localhost` ou `.\SQLEXPRESS`) | `MACROBUS_PROD` |
| `CM_DWH` | idem | `MACROBUS_DWH_2` |

Fournisseur : *Microsoft OLE DB Driver for SQL Server* (ou *SQL Server Native Client 11*). Authentification Windows.

## 3. Les packages à créer

```
00_Master.dtsx          -> orchestre tout (Execute Package Tasks)
01_DimDate.dtsx         -> Execute SQL Task
02_DimGeographie.dtsx   -> Data Flow
03_DimProductLine.dtsx  -> Data Flow
04_DimProduct.dtsx      -> Data Flow (+ Lookup DimProductLine)  [flocon]
05_DimFournisseur.dtsx  -> Data Flow
06_DimContact.dtsx      -> Data Flow
07_DimCustomers.dtsx    -> Data Flow (+ Lookup DimContact)      [flocon]
08_DimOffice.dtsx       -> Data Flow
09_DimCommerciaux.dtsx  -> Data Flow (+ Lookup DimOffice)       [flocon]
10_DimManagers.dtsx     -> Data Flow
11_FaitOrders.dtsx      -> Execute SQL Task : EXEC dbo.sp_ChargerFaitOrders
```

> **Astuce n°1 (évite 90 % des erreurs SSIS)** : dans chaque *OLE DB Source*, utilisez le mode
> **« SQL command »** avec les requêtes ci-dessous. Elles font déjà les `CAST(... AS NVARCHAR)`, ce qui
> évite l'erreur *« cannot convert between unicode and non-unicode string data types »*
> (DT_STR vs DT_WSTR) et donc le composant *Data Conversion*.

---

## 4. Modèle de Data Flow d'une dimension (SCD type 1)

Toutes les dimensions suivent le même schéma :

```
[OLE DB Source] -> ([Lookup] parent du flocon -> [Derived Column] cle -1 si absente)
               -> [Slowly Changing Dimension]
                      |-- New Output                -> OLE DB Destination (INSERT)
                      |-- Changing Attribute Output -> OLE DB Command (UPDATE)
```

### Paramétrer l'assistant *Slowly Changing Dimension*
1. Glisser **Slowly Changing Dimension** (boîte à outils « Autres transformations »), relier la source, double-clic.
2. Connexion : `CM_DWH`, table : la dimension.
3. Colonne d'entrée ↔ colonne de dimension : mapper toutes les colonnes ; la **clé naturelle** est en
   *Business Key* (voir tableau ci-dessous).
4. Type de chaque attribut : **Changing attribute** (= type 1, écrasement).
5. Décocher « Inferred members ». Terminer : SSIS génère automatiquement les sorties INSERT et UPDATE.

| Dimension | Business key | Lookup (flocon) |
|---|---|---|
| DimGeographie | City + State + Country | — |
| DimProductLine | ProductLine | — |
| DimProduct | ProductCode | DimProductLine sur ProductLine → KeyDimProductLine |
| DimFournisseur | ProductVendor | — |
| DimContact | CustomerNumber | — |
| DimCustomers | CustomerNumber | DimContact sur CustomerNumber → KeyDimContact |
| DimOffice | OfficeCode | — |
| DimCommerciaux | EmployeeNumber | DimOffice sur OfficeCode → KeyDimOffice |
| DimManagers | EmployeeNumber | — |

### Paramétrer un *Lookup* (flocon)
1. Onglet *Général* : **Full cache** ; « Spécifier comment gérer les lignes sans correspondance » :
   **Ignorer l'échec** (*Ignore failure*).
2. Onglet *Connexion* : `CM_DWH`, requête : `SELECT KeyDimProductLine, ProductLine FROM dbo.DimProductLine`.
3. Onglet *Colonnes* : relier `ProductLine` ↔ `ProductLine`, cocher `KeyDimProductLine` en sortie.
4. Ajouter un **Derived Column** derrière : remplacer `KeyDimProductLine` par
   `ISNULL(KeyDimProductLine) ? -1 : KeyDimProductLine`.

> Exclure les membres « Inconnu » de la comparaison : ils ont une clé naturelle (-1, 'Inconnu', 'N/A') qui
> n'existe pas dans la source, le SCD ne les touchera donc pas.

---

## 5. Requêtes des OLE DB Source (connexion `CM_MACROBUS_PROD`)

### 02_DimGeographie
```sql
WITH TerritoirePays AS (
    SELECT country, MIN(territory) AS territory FROM dbo.offices GROUP BY country
), g AS (
    SELECT city, ISNULL(state,'N/A') AS state, country, ISNULL(territory,'N/A') AS territory, 1 AS prio
    FROM dbo.offices
    UNION ALL
    SELECT c.city, ISNULL(c.state,'N/A'), c.country,
           COALESCE(tp.territory, orep.territory, 'N/A'), 2
    FROM dbo.customers c
    LEFT JOIN TerritoirePays tp ON tp.country = c.country
    LEFT JOIN dbo.employees e  ON e.employeeNumber = c.salesRepEmployeeNumber
    LEFT JOIN dbo.offices orep ON orep.officeCode = e.officeCode
), d AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY city, state, country ORDER BY prio, territory) AS rn FROM g
)
SELECT CAST(city AS NVARCHAR(50)) AS City, CAST(state AS NVARCHAR(50)) AS State,
       CAST(country AS NVARCHAR(50)) AS Country, CAST(territory AS NVARCHAR(10)) AS Territory
FROM d WHERE rn = 1;
```

### 03_DimProductLine
```sql
SELECT CAST(productLine AS NVARCHAR(50)) AS ProductLine,
       CAST(textDescription AS NVARCHAR(4000)) AS TextDescription
FROM dbo.productlines;
```

### 04_DimProduct
```sql
SELECT CAST(productCode AS NVARCHAR(15)) AS ProductCode,
       CAST(productName AS NVARCHAR(70)) AS ProductName,
       CAST(productScale AS NVARCHAR(10)) AS ProductScale,
       CAST(productDescription AS NVARCHAR(4000)) AS ProductDescription,
       CAST(quantityInStock AS INT) AS QuantityInStock,
       buyPrice AS BuyPrice, MSRP,
       CAST(productLine AS NVARCHAR(50)) AS ProductLine
FROM dbo.products;
```
→ Lookup `DimProductLine` (ProductLine) → Derived Column → SCD `DimProduct`.

### 05_DimFournisseur
```sql
SELECT DISTINCT CAST(productVendor AS NVARCHAR(50)) AS ProductVendor FROM dbo.products;
```

### 06_DimContact
```sql
SELECT customerNumber AS CustomerNumber,
       CAST(contactFirstName AS NVARCHAR(50)) AS ContactFirstName,
       CAST(contactLastName AS NVARCHAR(50))  AS ContactLastName,
       CAST(contactFirstName + ' ' + contactLastName AS NVARCHAR(101)) AS ContactFullName,
       CAST(phone AS NVARCHAR(50)) AS Phone
FROM dbo.customers;
```

### 07_DimCustomers
```sql
SELECT customerNumber AS CustomerNumber,
       CAST(customerName AS NVARCHAR(50)) AS CustomerName,
       CAST(phone AS NVARCHAR(50)) AS Phone,
       CAST(addressLine1 AS NVARCHAR(50)) AS AddressLine1,
       CAST(postalCode AS NVARCHAR(15)) AS PostalCode,
       creditLimit AS CreditLimit,
       salesRepEmployeeNumber AS SalesRepEmployeeNumber
FROM dbo.customers;
```
→ Lookup `DimContact` (CustomerNumber) → Derived Column → SCD `DimCustomers`.

### 08_DimOffice
```sql
SELECT CAST(officeCode AS NVARCHAR(10)) AS OfficeCode,
       CAST(city + ' (' + country + ')' AS NVARCHAR(60)) AS NomFiliale,
       CAST(phone AS NVARCHAR(50)) AS Phone,
       CAST(addressLine1 AS NVARCHAR(50)) AS AddressLine1,
       CAST(postalCode AS NVARCHAR(15)) AS PostalCode
FROM dbo.offices;
```

### 09_DimCommerciaux
```sql
SELECT e.employeeNumber AS EmployeeNumber,
       CAST(e.firstName AS NVARCHAR(50)) AS FirstName,
       CAST(e.lastName AS NVARCHAR(50))  AS LastName,
       CAST(e.firstName + ' ' + e.lastName AS NVARCHAR(101)) AS FullName,
       CAST(e.officeCode AS NVARCHAR(10)) AS OfficeCode,
       CAST(e.extension AS NVARCHAR(10)) AS Extension,
       CAST(e.email AS NVARCHAR(100)) AS Email,
       CAST(e.jobTitle AS NVARCHAR(50)) AS JobTitle,
       e.reportsTo AS ReportsTo
FROM dbo.employees e
WHERE e.jobTitle = 'Sales Rep'
   OR e.employeeNumber IN (SELECT salesRepEmployeeNumber FROM dbo.customers
                           WHERE salesRepEmployeeNumber IS NOT NULL);
```
→ Lookup `DimOffice` (OfficeCode) → Derived Column → SCD `DimCommerciaux`.

### 10_DimManagers
Même requête que 09 (sans `KeyDimOffice`), avec ce filtre :
```sql
WHERE e.employeeNumber IN (SELECT reportsTo FROM dbo.employees WHERE reportsTo IS NOT NULL);
```

---

## 6. Packages « SQL » (connexion `CM_DWH`)

- **01_DimDate** : *Execute SQL Task* →
  `EXEC dbo.sp_ChargerDimDate @DateDebut = '2003-01-01', @DateFin = '2006-12-31';`
- **11_FaitOrders** : *Execute SQL Task* → `EXEC dbo.sp_ChargerFaitOrders;`
  Ajouter une 2ᵉ *Execute SQL Task* → `EXEC dbo.sp_ControleChargement;` (contrôle).

> Variante possible pour aller plus loin (non exigée) : charger le fait dans un Data Flow (source =
> jointure orderdetails/orders/products/customers/employees, puis une série de *Lookup* vers chaque
> dimension, puis *Derived Column* pour les mesures, puis *OLE DB Destination*). Le sujet demande
> explicitement une **procédure stockée**, d'où le choix de l'*Execute SQL Task*.

## 7. Package Master `00_Master.dtsx`

Dans le *Control Flow*, glisser une **Execute Package Task** par package (*Reference type = Project
Reference*, *PackageNameFromProjectReference = 01_DimDate.dtsx*, etc.) et les relier avec des
**contraintes de précédence vertes (Success)** dans cet ordre :

```
01_DimDate -> 02_DimGeographie -> 03_DimProductLine -> 04_DimProduct -> 05_DimFournisseur
-> 06_DimContact -> 07_DimCustomers -> 08_DimOffice -> 09_DimCommerciaux -> 10_DimManagers
-> 11_FaitOrders
```
(On peut paralléliser les branches indépendantes, par exemple produit, client et organisation, puis les
regrouper dans un *Sequence Container* avant le fait.) L'important est que les **parents du flocon**
(ProductLine, Contact et Office) soient chargés **avant** leurs enfants, et le **fait en dernier**.

## 8. Exécuter et vérifier

1. Clic droit sur `00_Master.dtsx` → **Exécuter le package** : toutes les tâches doivent passer au vert ✔.
2. Dans SSMS : `EXEC dbo.sp_ControleChargement;` doit afficher le même nombre de lignes et le même CA en
   prod et dans le DWH, et `SELECT * FROM dbo.EtlLog;` doit afficher l'historique des chargements.
3. Relancer le Master une 2ᵉ fois : aucune ligne n'est ajoutée (SCD et MERGE sont idempotents). C'est une
   capture intéressante pour le rapport.

## 9. Erreurs fréquentes

| Erreur | Solution |
|---|---|
| *cannot convert between unicode and non-unicode* | Utiliser les requêtes avec `CAST(... AS NVARCHAR)` ci-dessus |
| *Violation of UNIQUE KEY* | Mauvaise *Business Key* dans le SCD, ou package lancé alors que les données existent : vérifier le mapping |
| *FOREIGN KEY constraint* | Ordre d'exécution : charger le parent du flocon avant l'enfant, et le fait en dernier |
| *Invalid object name 'src.orders'* | Synonymes : la base de prod ne s'appelle pas `MACROBUS_PROD` → adapter la fin du script 01 |
| Lookup : *row yielded no match* | Mettre le Lookup en *Ignore failure* + Derived Column `-1` |
