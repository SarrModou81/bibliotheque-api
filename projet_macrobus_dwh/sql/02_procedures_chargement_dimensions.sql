/* =====================================================================
   PROJET MACROBUS - Script 02 : Procedures de chargement des DIMENSIONS
   ---------------------------------------------------------------------
   Dans le projet, les dimensions sont chargees par SSIS (voir
   ssis/GUIDE_SSIS.md). Ces procedures servent :
     - a charger DimDate (appelee depuis SSIS par une "Execute SQL Task"),
     - de plan B / de test : elles produisent exactement le meme resultat
       que les packages SSIS, ce qui permet de verifier vos packages.
   Toutes les dimensions sont gerees en SCD de type 1 (ecrasement).
   ===================================================================== */
USE MACROBUS_DWH_2;
GO

/* ---------------------------------------------------------------------
   DimDate : generation du calendrier (independant de SET DATEFIRST /
   SET LANGUAGE grace au calcul manuel du jour de la semaine)
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimDate
    @DateDebut DATE = '2003-01-01',
    @DateFin   DATE = '2006-12-31'
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH n AS (
        SELECT TOP (DATEDIFF(DAY, @DateDebut, @DateFin) + 1)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ), d AS (
        SELECT DATEADD(DAY, i, @DateDebut) AS dt FROM n
    ), c AS (
        SELECT dt,
               (DATEDIFF(DAY, '19000101', dt) % 7) + 1 AS js,   -- 1 = lundi
               MONTH(dt) AS m,
               DATEPART(QUARTER, dt) AS t,
               CASE WHEN MONTH(dt) <= 6 THEN 1 ELSE 2 END AS s,
               YEAR(dt) AS a
        FROM d
    )
    INSERT INTO dbo.DimDate (KeyDimDate, FullDate, Jour, NomJour, JourSemaine, SemaineAnnee,
                             Mois, NomMois, Trimestre, LibelleTrimestre, Semestre,
                             LibelleSemestre, Annee, AnneeMois, EstWeekEnd)
    SELECT CONVERT(INT, CONVERT(CHAR(8), dt, 112)),
           dt,
           DAY(dt),
           CHOOSE(js, N'Lundi', N'Mardi', N'Mercredi', N'Jeudi', N'Vendredi', N'Samedi', N'Dimanche'),
           js,
           DATEPART(ISO_WEEK, dt),
           m,
           CHOOSE(m, N'Janvier', N'Fevrier', N'Mars', N'Avril', N'Mai', N'Juin', N'Juillet',
                     N'Aout', N'Septembre', N'Octobre', N'Novembre', N'Decembre'),
           t,
           CONCAT(N'T', t, N'-', a),
           s,
           CONCAT(N'S', s, N'-', a),
           a,
           a * 100 + m,
           CASE WHEN js IN (6, 7) THEN 1 ELSE 0 END
    FROM c
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate x WHERE x.FullDate = c.dt);

    PRINT CONCAT('DimDate : ', @@ROWCOUNT, ' jour(s) ajoute(s)');
END
GO

/* ---------------------------------------------------------------------
   DimGeographie : villes des filiales + villes des clients.
   Territoire d'une ville client = territoire d'une filiale du meme pays,
   sinon territoire de la filiale de son commercial, sinon 'N/A'.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimGeographie
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH TerritoirePays AS (
        SELECT country, MIN(territory) AS territory
        FROM src.offices GROUP BY country
    ), g AS (
        SELECT CAST(o.city AS NVARCHAR(50))                    AS City,
               CAST(ISNULL(o.state, 'N/A') AS NVARCHAR(50))     AS State,
               CAST(o.country AS NVARCHAR(50))                  AS Country,
               CAST(ISNULL(o.territory, 'N/A') AS NVARCHAR(10)) AS Territory,
               1 AS Priorite
        FROM src.offices o
        UNION ALL
        SELECT CAST(c.city AS NVARCHAR(50)),
               CAST(ISNULL(c.state, 'N/A') AS NVARCHAR(50)),
               CAST(c.country AS NVARCHAR(50)),
               CAST(COALESCE(tp.territory, orep.territory, 'N/A') AS NVARCHAR(10)),
               2
        FROM src.customers c
        LEFT JOIN TerritoirePays tp ON tp.country = c.country
        LEFT JOIN src.employees e   ON e.employeeNumber = c.salesRepEmployeeNumber
        LEFT JOIN src.offices orep  ON orep.officeCode = e.officeCode
    ), dedoublonne AS (
        SELECT City, State, Country, Territory,
               ROW_NUMBER() OVER (PARTITION BY City, State, Country
                                  ORDER BY Priorite, Territory) AS rn
        FROM g
    )
    MERGE dbo.DimGeographie AS cible
    USING (SELECT City, State, Country, Territory FROM dedoublonne WHERE rn = 1) AS source
       ON cible.City = source.City AND cible.State = source.State AND cible.Country = source.Country
    WHEN MATCHED AND cible.Territory <> source.Territory THEN
        UPDATE SET Territory = source.Territory
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (City, State, Country, Territory)
        VALUES (source.City, source.State, source.Country, source.Territory);
END
GO

/* --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimProductLine
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimProductLine AS cible
    USING (SELECT CAST(productLine AS NVARCHAR(50))       AS ProductLine,
                  CAST(textDescription AS NVARCHAR(4000)) AS TextDescription
           FROM src.productlines) AS source
       ON cible.ProductLine = source.ProductLine
    WHEN MATCHED AND ISNULL(cible.TextDescription, N'') <> ISNULL(source.TextDescription, N'') THEN
        UPDATE SET TextDescription = source.TextDescription
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (ProductLine, TextDescription) VALUES (source.ProductLine, source.TextDescription);
END
GO

/* --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimProduct
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimProduct AS cible
    USING (SELECT CAST(p.productCode AS NVARCHAR(15))          AS ProductCode,
                  CAST(p.productName AS NVARCHAR(70))          AS ProductName,
                  CAST(p.productScale AS NVARCHAR(10))         AS ProductScale,
                  CAST(p.productDescription AS NVARCHAR(4000)) AS ProductDescription,
                  CAST(p.quantityInStock AS INT)               AS QuantityInStock,
                  p.buyPrice                                   AS BuyPrice,
                  p.MSRP                                       AS MSRP,
                  CAST(p.productLine AS NVARCHAR(50))          AS ProductLine,
                  ISNULL(pl.KeyDimProductLine, -1)             AS KeyDimProductLine
           FROM src.products p
           LEFT JOIN dbo.DimProductLine pl ON pl.ProductLine = p.productLine) AS source
       ON cible.ProductCode = source.ProductCode
    WHEN MATCHED THEN
        UPDATE SET ProductName = source.ProductName, ProductScale = source.ProductScale,
                   ProductDescription = source.ProductDescription,
                   QuantityInStock = source.QuantityInStock, BuyPrice = source.BuyPrice,
                   MSRP = source.MSRP, ProductLine = source.ProductLine,
                   KeyDimProductLine = source.KeyDimProductLine
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (ProductCode, ProductName, ProductScale, ProductDescription, QuantityInStock,
                BuyPrice, MSRP, ProductLine, KeyDimProductLine)
        VALUES (source.ProductCode, source.ProductName, source.ProductScale, source.ProductDescription,
                source.QuantityInStock, source.BuyPrice, source.MSRP, source.ProductLine,
                source.KeyDimProductLine);
END
GO

/* --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimFournisseur
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.DimFournisseur (ProductVendor)
    SELECT DISTINCT CAST(p.productVendor AS NVARCHAR(50))
    FROM src.products p
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimFournisseur f WHERE f.ProductVendor = p.productVendor);
END
GO

/* --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimContact
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimContact AS cible
    USING (SELECT customerNumber                                   AS CustomerNumber,
                  CAST(contactFirstName AS NVARCHAR(50))           AS ContactFirstName,
                  CAST(contactLastName AS NVARCHAR(50))            AS ContactLastName,
                  CAST(CONCAT(contactFirstName, ' ', contactLastName) AS NVARCHAR(101)) AS ContactFullName,
                  CAST(phone AS NVARCHAR(50))                      AS Phone
           FROM src.customers) AS source
       ON cible.CustomerNumber = source.CustomerNumber
    WHEN MATCHED THEN
        UPDATE SET ContactFirstName = source.ContactFirstName, ContactLastName = source.ContactLastName,
                   ContactFullName = source.ContactFullName, Phone = source.Phone
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CustomerNumber, ContactFirstName, ContactLastName, ContactFullName, Phone)
        VALUES (source.CustomerNumber, source.ContactFirstName, source.ContactLastName,
                source.ContactFullName, source.Phone);
END
GO

/* --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimCustomers
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimCustomers AS cible
    USING (SELECT c.customerNumber                       AS CustomerNumber,
                  CAST(c.customerName AS NVARCHAR(50))   AS CustomerName,
                  CAST(c.phone AS NVARCHAR(50))          AS Phone,
                  CAST(c.addressLine1 AS NVARCHAR(50))   AS AddressLine1,
                  CAST(c.postalCode AS NVARCHAR(15))     AS PostalCode,
                  c.creditLimit                          AS CreditLimit,
                  c.salesRepEmployeeNumber               AS SalesRepEmployeeNumber,
                  ISNULL(ct.KeyDimContact, -1)           AS KeyDimContact
           FROM src.customers c
           LEFT JOIN dbo.DimContact ct ON ct.CustomerNumber = c.customerNumber) AS source
       ON cible.CustomerNumber = source.CustomerNumber
    WHEN MATCHED THEN
        UPDATE SET CustomerName = source.CustomerName, Phone = source.Phone,
                   AddressLine1 = source.AddressLine1, PostalCode = source.PostalCode,
                   CreditLimit = source.CreditLimit,
                   SalesRepEmployeeNumber = source.SalesRepEmployeeNumber,
                   KeyDimContact = source.KeyDimContact
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CustomerNumber, CustomerName, Phone, AddressLine1, PostalCode, CreditLimit,
                SalesRepEmployeeNumber, KeyDimContact)
        VALUES (source.CustomerNumber, source.CustomerName, source.Phone, source.AddressLine1,
                source.PostalCode, source.CreditLimit, source.SalesRepEmployeeNumber,
                source.KeyDimContact);
END
GO

/* --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimOffice
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimOffice AS cible
    USING (SELECT CAST(officeCode AS NVARCHAR(10))                        AS OfficeCode,
                  CAST(CONCAT(city, ' (', country, ')') AS NVARCHAR(60))  AS NomFiliale,
                  CAST(phone AS NVARCHAR(50))                             AS Phone,
                  CAST(addressLine1 AS NVARCHAR(50))                      AS AddressLine1,
                  CAST(postalCode AS NVARCHAR(15))                        AS PostalCode
           FROM src.offices) AS source
       ON cible.OfficeCode = source.OfficeCode
    WHEN MATCHED THEN
        UPDATE SET NomFiliale = source.NomFiliale, Phone = source.Phone,
                   AddressLine1 = source.AddressLine1, PostalCode = source.PostalCode
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (OfficeCode, NomFiliale, Phone, AddressLine1, PostalCode)
        VALUES (source.OfficeCode, source.NomFiliale, source.Phone, source.AddressLine1, source.PostalCode);
END
GO

/* ---------------------------------------------------------------------
   DimCommerciaux = employes "Sales Rep" + tout employe rattache a un
   client (salesRepEmployeeNumber)
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimCommerciaux
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimCommerciaux AS cible
    USING (SELECT e.employeeNumber                                           AS EmployeeNumber,
                  CAST(e.firstName AS NVARCHAR(50))                          AS FirstName,
                  CAST(e.lastName AS NVARCHAR(50))                           AS LastName,
                  CAST(CONCAT(e.firstName, ' ', e.lastName) AS NVARCHAR(101)) AS FullName,
                  CAST(e.officeCode AS NVARCHAR(10))                         AS OfficeCode,
                  CAST(e.extension AS NVARCHAR(10))                          AS Extension,
                  CAST(e.email AS NVARCHAR(100))                             AS Email,
                  CAST(e.jobTitle AS NVARCHAR(50))                           AS JobTitle,
                  e.reportsTo                                                AS ReportsTo,
                  ISNULL(o.KeyDimOffice, -1)                                 AS KeyDimOffice
           FROM src.employees e
           LEFT JOIN dbo.DimOffice o ON o.OfficeCode = e.officeCode
           WHERE e.jobTitle = 'Sales Rep'
              OR e.employeeNumber IN (SELECT salesRepEmployeeNumber FROM src.customers
                                      WHERE salesRepEmployeeNumber IS NOT NULL)) AS source
       ON cible.EmployeeNumber = source.EmployeeNumber
    WHEN MATCHED THEN
        UPDATE SET FirstName = source.FirstName, LastName = source.LastName,
                   FullName = source.FullName, OfficeCode = source.OfficeCode,
                   Extension = source.Extension, Email = source.Email,
                   JobTitle = source.JobTitle, ReportsTo = source.ReportsTo,
                   KeyDimOffice = source.KeyDimOffice
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (EmployeeNumber, FirstName, LastName, FullName, OfficeCode, Extension, Email,
                JobTitle, ReportsTo, KeyDimOffice)
        VALUES (source.EmployeeNumber, source.FirstName, source.LastName, source.FullName,
                source.OfficeCode, source.Extension, source.Email, source.JobTitle,
                source.ReportsTo, source.KeyDimOffice);
END
GO

/* ---------------------------------------------------------------------
   DimManagers = tout employe qui a au moins un subordonne (reportsTo)
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerDimManagers
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimManagers AS cible
    USING (SELECT e.employeeNumber                                           AS EmployeeNumber,
                  CAST(e.firstName AS NVARCHAR(50))                          AS FirstName,
                  CAST(e.lastName AS NVARCHAR(50))                           AS LastName,
                  CAST(CONCAT(e.firstName, ' ', e.lastName) AS NVARCHAR(101)) AS FullName,
                  CAST(e.officeCode AS NVARCHAR(10))                         AS OfficeCode,
                  CAST(e.extension AS NVARCHAR(10))                          AS Extension,
                  CAST(e.email AS NVARCHAR(100))                             AS Email,
                  CAST(e.jobTitle AS NVARCHAR(50))                           AS JobTitle,
                  e.reportsTo                                                AS ReportsTo
           FROM src.employees e
           WHERE e.employeeNumber IN (SELECT reportsTo FROM src.employees
                                      WHERE reportsTo IS NOT NULL)) AS source
       ON cible.EmployeeNumber = source.EmployeeNumber
    WHEN MATCHED THEN
        UPDATE SET FirstName = source.FirstName, LastName = source.LastName,
                   FullName = source.FullName, OfficeCode = source.OfficeCode,
                   Extension = source.Extension, Email = source.Email,
                   JobTitle = source.JobTitle, ReportsTo = source.ReportsTo
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (EmployeeNumber, FirstName, LastName, FullName, OfficeCode, Extension, Email,
                JobTitle, ReportsTo)
        VALUES (source.EmployeeNumber, source.FirstName, source.LastName, source.FullName,
                source.OfficeCode, source.Extension, source.Email, source.JobTitle,
                source.ReportsTo);
END
GO

/* ---------------------------------------------------------------------
   Orchestration : charge toutes les dimensions dans le bon ordre
   (les "parents" d'un flocon avant les "enfants")
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChargerToutesDimensions
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @debut DATE, @fin DATE;
    SELECT @debut = DATEFROMPARTS(YEAR(MIN(orderDate)), 1, 1),
           @fin   = DATEFROMPARTS(YEAR(MAX(CASE WHEN shippedDate > requiredDate
                                                THEN shippedDate ELSE requiredDate END)), 12, 31)
    FROM src.orders;

    EXEC dbo.sp_ChargerDimDate @DateDebut = @debut, @DateFin = @fin;
    EXEC dbo.sp_ChargerDimGeographie;
    EXEC dbo.sp_ChargerDimProductLine;
    EXEC dbo.sp_ChargerDimProduct;       -- apres DimProductLine
    EXEC dbo.sp_ChargerDimFournisseur;
    EXEC dbo.sp_ChargerDimContact;
    EXEC dbo.sp_ChargerDimCustomers;     -- apres DimContact
    EXEC dbo.sp_ChargerDimOffice;
    EXEC dbo.sp_ChargerDimCommerciaux;   -- apres DimOffice
    EXEC dbo.sp_ChargerDimManagers;
    PRINT 'Dimensions chargees.';
END
GO
