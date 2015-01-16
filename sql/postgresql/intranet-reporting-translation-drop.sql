-- /packages/intranet-invoices/sql/postgresql/intranet-reporting-translation-drop.sql
--
-- Copyright (C) 2003 - 2009 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com



-- Delete reports defined by this package
create or replace function inline_0 ()
returns integer as $body$
declare
	row			RECORD;
	v_menu			integer;
	v_reporting_menu 	integer;
BEGIN
	FOR row IN
		select	report_id
		from	im_reports
		where	report_menu_id in (
			select	menu_id
			from	im_menus
			where	package_name = 'intranet-reporting-translation'
		)
	LOOP
		perform im_report__delete(row.report_id);
	END LOOP;
	return 0;
end;$body$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();

select im_menu__del_module('intranet-reporting-translation');
