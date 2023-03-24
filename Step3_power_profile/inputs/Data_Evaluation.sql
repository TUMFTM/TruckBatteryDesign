-- just show the tracks
select * from fleet_test.vehicle v 
join track.track t on v.id = t.vehicle_id 
join track.track_metadata tm on t.id = tm.track_id 
where fleet_test_id in $fleets
and tm.distance > $min_distance-- 

-- first track of day
--- when does a truck "wake up" ?
select extract (hour from start_time) as "Departure", COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () as "Chance" -- , count(*) as absolute,
from 
(
select distinct on (vehicle_id_anon, date_trunc('day', start_time) , vehicle_id_anon) start_time from
(
select am.vehicle_id_anon, am.start_time 
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
order by vehicle_id_anon, start_time asc
) t1
) t
group by extract (hour from start_time)
order by extract (hour from start_time) asc


-- group by day of week
-- "wie wahrscheinlich ist es dass an einem Wochentag 0, 1, 2, 3, x trips gefahren werden?"
--select * from crosstab('
with proba_0_weekend as (select avg(proba_0) from
(
select vehicle_id_anon, 1.0 - count(*)::float / public.count_weekend_days(date_trunc('day',min(start_time))::date,date_trunc('day',max(start_time))::date)::float as proba_0 from (
select distinct on (am.vehicle_id_anon, date_trunc('day', start_time)) am.vehicle_id_anon, start_time
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
and extract (isodow from start_time) >= 6
order by am.vehicle_id_anon, date_trunc('day', start_time) 
)t
group by vehicle_id_anon
)t2),
proba_0_week as (select avg(proba_0) from
(
select vehicle_id_anon, 1.0 - count(*)::float / public.count_business_days(date_trunc('day',min(start_time))::date,date_trunc('day',max(start_time))::date)::float as proba_0 from (
select distinct on (am.vehicle_id_anon, date_trunc('day', start_time)) am.vehicle_id_anon, start_time
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
and extract (isodow from start_time) < 6
order by am.vehicle_id_anon, date_trunc('day', start_time) 
)t
group by vehicle_id_anon
)t2)
select coalesce(week."Number", weekend."Number") as "Number"  , coalesce("Chance_week" * (1.0- (select * from proba_0_week)),0) as "Chance_week" , coalesce("Chance_weekend" * (1-(select * from proba_0_weekend)),0) as "Chance_weekend" from (
select num_tracks as "Number", COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () as "Chance_week" from (
select am.vehicle_id_anon, date_trunc('day', start_time), count(*) as num_tracks
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
and extract (isodow from start_time) < 6
group by am.vehicle_id_anon, date_trunc('day', start_time)
order by 1,2
)t
group by  num_tracks
order by num_tracks ) week
full join 
(select num_tracks as "Number", COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () as "Chance_weekend" from (
select am.vehicle_id_anon, date_trunc('day', start_time), count(*) as num_tracks
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
and extract (isodow from start_time) >= 6
group by am.vehicle_id_anon, date_trunc('day', start_time)
order by 1,2
)t
group by  num_tracks
order by num_tracks) weekend
on week."Number" = weekend."Number"
union select  0 as "Number", (select * from proba_0_week) as "Chance_week", (select * from proba_0_weekend) as "Chance_weekend"
order by "Number" 
--') as ct(vehicle_id int8, n1 int8, n2 int8, n_3 int8
--, n_4 int8, n_5 int8, n_6 int8, n_7 int8
--, n_8 int8, n_9 int8, n_10 int8, n_11 int8)

-- probability of "no trips":
select avg(proba_0) from
(
select vehicle_id_anon, 1.0 - count(*)::float / public.count_weekend_days(date_trunc('day',min(start_time))::date,date_trunc('day',max(start_time))::date)::float as proba_0 from (
select distinct on (am.vehicle_id_anon, date_trunc('day', start_time)) am.vehicle_id_anon, start_time
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
and extract (isodow from start_time) >= 6
order by am.vehicle_id_anon, date_trunc('day', start_time) 
)t
group by vehicle_id_anon
)t2

