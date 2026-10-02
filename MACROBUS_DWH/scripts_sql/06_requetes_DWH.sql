/* =====================================================================
   PROJET MACROBUS - 06 : Questions B-1 sur l'entrepôt MACROBUS_DWH_XXXX
   Les résultats doivent être IDENTIQUES à ceux du script 05
   (c'est la validation fonctionnelle du DWH).
   ===================================================================== */
USE MACROBUS_DWH_XXXX;
GO

/* Q1) Nombre et montant total des commandes par territoire */
SELECT  g.territory                                 AS Territoire,
        COUNT(DISTINCT f.orderNumber)               AS NbCommandes,
        SUM(f.Montant)                              AS MontantTotal
FROM FaitOrders f
JOIN DimGeographieOffice g ON g.KeyDimGeographieOffice = f.KeyDimGeographieOffice
GROUP BY g.territory
ORDER BY MontantTotal DESC;
GO

/* Q2) Top 2 des commerciaux qui reçoivent le plus de commandes */
SELECT TOP (2) WITH TIES
        c.employeeNumber,
        c.fullName_FirstName_LastName_              AS Commercial,
        COUNT(DISTINCT f.orderNumber)               AS NbCommandes
FROM FaitOrders f
JOIN DimCommerciaux c ON c.KeyDimCommerciaux = f.KeyDimCommerciaux
GROUP BY c.employeeNumber, c.fullName_FirstName_LastName_
ORDER BY NbCommandes DESC;
GO

/* Q3) Les 3 produits les plus commandés (en quantité) au 2e trimestre 2003 */
SELECT TOP (3) WITH TIES
        p.productCode,
        p.productName,
        SUM(f.QuantityOrdere)                       AS QuantiteCommandee,
        COUNT(DISTINCT f.orderNumber)               AS NbCommandes
FROM FaitOrders f
JOIN DimProduct p ON p.KeyDimProduct = f.KeyDimProduct
JOIN DimDate    d ON d.KeyDimDate    = f.KeyOrderDate
WHERE d.Annee = 2003 AND d.Trimestre = 2
GROUP BY p.productCode, p.productName
ORDER BY QuantiteCommandee DESC;
GO

/* Q4) Montant total par filiale et par catégorie de produit au 2nd semestre 2003
       (on traverse les deux branches du flocon : Employees -> Office
        et Product -> ProductLine) */
SELECT  o.officeCode,
        o.city                                      AS Filiale,
        pl.productLine                              AS Categorie,
        SUM(f.Montant)                              AS MontantTotal
FROM FaitOrders f
JOIN DimEmployees   e  ON e.KeyDimEmployees   = f.KeyDimEmployees
JOIN DimOffice      o  ON o.KeyDimOffices     = e.KeyDimOffices
JOIN DimProduct     p  ON p.KeyDimProduct     = f.KeyDimProduct
JOIN DimProductLine pl ON pl.KeyDimProductLine = p.KeyDimProductLine
JOIN DimDate        d  ON d.KeyDimDate        = f.KeyOrderDate
WHERE d.Annee = 2003 AND d.Semestre = 2
GROUP BY o.officeCode, o.city, pl.productLine
ORDER BY o.city, MontantTotal DESC;
GO
