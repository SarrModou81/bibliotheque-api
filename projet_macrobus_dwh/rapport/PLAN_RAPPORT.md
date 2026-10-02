# Plan du rapport — Projet MacroBus (exigence C-4)

**Page de garde** : titre, école, cours, enseignant, **numéro de groupe**, **membres du groupe** (C-5), date.

## 1. Introduction
- Contexte : MacroBus vend des véhicules sur plusieurs marchés.
- Problématique : piloter l'activité et mesurer la performance des commerciaux dans le temps.
- Objectif : mettre en place un système d'aide à la décision (DWH + ETL + reporting).
- Outils : SQL Server, SSIS (Visual Studio), Power BI.

## 2. Analyse de l'existant (base de production)
- Présentation des 8 tables OLTP et de leurs relations (diagramme SSMS).
- Volumétrie : 122 clients, 23 employés, 7 bureaux, 110 produits, 7 gammes, 326 commandes et
  2 996 lignes (à adapter à vos données).
- Limites de l'OLTP pour l'analyse : jointures nombreuses, pas d'axe temps exploitable, et performances.

## 3. Conception du modèle multidimensionnel
- 3.1 Démarche de Kimball : processus (prise de commande) → **grain** (ligne de commande) → dimensions → mesures.
- 3.2 Schéma en flocon (insérer le diagramme : diagramme de base de données SSMS ou le mermaid du README).
- 3.3 Dictionnaire de données : un tableau par table (colonne, type, description, source).
- 3.4 Justification des choix :
  - pourquoi un flocon (ProductLine, Contact et Office normalisés) plutôt qu'une étoile ;
  - ajout de **DimDate** et de ses rôles multiples (commande, requise, expédition) ;
  - **DimGeographie** unique à 2 rôles ; DimContact, DimCommerciaux, DimManagers et DimFournisseur ;
  - remplacement de DimEmployees ; clés de substitution ; membres « Inconnu » (-1) ;
  - grain ligne de commande (contre `orderNumber` seul) ;
  - mesures calculées (Montant, Marge, Délai, Retard) ;
  - gestion de l'historique : SCD type 1, avec en perspective un type 2 pour un commercial qui change de filiale.

## 4. Implémentation
- 4.1 Création du DWH : script 01, avec des extraits commentés et une capture SSMS.
- 4.2 ETL SSIS : connexions, package Master (capture), un package de dimension détaillé (capture du Data
  Flow avec Lookup et SCD), ordre de chargement et gestion des erreurs.
- 4.3 Procédure stockée de chargement du fait (script 03) : explication des lookups, du MERGE
  incrémental, de la transaction et de la table EtlLog.
- 4.4 Captures d'exécution : packages en vert, `sp_ControleChargement` et `EtlLog`.

## 5. Validation fonctionnelle (B-1)
Pour chacune des 4 questions :
- la requête sur la production (capture) ;
- la requête sur le DWH (capture) ;
- la comparaison des résultats, qui doivent être identiques, et l'interprétation métier ;
- une remarque sur la simplicité des requêtes DWH (filtres par Trimestre ou Semestre de DimDate, moins de jointures).

Préciser les conventions : montant = quantité × prix ; commandes annulées incluses ; territoire et filiale
= bureau du commercial ; ex aequo gérés par `WITH TIES`.

## 6. Restitution Power BI (B-2)
- Modèle de données (capture de la vue Modèle).
- Mesures DAX principales.
- Une capture par page, avec l'interprétation pour les décideurs.

## 7. Difficultés rencontrées et solutions
Exemples : conversion unicode/non-unicode dans SSIS, ordre de chargement des flocons, clés NULL (commande
non expédiée ou président sans manager), territoire des clients, et relations multiples vers DimDate dans
Power BI.

## 8. Conclusion et perspectives
Bilan, puis pistes : SCD type 2, cube SSAS, planification avec SQL Agent, ajout des paiements
(table `payments`) dans un 2ᵉ fait, et chargement incrémental par date.

## Annexes
Les scripts SQL complets et la liste des membres du groupe.
