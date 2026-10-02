/* =====================================================================
   PROJET MACROBUS - 02 : Création de l'entrepôt MACROBUS_DWH_XXXX
   ---------------------------------------------------------------------
   Modèle en FLOCON (snowflake) :
     FaitOrders (grain = 1 ligne de commande = 1 produit dans 1 commande)
       -> DimDate (x3 rôles : date commande, date expédition, date requise)
       -> DimProduct  -> DimProductLine          (flocon)
       -> DimFournisseur
       -> DimCustomers -> DimContact             (flocon)
       -> DimEmployees -> DimOffice              (flocon)
       -> DimCommerciaux
       -> DimManagers
       -> DimGeographieClient
       -> DimGeographieOffice
   ⚠ Remplacez XXXX par le numéro de votre groupe (Ctrl+H dans SSMS).
   ===================================================================== */
USE master;
GO
IF DB_ID('MACROBUS_DWH_XXXX') IS NOT NULL
BEGIN
    ALTER DATABASE MACROBUS_DWH_XXXX SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MACROBUS_DWH_XXXX;
END
GO
CREATE DATABASE MACROBUS_DWH_XXXX;
GO
USE MACROBUS_DWH_XXXX;
GO

/* --------------------------- DimDate ------------------------------ */
CREATE TABLE dbo.DimDate (
    KeyDimDate      INT          NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY, -- AAAAMMJJ (-1 = inconnue)
    DateComplete    DATE         NULL,
    Jour            TINYINT      NULL,
    NomJour         VARCHAR(20)  NULL,
    NumSemaine      TINYINT      NULL,
    Mois            TINYINT      NULL,
    NomMois         VARCHAR(20)  NULL,
    Trimestre       TINYINT      NULL,
    LibTrimestre    VARCHAR(10)  NULL,   -- ex. 2003-T2
    Semestre        TINYINT      NULL,
    LibSemestre     VARCHAR(10)  NULL,   -- ex. 2003-S2
    Annee           SMALLINT     NULL,
    AnneeMois       CHAR(7)      NULL    -- ex. 2003-04
);

/* ------------------------ Produits (flocon) ------------------------ */
CREATE TABLE dbo.DimProductLine (
    KeyDimProductLine INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProductLine PRIMARY KEY,
    productLine       VARCHAR(50)   NOT NULL CONSTRAINT UQ_DimProductLine UNIQUE,
    textDescription   VARCHAR(4000) NULL
);

CREATE TABLE dbo.DimProduct (
    KeyDimProduct      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
    productCode        VARCHAR(15)   NOT NULL CONSTRAINT UQ_DimProduct UNIQUE,
    productName        VARCHAR(70)   NOT NULL,
    productScale       VARCHAR(10)   NULL,
    productDescription VARCHAR(MAX)  NULL,
    quantityInStock    SMALLINT      NULL,
    buyPrice           DECIMAL(10,2) NULL,
    MSRP               DECIMAL(10,2) NULL,
    productLine        VARCHAR(50)   NULL,
    KeyDimProductLine  INT           NOT NULL
        CONSTRAINT FK_DimProduct_DimProductLine REFERENCES dbo.DimProductLine(KeyDimProductLine)
);

CREATE TABLE dbo.DimFournisseur (
    keyDimFournisseur INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimFournisseur PRIMARY KEY,
    codeDuProduit     VARCHAR(15) NOT NULL CONSTRAINT UQ_DimFournisseur UNIQUE,
    productVendor     VARCHAR(50) NOT NULL
);

/* ------------------------ Clients (flocon) ------------------------- */
CREATE TABLE dbo.DimContact (
    KeyDimContact    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimContact PRIMARY KEY,
    CustomersNumber  INT          NOT NULL CONSTRAINT UQ_DimContact UNIQUE,
    contactFirstName VARCHAR(50)  NOT NULL,
    contactLastName  VARCHAR(50)  NOT NULL,
    contactFullName  VARCHAR(101) NOT NULL,
    phone            VARCHAR(50)  NULL
);

