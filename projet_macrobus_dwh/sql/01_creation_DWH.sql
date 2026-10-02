/* =====================================================================
   PROJET MACROBUS - Script 01 : Creation de l'entrepot MACROBUS_DWH_2
   ---------------------------------------------------------------------
   Source : base de production MACROBUS_PROD (script 00)
   >>> Si votre base de production a un autre nom, modifier uniquement
       la section "SYNONYMES" en bas du script.

   Modele en FLOCON (snowflake) - grain de la table de fait :
       1 ligne = 1 ligne de commande (orderNumber + productCode)

   Flocons (dimensions normalisees) :
       FaitOrders -> DimProduct      -> DimProductLine
       FaitOrders -> DimCustomers    -> DimContact
       FaitOrders -> DimCommerciaux  -> DimOffice
   Dimension a roles multiples (role-playing) :
       DimDate       : date de commande / date requise / date d'expedition
       DimGeographie : geographie du client / geographie de la filiale
   ===================================================================== */

IF DB_ID('MACROBUS_DWH_2') IS NULL
    CREATE DATABASE MACROBUS_DWH_2;
GO
USE MACROBUS_DWH_2;
GO

/* ---------- Nettoyage (permet de relancer le script) ---------------- */
IF OBJECT_ID('dbo.FaitOrders')       IS NOT NULL DROP TABLE dbo.FaitOrders;
IF OBJECT_ID('dbo.DimCustomers')     IS NOT NULL DROP TABLE dbo.DimCustomers;
IF OBJECT_ID('dbo.DimContact')       IS NOT NULL DROP TABLE dbo.DimContact;
IF OBJECT_ID('dbo.DimProduct')       IS NOT NULL DROP TABLE dbo.DimProduct;
IF OBJECT_ID('dbo.DimProductLine')   IS NOT NULL DROP TABLE dbo.DimProductLine;
IF OBJECT_ID('dbo.DimFournisseur')   IS NOT NULL DROP TABLE dbo.DimFournisseur;
IF OBJECT_ID('dbo.DimCommerciaux')   IS NOT NULL DROP TABLE dbo.DimCommerciaux;
IF OBJECT_ID('dbo.DimManagers')      IS NOT NULL DROP TABLE dbo.DimManagers;
IF OBJECT_ID('dbo.DimOffice')        IS NOT NULL DROP TABLE dbo.DimOffice;
IF OBJECT_ID('dbo.DimGeographie')    IS NOT NULL DROP TABLE dbo.DimGeographie;
IF OBJECT_ID('dbo.DimDate')          IS NOT NULL DROP TABLE dbo.DimDate;
IF OBJECT_ID('dbo.EtlLog')           IS NOT NULL DROP TABLE dbo.EtlLog;
GO

/* =====================================================================
   1. DIMENSION TEMPS
   ===================================================================== */
CREATE TABLE dbo.DimDate (
    KeyDimDate      INT          NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY, -- AAAAMMJJ
    FullDate        DATE         NOT NULL,
    Jour            TINYINT      NOT NULL,
    NomJour         NVARCHAR(10) NOT NULL,
    JourSemaine     TINYINT      NOT NULL,      -- 1 = lundi ... 7 = dimanche
    SemaineAnnee    TINYINT      NOT NULL,      -- semaine ISO
    Mois            TINYINT      NOT NULL,
    NomMois         NVARCHAR(10) NOT NULL,
    Trimestre       TINYINT      NOT NULL,
    LibelleTrimestre NVARCHAR(10) NOT NULL,     -- ex : T2-2003
    Semestre        TINYINT      NOT NULL,
    LibelleSemestre NVARCHAR(10) NOT NULL,      -- ex : S2-2003
    Annee           SMALLINT     NOT NULL,
    AnneeMois       INT          NOT NULL,      -- ex : 200307 (tri)
    EstWeekEnd      BIT          NOT NULL
);

/* =====================================================================
   2. DIMENSION GEOGRAPHIE (DimGeographie) - utilisee 2 fois par le fait
      (geographie client + geographie filiale)
   ===================================================================== */
CREATE TABLE dbo.DimGeographie (
    KeyDimGeographie INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimGeographie PRIMARY KEY,
    City             NVARCHAR(50) NOT NULL,
    State            NVARCHAR(50) NOT NULL,   -- 'N/A' si absent
    Country          NVARCHAR(50) NOT NULL,
    Territory        NVARCHAR(10) NOT NULL,   -- NA, EMEA, APAC, Japan
    CONSTRAINT UQ_DimGeographie UNIQUE (City, State, Country)
);

