# Partie B-2 : visuels Power BI pour les décideurs

## 1. Connexion au DWH
1. Ouvrez Power BI Desktop, puis **Obtenir les données > SQL Server**.
2. Serveur : `localhost`. Base de données : `MACROBUS_DWH_XXXX`. Mode : **Importer**.
3. Cochez toutes les tables `Dim*` et `FaitOrders`, puis cliquez sur **Charger**.

## 2. Modèle (vue *Modèle*)
Power BI détecte la plupart des relations automatiquement. Vérifiez-les :

| De (plusieurs) | Vers (un) | Active ? |
|----------------|-----------|----------|
| FaitOrders[KeyOrderDate] | DimDate[KeyDimDate] | ✅ Oui |
| FaitOrders[KeyShipperDate] | DimDate[KeyDimDate] | ❌ Non (inactive) |
| FaitOrders[KeyRequiredDate] | DimDate[KeyDimDate] | ❌ Non (inactive) |
| FaitOrders[KeyDimProduct] | DimProduct | ✅ |
| DimProduct[KeyDimProductLine] | DimProductLine | ✅ (flocon) |
| FaitOrders[KeyDimCustomers] | DimCustomers | ✅ |
| DimCustomers[KeyDimContact] | DimContact | ✅ (flocon) |
| FaitOrders[KeyDimEmployees] | DimEmployees | ✅ |
| DimEmployees[KeyDimOffices] | DimOffice | ✅ (flocon) |
| FaitOrders[KeyDimCommerciaux] | DimCommerciaux | ✅ |
| FaitOrders[KeyDimManagers] | DimManagers | ✅ |
| FaitOrders[keyDimFournisseur] | DimFournisseur | ✅ |
| FaitOrders[KeyDimGeographieOffice] | DimGeographieOffice | ✅ |
| FaitOrders[KeyDimGeographieClient] | DimGeographieClient | ✅ |

- Dans DimDate, triez `NomMois` par `Mois` (sélectionnez la colonne, puis *Trier par colonne* > `Mois`).
- Marquez DimDate comme table de dates : clic droit, puis **Marquer comme table de dates**, colonne `DateComplete`.
- Catégorie de données : `DimGeographieClient[country]` = **Pays/Région** et `[city]` = **Ville** (pour la carte).

## 3. Mesures DAX
Créez une table vide « Mesures » (*Accueil > Entrer des données*), puis ajoutez :

```DAX
CA Total = SUM ( FaitOrders[Montant] )

Nb Commandes = DISTINCTCOUNT ( FaitOrders[orderNumber] )

Quantité Vendue = SUM ( FaitOrders[QuantityOrdere] )

Panier Moyen = DIVIDE ( [CA Total], [Nb Commandes] )

Nb Clients Actifs = DISTINCTCOUNT ( FaitOrders[KeyDimCustomers] )

CA Année Précédente =
    CALCULATE ( [CA Total], SAMEPERIODLASTYEAR ( DimDate[DateComplete] ) )

Croissance CA % = DIVIDE ( [CA Total] - [CA Année Précédente], [CA Année Précédente] )

Marge Brute =
    SUMX ( FaitOrders,
           FaitOrders[QuantityOrdere] * ( FaitOrders[unitPrice] - RELATED ( DimProduct[buyPrice] ) ) )

Taux de Marge % = DIVIDE ( [Marge Brute], [CA Total] )

CA par Date Expédition =
    CALCULATE ( [CA Total], USERELATIONSHIP ( FaitOrders[KeyShipperDate], DimDate[KeyDimDate] ) )

Commandes Livrées à Temps % =
    DIVIDE (
        CALCULATE ( [Nb Commandes],
                    FILTER ( FaitOrders,
                             FaitOrders[KeyShipperDate] <> -1
                             && FaitOrders[KeyShipperDate] <= FaitOrders[KeyRequiredDate] ) ),
        CALCULATE ( [Nb Commandes], FaitOrders[KeyShipperDate] <> -1 ) )
```

## 4. Rapport proposé (3 pages)

### Page 1 : « Vue d'ensemble »
| Visuel | Champs | Message pour le décideur |
|--------|--------|--------------------------|
| 5 **Cartes** (KPI) | CA Total, Nb Commandes, Panier Moyen, Taux de Marge %, Commandes Livrées à Temps % | État de santé global |
| **Graphique en courbes** | Axe : DimDate[AnneeMois] ; Valeur : CA Total | Évolution et saisonnalité (pic en novembre) |
| **Histogramme groupé** | Axe : DimDate[Annee] ; Valeurs : CA Total, Croissance CA % | Croissance annuelle |
| **Anneau** | Légende : DimProductLine[productLine] ; Valeur : CA Total | Poids de chaque catégorie (Classic Cars en tête) |
| **Segments** | DimDate[Annee], DimDate[LibTrimestre], DimGeographieOffice[territory] | Filtres interactifs |

### Page 2 : « Performance des commerciaux » (le besoin principal du PDG)
| Visuel | Champs |
|--------|--------|
| **Barres horizontales** (Top N = 5 via le volet Filtres) | Axe : DimCommerciaux[fullName_FirstName_LastName_] ; Valeur : Nb Commandes |
| **Matrice** | Lignes : DimManagers[fullName…], puis DimCommerciaux[fullName…] ; Colonnes : DimDate[Annee] ; Valeurs : CA Total |
| **Graphique en cascade** ou **courbes** | Axe : DimDate[LibTrimestre] ; Légende : DimCommerciaux ; Valeur : CA Total |
| **Nuage de points** | X : Nb Commandes ; Y : Panier Moyen ; Détails : commercial ; Taille : CA Total |

### Page 3 : « Marchés et produits »
| Visuel | Champs |
|--------|--------|
| **Carte (Map / Azure Map)** | Emplacement : DimGeographieClient[country] ; Taille : CA Total |
| **Histogramme empilé** | Axe : DimGeographieOffice[territory] ; Légende : DimProductLine[productLine] ; Valeur : CA Total (question 1 et 4) |
| **Matrice** avec mise en forme conditionnelle | Lignes : DimOffice[city] ; Colonnes : DimProductLine[productLine] ; Valeur : CA Total |
| **Tableau Top 10 produits** | DimProduct[productName], Quantité Vendue, CA Total, Marge Brute |
| **Barres** | DimFournisseur[productVendor] ; CA Total |

**Conseils de présentation** : utilisez un thème cohérent (*Affichage > Thèmes*), donnez un titre clair à chaque visuel, ajoutez des info-bulles et activez les interactions croisées entre visuels.
Enregistrez le fichier sous **`MACROBUS_XXXX.pbix`** et faites des captures d'écran de chaque page pour le rapport.