CREATE TABLE dbo.DimCustomers (
    KeyDimCustomers             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCustomers PRIMARY KEY,
    CustomersNumber             INT           NOT NULL CONSTRAINT UQ_DimCustomers UNIQUE,
    customerName                VARCHAR(50)   NOT NULL,
    phone                       VARCHAR(50)   NULL,
    adresseLine1                VARCHAR(50)   NULL,
    city                        VARCHAR(50)   NULL,
    country                     VARCHAR(50)   NULL,
    creditlimit                 DECIMAL(10,2) NULL,
    salesrepemployeesNumber     INT           NULL,
    contactLastName             VARCHAR(50)   NULL,
    contactFirstName            VARCHAR(50)   NULL,
    KeyDimContact               INT           NOT NULL
        CONSTRAINT FK_DimCustomers_DimContact REFERENCES dbo.DimContact(KeyDimContact)
);

/* ----------------------- Employés (flocon) ------------------------- */
CREATE TABLE dbo.DimOffice (
    KeyDimOffices INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimOffice PRIMARY KEY,
    officeCode    VARCHAR(10) NOT NULL CONSTRAINT UQ_DimOffice UNIQUE,
    city          VARCHAR(50) NOT NULL,
    country       VARCHAR(50) NOT NULL,
    territory     VARCHAR(10) NOT NULL,
    phone         VARCHAR(50) NULL,
    adressLine1   VARCHAR(50) NULL,
    postalCode    VARCHAR(15) NULL
);

CREATE TABLE dbo.DimEmployees (
    KeyDimEmployees                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEmployees PRIMARY KEY,
    employeeNumber                 INT          NOT NULL CONSTRAINT UQ_DimEmployees UNIQUE,
    fullName_FirstName_LastName_   VARCHAR(101) NOT NULL,
    officeCode                     VARCHAR(10)  NOT NULL,
    extension                      VARCHAR(10)  NULL,
    email                          VARCHAR(100) NULL,
    jopTitle                       VARCHAR(50)  NULL,
    ReportTo                       INT          NULL,
    KeyDimOffices                  INT          NOT NULL
        CONSTRAINT FK_DimEmployees_DimOffice REFERENCES dbo.DimOffice(KeyDimOffices)
);

CREATE TABLE dbo.DimCommerciaux (
    KeyDimCommerciaux              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCommerciaux PRIMARY KEY,
    employeeNumber                 INT          NOT NULL CONSTRAINT UQ_DimCommerciaux UNIQUE,
    fullName_FirstName_LastName_   VARCHAR(101) NOT NULL,
    officeCode                     VARCHAR(10)  NOT NULL,
    extension                      VARCHAR(10)  NULL,
    email                          VARCHAR(100) NULL,
    jopTitle                       VARCHAR(50)  NULL,
    ReportTo                       INT          NULL
);

CREATE TABLE dbo.DimManagers (
    KeyDimManagers                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimManagers PRIMARY KEY,
    employeeNumber                 INT          NOT NULL CONSTRAINT UQ_DimManagers UNIQUE,
    fullName_FirstName_LastName_   VARCHAR(101) NOT NULL,
    officeCode                     VARCHAR(10)  NOT NULL,
    extension                      VARCHAR(10)  NULL,
    email                          VARCHAR(100) NULL,
    jopTitle                       VARCHAR(50)  NULL,
    ReportTo                       INT          NULL
);

/* --------------------------- Géographie ---------------------------- */
CREATE TABLE dbo.DimGeographieClient (
    KeyDimGeographieClient INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimGeographieClient PRIMARY KEY,
    city      VARCHAR(50) NOT NULL,
    state     VARCHAR(50) NULL,
    country   VARCHAR(50) NOT NULL,
    territory VARCHAR(10) NOT NULL,   -- territoire commercial (celui du bureau du commercial)
    CONSTRAINT UQ_DimGeographieClient UNIQUE (city, country, territory)
);

CREATE TABLE dbo.DimGeographieOffice (
    KeyDimGeographieOffice INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimGeographieOffice PRIMARY KEY,
    city      VARCHAR(50) NOT NULL,
    state     VARCHAR(50) NULL,
    country   VARCHAR(50) NOT NULL,
    territory VARCHAR(10) NOT NULL,
    CONSTRAINT UQ_DimGeographieOffice UNIQUE (city, country, territory)
);

