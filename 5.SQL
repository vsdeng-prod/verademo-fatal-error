CREATE OR REPLACE TABLE {project_id}.{dataset_id}.{table_id} AS
with metadata as
(

SELECT * except(rn) 
FROM
(
    SELECT          
        uuid_programme ,
        programme_title ,
        --programme_genre_epg,
        programme_sub_genre,
        programme_type,
        --parental_controls,
        row_number() over (partition by uuid_programme order by partition_date desc) AS rn
    FROM `ita-da-daita-prod.content_metadata_repository.programme` )
    WHERE rn=1
),

stock_list_data as 

(
select * except(rn)
FROM (
   SELECT DISTINCT
               b.uuid_programme as uuid,
               b.programme_title as title,
              -- num_duration_programme_min AS NUM_DURATION_PROGRAMME_MIN,
               b.programme_sub_genre,
               b.programme_type,
               a.GENRE,
               country_agcom AS COUNTRY,
               recommended as PARENTAL_CONTROLS,
               a.director  as DIRECTOR,
               a.year    as YEAR,
               a.CAST_ as PROGRAMME_CAST,
               ROW_NUMBER()OVER(PARTITION BY programme_title, director order by b.uuid_programme) as rn
FROM            {project_id}.{dataset_id}.cpo_titles_stock_list  a 
               JOIN    metadata b
                 ON              id_mds = b.uuid_programme


)),

content_metadata as (
select * except (rn) from (
SELECT  UUID,
	    TITLE,
	    PROGRAMME_TYPE,
        programme_sub_genre,
	   -- cast(NUM_DURATION_PROGRAMME_MIN as int64) as NUM_DURATION_PROGRAMME_MIN,
	    GENRE,
	    COUNTRY,
	    PARENTAL_CONTROLS,
	    DIRECTOR,
	    YEAR,
	    PROGRAMME_CAST,
      case when COUNTRY like '%ITA%' then 1 else 0 end as italian_movie,
      ROW_NUMBER()OVER(PARTITION BY lower(title), director order by uuid) as rn
FROM stock_list_data
--WHERE cast(NUM_DURATION_PROGRAMME_MIN as int64) > 0

) where rn=1)
select  * from content_metadata

File
Search
