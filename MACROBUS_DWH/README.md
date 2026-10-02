# Projet MACROBUS : entrepôt de données (SQL Server · SSIS · Power BI)

## Contenu
```
MACROBUS_DWH/
├── scripts_sql/
│   ├── 01_base_production_MACROBUS_PROD.sql   ← base de production + toutes les données
│   ├── 02_creation_DWH_MACROBUS_DWH_XXXX.sql  ← DWH en flocon + remplissage DimDate
│   ├── 03_ps_chargement_dimensions.sql        ← procédures de chargement des dimensions
│   ├── 04_ps_chargement_FaitOrders.sql        ← procédure stockée du fait (question A-3)
│   ├── 05_requetes_base_production.sql        ← questions B-1 sur la production
│   └── 06_requetes_DWH.sql                    ← questions B-1 sur le DWH
├── MACROBUS_ETL_XXXX/
│   ├── Chargement_DWH.dtsx                    ← package SSIS (livrable 1)
│   └── LISEZMOI.md
└── docs/
    ├── 01_INSTALLATION_VisualStudio_SSMS_SSIS.md
    ├── 02_GUIDE_SSIS.md
    ├── 03_GUIDE_POWER_BI.md
    ├── RAPPORT_PROJET_MACROBUS.md / .docx     ← rapport (livrable 4)
    ├── MEMBRES_DU_GROUPE.md / .docx           ← livrable 5
    └── images/modele_flocon.png
```
L'archive **`LIVRABLES_MACROBUS_XXXX.zip`** regroupe les 5 livrables demandés par le sujet.

## Ordre d'exécution
0. Installez les outils (`docs/01_INSTALLATION…`).
1. **Remplacez `XXXX` par votre numéro de groupe** dans les scripts 02 à 06 (Ctrl+H dans SSMS).
2. Dans SSMS, exécutez **01**, puis **02**, **03** et **04** (touche F5).
3. Chargez le DWH :
   - **avec SSIS** (demandé par le sujet) : ajoutez `MACROBUS_ETL_XXXX/Chargement_DWH.dtsx` à un projet Integration Services (voir son `LISEZMOI.md`) et exécutez-le ;
   - **ou en secours** : `EXEC dbo.ps_ChargerDimensions; EXEC dbo.ps_ChargerFaitOrders;`
4. Exécutez **05** et **06** : les résultats doivent être identiques.
5. Construisez le rapport Power BI (`docs/03_GUIDE_POWER_BI.md`).
6. Complétez le rapport (noms, captures d'écran).

## Contrôles attendus
| Contrôle | Valeur |
|----------|--------|
| `SELECT COUNT(*) FROM FaitOrders` | 2 996 |
| `SELECT SUM(Montant) FROM FaitOrders` | 9 604 190,61 |
| Q2 : top 2 commerciaux | Gerard Hernandez (43), Leslie Jennings (34) |

Tous les scripts ont été testés sur SQL Server 2022.