/* =====================================================================
   3. PRODUIT (flocon : DimProduct -> DimProductLine) + FOURNISSEUR
   ===================================================================== */
CREATE TABLE dbo.DimProductLine (
    KeyDimProductLine INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProductLine PRIMARY KEY,
    ProductLine       NVARCHAR(50)   NOT NULL CONSTRAINT UQ_DimProductLine UNIQUE,
    TextDescription   NVARCHAR(4000) NULL
);

CREATE TABLE dbo.DimProduct (
    KeyDimProduct      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
    ProductCode        NVARCHAR(15)   NOT NULL CONSTRAINT UQ_DimProduct UNIQUE,
    ProductName        NVARCHAR(70)   NOT NULL,
    ProductScale       NVARCHAR(10)   NULL,
    ProductDescription NVARCHAR(4000) NULL,
    QuantityInStock    INT            NULL,
    BuyPrice           DECIMAL(10,2)  NULL,
    MSRP               DECIMAL(10,2)  NULL,
    ProductLine        NVARCHAR(50)   NULL,
    KeyDimProductLine  INT            NOT NULL
        CONSTRAINT FK_DimProduct_ProductLine REFERENCES dbo.DimProductLine(KeyDimProductLine)
);

CREATE TABLE dbo.DimFournisseur (
    KeyDimFournisseur INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimFournisseur PRIMARY KEY,
    ProductVendor     NVARCHAR(50) NOT NULL CONSTRAINT UQ_DimFournisseur UNIQUE
);

/* =====================================================================
   4. CLIENT (flocon : DimCustomers -> DimContact)
   ===================================================================== */
CREATE TABLE dbo.DimContact (
    KeyDimContact    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimContact PRIMARY KEY,
    CustomerNumber   INT           NOT NULL CONSTRAINT UQ_DimContact UNIQUE, -- 1 contact par client
    ContactFirstName NVARCHAR(50)  NOT NULL,
    ContactLastName  NVARCHAR(50)  NOT NULL,
    ContactFullName  NVARCHAR(101) NOT NULL,
    Phone            NVARCHAR(50)  NULL
);

CREATE TABLE dbo.DimCustomers (
    KeyDimCustomers         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCustomers PRIMARY KEY,
    CustomerNumber          INT           NOT NULL CONSTRAINT UQ_DimCustomers UNIQUE,
    CustomerName            NVARCHAR(50)  NOT NULL,
    Phone                   NVARCHAR(50)  NULL,
    AddressLine1            NVARCHAR(50)  NULL,
    PostalCode              NVARCHAR(15)  NULL,
    CreditLimit             DECIMAL(10,2) NULL,
    SalesRepEmployeeNumber  INT           NULL,
    KeyDimContact           INT           NOT NULL
        CONSTRAINT FK_DimCustomers_Contact REFERENCES dbo.DimContact(KeyDimContact)
);

/* =====================================================================
   5. ORGANISATION COMMERCIALE
      DimOffice (filiales), DimCommerciaux (-> DimOffice), DimManagers
   ===================================================================== */
CREATE TABLE dbo.DimOffice (
    KeyDimOffice INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimOffice PRIMARY KEY,
    OfficeCode   NVARCHAR(10) NOT NULL CONSTRAINT UQ_DimOffice UNIQUE,
    NomFiliale   NVARCHAR(60) NOT NULL,      -- ex : 'Paris (France)'
    Phone        NVARCHAR(50) NULL,
    AddressLine1 NVARCHAR(50) NULL,
    PostalCode   NVARCHAR(15) NULL
);

CREATE TABLE dbo.DimCommerciaux (
    KeyDimCommerciaux INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCommerciaux PRIMARY KEY,
    EmployeeNumber    INT           NOT NULL CONSTRAINT UQ_DimCommerciaux UNIQUE,
    FirstName         NVARCHAR(50)  NOT NULL,
    LastName          NVARCHAR(50)  NOT NULL,
    FullName          NVARCHAR(101) NOT NULL,
    OfficeCode        NVARCHAR(10)  NULL,
    Extension         NVARCHAR(10)  NULL,
    Email             NVARCHAR(100) NULL,
    JobTitle          NVARCHAR(50)  NULL,
    ReportsTo         INT           NULL,
    KeyDimOffice      INT           NOT NULL
        CONSTRAINT FK_DimCommerciaux_Office REFERENCES dbo.DimOffice(KeyDimOffice)
);

