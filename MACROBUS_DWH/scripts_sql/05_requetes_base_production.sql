/* =====================================================================
   PROJET MACROBUS - 05 : Questions B-1 sur la base de PRODUCTION
   (toutes les commandes sont prises en compte, quel que soit le statut)
   ===================================================================== */
USE MACROBUS_PROD;
GO

/* Q1) Nombre et montant total des commandes par territoire
       (territoire = celui du bureau du commercial qui gère le client) */
SELECT  ofc.territory                               AS Territoire,
        COUNT(DISTINCT o.orderNumber)               AS NbCommandes,
        SUM(od.quantityOrdered * od.priceEach)      AS MontantTotal
FROM orders o
JOIN orderdetails od ON od.orderNumber   = o.orderNumber
JOIN customers   c   ON c.customerNumber = o.customerNumber
JOIN employees   e   ON e.employeeNumber = c.salesRepEmployeeNumber
JOIN offices     ofc ON ofc.officeCode   = e.officeCode
GROUP BY ofc.territory
ORDER BY MontantTotal DESC;
GO

/* Q2) Top 2 des commerciaux qui reçoivent le plus de commandes */
SELECT TOP (2) WITH TIES
        e.employeeNumber,
        e.firstName + ' ' + e.lastName              AS Commercial,
        COUNT(o.orderNumber)                        AS NbCommandes
FROM orders o
JOIN customers c ON c.customerNumber = o.customerNumber
JOIN employees e ON e.employeeNumber = c.salesRepEmployeeNumber
GROUP BY e.employeeNumber, e.firstName, e.lastName
ORDER BY NbCommandes DESC;
GO

/* Q3) Les 3 produits les plus commandés (en quantité) au 2e trimestre 2003 */
SELECT TOP (3) WITH TIES
        p.productCode,
        p.productName,
        SUM(od.quantityOrdered)                     AS QuantiteCommandee,
        COUNT(DISTINCT o.orderNumber)               AS NbCommandes
FROM orders o
JOIN orderdetails od ON od.orderNumber = o.orderNumber
JOIN products     p  ON p.productCode  = od.productCode
WHERE o.orderDate >= '2003-04-01' AND o.orderDate < '2003-07-01'
GROUP BY p.productCode, p.productName
ORDER BY QuantiteCommandee DESC;
GO

/* Q4) Montant total des commandes par filiale (bureau) et par catégorie
       de produit (productLine) durant le second semestre 2003 */
SELECT  ofc.officeCode,
        ofc.city                                    AS Filiale,
        p.productLine                               AS Categorie,
        SUM(od.quantityOrdered * od.priceEach)      AS MontantTotal
FROM orders o
JOIN orderdetails od ON od.orderNumber   = o.orderNumber
JOIN products     p  ON p.productCode    = od.productCode
JOIN customers    c  ON c.customerNumber = o.customerNumber
JOIN employees    e  ON e.employeeNumber = c.salesRepEmployeeNumber
JOIN offices      ofc ON ofc.officeCode  = e.officeCode
WHERE o.orderDate >= '2003-07-01' AND o.orderDate < '2004-01-01'
GROUP BY ofc.officeCode, ofc.city, p.productLine
ORDER BY ofc.city, MontantTotal DESC;
GO
