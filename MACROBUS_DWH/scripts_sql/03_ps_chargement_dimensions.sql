/* =====================================================================
   PROJET MACROBUS - 03 : Procédures de chargement des DIMENSIONS
   ---------------------------------------------------------------------
   Ces procédures font le même travail que les Data Flow SSIS
   (source MACROBUS_PROD -> dimensions MACROBUS_DWH_XXXX).
   Elles sont appelées par le package SSIS (tâches "Exécuter SQL") ou
   peuvent servir de solution de secours / de vérification.
   Toutes sont ré-exécutables : MERGE = insertion des nouveaux membres
   + mise à jour des membres existants (SCD type 1).
   ===================================================================== */
USE MACROBUS_DWH_XXXX;
GO

/* ----------------------------- Produits ----------------------------- */
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimProductLine
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimProductLine AS cible
    USING (SELECT productLine, textDescription FROM MACROBUS_PROD.dbo.productlines) AS src
       ON cible.productLine = src.productLine
    WHEN MATCHED THEN UPDATE SET cible.textDescription = src.textDescription
    WHEN NOT MATCHED THEN INSERT (productLine, textDescription) VALUES (src.productLine, src.textDescription);
END
GO

CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimProduct
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimProduct AS cible
    USING (
        SELECT p.productCode, p.productName, p.productScale, p.productDescription,
               p.quantityInStock, p.buyPrice, p.MSRP, p.productLine, pl.KeyDimProductLine
        FROM MACROBUS_PROD.dbo.products p
        JOIN dbo.DimProductLine pl ON pl.productLine = p.productLine      -- lookup flocon
    ) AS src
       ON cible.productCode = src.productCode
    WHEN MATCHED THEN UPDATE SET
         productName = src.productName, productScale = src.productScale,
         productDescription = src.productDescription, quantityInStock = src.quantityInStock,
         buyPrice = src.buyPrice, MSRP = src.MSRP, productLine = src.productLine,
         KeyDimProductLine = src.KeyDimProductLine
    WHEN NOT MATCHED THEN INSERT
         (productCode, productName, productScale, productDescription, quantityInStock,
          buyPrice, MSRP, productLine, KeyDimProductLine)
    VALUES (src.productCode, src.productName, src.productScale, src.productDescription,
            src.quantityInStock, src.buyPrice, src.MSRP, src.productLine, src.KeyDimProductLine);
END
GO

CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimFournisseur
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimFournisseur AS cible
    USING (SELECT productCode, productVendor FROM MACROBUS_PROD.dbo.products) AS src
       ON cible.codeDuProduit = src.productCode
    WHEN MATCHED THEN UPDATE SET productVendor = src.productVendor
    WHEN NOT MATCHED THEN INSERT (codeDuProduit, productVendor) VALUES (src.productCode, src.productVendor);
END
GO

/* ------------------------------ Clients ----------------------------- */
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimContact
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimContact AS cible
    USING (
        SELECT customerNumber,
               LTRIM(RTRIM(contactFirstName)) AS contactFirstName,
               LTRIM(RTRIM(contactLastName))  AS contactLastName,
               phone
        FROM MACROBUS_PROD.dbo.customers
    ) AS src
       ON cible.CustomersNumber = src.customerNumber
    WHEN MATCHED THEN UPDATE SET
         contactFirstName = src.contactFirstName, contactLastName = src.contactLastName,
         contactFullName = src.contactFirstName + ' ' + src.contactLastName, phone = src.phone
    WHEN NOT MATCHED THEN INSERT (CustomersNumber, contactFirstName, contactLastName, contactFullName, phone)
    VALUES (src.customerNumber, src.contactFirstName, src.contactLastName,
            src.contactFirstName + ' ' + src.contactLastName, src.phone);
END
GO

CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimCustomers
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimCustomers AS cible
    USING (
        SELECT c.customerNumber, c.customerName, c.phone, c.addressLine1, c.city, c.country,
               c.creditLimit, c.salesRepEmployeeNumber,
               LTRIM(RTRIM(c.contactLastName)) AS contactLastName,
               LTRIM(RTRIM(c.contactFirstName)) AS contactFirstName,
               ct.KeyDimContact
        FROM MACROBUS_PROD.dbo.customers c
        JOIN dbo.DimContact ct ON ct.CustomersNumber = c.customerNumber   -- lookup flocon
    ) AS src
       ON cible.CustomersNumber = src.customerNumber
    WHEN MATCHED THEN UPDATE SET
         customerName = src.customerName, phone = src.phone, adresseLine1 = src.addressLine1,
         city = src.city, country = src.country, creditlimit = src.creditLimit,
         salesrepemployeesNumber = src.salesRepEmployeeNumber,
         contactLastName = src.contactLastName, contactFirstName = src.contactFirstName,
         KeyDimContact = src.KeyDimContact
    WHEN NOT MATCHED THEN INSERT
         (CustomersNumber, customerName, phone, adresseLine1, city, country, creditlimit,
          salesrepemployeesNumber, contactLastName, contactFirstName, KeyDimContact)
    VALUES (src.customerNumber, src.customerName, src.phone, src.addressLine1, src.city, src.country,
            src.creditLimit, src.salesRepEmployeeNumber, src.contactLastName, src.contactFirstName,
            src.KeyDimContact);
END
GO

/* ------------------------- Bureaux / Employés ----------------------- */
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimOffice
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimOffice AS cible
    USING (SELECT officeCode, city, country, territory, phone, addressLine1, postalCode
           FROM MACROBUS_PROD.dbo.offices) AS src
       ON cible.officeCode = src.officeCode
    WHEN MATCHED THEN UPDATE SET
         city = src.city, country = src.country, territory = src.territory,
         phone = src.phone, adressLine1 = src.addressLine1, postalCode = src.postalCode
    WHEN NOT MATCHED THEN INSERT (officeCode, city, country, territory, phone, adressLine1, postalCode)
    VALUES (src.officeCode, src.city, src.country, src.territory, src.phone, src.addressLine1, src.postalCode);
END
GO

CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimEmployees
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimEmployees AS cible
    USING (
        SELECT e.employeeNumber, e.firstName + ' ' + e.lastName AS fullName, e.officeCode,
               e.extension, e.email, e.jobTitle, e.reportsTo, o.KeyDimOffices
        FROM MACROBUS_PROD.dbo.employees e
        JOIN dbo.DimOffice o ON o.officeCode = e.officeCode               -- lookup flocon
    ) AS src
       ON cible.employeeNumber = src.employeeNumber
    WHEN MATCHED THEN UPDATE SET
         fullName_FirstName_LastName_ = src.fullName, officeCode = src.officeCode,
         extension = src.extension, email = src.email, jopTitle = src.jobTitle,
         ReportTo = src.reportsTo, KeyDimOffices = src.KeyDimOffices
    WHEN NOT MATCHED THEN INSERT
         (employeeNumber, fullName_FirstName_LastName_, officeCode, extension, email, jopTitle, ReportTo, KeyDimOffices)
    VALUES (src.employeeNumber, src.fullName, src.officeCode, src.extension, src.email,
            src.jobTitle, src.reportsTo, src.KeyDimOffices);
END
GO

-- Commercial = employé rattaché à au moins un client (salesRepEmployeeNumber) ou de fonction "Sales Rep"
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimCommerciaux
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimCommerciaux AS cible
    USING (
        SELECT e.employeeNumber, e.firstName + ' ' + e.lastName AS fullName, e.officeCode,
               e.extension, e.email, e.jobTitle, e.reportsTo
        FROM MACROBUS_PROD.dbo.employees e
        WHERE e.jobTitle = 'Sales Rep'
           OR e.employeeNumber IN (SELECT salesRepEmployeeNumber FROM MACROBUS_PROD.dbo.customers
                                   WHERE salesRepEmployeeNumber IS NOT NULL)
    ) AS src
       ON cible.employeeNumber = src.employeeNumber
    WHEN MATCHED THEN UPDATE SET
         fullName_FirstName_LastName_ = src.fullName, officeCode = src.officeCode,
         extension = src.extension, email = src.email, jopTitle = src.jobTitle, ReportTo = src.reportsTo
    WHEN NOT MATCHED THEN INSERT
         (employeeNumber, fullName_FirstName_LastName_, officeCode, extension, email, jopTitle, ReportTo)
    VALUES (src.employeeNumber, src.fullName, src.officeCode, src.extension, src.email, src.jobTitle, src.reportsTo);
