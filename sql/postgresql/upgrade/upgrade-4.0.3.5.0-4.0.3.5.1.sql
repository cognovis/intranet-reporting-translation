
SELECT acs_log__debug('/packages/intranet-reporting-translation/sql/postgresql/upgrade/upgrade-4.0.3.5.0-4.0.3.5.1.sql','');


create or replace function inline_0 ()
returns integer as $body$
declare
	-- Menu IDs
	v_menu			integer;
	v_reporting_menu 	integer;

	-- Groups
	v_employees		integer;
BEGIN
	select group_id into v_employees from groups where group_name = 'Employees';

	select menu_id into v_reporting_menu from im_menus where label='reporting-translation';

	v_reporting_menu := im_menu__new (
		null,							-- p_menu_id
		'im_menu',						-- object_type
		now(),							-- creation_date
		null,							-- creation_user
		null,							-- creation_ip
		null,							-- context_id
		'intranet-reporting-translation',			-- package_name
		'reporting-translation-tm-savings',			-- label
		'TM Savings',						-- name
		'/intranet-reporting-translation/translation-tm-savings',	-- url
		75,							-- sort_order
		v_reporting_menu,					-- parent_menu_id
		null							-- p_visible_tcl
	);

	return 0;
end;$body$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();