CREATE TABLE dbo.DimManagers (
    KeyDimManagers INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimManagers PRIMARY KEY,
    EmployeeNumber INT           NOT NULL CONSTRAINT UQ_DimManagers UNIQUE,
    FirstName      NVARCHAR(50)  NOT NULL,
    LastName       NVARCHAR(50)  NOT NULL,
    FullName       NVARCHAR(101) NOT NULL,
    OfficeCode     NVARCHAR(10)  NULL,
    Extension      NVARCHAR(10)  NULL,
    Email          NVARCHAR(100) NULL,
    JobTitle       NVARCHAR(50)  NULL,
    ReportsTo      INT           NULL
);

/* =====================================================================
   6. TABLE DE FAIT
   ===================================================================== */
CREATE TABLE dbo.FaitOrders (
    KeyFaitOrders           BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FaitOrders PRIMARY KEY,
    -- Dimensions degenerees (viennent de la commande elle-meme)
    OrderNumber             INT            NOT NULL,
    OrderLineNumber         SMALLINT       NOT NULL,
    Status                  NVARCHAR(15)   NOT NULL,
    Comments                NVARCHAR(4000) NULL,
    -- Cles etrangeres
    KeyDateCommande         INT NOT NULL CONSTRAINT FK_Fait_DateCommande   REFERENCES dbo.DimDate(KeyDimDate),
    KeyDateRequise          INT NOT NULL CONSTRAINT FK_Fait_DateRequise    REFERENCES dbo.DimDate(KeyDimDate),
    KeyDateExpedition       INT NOT NULL CONSTRAINT FK_Fait_DateExpedition REFERENCES dbo.DimDate(KeyDimDate),
    KeyDimProduct           INT NOT NULL CONSTRAINT FK_Fait_Product        REFERENCES dbo.DimProduct(KeyDimProduct),
    KeyDimFournisseur       INT NOT NULL CONSTRAINT FK_Fait_Fournisseur    REFERENCES dbo.DimFournisseur(KeyDimFournisseur),
    KeyDimCustomers         INT NOT NULL CONSTRAINT FK_Fait_Customers      REFERENCES dbo.DimCustomers(KeyDimCustomers),
    KeyDimGeographieClient  INT NOT NULL CONSTRAINT FK_Fait_GeoClient      REFERENCES dbo.DimGeographie(KeyDimGeographie),
    KeyDimGeographieOffice  INT NOT NULL CONSTRAINT FK_Fait_GeoOffice      REFERENCES dbo.DimGeographie(KeyDimGeographie),
    KeyDimCommerciaux       INT NOT NULL CONSTRAINT FK_Fait_Commerciaux    REFERENCES dbo.DimCommerciaux(KeyDimCommerciaux),
    KeyDimManagers          INT NOT NULL CONSTRAINT FK_Fait_Managers       REFERENCES dbo.DimManagers(KeyDimManagers),
    -- Mesures
    QuantityOrdered         INT            NOT NULL,
    UnitPrice               DECIMAL(10,2)  NOT NULL,
    Montant                 DECIMAL(14,2)  NOT NULL,   -- QuantityOrdered * UnitPrice
    CoutAchat               DECIMAL(14,2)  NOT NULL,   -- QuantityOrdered * BuyPrice
    Marge                   DECIMAL(14,2)  NOT NULL,   -- Montant - CoutAchat
    DelaiExpeditionJours    INT            NULL,       -- shippedDate - orderDate
    LivreEnRetard           BIT            NULL,       -- shippedDate > requiredDate
    DateChargement          DATETIME2(0)   NOT NULL CONSTRAINT DF_Fait_DateChargement DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_FaitOrders_Ligne UNIQUE (OrderNumber, KeyDimProduct)
);

CREATE INDEX IX_Fait_DateCommande  ON dbo.FaitOrders(KeyDateCommande);
CREATE INDEX IX_Fait_Product       ON dbo.FaitOrders(KeyDimProduct);
CREATE INDEX IX_Fait_Customers     ON dbo.FaitOrders(KeyDimCustomers);
CREATE INDEX IX_Fait_Commerciaux   ON dbo.FaitOrders(KeyDimCommerciaux);
CREATE INDEX IX_Fait_GeoOffice     ON dbo.FaitOrders(KeyDimGeographieOffice);
GO

/* =====================================================================
   7. JOURNAL D'EXECUTION ETL (utile pour le rapport)
   ===================================================================== */
CREATE TABLE dbo.EtlLog (
    IdLog        INT IDENTITY(1,1) PRIMARY KEY,
    Traitement   NVARCHAR(100) NOT NULL,
    DateDebut    DATETIME2(0)  NOT NULL,
    DateFin      DATETIME2(0)  NULL,
    NbInseres    INT           NULL,
    NbMisAJour   INT           NULL,
    Statut       NVARCHAR(20)  NOT NULL,
    MessageErreur NVARCHAR(4000) NULL
);
GO

