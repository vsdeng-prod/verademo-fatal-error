insert into `{workspace_project_id}.{workspace_dataset_id}.{performances_table_id}`
(
    channel,
    day_of_month,
    count_rating_not_respected,
    count_rating_not_respected_prime_time,
    avg_rating_night_time,
    avg_rating_6to12,
    avg_rating_12to16,
    avg_rating_16to19,
    avg_rating_pre_prime_time,
    avg_rating_prime_time,
    avg_rating_22to24,
    count_parental_control_not_respected,
    count_free_plays_x_day,
    num_play_remains_not_respected,
    titles_play_remains_not_respected,
    num_genres_per_day,
    total_genres,
    holes_minutes_per_day,
    adv_minutes_per_day,
    num_interstitials_per_day,
    interstitals_minutes_per_day,
    min_consecutive_schedule_distance_days,
    date_prediction_reference,
    date_prediction_run
)
WITH CPO_OUTPUT AS (
    SELECT 
        *,
        TIMESTAMP_ADD(start_time, INTERVAL (EXTRACT(HOUR FROM running_time)*3600 + EXTRACT(MINUTE FROM running_time)*60 + EXTRACT(SECOND FROM running_time)) SECOND) AS end_time,
        LEAD(start_time) OVER(PARTITION BY channel ORDER BY start_time) AS next_start_time,  
    FROM `{export_project_id}.{export_dataset_id}.{output_table_id}`
    WHERE date_prediction_run=(SELECT MAX(date_prediction_run) from `{export_project_id}.{export_dataset_id}.{output_table_id}`
                                WHERE date_prediction_reference="{date_reference}")
    AND date_prediction_reference="{date_reference}"
),
CPO_MASTERTABLE AS (
    SELECT 
        channel,
        uuid,
        ANY_VALUE(GENRE) AS GENRE,
        ANY_VALUE(PLAY_REMAINED) AS PLAY_REMAINED,
        ANY_VALUE(RATING) AS RATING,
        --ANY_VALUE(PARENTAL_CONTROLS) AS PARENTAL_CONTROLS,
        ANY_VALUE(FLG_INTERSTITIALS) AS FLG_INTERSTITIALS
    FROM `{export_project_id}.{export_dataset_id}.{master_table_id}`
    WHERE date_kpis_run=(SELECT MAX(date_kpis_run)  FROM `{export_project_id}.{export_dataset_id}.{master_table_id}`
                                 WHERE date_kpis_reference="{date_reference}")
    AND date_kpis_reference="{date_reference}"
    GROUP BY channel, uuid
),
CONTENTS_DISTANCE AS (
    SELECT  
        channel,
        uuid,
        start_time,
        TIMESTAMP_DIFF(LEAD(start_time) OVER(PARTITION BY channel, uuid ORDER BY start_time), start_time, SECOND) / (3600*24) AS consecutive_schedule_distance_days 
    FROM CPO_OUTPUT
    WHERE flag_free_play=false
),
COUNT_PLAY_REMAINS AS (
    SELECT 
        uuid,
        title,
        ANY_VALUE(CPO_MASTERTABLE.PLAY_REMAINED) - COUNT(*) AS play_remained_per_uuid
    FROM CPO_OUTPUT
    JOIN CPO_MASTERTABLE USING(uuid)
    WHERE flag_free_play = False
    GROUP BY uuid, title
),
PLAY_REMAINS_NOT_RESPECTED AS (
    SELECT 
        COUNT(*) AS count_play_remains_not_respected,
        STRING_AGG(title, " | ") AS titles_play_remains_not_respected
    FROM COUNT_PLAY_REMAINS
    WHERE COUNT_PLAY_REMAINS.play_remained_per_uuid < 0
),
TOTAL_GENRES AS (
    SELECT 
        channel,
        COUNT(DISTINCT(TRIM(LOWER(GENRE)))) AS total_genres,
        STRING_AGG(DISTINCT(TRIM(LOWER(GENRE))), " | ") AS genres,
    FROM CPO_MASTERTABLE
    GROUP BY channel
),
SOFT_CONSTRAINTS AS (
    SELECT DISTINCT
        week_day,
        time_slot,
        rating
    FROM `{workspace_project_id}.{workspace_dataset_id}.cpo_content_planning_soft_constraints`
),
TITLES_STOCK_LIST AS (
    SELECT DISTINCT
        id_mds AS uuid,
        CASE 
            WHEN LOWER(recommended)in ("suggested 12","universal","parental guidance") AND LOWER(notes_advices_viewing) = "" THEN " -U"
            WHEN LOWER(recommended) = "suggested 12" AND LOWER(notes_advices_viewing) = "no dt" THEN " -S12-NODT"
            WHEN LOWER(recommended) = "suggested 12" AND LOWER(notes_advices_viewing) = "no fp" THEN " -S12-NOFP"
            WHEN LOWER(recommended) = "suggested 14" AND LOWER(notes_advices_viewing) = "no dt" THEN " -S14-NODT"
            WHEN LOWER(recommended) = "suggested 14" AND LOWER(notes_advices_viewing) = "no fp" THEN " -S14-NOFP"
            WHEN LOWER(recommended) = "legal - vm16" AND LOWER(notes_advices_viewing) = ""  THEN " -VM16"
            WHEN LOWER(recommended) = "legal - vm14" AND LOWER(notes_advices_viewing) = "" THEN " -VM14"
            WHEN LOWER(recommended) = "legal - vm14" AND LOWER(notes_advices_viewing) = "no dt" THEN " -VM14-NODT"
            WHEN LOWER(recommended) = "legal - vm14" AND LOWER(notes_advices_viewing) = "no fp" THEN " -VM14"
            WHEN LOWER(recommended) = "legal - vm12" AND notes_advices_viewing = "" THEN " -VM12"
            WHEN LOWER(recommended) = "legal - vm14/suggested 12" AND  LOWER(notes_advices_viewing) = "no fp" THEN " -VM14"
            ELSE "other"
        END AS parental_control_basket
    FROM `{workspace_project_id}.{workspace_dataset_id}.cpo_titles_stock_list` 
),
HARD_CONSTRAINTS AS (
    SELECT DISTINCT
        week_day,
        time_slot,
        parental_control
    FROM `{workspace_project_id}.{workspace_dataset_id}.cpo_content_planning_hard_constraints`
),
JOINED_RESULTS AS (
    SELECT 
        CPO_OUTPUT.*,
        CPO_MASTERTABLE.* EXCEPT(channel, uuid, flg_interstitials),
        CAST(CPO_MASTERTABLE.rating AS STRING) AS rating_string,
        count_play_remains_not_respected,
        titles_play_remains_not_respected,
        TOTAL_GENRES.total_genres,
        SOFT_CONSTRAINTS.time_slot,
        SOFT_CONSTRAINTS.week_day,
        SOFT_CONSTRAINTS.rating AS accepted_ratings,
        HARD_CONSTRAINTS.parental_control AS accepted_parental_control,
        CONTENTS_DISTANCE.consecutive_schedule_distance_days as consecutive_schedule_distance_days,
        CASE 
            WHEN title = "interstitial" THEN 1
            ELSE flg_interstitials 
        END AS flg_interstitials
    FROM CPO_OUTPUT
    LEFT JOIN CPO_MASTERTABLE
        USING(channel, uuid)
    LEFT JOIN CONTENTS_DISTANCE
        ON CPO_OUTPUT.channel = CONTENTS_DISTANCE.channel
        AND CPO_OUTPUT.UUID=CONTENTS_DISTANCE.UUID
        AND CPO_OUTPUT.start_time=CONTENTS_DISTANCE.start_time
    LEFT JOIN SOFT_CONSTRAINTS
        --ON CPO_OUTPUT.channel = SOFT_CONSTRAINTS.channel
        ON EXTRACT(TIME FROM CPO_OUTPUT.start_time) = SOFT_CONSTRAINTS.time_slot
        AND EXTRACT(DAYOFWEEK FROM CPO_OUTPUT.start_time) = SOFT_CONSTRAINTS.week_day
    LEFT JOIN TITLES_STOCK_LIST
        ON CPO_OUTPUT.uuid = TITLES_STOCK_LIST.uuid
    LEFT JOIN HARD_CONSTRAINTS
        --ON CPO_OUTPUT.channel = HARD_CONSTRAINTS.channel
        ON EXTRACT(TIME FROM CPO_OUTPUT.start_time) = HARD_CONSTRAINTS.time_slot
        AND EXTRACT(DAYOFWEEK FROM CPO_OUTPUT.start_time) = HARD_CONSTRAINTS.week_day
        AND TITLES_STOCK_LIST.parental_control_basket = HARD_CONSTRAINTS.parental_control
    LEFT JOIN TOTAL_GENRES
        ON CPO_OUTPUT.channel = TOTAL_GENRES.channel,
    PLAY_REMAINS_NOT_RESPECTED
),
WITH_HOLES AS (
    SELECT 
        *,
        TIMESTAMP_DIFF(next_start_time, end_time, SECOND) / 60 AS hole_slot_in_minutes
    FROM JOINED_RESULTS
)

