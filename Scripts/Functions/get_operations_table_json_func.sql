create or replace function get_operations_table_json(p_date_from date, p_date_to date default null::date)
	returns text
	language plpgsql
as $function$
	
	declare

		result text;
		v_last_operation_date date;
		v_date_to date;
		jsonb jsonb;
	
	begin
	
		select max(date) into v_last_operation_date from operation;
	
		if p_date_to is null
			then select to_char(case when v_last_operation_date <= current_date then current_date else v_last_operation_date end + interval '15' day, 'YYYY-mm-DD') into v_date_to;
			else v_date_to = p_date_to;
		end if;
		
		select
		(select
			json_build_object(
				'headers',
				('[
					{
						"key": "month",
						"label": "М",
						"type": "string"
					},
					{
						"key": "week",
						"label": "Н",
						"type": "string"
					},
					{
						"key": "day",
						"label": "Д",
						"type": "string"
					},
					{
						"key": "date",
						"label": "Дата",
						"type": "date"
					},
					{
						"key": "amountPlus",
						"label": "Приход",
						"type": "amount"
					},
					{
						"key": "amountMinus",
						"label": "Расход",
						"type": "amount"
					},
					{
						"key": "isFact",
						"label": "Ф",
						"type": "boolean",
						"editable": true
					},
					{
						"key": "accountingObjectOrTransferName",
						"label": "|",
						"type": "string"
					},
					{
						"key": "category",
						"label": "|",
						"type": "string"
					}
				]')::jsonb ||
				(select
					coalesce(jsonb_agg(json_build_object(
						'key', 'accountingObject' || id
						, 'label', name_short
						, 'type', 'amount')), '[]'::jsonb)::jsonb
				from (
					select
						distinct
						ao.id
						, ao.name_short
						, c.ordinal_number
						, aot.is_credit
						, ao.ordinal_number
					from
						accounting_object ao
					join currency c on c.id = ao.currency_id
					join accounting_object_type aot on aot.id = ao.type_id
					where
						ao.open_date <= v_date_to
						and coalesce(ao.close_date, p_date_from) >= p_date_from
					order by
						c.ordinal_number nulls last
						, aot.is_credit
						, ao.ordinal_number nulls last
					) q) ||
				(select 
					coalesce(jsonb_agg(json_build_object(
					'key', 'sumByCurrency' || id
					, 'label', 'Сумма, ' || grapheme 
					, 'type', 'amount')), '[]'::jsonb)::jsonb
				from (
					select
						distinct
						c.id
						, c.grapheme 
						, c.ordinal_number 
					from
						accounting_object ao 
					join	currency c on c.id = ao.currency_id
					where
						ao.open_date <= v_date_to
						and coalesce(ao.close_date, p_date_from) >= p_date_from
					order by 
						c.ordinal_number
					) q)
			
			)::jsonb ||
		(select
			jsonb_build_object(
			'data',
			jsonb_agg(row)
			)
		from
			(select * from get_operation_as_json_object(p_date_from, v_date_to)
			order by
				date
				, index_by_date) q
			)) into jsonb;
		select jsonb::text into result;
	
		return result;
	
	end;

$function$
;