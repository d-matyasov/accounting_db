create or replace procedure recalculate_current_amount(p_accounting_object_id integer default null::integer)
 language plpgsql
as $procedure$

	declare

		v_accounting_object_ids int[];
		x int;
		v_start_amount bigint;
		v_sum bigint;

	begin

	    if p_accounting_object_id is null
	    	then v_accounting_object_ids = (select 
												array_agg(ao.id) 
											from
												accounting_object ao);
			else v_accounting_object_ids = array[p_accounting_object_id];
		end if;
	
		foreach x in array v_accounting_object_ids
		loop
			
			v_start_amount = (select ao.start_amount from accounting_object ao where ao.id = x);
		
			v_sum = (select sum(o.amount_plus) - sum(o.amount_minus) from operation o where o.accounting_object_id = x and o.is_fact = true);
		
			update accounting_object set current_amount = v_start_amount + coalesce(v_sum, 0) where id = x;
			
	   end loop;
	  
    end;
   
$procedure$
;