/* =====================================================================
   PROJET MACROBUS - Script 03 : Procedure stockee de chargement de la
   TABLE DE FAIT FaitOrders  (exigence A-3 du sujet)
   ---------------------------------------------------------------------
   Principe :
     1. Lecture des lignes de commande en production
        (orderdetails + orders + products + customers + employees + offices)
     2. Recherche des cles de substitution (lookups) dans les dimensions
        via les cles naturelles. Cle introuvable => -1 (membre "Inconnu")
     3. Calcul des mesures (Montant, CoutAchat, Marge, delais)
     4. MERGE : insertion des nouvelles lignes, mise a jour des lignes
        dont le statut / la date d'expedition / les montants ont change
        => la procedure est re-executable sans creer de doublons
     5. Trace dans dbo.EtlLog ; tout se fait dans une transaction.

   Pre-requis : les dimensions sont chargees (packages SSIS ou
                EXEC dbo.sp_ChargerToutesDimensions).
   Appel      : EXEC dbo.sp_ChargerFaitOrders;
   ===================================================================== */
USE MACROBUS_DWH_XXXX;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ChargerFaitOrders
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdLog INT;
    DECLARE @Actions TABLE (Action NVARCHAR(10));

    INSERT INTO dbo.EtlLog (Traitement, DateDebut, Statut)
    VALUES (N'sp_ChargerFaitOrders', SYSDATETIME(), N'En cours');
    SET @IdLog = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---------- 1. Extraction + 2. Lookups des cles ---------------- */
        ;WITH Source AS (
            SELECT
                od.orderNumber                                   AS OrderNumber,
                od.orderLineNumber                               AS OrderLineNumber,
                CAST(o.status AS NVARCHAR(15))                   AS Status,
                CAST(o.comments AS NVARCHAR(4000))               AS Comments,

                CONVERT(INT, CONVERT(CHAR(8), o.orderDate, 112))     AS KeyDateCommande,
                CONVERT(INT, CONVERT(CHAR(8), o.requiredDate, 112))  AS KeyDateRequise,
                ISNULL(CONVERT(INT, CONVERT(CHAR(8), o.shippedDate, 112)), -1) AS KeyDateExpedition,

                ISNULL(dp.KeyDimProduct, -1)                     AS KeyDimProduct,
                ISNULL(df.KeyDimFournisseur, -1)                 AS KeyDimFournisseur,
                ISNULL(dc.KeyDimCustomers, -1)                   AS KeyDimCustomers,
                ISNULL(gc.KeyDimGeographie, -1)                  AS KeyDimGeographieClient,
                ISNULL(gof.KeyDimGeographie, -1)                  AS KeyDimGeographieOffice,
                ISNULL(dcom.KeyDimCommerciaux, -1)               AS KeyDimCommerciaux,
                ISNULL(dm.KeyDimManagers, -1)                    AS KeyDimManagers,

                /* ---------- 3. Mesures ---------- */
                od.quantityOrdered                               AS QuantityOrdered,
                od.priceEach                                     AS UnitPrice,
                CAST(od.quantityOrdered * od.priceEach AS DECIMAL(14,2))  AS Montant,
                CAST(od.quantityOrdered * p.buyPrice   AS DECIMAL(14,2))  AS CoutAchat,
                CAST(od.quantityOrdered * (od.priceEach - p.buyPrice) AS DECIMAL(14,2)) AS Marge,
                DATEDIFF(DAY, o.orderDate, o.shippedDate)        AS DelaiExpeditionJours,
                CASE WHEN o.shippedDate IS NULL THEN NULL
                     WHEN o.shippedDate > o.requiredDate THEN 1 ELSE 0 END AS LivreEnRetard
            FROM src.orderdetails od
            JOIN src.orders      o   ON o.orderNumber   = od.orderNumber
            JOIN src.products    p   ON p.productCode   = od.productCode
            JOIN src.customers   c   ON c.customerNumber = o.customerNumber
            LEFT JOIN src.employees rep ON rep.employeeNumber = c.salesRepEmployeeNumber
            LEFT JOIN src.offices   ofc ON ofc.officeCode     = rep.officeCode
            -- lookups dans les dimensions
            LEFT JOIN dbo.DimProduct     dp   ON dp.ProductCode      = od.productCode
            LEFT JOIN dbo.DimFournisseur df   ON df.ProductVendor    = p.productVendor
            LEFT JOIN dbo.DimCustomers   dc   ON dc.CustomerNumber   = c.customerNumber
            LEFT JOIN dbo.DimGeographie  gc   ON gc.City = c.city AND gc.Country = c.country
                                             AND gc.State = ISNULL(c.state, 'N/A')
            LEFT JOIN dbo.DimGeographie  gof  ON gof.City = ofc.city AND gof.Country = ofc.country
                                             AND gof.State = ISNULL(ofc.state, 'N/A')
            LEFT JOIN dbo.DimCommerciaux dcom ON dcom.EmployeeNumber = rep.employeeNumber
            LEFT JOIN dbo.DimManagers    dm   ON dm.EmployeeNumber   = rep.reportsTo
        )
        /* ---------- 4. Chargement incremental ------------------------- */
        MERGE dbo.FaitOrders AS cible
        USING Source AS s
           ON cible.OrderNumber = s.OrderNumber AND cible.KeyDimProduct = s.KeyDimProduct
        WHEN MATCHED AND (   cible.Status            <> s.Status
                          OR cible.KeyDateExpedition <> s.KeyDateExpedition
                          OR cible.QuantityOrdered   <> s.QuantityOrdered
                          OR cible.UnitPrice         <> s.UnitPrice
                          OR cible.KeyDimCommerciaux <> s.KeyDimCommerciaux
                          OR ISNULL(cible.Comments, N'') <> ISNULL(s.Comments, N'')) THEN
            UPDATE SET Status = s.Status, Comments = s.Comments,
                       KeyDateExpedition = s.KeyDateExpedition,
                       KeyDimCommerciaux = s.KeyDimCommerciaux, KeyDimManagers = s.KeyDimManagers,
                       KeyDimGeographieOffice = s.KeyDimGeographieOffice,
                       QuantityOrdered = s.QuantityOrdered, UnitPrice = s.UnitPrice,
                       Montant = s.Montant, CoutAchat = s.CoutAchat, Marge = s.Marge,
                       DelaiExpeditionJours = s.DelaiExpeditionJours,
                       LivreEnRetard = s.LivreEnRetard, DateChargement = SYSDATETIME()
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (OrderNumber, OrderLineNumber, Status, Comments,
                    KeyDateCommande, KeyDateRequise, KeyDateExpedition,
                    KeyDimProduct, KeyDimFournisseur, KeyDimCustomers,
                    KeyDimGeographieClient, KeyDimGeographieOffice,
                    KeyDimCommerciaux, KeyDimManagers,
                    QuantityOrdered, UnitPrice, Montant, CoutAchat, Marge,
                    DelaiExpeditionJours, LivreEnRetard)
            VALUES (s.OrderNumber, s.OrderLineNumber, s.Status, s.Comments,
                    s.KeyDateCommande, s.KeyDateRequise, s.KeyDateExpedition,
                    s.KeyDimProduct, s.KeyDimFournisseur, s.KeyDimCustomers,
                    s.KeyDimGeographieClient, s.KeyDimGeographieOffice,
                    s.KeyDimCommerciaux, s.KeyDimManagers,
                    s.QuantityOrdered, s.UnitPrice, s.Montant, s.CoutAchat, s.Marge,
                    s.DelaiExpeditionJours, s.LivreEnRetard)
        OUTPUT $action INTO @Actions;

        COMMIT TRANSACTION;

        /* ---------- 5. Journalisation ---------------------------------- */
        UPDATE dbo.EtlLog
        SET DateFin    = SYSDATETIME(),
            NbInseres  = (SELECT COUNT(*) FROM @Actions WHERE Action = 'INSERT'),
            NbMisAJour = (SELECT COUNT(*) FROM @Actions WHERE Action = 'UPDATE'),
            Statut     = N'Succes'
        WHERE IdLog = @IdLog;

        SELECT NbInseres, NbMisAJour FROM dbo.EtlLog WHERE IdLog = @IdLog;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        UPDATE dbo.EtlLog
        SET DateFin = SYSDATETIME(), Statut = N'Echec', MessageErreur = ERROR_MESSAGE()
        WHERE IdLog = @IdLog;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   Controle de coherence apres chargement : la production et le DWH
   doivent donner le meme nombre de lignes et le meme chiffre d'affaires
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ControleChargement
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 'Production' AS Base, COUNT(*) AS NbLignes,
           COUNT(DISTINCT orderNumber) AS NbCommandes,
           SUM(quantityOrdered * priceEach) AS MontantTotal
    FROM src.orderdetails
    UNION ALL
    SELECT 'DWH', COUNT(*), COUNT(DISTINCT OrderNumber), SUM(Montant)
    FROM dbo.FaitOrders;

    -- lignes rattachees a un membre "Inconnu" (a analyser dans le rapport)
    SELECT
        SUM(CASE WHEN KeyDimProduct          = -1 THEN 1 ELSE 0 END) AS ProduitInconnu,
        SUM(CASE WHEN KeyDimCustomers        = -1 THEN 1 ELSE 0 END) AS ClientInconnu,
        SUM(CASE WHEN KeyDimCommerciaux      = -1 THEN 1 ELSE 0 END) AS CommercialInconnu,
        SUM(CASE WHEN KeyDimManagers         = -1 THEN 1 ELSE 0 END) AS ManagerInconnu,
        SUM(CASE WHEN KeyDimGeographieClient = -1 THEN 1 ELSE 0 END) AS GeoClientInconnue,
        SUM(CASE WHEN KeyDimGeographieOffice = -1 THEN 1 ELSE 0 END) AS GeoOfficeInconnue,
        SUM(CASE WHEN KeyDateExpedition      = -1 THEN 1 ELSE 0 END) AS NonExpediees
    FROM dbo.FaitOrders;
END
GO
