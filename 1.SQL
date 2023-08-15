CREATE OR REPLACE TABLE `{workspace_project_id}.{workspace_dataset_id}.{use_case_id}_export_to_IBMS` AS
WITH
ALL_DATA_FILTERED AS (
    SELECT 
        uuid,
        NUM_DURATION_PROGRAMME_MIN,
        title,
        n_slot_to_use,
        start_time,
        channel,
        time(timestamp_seconds(safe_multiply(safe_cast(n_slot_to_use AS int64), 300))) AS running_time  --300=5'slot duration *60'
    FROM `{export_project_id}.{export_dataset_id}.{output_table_id}` 
    WHERE 
        date_prediction_reference = @date_prediction_reference
        AND date_prediction_run IN (SELECT MAX(date_prediction_run) 
                                    FROM `{export_project_id}.{export_dataset_id}.{output_table_id}`
                                    WHERE date_prediction_reference = @date_prediction_reference)
),
FINAL AS (
    select 
        *,
        case 
            when EXTRACT(time from start_time) between '00:00:00' and '05:59:59' then TIMESTAMP_SUB(start_time, INTERVAL 1 day)
            else start_time
        end AS start_time_new
    from ALL_DATA_FILTERED
)

SELECT
    FORMAT_DATE("%d/%m/%Y", DATE(start_time_new)) AS schedule_date,
    CASE 
        WHEN EXTRACT(hour from start_time_new) between 0 and 5 then 
            # NECESSARY TO CONVERT TO HH:MM FORMAT
            CONCAT(EXTRACT(hour FROM start_time_new)+24,":", FORMAT_TIMESTAMP("%M", start_time_new))
        ELSE  CAST(FORMAT_TIME("%R", TIME(EXTRACT(TIME FROM start_time_new))) AS STRING)
    END AS start_time,
    FORMAT_TIME("%R", TIME(timestamp_seconds(CAST(safe_multiply(n_slot_to_use, 300) AS INT64)))) AS slot_duration,
    --substring(safe_cast(time(timestamp_seconds(CAST(safe_multiply(n_slot_to_use, 300) AS INT64))) AS string),0,5) AS slot_duration,
    substring(replace(title, ",", " "), 0, 30) AS slot_name,
    NULL AS episode_title,
    NULL AS genre_id,
    NULL AS genre,
    NULL AS subgenre_id,
    NULL AS subgenre,
    NULL AS genre_internal_name,
    NULL AS censor_code,
    NULL AS censor_name,
    NULL AS parental_id_warning,
    NULL AS parental_warning,
    NULL AS synopsis,
    NULL AS production_year,
    NULL AS actors,
    NULL AS director,
    "ITA" AS language
FROM FINAL
ORDER BY schedule_date, start_time

File
Search
