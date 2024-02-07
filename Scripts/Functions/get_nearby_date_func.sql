create or replace function get_nearby_date(p_id integer, p_direction integer)
	returns date
	language plpgsql
as $function$

	declare
	
		v_date date;
		v_index_by_date integer;
		v_sort_direction text;
		v_comparison_sign text;
		q text;
		result date;
	
	begin
	
		if p_direction not in (-1, 1)
			then raise exception 'Параметр p_direction должен быть одним из: -1, 1 (предыдущая или следующая соответственно).';
		end if;
	
		v_date = (select date from operation where id = p_id);
		v_index_by_date = (select index_by_date from operation where id = p_id);
	
		if p_direction = -1
		then
			v_sort_direction = 'desc';
			v_comparison_sign = '<';
		elsif p_direction = 1
		then
			v_sort_direction = 'asc';
			v_comparison_sign = '>';
		end if;
		
		q = 'select date from (
					select
						row_number() over (order by o.date %sort_direction%)
						, o.date
					from
						operation_as_json_object_view o
					where
						o.date %comparison_sign% $1
						or (o.date = $1 and o.index_by_date %comparison_sign% $2)
					) q
				where row_number = 1';
		
		q = replace(q, '%sort_direction%', v_sort_direction);
		q = replace(q, '%comparison_sign%', v_comparison_sign);
	
		execute q using v_date, v_index_by_date into result;
		return result;
	
	end;

$function$
;