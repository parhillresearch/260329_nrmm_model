| step | object | file | class | dimensions | description |
|------|--------|------|-------|------------|-------------|
| 1 | audits | audits.rds | tbl_df | 19987 x 30 | All ingested audit records including Variable_Speed group duplication of CAZ_Plus and Rest_of_London rows. |
| 1 | audits_uniq | audits_uniq.rds | tbl_df | 11131 x 30 | Unique audit records after all exclusion filters applied, one row per audit with group == group_primary. |
| 1 | exclusions | exclusions.rds | tbl_df | 5120 x 3 | Excluded records with date, year, and excl_reason documenting each filter applied during ingestion. |
