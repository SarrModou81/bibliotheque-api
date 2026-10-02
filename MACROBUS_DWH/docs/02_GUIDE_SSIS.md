# Construire le projet SSIS `MACROBUS_ETL_XXXX` pas à pas

**Pré-requis** : les scripts `01` (base de production) et `02` (création du DWH, avec `DimDate` déjà remplie) ont été exécutés dans SSMS.
Si vous voulez une solution de secours pour les dimensions, exécutez aussi le script `03`. Le script `04` (procédure stockée du fait) est **obligatoire**.

## Architecture du package `Chargement_DWH.dtsx`

```
Flux de contrôle (Control Flow)
┌───────────────────────────────────────────────────────────────┐
│ [Conteneur de séquence] SEQ - Dimensions niveau 1             │
│    DFT DimProductLine   DFT DimFournisseur   DFT DimContact   │
│    DFT DimOffice        DFT DimCommerciaux   DFT DimManagers  │
│    DFT DimGeographieOffice   DFT DimGeographieClient          │
└──────────────────────────────┬────────────────────────────────┘
                               │ (contrainte Succès, flèche verte)
┌──────────────────────────────▼────────────────────────────────┐
│ [Conteneur de séquence] SEQ - Dimensions niveau 2 (flocon)    │
│    DFT DimProduct (lookup DimProductLine)                     │
│    DFT DimCustomers (lookup DimContact)                       │
│    DFT DimEmployees (lookup DimOffice)                        │
└──────────────────────────────┬────────────────────────────────┘
                               │
┌──────────────────────────────▼────────────────────────────────┐
│ [Tâche Exécuter SQL] SQL - Charger FaitOrders                 │
│    EXEC dbo.ps_ChargerFaitOrders;                             │
└───────────────────────────────────────────────────────────────┘
```

Les dimensions « enfants » du flocon (DimProduct, DimCustomers, DimEmployees) ont besoin de la clé de leur dimension « parente ». C'est pour cela qu'elles sont chargées dans un deuxième temps.

---

## 1. Les gestionnaires de connexions

Dans le *Explorateur de solutions*, faites un clic droit sur **Gestionnaires de connexions**, puis **Nouveau gestionnaire de connexions > OLEDB > Ajouter > Nouveau…**

| Nom | Serveur | Base | Rôle |
|-----|---------|------|------|
| `CM_SRC_PROD` | `localhost` | `MACROBUS_PROD` | Source |
| `CM_DWH` | `localhost` | `MACROBUS_DWH_XXXX` | Destination |

- Fournisseur : **Microsoft OLE DB Driver for SQL Server**
- Authentification : **Windows**
- Onglet *All* (Tous) : `Trust Server Certificate = True`
- Cliquez sur **Tester la connexion**.

Les gestionnaires créés au niveau du **projet** sont partagés par tous les packages.

---

## 2. Modèle de Data Flow pour une dimension simple (exemple : DimProductLine)

1. Glissez une **Tâche de flux de données** dans le conteneur *SEQ - Dimensions niveau 1* et renommez-la `DFT DimProductLine`.
2. Double-cliquez dessus pour ouvrir l'onglet *Flux de données*, puis ajoutez :

   **a) Source OLE DB** (`SRC productlines`)
   - Connexion : `CM_SRC_PROD`
   - Mode d'accès : **Commande SQL**
   ```sql
   SELECT productLine, textDescription FROM dbo.productlines;
   ```

   **b) Recherche / Lookup** (`LKP DimProductLine existe ?`)
   - Onglet *Général* : Mode cache complet. Dans *Spécifier comment gérer les lignes sans entrée correspondante*, choisissez **Rediriger les lignes vers la sortie Aucune correspondance**.
   - Onglet *Connexion* : `CM_DWH`, avec la requête :
     ```sql
     SELECT KeyDimProductLine, productLine FROM dbo.DimProductLine;
     ```
   - Onglet *Colonnes* : reliez `productLine` (source) à `productLine` (référence).

   **c) Destination OLE DB** (`DST DimProductLine`)
   - Reliez-la à la sortie **Sortie Aucune correspondance de la recherche** du Lookup.
   - Connexion : `CM_DWH`, Table : `dbo.DimProductLine`. Pour la vitesse, choisissez le mode « Table ou vue - chargement rapide ».
   - Onglet *Mappages* : `productLine → productLine`, `textDescription → textDescription`. Laissez `KeyDimProductLine` en *<ignorer>* (colonne IDENTITY).

   ```
   SRC productlines ──► LKP existe ? ──(Aucune correspondance)──► DST DimProductLine
   ```
   Seules les **nouvelles** lignes sont insérées, donc le package peut être relancé autant de fois que nécessaire.

