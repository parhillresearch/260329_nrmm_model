| step | object | file | class | dimensions | description |
|------|--------|------|-------|------------|-------------|
| 1 | audits | audits.rds | tbl_df | 19987 x 30 | All ingested audit records including Variable_Speed group duplication of CAZ_Plus and Rest_of_London rows. |
| 1 | audits_uniq | audits_uniq.rds | tbl_df | 11131 x 30 | Unique audit records after all exclusion filters applied, one row per audit with group == group_primary. |
| 1 | exclusions | exclusions.rds | tbl_df | 5120 x 3 | Excluded records with date, year, and excl_reason documenting each filter applied during ingestion. |
| EF | ef_fleet | ef_fleet_260717_v1.rds | list | 13 subgroup-phase cells | Fleet-effective EF (NOx, PM; count- and power-weighted g/kWh) by sub-group, phase and engagement, from initial stage limits at engine power band; records with unresolvable stage or subgroup excluded. | 
| EF | ef_fleet | ef_fleet_260717_v1.rds | list | 13 subgroup-phase cells | Fleet-effective EF (NOx, PM; count- and power-weighted g/kWh) by sub-group, phase and engagement, from initial stage limits at engine power band; records with unresolvable stage or subgroup excluded. | 
| EF | ef_fleet_v2 | ef_fleet_260717_v2.rds | list | 13 subgroup-phase cells | Type-stratified convex-combination fleet EF (NOx g/kWh) with placeholder usage indices, adversarial envelopes and OAT sensitivity; N_t placeholder is audit counts pending registration database. | 
| EF | ef_fleet_v2 | ef_fleet_260717_v2.rds | list | 13 subgroup-phase cells | Type-stratified convex-combination fleet EF (NOx g/kWh) with placeholder usage indices, adversarial envelopes and OAT sensitivity; N_t placeholder is audit counts pending registration database. | 
