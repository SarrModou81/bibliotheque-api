/* =====================================================================
   PROJET MACROBUS - 04 : Procédure stockée de chargement de FaitOrders
   ---------------------------------------------------------------------
   Grain : 1 ligne = 1 produit d'une commande (orders x orderdetails).
   Chargement INCRÉMENTAL : seules les lignes absentes du fait sont
   insérées ; les lignes existantes dont le statut / la date
   d'expédition ont changé sont mises à jour.
   Pré-requis : dimensions chargées (SSIS ou EXEC dbo.ps_ChargerDimensions).
   Utilisation : EXEC dbo.ps_ChargerFaitOrders;
   ===================================================================== */
USE MACROBUS_DWH_XXXX;
GO

CREATE OR ALTER PROCEDURE dbo.ps_ChargerFaitOrders
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* 1) Extraction + recherche des clés de substitution (lookups) */
        SELECT
            o.orderNumber,
            od.orderLineNumber,
            od.quantityOrdered                         AS QuantityOrdere,
            od.priceEach                               AS unitPrice,
            CAST(od.quantityOrdered * od.priceEach AS DECIMAL(12,2)) AS Montant,
            o.status,
            o.comments,
            CONVERT(INT, FORMAT(o.orderDate, 'yyyyMMdd'))                       AS KeyOrderDate,
            ISNULL(CONVERT(INT, FORMAT(o.shippedDate, 'yyyyMMdd')), -1)         AS KeyShipperDate,
            CONVERT(INT, FORMAT(o.requiredDate, 'yyyyMMdd'))                    AS KeyRequiredDate,
            de.KeyDimEmployees,
            dc.KeyDimCustomers,
            dgo.KeyDimGeographieOffice,
            dgc.KeyDimGeographieClient,
            df.keyDimFournisseur,
            dp.KeyDimProduct,
            dco.KeyDimCommerciaux,
            dm.KeyDimManagers
        INTO #Stage
        FROM MACROBUS_PROD.dbo.orders o
        JOIN MACROBUS_PROD.dbo.orderdetails od ON od.orderNumber    = o.orderNumber
        JOIN MACROBUS_PROD.dbo.customers    c  ON c.customerNumber  = o.customerNumber
        JOIN MACROBUS_PROD.dbo.employees    e  ON e.employeeNumber  = c.salesRepEmployeeNumber
        JOIN MACROBUS_PROD.dbo.offices      ofc ON ofc.officeCode   = e.officeCode
        JOIN dbo.DimCustomers        dc  ON dc.CustomersNumber = c.customerNumber
        JOIN dbo.DimProduct          dp  ON dp.productCode     = od.productCode
        JOIN dbo.DimFournisseur      df  ON df.codeDuProduit   = od.productCode
        JOIN dbo.DimEmployees        de  ON de.employeeNumber  = e.employeeNumber
        JOIN dbo.DimCommerciaux      dco ON dco.employeeNumber = e.employeeNumber
        JOIN dbo.DimManagers         dm  ON dm.employeeNumber  = e.reportsTo
        JOIN dbo.DimGeographieOffice dgo ON dgo.city = ofc.city AND dgo.country = ofc.country
                                        AND dgo.territory = ofc.territory
        JOIN dbo.DimGeographieClient dgc ON dgc.city = c.city AND dgc.country = c.country
                                        AND dgc.territory = ofc.territory;

        /* 2) Mise à jour des lignes déjà présentes (statut, expédition...) */
        UPDATE f
           SET f.status         = s.status,
               f.comments       = s.comments,
               f.KeyShipperDate = s.KeyShipperDate,
               f.QuantityOrdere = s.QuantityOrdere,
               f.unitPrice      = s.unitPrice,
               f.Montant        = s.Montant
        FROM dbo.FaitOrders f
        JOIN #Stage s ON s.orderNumber = f.orderNumber AND s.KeyDimProduct = f.KeyDimProduct
        WHERE ISNULL(f.status, '') <> ISNULL(s.status, '')
           OR f.KeyShipperDate <> s.KeyShipperDate
           OR f.Montant <> s.Montant;
        DECLARE @nbMaj INT = @@ROWCOUNT;

        /* 3) Insertion des nouvelles lignes */
        INSERT INTO dbo.FaitOrders (
            orderNumber, orderLineNumber, QuantityOrdere, unitPrice, Montant, status, comments,
            KeyOrderDate, KeyShipperDate, KeyRequiredDate,
            KeyDimEmployees, KeyDimCustomers, KeyDimGeographieOffice, KeyDimGeographieClient,
            keyDimFournisseur, KeyDimProduct, KeyDimCommerciaux, KeyDimManagers)
        SELECT
            s.orderNumber, s.orderLineNumber, s.QuantityOrdere, s.unitPrice, s.Montant, s.status, s.comments,
            s.KeyOrderDate, s.KeyShipperDate, s.KeyRequiredDate,
            s.KeyDimEmployees, s.KeyDimCustomers, s.KeyDimGeographieOffice, s.KeyDimGeographieClient,
            s.keyDimFournisseur, s.KeyDimProduct, s.KeyDimCommerciaux, s.KeyDimManagers
        FROM #Stage s
        WHERE NOT EXISTS (SELECT 1 FROM dbo.FaitOrders f
                          WHERE f.orderNumber = s.orderNumber AND f.KeyDimProduct = s.KeyDimProduct);
        DECLARE @nbIns INT = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT @nbIns AS LignesInserees, @nbMaj AS LignesMisesAJour,
               (SELECT COUNT(*) FROM dbo.FaitOrders) AS TotalFaitOrders;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* Exécution complète (dimensions puis fait) :
   EXEC dbo.ps_ChargerDimensions;
   EXEC dbo.ps_ChargerFaitOrders;
*/
