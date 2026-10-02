# Guide Power BI — tableau de bord MacroBus (exigence B-2)

## 1. Importer les données

*Accueil → Obtenir les données → SQL Server* → serveur `localhost` (ou le vôtre), base
`MACROBUS_DWH_2`, mode **Import**. Cocher :

`FaitOrders`, `DimDate`, `DimProduct`, `DimProductLine`, `DimFournisseur`, `DimCustomers`,
`DimContact`, `DimCommerciaux`, `DimOffice`, `DimManagers`, `vw_GeoClient`, `vw_GeoFiliale`.

> Ne **pas** importer `DimGeographie` directement : les deux vues jouent ses deux rôles (client et filiale).

Dans Power Query, renommer éventuellement `vw_GeoClient` en **Géo Client** et `vw_GeoFiliale` en
**Géo Filiale**. Vous pouvez aussi filtrer les lignes de clé `-1` dans les dimensions si vous ne voulez pas
voir « Inconnu ».

## 2. Modèle (vue Modèle)

Vérifier ou créer ces relations, toutes en **plusieurs-à-un (*:1), filtrage unidirectionnel** :

| De (FaitOrders) | Vers | Active ? |
|---|---|---|
| KeyDateCommande | DimDate[KeyDimDate] | ✅ oui |
| KeyDateRequise | DimDate[KeyDimDate] | ❌ inactive |
| KeyDateExpedition | DimDate[KeyDimDate] | ❌ inactive |
| KeyDimProduct | DimProduct | ✅ |
| KeyDimFournisseur | DimFournisseur | ✅ |
| KeyDimCustomers | DimCustomers | ✅ |
| KeyDimGeographieClient | vw_GeoClient | ✅ |
| KeyDimGeographieOffice | vw_GeoFiliale | ✅ |
| KeyDimCommerciaux | DimCommerciaux | ✅ |
| KeyDimManagers | DimManagers | ✅ |
| DimProduct[KeyDimProductLine] | DimProductLine | ✅ (flocon) |
| DimCustomers[KeyDimContact] | DimContact | ✅ (flocon) |
| DimCommerciaux[KeyDimOffice] | DimOffice | ✅ (flocon) |

Ensuite :
- Sélectionner `DimDate` puis **Marquer comme table de dates** (colonne `FullDate`).
- Dans `DimDate`, trier `NomMois` par `Mois` (*Outils de colonne → Trier par colonne*) et `NomJour` par `JourSemaine`.
- Catégoriser `vw_GeoClient[PaysClient]` et `vw_GeoFiliale[PaysFiliale]` en **Pays/Région**, et les
  colonnes de ville en **Ville**, pour les cartes.
- Masquer toutes les colonnes `Key...` côté rapport.

## 3. Mesures DAX

Créer une table vide **`_Mesures`** (*Entrer des données → OK*) et y placer :

```DAX
CA = SUM ( FaitOrders[Montant] )

Nb Commandes = DISTINCTCOUNT ( FaitOrders[OrderNumber] )

Quantité = SUM ( FaitOrders[QuantityOrdered] )

Marge = SUM ( FaitOrders[Marge] )

Taux de marge = DIVIDE ( [Marge], [CA] )

Panier moyen = DIVIDE ( [CA], [Nb Commandes] )

Nb Clients actifs = DISTINCTCOUNT ( FaitOrders[KeyDimCustomers] )

CA N-1 = CALCULATE ( [CA], SAMEPERIODLASTYEAR ( DimDate[FullDate] ) )

Croissance CA % = DIVIDE ( [CA] - [CA N-1], [CA N-1] )

CA cumul annuel = TOTALYTD ( [CA], DimDate[FullDate] )

Rang Commercial =
RANKX ( ALL ( DimCommerciaux[FullName] ), [Nb Commandes], , DESC, DENSE )

CA par date d'expédition =
CALCULATE ( [CA], USERELATIONSHIP ( FaitOrders[KeyDateExpedition], DimDate[KeyDimDate] ) )

Délai moyen expédition (j) = AVERAGE ( FaitOrders[DelaiExpeditionJours] )

% Livraisons en retard =
DIVIDE (
    CALCULATE ( COUNTROWS ( FaitOrders ), FaitOrders[LivreEnRetard] = TRUE () ),
    CALCULATE ( COUNTROWS ( FaitOrders ), NOT ISBLANK ( FaitOrders[LivreEnRetard] ) )
)

Commandes non expédiées =
CALCULATE ( [Nb Commandes], FaitOrders[KeyDateExpedition] = -1 )
```

Format : `CA`, `Marge` et `Panier moyen` en devise ($, car les données sont en dollars) ; les `%` en pourcentage.

## 4. Pages du rapport (proposition)

### Page 1 — Vue d'ensemble (direction générale)
- **Cartes (KPI)** : CA, Nb Commandes, Marge, Taux de marge, Panier moyen, Croissance CA %.
- **Histogramme groupé** : CA par `Annee` puis `NomMois` (hiérarchie, avec exploration).
- **Carte (Map)** : CA par `PaysClient` (taille de bulle = CA).
- **Anneau** : CA par `Territoire` → répond à **Q1** visuellement.
- **Segments** : Annee, Trimestre, Territoire, Status.

### Page 2 — Performance des commerciaux (cœur du besoin)
- **Barres horizontales** : Nb Commandes par `DimCommerciaux[FullName]`, avec un filtre visuel *Top N = 2*
  pour **Q2** (ou laisser tous les commerciaux, triés).
- **Tableau** : Commercial | Filiale (`DimOffice[NomFiliale]`) | Manager | Nb Commandes | CA | Marge | Rang.
- **Courbe** : CA par mois, légende = commercial (évolution dans le temps).
- **Matrice** : Manager → Commercial (hiérarchie) × Année, valeurs = CA.

### Page 3 — Produits
- **Barres** : Quantité par `ProductName`, filtre *Top N = 3*, segment Année = 2003 et Trimestre = 2 → **Q3**.
- **Treemap** : CA par `ProductLine` puis `ProductName`.
- **Nuage de points** : Quantité (X) × Taux de marge (Y), par produit.
- **Barres** : CA par fournisseur (`ProductVendor`).

### Page 4 — Filiales & logistique
- **Matrice** : lignes = `VilleFiliale`, colonnes = `ProductLine`, valeurs = CA ; segments Année = 2003
  et Semestre = 2 → **Q4**.
- **Jauge** : % Livraisons en retard.
- **Carte** : Délai moyen expédition (j), Commandes non expédiées.
- **Colonnes** : Nb Commandes par `Status`.

## 5. Finitions (pour la note)
- Un thème cohérent (*Affichage → Thèmes*) et un titre sur chaque page.
- Des **info-bulles** et une **extraction** (*drill-through*) vers une page « Détail commercial ».
- Des **signets** et des boutons de navigation entre les pages.
- Captures de chaque page dans le rapport, avec 2 ou 3 lignes d'interprétation par visuel (par exemple
  « EMEA représente 47 % du CA »).