> **Option SCD :** pour gérer aussi les mises à jour, remplacez le Lookup et la destination par le composant **Dimension à variation lente (Slowly Changing Dimension)**. Clé métier = `productLine`, attribut `textDescription` = *Attribut variable* (type 1).

---

## 3. Requêtes sources des autres dimensions du niveau 1

Appliquez **le même modèle** (Source, Lookup sur la clé naturelle, sortie Aucune correspondance, Destination) :

| Data Flow | Requête source (`CM_SRC_PROD`) | Clé de Lookup |
|-----------|-------------------------------|---------------|
| DimFournisseur | `SELECT productCode AS codeDuProduit, productVendor FROM dbo.products;` | `codeDuProduit` |
| DimContact | `SELECT customerNumber AS CustomersNumber, LTRIM(RTRIM(contactFirstName)) AS contactFirstName, LTRIM(RTRIM(contactLastName)) AS contactLastName, LTRIM(RTRIM(contactFirstName)) + ' ' + LTRIM(RTRIM(contactLastName)) AS contactFullName, phone FROM dbo.customers;` | `CustomersNumber` |
| DimOffice | `SELECT officeCode, city, country, territory, phone, addressLine1 AS adressLine1, postalCode FROM dbo.offices;` | `officeCode` |
| DimCommerciaux | `SELECT employeeNumber, firstName + ' ' + lastName AS fullName_FirstName_LastName_, officeCode, extension, email, jobTitle AS jopTitle, reportsTo AS ReportTo FROM dbo.employees WHERE jobTitle = 'Sales Rep' OR employeeNumber IN (SELECT salesRepEmployeeNumber FROM dbo.customers WHERE salesRepEmployeeNumber IS NOT NULL);` | `employeeNumber` |
| DimManagers | `SELECT employeeNumber, firstName + ' ' + lastName AS fullName_FirstName_LastName_, officeCode, extension, email, jobTitle AS jopTitle, reportsTo AS ReportTo FROM dbo.employees WHERE employeeNumber IN (SELECT reportsTo FROM dbo.employees WHERE reportsTo IS NOT NULL);` | `employeeNumber` |
| DimGeographieOffice | `SELECT DISTINCT city, state, country, territory FROM dbo.offices;` | `city` + `country` + `territory` |
| DimGeographieClient | `SELECT c.city, MAX(c.state) AS state, c.country, ISNULL(o.territory,'N/A') AS territory FROM dbo.customers c LEFT JOIN dbo.employees e ON e.employeeNumber = c.salesRepEmployeeNumber LEFT JOIN dbo.offices o ON o.officeCode = e.officeCode GROUP BY c.city, c.country, ISNULL(o.territory,'N/A');` | `city` + `country` + `territory` |

> Si une colonne source est en `VARCHAR` et que SSIS se plaint d'une conversion Unicode/non-Unicode, ajoutez un composant **Conversion de données** avant la destination. Avec ces scripts, toutes les colonnes sont en `VARCHAR` des deux côtés, donc la conversion n'est normalement pas nécessaire.

---

## 4. Dimensions du niveau 2 (flocon) : un Lookup de plus

Exemple : **DimProduct**

```
SRC products ─► LKP DimProductLine (récupère KeyDimProductLine) ─► LKP DimProduct existe ? ─(Aucune correspondance)─► DST DimProduct
```

1. **Source OLE DB** (`CM_SRC_PROD`) :
   ```sql
   SELECT productCode, productName, productScale, productDescription,
          quantityInStock, buyPrice, MSRP, productLine
   FROM dbo.products;
   ```
