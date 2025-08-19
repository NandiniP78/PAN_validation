create table pan_data (pan_number text)

select *
from pan_data

select count(*)
from pan_data -- 10,000 records
	
--1. data cleaning & preprocessing
--  identify and handle missing data - if found, remove it
select count(*)
from pan_data
where pan_number is null -- 965 null values

--  check for duplicates - if found, remove the duplicates
select pan_number, count(*)
from pan_data
group by pan_number
having count(*) > 1

--  handle leading/trailing spaces - remove any leading/trailing spaces
select pan_number
from pan_data
where pan_number <> trim(pan_number)

-- correct letter case - all numbers should be in uppercase
select pan_number
from pan_data
where pan_number <> upper(pan_number)
	
--  merging all the above queries to get cleaned pan numbers
select distinct upper(trim(pan_number))
from pan_data
where pan_number is not null
and trim(pan_number) <> ''


-- 2. pan format validation
--  function to check if two adjacent characters are same
create or replace function are_adjacent_same (pan_str text) returns boolean language plpgsql as $$
begin
	for i in 1 .. (length(pan_str) - 1)
	loop
		if substring(pan_str, i, 1) = substring(pan_str, i+1, 1)
		then
			return true; -- means adjacent characters are same
		end if;
	end loop;
	return false; -- come out of the loop-> characters are not same
end;
$$
-- select are_adjacent_same('zworz') returns false
-- select are_adjacent_same('zwooz') returns true

-- fucntion to check if characters are in sequence
create or replace function are_in_sequence (pan_str text) returns boolean language plpgsql as $$
begin
	for i in 1 .. (length(pan_str) - 1)
	loop
		if ascii(substring(pan_str, i, 1)) <> ascii(substring(pan_str, i+1, 1)) - 1
		then
			return false; -- means characters are not in sequence 
		end if;
	end loop;
	return true; -- come out of the loop-> characters are in sequence
end;
$$
-- select are_in_sequence('woucp') returns false as they are not in sequence

-- match the correct format for the pan
select pan_number
from pan_data
where pan_number ~ '^[a-z]{5}[0-9]{4}[a-z]$'
	
-- categorize
create or replace view vw_valid_invalid_pans as
with cte_cleaned_pan as 
	(select distinct upper(trim(pan_number)) as pan_number
		from pan_data
		where pan_number is not null
			and trim(pan_number) <> ''
	),
	cte_valid_pan as (
		select pan_number
		from cte_cleaned_pan
		where
			are_adjacent_same (pan_number) = false
			and are_in_sequence (substring(pan_number, 1, 5)) = false
			and are_in_sequence (substring(pan_number, 6, 9)) = false
			and pan_number ~ '^[a-z]{5}[0-9]{4}[a-z]$'
	)
select
	clp.pan_number,
	case
		when vlp.pan_number is null then 'invalid pan'
		else 'valid pan'
	end as status
from
	cte_cleaned_pan clp
	left join cte_valid_pan vlp on vlp.pan_number = clp.pan_number
	
select *
from vw_valid_invalid_pans

-- create a summary report that provides the following:
--   total records processed
--   total valid pans
--   total invalid pans
--   total missing or incomplete pans (if applicable)
with cte as 
	(select
		(select count(*) from pan_data) as total_processed_records,
			count(*) filter (where vw.status = 'valid pan') as total_valid_pans,
			count(*) filter (where vw.status = 'invalid pan') as total_invalid_pans
		from
			vw_valid_invalid_pans vw)
select
	total_processed_records,
	total_valid_pans,
	total_invalid_pans,
	total_processed_records - (total_valid_pans + total_invalid_pans) as missing_incomplete_pans
from
	cte;