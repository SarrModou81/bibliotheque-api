/* =====================================================================
   PROJET MACROBUS - Script 05 : Reponses aux questions (partie B-1)
   sur l'ENTREPOT  -> MACROBUS_DWH_2
   ---------------------------------------------------------------------
   Memes conventions que le script 04 : les resultats doivent etre
   IDENTIQUES a ceux de la production (c'est la validation fonctionnelle).
   On remarque que les requetes sont plus simples : les jointures
   passent toutes par la table de fait et les filtres de periode
   utilisent directement les attributs de DimDate (Trimestre, Semestre).
   ===================================================================== */
USE MACROBUS_DWH_2;
GO

/* ---------------------------------------------------------------------
   Q1. Nombre et montant total des commandes par territoire
   --------------------------------------------------------------------- */
SELECT g.Territory                     AS Territoire,
       COUNT(DISTINCT f.OrderNumber)   AS NbCommandes,
       SUM(f.Montant)                  AS MontantTotal
FROM dbo.FaitOrders f
JOIN dbo.DimGeographie g ON g.KeyDimGeographie = f.KeyDimGeographieOffice
GROUP BY g.Territory
ORDER BY MontantTotal DESC;

/* ---------------------------------------------------------------------
   Q2. Top 2 des commerciaux qui recoivent le plus de commandes
   --------------------------------------------------------------------- */
SELECT TOP (2) WITH TIES
       c.EmployeeNumber,
       c.FullName                      AS Commercial,
       o.NomFiliale                    AS Filiale,
       COUNT(DISTINCT f.OrderNumber)   AS NbCommandes,
       SUM(f.Montant)                  AS MontantTotal
FROM dbo.FaitOrders f
JOIN dbo.DimCommerciaux c ON c.KeyDimCommerciaux = f.KeyDimCommerciaux
JOIN dbo.DimOffice o      ON o.KeyDimOffice      = c.KeyDimOffice      -- flocon
WHERE f.KeyDimCommerciaux <> -1
GROUP BY c.EmployeeNumber, c.FullName, o.NomFiliale
ORDER BY NbCommandes DESC;

/* ---------------------------------------------------------------------
   Q3. Les 3 produits les plus commandes au 2e trimestre 2003
   --------------------------------------------------------------------- */
SELECT TOP (3) WITH TIES
       p.ProductCode,
       p.ProductName,
       pl.ProductLine,
       SUM(f.QuantityOrdered)          AS QuantiteCommandee,
       COUNT(DISTINCT f.OrderNumber)   AS NbCommandes,
       SUM(f.Montant)                  AS MontantTotal
FROM dbo.FaitOrders f
JOIN dbo.DimDate d         ON d.KeyDimDate        = f.KeyDateCommande
JOIN dbo.DimProduct p      ON p.KeyDimProduct     = f.KeyDimProduct
JOIN dbo.DimProductLine pl ON pl.KeyDimProductLine = p.KeyDimProductLine  -- flocon
WHERE d.Annee = 2003 AND d.Trimestre = 2
GROUP BY p.ProductCode, p.ProductName, pl.ProductLine
ORDER BY QuantiteCommandee DESC, MontantTotal DESC;

/* ---------------------------------------------------------------------
   Q4. Montant total des commandes par filiale et par categorie de
       produit durant le 2nd semestre 2003
   --------------------------------------------------------------------- */
SELECT CASE WHEN GROUPING(pl.ProductLine) = 1 THEN N'** Total filiale **'
            ELSE pl.ProductLine END    AS CategorieProduit,
       g.City                          AS Filiale,
       COUNT(DISTINCT f.OrderNumber)   AS NbCommandes,
       SUM(f.Montant)                  AS MontantTotal
FROM dbo.FaitOrders f
JOIN dbo.DimDate d         ON d.KeyDimDate         = f.KeyDateCommande
JOIN dbo.DimGeographie g   ON g.KeyDimGeographie   = f.KeyDimGeographieOffice
JOIN dbo.DimProduct p      ON p.KeyDimProduct      = f.KeyDimProduct
JOIN dbo.DimProductLine pl ON pl.KeyDimProductLine = p.KeyDimProductLine
WHERE d.Annee = 2003 AND d.Semestre = 2
GROUP BY GROUPING SETS ((g.City, pl.ProductLine), (g.City))
ORDER BY Filiale, GROUPING(pl.ProductLine), MontantTotal DESC;
