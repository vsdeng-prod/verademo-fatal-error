SELECT count(*) as cnt
FROM `da-daita-prod.asset_management_enriched.asset_catalogue` 
WHERE DATE(partition_date) = "2021-04-05"
and flg_pack_cinema = 1