END
GO

-- Manager = employé auquel au moins un autre employé rend compte (reportsTo)
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimManagers
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.DimManagers AS cible
    USING (
        SELECT e.employeeNumber, e.firstName + ' ' + e.lastName AS fullName, e.officeCode,
               e.extension, e.email, e.jobTitle, e.reportsTo
        FROM MACROBUS_PROD.dbo.employees e
        WHERE e.employeeNumber IN (SELECT reportsTo FROM MACROBUS_PROD.dbo.employees WHERE reportsTo IS NOT NULL)
    ) AS src
       ON cible.employeeNumber = src.employeeNumber
    WHEN MATCHED THEN UPDATE SET
         fullName_FirstName_LastName_ = src.fullName, officeCode = src.officeCode,
         extension = src.extension, email = src.email, jopTitle = src.jobTitle, ReportTo = src.reportsTo
    WHEN NOT MATCHED THEN INSERT
         (employeeNumber, fullName_FirstName_LastName_, officeCode, extension, email, jopTitle, ReportTo)
    VALUES (src.employeeNumber, src.fullName, src.officeCode, src.extension, src.email, src.jobTitle, src.reportsTo);
END
GO

/* ----------------------------- Géographie --------------------------- */
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimGeographieOffice
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.DimGeographieOffice (city, state, country, territory)
    SELECT DISTINCT o.city, o.state, o.country, o.territory
    FROM MACROBUS_PROD.dbo.offices o
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimGeographieOffice g
                      WHERE g.city = o.city AND g.country = o.country AND g.territory = o.territory);
END
GO

-- Le territoire d'un client = territoire du bureau de son commercial
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimGeographieClient
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.DimGeographieClient (city, state, country, territory)
    SELECT src.city, MAX(src.state), src.country, src.territory
    FROM (
        SELECT c.city, c.state, c.country, ISNULL(o.territory, 'N/A') AS territory
        FROM MACROBUS_PROD.dbo.customers c
        LEFT JOIN MACROBUS_PROD.dbo.employees e ON e.employeeNumber = c.salesRepEmployeeNumber
        LEFT JOIN MACROBUS_PROD.dbo.offices   o ON o.officeCode     = e.officeCode
    ) src
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimGeographieClient g
                      WHERE g.city = src.city AND g.country = src.country AND g.territory = src.territory)
    GROUP BY src.city, src.country, src.territory;
END
GO

/* ----------------- Procédure maître : toutes les dimensions ---------------- */
CREATE OR ALTER PROCEDURE dbo.ps_ChargerDimensions
AS
BEGIN
    SET NOCOUNT ON;
    -- l'ordre respecte le flocon : la dimension "parente" avant la dimension "enfant"
    EXEC dbo.ps_ChargerDimProductLine;
    EXEC dbo.ps_ChargerDimProduct;
    EXEC dbo.ps_ChargerDimFournisseur;
    EXEC dbo.ps_ChargerDimContact;
    EXEC dbo.ps_ChargerDimCustomers;
    EXEC dbo.ps_ChargerDimOffice;
    EXEC dbo.ps_ChargerDimEmployees;
    EXEC dbo.ps_ChargerDimCommerciaux;
    EXEC dbo.ps_ChargerDimManagers;
    EXEC dbo.ps_ChargerDimGeographieOffice;
    EXEC dbo.ps_ChargerDimGeographieClient;
END
GO
