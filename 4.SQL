SELECT DISTINCT title                                     AS programme_title,
                Cast(num_duration_programme_min AS INT64) AS num_duration_programme_min,
                subgenre                                  AS genre,
                country,
                parental_controls,
                tag_age_range,
                uuid_programme AS uuid,
                licence_start                             AS LICENCE_START,
                licence_end                               AS LICENCE_END,
                cinema_family_play_allowed   AS n_play_allowed,
                cinema_family_play_scheduled AS n_play_scheduled,
                cinema_family_play_remained  AS n_play_remained,
                CASE
                    WHEN  _cinema_family_free_play IS NULL AND              _cinema_family_play_allowed IS NOT NULL THEN 0
                    ELSE 1
                END free_play,
                director,
                agcom_year                                                   AS year,
                Row_number() OVER(partition BY title ORDER BY licence_start) AS rn
FROM            ` ita-da-datalab-dpa.workspace_test.cinema_family` a
                JOIN            `ita-da-daita-prod.content_metadata_repository.programme` b
                  ON              lower(a.title) = lower(b.programme_title)
WHERE           win_name LIKE '%PAY TV%'
AND             programme_type = 'param_programme_type'
AND             regexp_contains(parental_controls, 'param_parental_controls')
AND             NOT regexp_contains(subgenre, 'param_genres')
AND             num_duration_programme_min <> 'NULL'
AND             cast(num_duration_programme_min AS int64) > 60
and uuid_programme not in (select distinct uuid from  ita-da-datalab-dpa.workspace_test.linear_schedule_family)