create or replace function get_calculated_calendar(p_date_from date, p_date_to date)
 returns table(date date, month_short_name text, week_number integer, day_short_name text, day_type text)
 language plpgsql
as $function$

begin

	return query
	
		with
		period as (
			select
				d.date
			from generate_series(p_date_from, p_date_to, '1 day'::interval) d
			)
		, months as (
			select
				row_number() over () as month_number,
			t.month_short_name
			from ( select string_to_table('янв,фев,мар,апр,май,июн,июл,авг,сен,окт,ноя,дек', ',') as month_short_name) t
			)
		, days as (
			select
				row_number() over () as day_number,
				t.day_short_name
			from ( select string_to_table('пн,вт,ср,чт,пт,сб,вс', ',') as day_short_name) t
			)
		select
			p.date,
			m.month_short_name,
			date_part('week', p.date)::integer week_number,
			d.day_short_name,
			case
			when date_part('isodow', p.date) = any (array[6, 7]) then 'H'
			else 'W'
			end as day_type
		from period p
		join months m on m.month_number = date_part('month', p.date)
		join days d on d.day_number = date_part('isodow', p.date)
		order by p.date;

end;

$function$
;