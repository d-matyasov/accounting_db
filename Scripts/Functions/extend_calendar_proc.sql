create or replace procedure extend_calendar(p_date_from date, p_date_to date)
	language plpgsql
as $procedure$

	declare 
		
		i record;
		v_dates_count integer;
		v_calendar_dates_count integer;
		
begin

		select
			count(d.date) into v_dates_count
		from
			generate_series(p_date_from, p_date_to, '1 day'::interval) d;
		
		select
			count(c.date) into v_calendar_dates_count
		from
			calendar c
		where
			c.date >= p_date_from
			and c.date <= p_date_to;
		
	if v_dates_count <> v_calendar_dates_count
			then
				insert into calendar (date, month_short_name, week_number, day_short_name, day_type)
										select
											cc.date
											, cc.month_short_name
											, cc.week_number
											, cc.day_short_name
											, cc.day_type
										from
											get_calculated_calendar(p_date_from, p_date_to) cc
										where 
											cc.date not in (select date from calendar where	date >= p_date_from and date <= p_date_to);
			
	end if;
	
end;

$procedure$
;