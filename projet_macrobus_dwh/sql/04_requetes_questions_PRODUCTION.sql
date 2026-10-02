/* =====================================================================
   PROJET MACROBUS - Script 04 : Reponses aux questions (partie B-1)
   sur la base de PRODUCTION (OLTP)  -> MACROBUS
   ---------------------------------------------------------------------
   Conventions retenues (a expliquer dans le rapport) :
     - Montant d'une commande = SUM(quantityOrdered * priceEach)
     - Toutes les commandes sont prises en compte, quel que soit leur
       statut (Shipped, Cancelled, On Hold...). Pour exclure les
       annulees, ajouter : AND o.status <> 'Cancelled'
     - Le territoire / la filiale d'une commande = ceux du bureau
       (office) du commercial qui gere le client.
   ===================================================================== */
USE MACROBUS;
GO

/* ---------------------------------------------------------------------
   Q1. Nombre et montant total des commandes par territoire
   --------------------------------------------------------------------- */
SELECT ISNULL(ofc.territory, 'N/A')          AS Territoire,
       COUNT(DISTINCT o.orderNumber)          AS NbCommandes,
       SUM(od.quantityOrdered * od.priceEach) AS MontantTotal
FROM orders o
JOIN orderdetails od     ON od.orderNumber    = o.orderNumber
JOIN customers c         ON c.customerNumber  = o.customerNumber
LEFT JOIN employees e    ON e.employeeNumber  = c.salesRepEmployeeNumber
LEFT JOIN offices ofc    ON ofc.officeCode    = e.officeCode
GROUP BY ISNULL(ofc.territory, 'N/A')
ORDER BY MontantTotal DESC;

/* ---------------------------------------------------------------------
   Q2. Top 2 des commerciaux qui recoivent le plus de commandes
       (WITH TIES : en cas d'ex aequo, on les affiche tous)
   --------------------------------------------------------------------- */
SELECT TOP (2) WITH TIES
       e.employeeNumber,
       CONCAT(e.firstName, ' ', e.lastName)   AS Commercial,
       ofc.city                               AS Filiale,
       COUNT(DISTINCT o.orderNumber)          AS NbCommandes,
       SUM(od.quantityOrdered * od.priceEach) AS MontantTotal
FROM orders o
JOIN orderdetails od ON od.orderNumber   = o.orderNumber
JOIN customers c     ON c.customerNumber = o.customerNumber
JOIN employees e     ON e.employeeNumber = c.salesRepEmployeeNumber
JOIN offices ofc     ON ofc.officeCode   = e.officeCode
GROUP BY e.employeeNumber, e.firstName, e.lastName, ofc.city
ORDER BY NbCommandes DESC;

/* ---------------------------------------------------------------------
   Q3. Les 3 produits les plus commandes au 2e trimestre 2003
       (avril -> juin 2003, classement sur la quantite commandee)
   --------------------------------------------------------------------- */
SELECT TOP (3) WITH TIES
       p.productCode,
       p.productName,
       p.productLine,
       SUM(od.quantityOrdered)                AS QuantiteCommandee,
       COUNT(DISTINCT o.orderNumber)          AS NbCommandes,
       SUM(od.quantityOrdered * od.priceEach) AS MontantTotal
FROM orders o
JOIN orderdetails od ON od.orderNumber = o.orderNumber
JOIN products p      ON p.productCode  = od.productCode
WHERE o.orderDate >= '2003-04-01' AND o.orderDate < '2003-07-01'
GROUP BY p.productCode, p.productName, p.productLine
ORDER BY QuantiteCommandee DESC, MontantTotal DESC;

/* ---------------------------------------------------------------------
   Q4. Montant total des commandes par filiale et par categorie de
       produit durant le 2nd semestre 2003 (juillet -> decembre 2003)
       GROUPING SETS ajoute les sous-totaux par filiale.
   --------------------------------------------------------------------- */
SELECT CASE WHEN GROUPING(p.productLine) = 1 THEN '** Total filiale **'
            ELSE p.productLine END             AS CategorieProduit,
       ofc.city                                AS Filiale,
       COUNT(DISTINCT o.orderNumber)           AS NbCommandes,
       SUM(od.quantityOrdered * od.priceEach)  AS MontantTotal
FROM orders o
JOIN orderdetails od ON od.orderNumber    = o.orderNumber
JOIN products p      ON p.productCode     = od.productCode
JOIN customers c     ON c.customerNumber  = o.customerNumber
JOIN employees e     ON e.employeeNumber  = c.salesRepEmployeeNumber
JOIN offices ofc     ON ofc.officeCode    = e.officeCode
WHERE o.orderDate >= '2003-07-01' AND o.orderDate < '2004-01-01'
GROUP BY GROUPING SETS ((ofc.city, p.productLine), (ofc.city))
ORDER BY Filiale, GROUPING(p.productLine), MontantTotal DESC;
