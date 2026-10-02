/* =====================================================================
   PROJET MACROBUS - Script 06 : Vues pour Power BI
   ---------------------------------------------------------------------
   DimGeographie joue 2 roles (geographie du client / de la filiale).
   Power BI n'autorise qu'UNE relation active entre 2 tables : on expose
   donc 2 vues distinctes, chacune reliee a sa propre cle du fait.
   ===================================================================== */
USE MACROBUS_DWH_2;
GO

CREATE OR ALTER VIEW dbo.vw_GeoClient AS
SELECT KeyDimGeographie AS KeyDimGeographieClient,
       City      AS VilleClient,
       State     AS EtatClient,
       Country   AS PaysClient,
       Territory AS TerritoireClient
FROM dbo.DimGeographie;
GO

CREATE OR ALTER VIEW dbo.vw_GeoFiliale AS
SELECT KeyDimGeographie AS KeyDimGeographieOffice,
       City      AS VilleFiliale,
       State     AS EtatFiliale,
       Country   AS PaysFiliale,
       Territory AS Territoire
FROM dbo.DimGeographie;
GO