SELECT 
    channel,
    DATE(start_time) AS day_of_month,
    COUNTIF(CAST(RATING AS STRING) NOT IN (SELECT * FROM UNNEST(SPLIT(accepted_ratings)))) AS count_rating_not_respected,
    COUNTIF((EXTRACT(TIME FROM start_time) BETWEEN CAST("21:00:00" AS TIME) AND CAST("21:30:00" AS TIME)) AND CAST(RATING AS STRING) NOT IN (SELECT * FROM UNNEST(SPLIT(accepted_ratings)))) AS count_rating_not_respected_prime_time,
    AVG(IF((EXTRACT(TIME FROM start_time) BETWEEN CAST("00:00:00" AS TIME) AND CAST("05:59:00" AS TIME)), RATING, NULL)) AS avg_rating_night_time,
    AVG(IF((EXTRACT(TIME FROM start_time) BETWEEN CAST("06:00:00" AS TIME) AND CAST("11:59:00" AS TIME)), RATING, NULL)) AS avg_rating_6to12,
    AVG(IF((EXTRACT(TIME FROM start_time) BETWEEN CAST("12:00:00" AS TIME) AND CAST("15:59:00" AS TIME)), RATING, NULL)) AS avg_rating_12to16,
    AVG(IF((EXTRACT(TIME FROM start_time) BETWEEN CAST("16:00:00" AS TIME) AND CAST("18:59:00" AS TIME)), RATING, NULL)) AS avg_rating_16to19,
    AVG(IF((EXTRACT(TIME FROM start_time) BETWEEN CAST("19:00:00" AS TIME) AND CAST("20:59:00" AS TIME)), RATING, NULL)) AS avg_rating_pre_prime_time,
    AVG(IF((EXTRACT(TIME FROM start_time) BETWEEN CAST("21:00:00" AS TIME) AND CAST("21:59:00" AS TIME)), RATING, NULL)) AS avg_rating_prime_time,
    AVG(IF((EXTRACT(TIME FROM start_time) BETWEEN CAST("22:00:00" AS TIME) AND CAST("23:59:00" AS TIME)), RATING, NULL)) AS avg_rating_22to24,
    COUNTIF(accepted_parental_control  IS NULL AND flg_interstitials = 0) AS count_parental_control_not_respected,
    COUNTIF(flag_free_play=TRUE) AS count_free_plays_x_day,
ANY_VALUE(count_play_remains_not_respected) AS     num_play_remains_not_respected,
    ANY_VALUE(titles_play_remains_not_respected) AS titles_play_remains_not_respected,
    COUNT(DISTINCT(TRIM(LOWER(GENRE)))) AS num_genres_per_day,
    ANY_VALUE(total_genres) as total_genres,
    SUM(hole_slot_in_minutes) AS holes_minutes_per_day,
    SUM((n_slot_to_use*5) - num_duration_programme_min_prog) AS adv_minutes_per_day,
    SUM(flg_interstitials) AS num_interstitials_per_day,
    SUM(IF(flg_interstitials=1, num_duration_programme_min_prog,0)) AS interstitals_minutes_per_day,
    MIN(consecutive_schedule_distance_days) AS min_consecutive_schedule_distance_days,
    DATE('{date_reference}') AS date_prediction_reference,
    DATETIME('{run_date}') AS date_prediction_run
FROM WITH_HOLES
GROUP BY channel, day_of_month 
ORDER BY channel, day_of_month

File
Search