/* ---------------------------- FaitOrders --------------------------- */
CREATE TABLE dbo.FaitOrders (
    orderNumber             INT           NOT NULL,
    orderLineNumber         SMALLINT      NOT NULL,
    -- mesures
    QuantityOrdere          INT           NOT NULL,
    unitPrice               DECIMAL(10,2) NOT NULL,
    Montant                 DECIMAL(12,2) NOT NULL,   -- QuantityOrdere * unitPrice
    -- attributs dégénérés
    status                  VARCHAR(15)   NULL,
    comments                VARCHAR(MAX)  NULL,
    -- dates (rôles de DimDate)
    KeyOrderDate            INT NOT NULL CONSTRAINT FK_Fait_DateCommande   REFERENCES dbo.DimDate(KeyDimDate),
    KeyShipperDate          INT NOT NULL CONSTRAINT FK_Fait_DateExpedition REFERENCES dbo.DimDate(KeyDimDate),
    KeyRequiredDate         INT NOT NULL CONSTRAINT FK_Fait_DateRequise    REFERENCES dbo.DimDate(KeyDimDate),
    -- clés étrangères vers les dimensions
    KeyDimEmployees         INT NOT NULL CONSTRAINT FK_Fait_Employees   REFERENCES dbo.DimEmployees(KeyDimEmployees),
    KeyDimCustomers         INT NOT NULL CONSTRAINT FK_Fait_Customers   REFERENCES dbo.DimCustomers(KeyDimCustomers),
    KeyDimGeographieOffice  INT NOT NULL CONSTRAINT FK_Fait_GeoOffice   REFERENCES dbo.DimGeographieOffice(KeyDimGeographieOffice),
    KeyDimGeographieClient  INT NOT NULL CONSTRAINT FK_Fait_GeoClient   REFERENCES dbo.DimGeographieClient(KeyDimGeographieClient),
    keyDimFournisseur       INT NOT NULL CONSTRAINT FK_Fait_Fournisseur REFERENCES dbo.DimFournisseur(keyDimFournisseur),
    KeyDimProduct           INT NOT NULL CONSTRAINT FK_Fait_Product     REFERENCES dbo.DimProduct(KeyDimProduct),
    KeyDimCommerciaux       INT NOT NULL CONSTRAINT FK_Fait_Commerciaux REFERENCES dbo.DimCommerciaux(KeyDimCommerciaux),
    KeyDimManagers          INT NOT NULL CONSTRAINT FK_Fait_Managers    REFERENCES dbo.DimManagers(KeyDimManagers),
    CONSTRAINT PK_FaitOrders PRIMARY KEY (orderNumber, KeyDimProduct)
);
GO

CREATE INDEX IX_Fait_OrderDate   ON dbo.FaitOrders(KeyOrderDate);
CREATE INDEX IX_Fait_Commerciaux ON dbo.FaitOrders(KeyDimCommerciaux);
CREATE INDEX IX_Fait_GeoOffice   ON dbo.FaitOrders(KeyDimGeographieOffice);
GO

/* ------------- Remplissage de DimDate (2003-01-01 -> 2006-12-31) ------------- */
SET LANGUAGE French;
INSERT INTO dbo.DimDate (KeyDimDate, NomJour, NomMois, LibTrimestre, LibSemestre)
VALUES (-1, 'Inconnue', 'Inconnue', 'Inconnu', 'Inconnu');   -- membre "date inconnue" (ex. commande non expédiée)

DECLARE @d DATE = '2003-01-01';
WHILE @d <= '2006-12-31'
BEGIN
    INSERT INTO dbo.DimDate
    VALUES (
        CONVERT(INT, FORMAT(@d, 'yyyyMMdd')),
        @d,
        DAY(@d),
        DATENAME(WEEKDAY, @d),
        DATEPART(ISO_WEEK, @d),
        MONTH(@d),
        DATENAME(MONTH, @d),
        DATEPART(QUARTER, @d),
        CONCAT(YEAR(@d), '-T', DATEPART(QUARTER, @d)),
        CASE WHEN MONTH(@d) <= 6 THEN 1 ELSE 2 END,
        CONCAT(YEAR(@d), '-S', CASE WHEN MONTH(@d) <= 6 THEN 1 ELSE 2 END),
        YEAR(@d),
        FORMAT(@d, 'yyyy-MM')
    );
    SET @d = DATEADD(DAY, 1, @d);
END
SET LANGUAGE us_english;
GO

SELECT COUNT(*) AS nbJoursDimDate FROM dbo.DimDate;
GO