2. **Lookup 1** `LKP DimProductLine` (`CM_DWH`) :
   `SELECT KeyDimProductLine, productLine FROM dbo.DimProductLine;`
   Jointure sur `productLine`. **Cochez `KeyDimProductLine`** pour l'ajouter au flux. Lignes sans correspondance : *Rediriger vers la sortie d'erreur*, ou *Faire échouer le composant*.
3. **Lookup 2** `LKP DimProduct existe ?` : `SELECT productCode FROM dbo.DimProduct;`. Jointure sur `productCode`, avec redirection vers la sortie Aucune correspondance.
4. **Destination** `dbo.DimProduct` : mappez toutes les colonnes, y compris `KeyDimProductLine`.

Faites de même pour :

| Data Flow | Requête source | Lookup parent (clé récupérée) | Lookup existence |
|-----------|----------------|-------------------------------|------------------|
| DimCustomers | `SELECT customerNumber AS CustomersNumber, customerName, phone, addressLine1 AS adresseLine1, city, country, creditLimit AS creditlimit, salesRepEmployeeNumber AS salesrepemployeesNumber, LTRIM(RTRIM(contactLastName)) AS contactLastName, LTRIM(RTRIM(contactFirstName)) AS contactFirstName FROM dbo.customers;` | `DimContact` sur `CustomersNumber`, qui donne **KeyDimContact** | `CustomersNumber` |
| DimEmployees | `SELECT employeeNumber, firstName + ' ' + lastName AS fullName_FirstName_LastName_, officeCode, extension, email, jobTitle AS jopTitle, reportsTo AS ReportTo FROM dbo.employees;` | `DimOffice` sur `officeCode`, qui donne **KeyDimOffices** | `employeeNumber` |

---

## 5. Chargement de la table de fait (procédure stockée, question A-3)

1. Dans le flux de contrôle, ajoutez une **Tâche Exécuter SQL** après le conteneur *Niveau 2* et reliez-la avec une flèche verte (Succès).
2. Connexion : `CM_DWH`, Type : *Entrée directe*, Instruction SQL :
   ```sql
   EXEC dbo.ps_ChargerFaitOrders;
   ```
3. (Optionnel) Pour récupérer le nombre de lignes insérées : *ResultSet = Ligne unique*, puis mappez `LignesInserees` dans une variable `User::NbLignes`.

> **Variante 100 % SSIS (si l'enseignant la demande) :** un Data Flow `DFT FaitOrders` avec une Source qui fait la jointure `orders`/`orderdetails`/`customers`/`employees`/`offices`, une **Colonne dérivée** qui calcule `Montant = quantityOrdered * priceEach` et les clés de date (`(DT_I4)` au format AAAAMMJJ), puis **un Lookup par dimension** pour obtenir chaque clé de substitution, et enfin une Destination `FaitOrders`. La procédure stockée fait exactement ces opérations, mais en SQL.

---

## 6. Exécuter et vérifier

1. Clic droit sur `Chargement_DWH.dtsx`, puis **Exécuter le package** (ou F5). Toutes les tâches doivent afficher une coche verte ✅.
2. Dans SSMS :
   ```sql
   USE MACROBUS_DWH_XXXX;
   SELECT COUNT(*) FROM dbo.FaitOrders;      -- attendu : 2996
   SELECT SUM(Montant) FROM dbo.FaitOrders;  -- attendu : 9 604 190,61
   ```
3. Relancez le package : aucune ligne n'est dupliquée (chargement incrémental).

### (Optionnel) Déployer dans le catalogue SSISDB
1. Dans SSMS, faites un clic droit sur **Integration Services Catalogs**, puis **Créer un catalogue** (cochez *Activer l'intégration CLR*).
2. Dans Visual Studio, faites un clic droit sur le projet, puis **Déployer**, et choisissez le serveur `localhost` et un dossier `MACROBUS`.
3. Pour une exécution planifiée, créez un travail **SQL Server Agent** de type *Package SSIS*.

---

## 7. Ce qu'il faut rendre

Le dossier complet du projet SSIS : `MACROBUS_ETL_XXXX\` (fichiers `.sln`, `.dtproj` et `.dtsx`). Zippez-le tel quel.