/* =====================================================================
   8. MEMBRES "INCONNU" (cle -1) : evite les NULL dans la table de fait
      ex : commande non encore expediee, client sans commercial,
           commercial sans manager (le President)...
   ===================================================================== */
INSERT INTO dbo.DimDate VALUES
 (-1, '1900-01-01', 0, N'Inconnu', 0, 0, 0, N'Inconnu', 0, N'Inconnu', 0, N'Inconnu', 0, 0, 0);

SET IDENTITY_INSERT dbo.DimGeographie ON;
INSERT INTO dbo.DimGeographie (KeyDimGeographie, City, State, Country, Territory)
VALUES (-1, N'Inconnu', N'N/A', N'Inconnu', N'N/A');
SET IDENTITY_INSERT dbo.DimGeographie OFF;

SET IDENTITY_INSERT dbo.DimProductLine ON;
INSERT INTO dbo.DimProductLine (KeyDimProductLine, ProductLine, TextDescription)
VALUES (-1, N'Inconnu', NULL);
SET IDENTITY_INSERT dbo.DimProductLine OFF;

SET IDENTITY_INSERT dbo.DimFournisseur ON;
INSERT INTO dbo.DimFournisseur (KeyDimFournisseur, ProductVendor) VALUES (-1, N'Inconnu');
SET IDENTITY_INSERT dbo.DimFournisseur OFF;

SET IDENTITY_INSERT dbo.DimContact ON;
INSERT INTO dbo.DimContact (KeyDimContact, CustomerNumber, ContactFirstName, ContactLastName, ContactFullName, Phone)
VALUES (-1, -1, N'Inconnu', N'Inconnu', N'Inconnu', NULL);
SET IDENTITY_INSERT dbo.DimContact OFF;

SET IDENTITY_INSERT dbo.DimOffice ON;
INSERT INTO dbo.DimOffice (KeyDimOffice, OfficeCode, NomFiliale) VALUES (-1, N'N/A', N'Inconnue');
SET IDENTITY_INSERT dbo.DimOffice OFF;

SET IDENTITY_INSERT dbo.DimCommerciaux ON;
INSERT INTO dbo.DimCommerciaux (KeyDimCommerciaux, EmployeeNumber, FirstName, LastName, FullName, KeyDimOffice)
VALUES (-1, -1, N'Inconnu', N'Inconnu', N'Sans commercial', -1);
SET IDENTITY_INSERT dbo.DimCommerciaux OFF;

SET IDENTITY_INSERT dbo.DimManagers ON;
INSERT INTO dbo.DimManagers (KeyDimManagers, EmployeeNumber, FirstName, LastName, FullName)
VALUES (-1, -1, N'Inconnu', N'Inconnu', N'Sans manager');
SET IDENTITY_INSERT dbo.DimManagers OFF;
GO

/* =====================================================================
   9. SYNONYMES vers la base de PRODUCTION
      -> Seul endroit a modifier si votre base source a un autre nom.
      Les procedures stockees lisent la source via le schema "src".
   ===================================================================== */
IF SCHEMA_ID('src') IS NULL EXEC('CREATE SCHEMA src');
GO
IF OBJECT_ID('src.offices')      IS NOT NULL DROP SYNONYM src.offices;
IF OBJECT_ID('src.employees')    IS NOT NULL DROP SYNONYM src.employees;
IF OBJECT_ID('src.customers')    IS NOT NULL DROP SYNONYM src.customers;
IF OBJECT_ID('src.productlines') IS NOT NULL DROP SYNONYM src.productlines;
IF OBJECT_ID('src.products')     IS NOT NULL DROP SYNONYM src.products;
IF OBJECT_ID('src.orders')       IS NOT NULL DROP SYNONYM src.orders;
IF OBJECT_ID('src.orderdetails') IS NOT NULL DROP SYNONYM src.orderdetails;
GO
CREATE SYNONYM src.offices      FOR MACROBUS_PROD.dbo.offices;
CREATE SYNONYM src.employees    FOR MACROBUS_PROD.dbo.employees;
CREATE SYNONYM src.customers    FOR MACROBUS_PROD.dbo.customers;
CREATE SYNONYM src.productlines FOR MACROBUS_PROD.dbo.productlines;
CREATE SYNONYM src.products     FOR MACROBUS_PROD.dbo.products;
CREATE SYNONYM src.orders       FOR MACROBUS_PROD.dbo.orders;
CREATE SYNONYM src.orderdetails FOR MACROBUS_PROD.dbo.orderdetails;
GO

PRINT 'Entrepot MACROBUS_DWH_2 cree avec succes.';
