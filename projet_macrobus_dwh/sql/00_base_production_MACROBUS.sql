/* =====================================================================
   PROJET MACROBUS - Script 00 : Base de PRODUCTION (source OLTP)
   ---------------------------------------------------------------------
   A n'executer QUE si vous n'avez pas encore la base de production
   sous SQL Server (ex : la base vous a ete donnee en MySQL
   "classicmodels"). Elle recree la structure a l'identique, il suffit
   ensuite d'y importer les donnees (Assistant d'import SSMS, ou script
   d'INSERT fourni par l'enseignant).

   Si votre base de production existe deja : NE PAS executer ce script,
   notez simplement son nom (ici MACROBUS) et adaptez les synonymes du
   script 01.
   ===================================================================== */

IF DB_ID('MACROBUS') IS NULL
    CREATE DATABASE MACROBUS;
GO
USE MACROBUS;
GO

CREATE TABLE dbo.offices (
    officeCode   VARCHAR(10)  NOT NULL PRIMARY KEY,
    city         VARCHAR(50)  NOT NULL,
    phone        VARCHAR(50)  NOT NULL,
    addressLine1 VARCHAR(50)  NOT NULL,
    addressLine2 VARCHAR(50)  NULL,
    state        VARCHAR(50)  NULL,
    country      VARCHAR(50)  NOT NULL,
    postalCode   VARCHAR(15)  NOT NULL,
    territory    VARCHAR(10)  NOT NULL
);

CREATE TABLE dbo.employees (
    employeeNumber INT          NOT NULL PRIMARY KEY,
    lastName       VARCHAR(50)  NOT NULL,
    firstName      VARCHAR(50)  NOT NULL,
    extension      VARCHAR(10)  NOT NULL,
    email          VARCHAR(100) NOT NULL,
    officeCode     VARCHAR(10)  NOT NULL REFERENCES dbo.offices(officeCode),
    reportsTo      INT          NULL REFERENCES dbo.employees(employeeNumber),
    jobTitle       VARCHAR(50)  NOT NULL
);

CREATE TABLE dbo.customers (
    customerNumber         INT           NOT NULL PRIMARY KEY,
    customerName           VARCHAR(50)   NOT NULL,
    contactLastName        VARCHAR(50)   NOT NULL,
    contactFirstName       VARCHAR(50)   NOT NULL,
    phone                  VARCHAR(50)   NOT NULL,
    addressLine1           VARCHAR(50)   NOT NULL,
    addressLine2           VARCHAR(50)   NULL,
    city                   VARCHAR(50)   NOT NULL,
    state                  VARCHAR(50)   NULL,
    postalCode             VARCHAR(15)   NULL,
    country                VARCHAR(50)   NOT NULL,
    salesRepEmployeeNumber INT           NULL REFERENCES dbo.employees(employeeNumber),
    creditLimit            DECIMAL(10,2) NULL
);

CREATE TABLE dbo.productlines (
    productLine     VARCHAR(50)   NOT NULL PRIMARY KEY,
    textDescription VARCHAR(4000) NULL,
    htmlDescription VARCHAR(MAX)  NULL,
    image           VARBINARY(MAX) NULL
);

CREATE TABLE dbo.products (
    productCode        VARCHAR(15)   NOT NULL PRIMARY KEY,
    productName        VARCHAR(70)   NOT NULL,
    productLine        VARCHAR(50)   NOT NULL REFERENCES dbo.productlines(productLine),
    productScale       VARCHAR(10)   NOT NULL,
    productVendor      VARCHAR(50)   NOT NULL,
    productDescription VARCHAR(MAX)  NOT NULL,
    quantityInStock    SMALLINT      NOT NULL,
    buyPrice           DECIMAL(10,2) NOT NULL,
    MSRP               DECIMAL(10,2) NOT NULL
);

CREATE TABLE dbo.orders (
    orderNumber    INT          NOT NULL PRIMARY KEY,
    orderDate      DATE         NOT NULL,
    requiredDate   DATE         NOT NULL,
    shippedDate    DATE         NULL,
    status         VARCHAR(15)  NOT NULL,
    comments       VARCHAR(MAX) NULL,
    customerNumber INT          NOT NULL REFERENCES dbo.customers(customerNumber)
);

CREATE TABLE dbo.orderdetails (
    orderNumber     INT           NOT NULL REFERENCES dbo.orders(orderNumber),
    productCode     VARCHAR(15)   NOT NULL REFERENCES dbo.products(productCode),
    quantityOrdered INT           NOT NULL,
    priceEach       DECIMAL(10,2) NOT NULL,
    orderLineNumber SMALLINT      NOT NULL,
    PRIMARY KEY (orderNumber, productCode)
);

CREATE TABLE dbo.payments (
    customerNumber INT           NOT NULL REFERENCES dbo.customers(customerNumber),
    checkNumber    VARCHAR(50)   NOT NULL,
    paymentDate    DATE          NOT NULL,
    amount         DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (customerNumber, checkNumber)
);
GO