-- departure timeofday
select extract (hour from start_time), count(*) from fleet_test.vehicle v 
join track.track t on v.id = t.vehicle_id 
join track.track_metadata tm on t.id = tm.track_id 
where fleet_test_id in $fleets
and tm.distance > $min_distance
group by  extract (hour from start_time)
order by 1

-- payload

select floor(gross_weight_kg/1000), count(*) from nefton_rio_telemetry.track_data td 
where td.distance_km > 1 and gross_weight_kg is not null
group by floor(gross_weight_kg/1000) 
order by 1


-- distance - duration
select count(*)
from fleet_test.vehicle v 
join track.track t on v.id = t.vehicle_id 
join track.track_metadata tm on t.id = tm.track_id 
where fleet_test_id in $fleets
and tm.distance > $min_distance
and tm.distance / extract (epoch from stop_time - start_time) < $max_speed
-- result 21127

select distance as distance_km , duration as duration_min, 
distance + $dist_step/2000.0 as mean_distance,
duration + $time_step/2.0 as mean_duration,
coalesce("Chance",0) as "Chance"
from 
( SELECT *
 FROM   generate_series(0,375,$dist_step/1000) distance
     , generate_series(0,270,$time_step) duration
) grid
left join (
select distance_km,duration_min, count(*) as num_tracks, count(*) / SUM(COUNT(*)) OVER () as "Chance" from (
select 
floor (extract (epoch from stop_time - start_time) / 60 / $time_step)*$time_step as duration_min,
floor(distance / $dist_step)*$dist_step / 1000 as distance_km
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
and distance / extract (epoch from stop_time - start_time) < $max_speed
) t
group by duration_min, distance_km
) values 
on grid.distance = values.distance_km and grid.duration = values.duration_min
order by 2,1


-- rest time 
select
	floor(rest_time / $rest_time_step)* $rest_time_step as "Rest",
	count(*) / SUM(COUNT(*)) over () as "Chance",
	floor(rest_time / $rest_time_step)* $rest_time_step + $rest_time_step / 2.0 as "mean_rest_time"
from
	(
	select
		extract (epoch
	from
		start_time - lag(stop_time, 1) over 
(partition by am.vehicle_id_anon,
		date_trunc('day', start_time)
	order by
		am.vehicle_id_anon,
		start_time asc)) / 60 as rest_time
	from
		nefton_rio_telemetry.anon_master am
	join nefton_rio_telemetry.anon_vehicle_id avi on
		am.vehicle_id_anon = avi.vehicle_id_anon
	where
		fleet_test_id in $fleets
		and distance > $min_distance
	) t
where rest_time is not null
group by
	floor(rest_time / $rest_time_step)* $rest_time_step
order by
	floor(rest_time / $rest_time_step)* $rest_time_step
	
	
select vehicle_id_anon, 
public.count_business_days(date_trunc('day',min(start_time))::date,date_trunc('day',max(start_time))::date)::float as business_days,
sum(distance),
sum(distance) / public.count_business_days(date_trunc('day',min(start_time))::date,date_trunc('day',max(start_time))::date)::float as avg_dist_per_day
from ( select 
am.vehicle_id_anon, start_time, distance
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where fleet_test_id in $fleets
and distance > $min_distance
and extract (isodow from start_time) < 6
order by am.vehicle_id_anon, date_trunc('day', start_time) ) t
group  by vehicle_id_anon
order by avg_dist_per_day desc

select *
from nefton_rio_telemetry.anon_master am
join nefton_rio_telemetry.anon_vehicle_id avi on am.vehicle_id_anon = avi.vehicle_id_anon 
where am.vehicle_id_anon = 50

select * from nefton_rio_telemetry.anon_vehicle_id avi where vehicle_id_anon = 50

select date_trunc('second', time) as time, avg(altitude) as alt, avg(speed) as speed_ms from sensor.location sl where vehicle_id = 1700000752
group by date_trunc('second', time) 
