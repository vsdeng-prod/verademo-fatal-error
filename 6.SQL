insert into {export_project_id}.{export_dataset_id}.{table_id}
(
    UUID_INTEGER,
    UUID,
    TITLE,
    TITLE_ID,
    PROGRAMME_TYPE,
    NUM_DURATION_PROGRAMME_MIN,
    GENRE,
    COUNTRY,
    PARENTAL_CONTROLS,
    DIRECTOR,
    YEAR,
    PROGRAMME_CAST,
    DISTRIBUTOR,
    PLAY_ALLOWED,
    PLAY_SCHEDULED,
    PLAY_REMAINED,
    FREE_PLAY,
    TOTAL_PLAYS_ALLOWED,
    N_FUTURE_SCHEDULES_5d,
    N_HISTORICAL_SCHEDULES_5d,
    AVG_DAILY_NUM_VIEWS,
    TOTAL_TTS,
    RATING,
    FLG_EU_MOVIE_CONSTRAINT,
    flg_is_current,
    N_SLOT_TO_USE,
    CURRENT_CONTENT,
    start_slot,
    week_day,
    channel,
    date_kpis_reference,
    date_kpis_run,
    flg_interstitials,
    notes_advices_viewing,
    date_end_certificate,
    date_start_certificate,
    programme_sub_genre
)
WITH
  HARD_CONSTRAINTS AS (
  SELECT DISTINCT 
    time_slot,
    week_day,
    parental_control,
    channel
  FROM
    `{workspace_project_id}.{workspace_dataset_id}.cpo_content_planning_hard_constraints`),
 mastertable as (
  select DISTINCT UUID_INTEGER,
    UUID,
    TITLE,
    TITLE_ID,
    PROGRAMME_TYPE,
    NUM_DURATION_PROGRAMME_MIN,
    GENRE,
    COUNTRY,
    PARENTAL_CONTROLS,
    DIRECTOR,
    YEAR,
    PROGRAMME_CAST,
    DISTRIBUTOR,
    PLAY_ALLOWED,
    PLAY_SCHEDULED,
    PLAY_REMAINED,
    COALESCE(FREE_PLAY, 0) AS FREE_PLAY,
    TOTAL_PLAYS_ALLOWED,
    N_FUTURE_SCHEDULES_5d,
    N_HISTORICAL_SCHEDULES_5d,
    COALESCE(AVG_DAILY_NUM_VIEWS, 0) AS AVG_DAILY_NUM_VIEWS,
    COALESCE(TOTAL_TTS, 0) AS TOTAL_TTS,
    c.RATING,
    FLG_EU_MOVIE_CONSTRAINT,
    flg_is_current,
    N_SLOT_TO_USE,
    CURRENT_CONTENT,
    time_slot as start_slot, 
    week_day,
    CHANNEL_ as channel,
    date_kpis_reference,
    date_kpis_run,
    flg_interstitials,
    notes_advices_viewing,
    date_end_certificate,
    date_start_certificate,
    programme_sub_genre,
    TIME_ADD(time_slot,INTERVAL (N_SLOT_TO_USE+2)*5 MINUTE) AS end_time,
    parental_control_basket
    from (select
         *,
        ROW_NUMBER() OVER() as UUID_INTEGER
        from (
        Select 
        ROW_NUMBER() OVER(partition by m.uuid order by grading,PLAY_REMAINED) as rn,
        t.id_mds as UUID,
        t.TITLE as TITLE,
        t.id_title as TITLE_ID,
        m.PROGRAMME_TYPE,
        t.NUM_DURATION_PROGRAMME_MIN,
        t.channel_name as CHANNEL_,
        t.GENRE,
        m.COUNTRY,
        --m.PARENTAL_CONTROLS,
        certificate_version as PARENTAL_CONTROLS,
        m.DIRECTOR,
        cast(m.YEAR as string) as YEAR,
        m.PROGRAMME_CAST,
        t.DISTRIBUTOR,
        safe_cast(t.PLAY_ALLOWED as int64) as PLAY_ALLOWED,
        safe_cast(t.PLAY_SCHEDULED as int64) as PLAY_SCHEDULED,
        safe_cast(t.PLAY_REMAINED as int64) as PLAY_REMAINED,
        safe_cast(t.FREE_PLAY as int64) as FREE_PLAY,
        safe_cast(t.TOTAL_PLAYS_ALLOWED as int64) as TOTAL_PLAYS_ALLOWED,  
        f.N_FUTURE_SCHEDULES_5d,
        h.N_HISTORICAL_SCHEDULES_5d,
        v.AVG_DAILY_NUM_VIEWS,
        v.TOTAL_TTS,
        t.grading as RATING,
        t.flg_eu_movie as FLG_EU_MOVIE_CONSTRAINT,
        safe_cast(flg_is_current as int64) as flg_is_current,
        case when mod(t.NUM_DURATION_PROGRAMME_MIN ,5)=0 then safe_cast(t.NUM_DURATION_PROGRAMME_MIN/5 as int64)
        else 
        safe_cast(floor(safe_cast(t.NUM_DURATION_PROGRAMME_MIN as float64) / 5.0) as int64) + 1 
        end
        as N_SLOT_TO_USE,
        case when lower(recommended)in ("suggested 12","universal","parental guidance") and lower(notes_advices_viewing) ="" then " -U"
        when lower(recommended)="suggested 12" and lower(notes_advices_viewing)="no dt" then " -S12-NODT"
        when lower(recommended)="suggested 12" and lower(notes_advices_viewing)="no fp" then " -S12-NOFP"
        when lower(recommended)="suggested 14" and lower(notes_advices_viewing)="no dt" then " -S14-NODT"
        when lower(recommended)="suggested 14" and lower(notes_advices_viewing)="no fp" then " -S14-NOFP"
        when lower(recommended)="legal - vm16" and lower(notes_advices_viewing)=""  then " -VM16"
        when lower(recommended) ="legal - vm14" and lower(notes_advices_viewing)="" then " -VM14"
        when lower(recommended)="legal - vm14" and lower(notes_advices_viewing)="no dt" then " -VM14-NODT"
        when lower(recommended)="legal - vm14" and  lower(notes_advices_viewing)="no fp" then " -VM14"
        when lower(recommended)="legal - vm12" and notes_advices_viewing="" then " -VM12"
        when lower(recommended)="legal - vm14/suggested 12" and  lower(notes_advices_viewing)="no fp" then " -VM14"
        else "other"
        end as parental_control_basket,
        case when safe_cast(m.YEAR as int64)> 1990 then 1 else 0 end as CURRENT_CONTENT,
        DATE('{date_reference}') AS date_kpis_reference,
        DATETIME('{run_date}') AS date_kpis_run,
        t.flg_interstitials,
        t.notes_advices_viewing,
        t.date_end_certificate,
        t.date_start_certificate,
        m.programme_sub_genre 
       from `{workspace_project_id}.{workspace_dataset_id}.cpo_titles_stock_list` t 
       left join `{workspace_project_id}.{workspace_dataset_id}.cpo_content_metadata` m on m.uuid=t.id_mds 

        left join `{workspace_project_id}.{workspace_dataset_id}.cpo_future_schedule` f on m.UUID = f.UUID
        left join `{workspace_project_id}.{workspace_dataset_id}.cpo_historical_schedule`  h on m.UUID = h.UUID
        left join `{workspace_project_id}.{workspace_dataset_id}.cpo_viewership_data` v on m.UUID = v.UUID) b
     where rn=1) c
        join HARD_CONSTRAINTS r on c.parental_control_basket = r.parental_control 
        --and REGEXP_CONTAINS(r.rating, safe_cast(c.RATING as string))
)
SELECT
    UUID_INTEGER,
    UUID,
    TITLE,
    TITLE_ID,
    PROGRAMME_TYPE,
    NUM_DURATION_PROGRAMME_MIN,
    GENRE,
    COUNTRY,
    PARENTAL_CONTROLS,
    DIRECTOR,
    YEAR,
    PROGRAMME_CAST,
      DISTRIBUTOR,
    PLAY_ALLOWED,
    PLAY_SCHEDULED,
    PLAY_REMAINED,
    COALESCE(FREE_PLAY, 0) AS FREE_PLAY,
    TOTAL_PLAYS_ALLOWED,
    N_FUTURE_SCHEDULES_5d,
    N_HISTORICAL_SCHEDULES_5d,
    COALESCE(AVG_DAILY_NUM_VIEWS, 0) AS AVG_DAILY_NUM_VIEWS,
    COALESCE(TOTAL_TTS, 0) AS TOTAL_TTS,
    RATING,
    FLG_EU_MOVIE_CONSTRAINT,
    flg_is_current,
    N_SLOT_TO_USE,
    CURRENT_CONTENT,
    start_slot,
    m.week_day,
    m.channel,
    date_kpis_reference,
    date_kpis_run,
    flg_interstitials,
    notes_advices_viewing,
    date_end_certificate,
    date_start_certificate,
    programme_sub_genre
FROM MASTERTABLE m
JOIN
  HARD_CONSTRAINTS r
ON
  m.parental_control_basket=r.parental_control
  AND m.start_slot=r.time_slot
  AND m.week_day=r.week_day
JOIN
  HARD_CONSTRAINTS q
ON
  m.parental_control_basket=q.parental_control
  AND m.end_time=q.time_slot
  AND m.week_day=q.week_day

File
Search
