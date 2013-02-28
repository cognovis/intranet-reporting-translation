# /packages/intranet-reporting-translation/www/translation-tm-savings.tcl
#
# Copyright (c) 2003-2013 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.

ad_page_contract {
    Lists risks per project, taking into account DynFields.
} {
    { start_date "" }
    { end_date "" }
    { customer_id "" }
    { level_of_detail:integer 3 }
    { output_format "html" }
    { number_locale "" }
}

# ------------------------------------------------------------
# Security
#
set menu_label "reporting-translation-tm-savings"
set current_user_id [ad_maybe_redirect_for_registration]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

# For testing - set manually
set read_p "t"

if {![string equal "t" $read_p]} {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}


# ------------------------------------------------------------
# Check Parameters
#

# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }

# Default is user locale
if {"" == $number_locale} { set number_locale [lang::user::locale] }


db_1row todays_date "
select
	to_char(sysdate::date, 'YYYY') as todays_year,
	to_char(sysdate::date, 'YYYY')::integer + 1 as next_year
from dual
"

if {"" == $start_date} { set start_date "$todays_year-01-01" }
if {"" == $end_date} { set end_date "$next_year-01-01" }

# Check that Start & End-Date have correct format
if {"" != $start_date && ![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM-DD'"
}

if {"" != $end_date && ![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$end_date'<br>
    Expected format: 'YYYY-MM-DD'"
}


# ------------------------------------------------------------
# Page Title, Bread Crums and Help
#
set page_title [lang::message::lookup "" intranet-reporting-translation.TM_Savings "TM Savings"]
set context_bar [im_context_bar $page_title]
set help_text "
	<strong>$page_title:</strong><br>
	[lang::message::lookup "" intranet-reporting-translation.TM_Savings_help "
	This report lists the customer savings by using a translation memory.<br>
	It compares the plain word count of the translated documents with the<br>
	word count calculated by applying a discount matrix.
"]"


# ------------------------------------------------------------
# Default Values and Constants
#
set rowclass(0) "roweven"
set rowclass(1) "rowodd"

# Variable formatting - Default formatting is quite ugly
# normally. In the future we will include locale specific
# formatting. 
#
set currency_format "999,999,999.09"
set percentage_format "90.9"
set date_format "YYYY-MM-DD"

# Set URLs on how to get to other parts of the system for convenience.
set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="
set this_url "[export_vars -base "/intranet-riskmanagement/project-risks-report" {} ]?"

# Level of Details
# Determines the LoD of the grouping to be displayed
#
set levels [list \
    2 [lang::message::lookup "" intranet-riskmanagement.Risks_per_Project "Risks per Project"] \
    3 [lang::message::lookup "" intranet-riskmanagement.All_Details "All Details"] \
]


# ------------------------------------------------------------
# Report SQL
#

# Get dynamic risk fields
#
set deref_list [im_dynfield_object_attributes_derefs -object_type "im_risk" -prefix "r."]
set deref_extra_select [join $deref_list ",\n\t"]
if {"" != $deref_extra_select} { set deref_extra_select ",\n\t$deref_extra_select" }


set customer_sql ""
if {"" != $customer_id && 0 != $customer_id} {
    set customer_sql "and main_p.customer_id = :customer_id\n"
} else {
    # No specific customer set
    set customer_sql ""
}

set report_sql "
select	t.*,
	source_language || '-' || target_language || '-' || main_project_id as language_combination,
	CASE WHEN billable_units > 0.0 and raw_units > 0.0 THEN
		to_char(100.0 * (t.raw_units - t.billable_units) / t.billable_units, '990.0')
	ELSE 'undef' END as savings_percent,
	(select pp.company_contact_id from im_projects pp where pp.project_id = t.main_project_id) as customer_contact_id,
	(select im_name_from_user_id(pp.company_contact_id) from im_projects pp where pp.project_id = t.main_project_id) as customer_contact_name
from    (


		select  customer_id,
			acs_object__name(customer_id) as customer_name,
			main_project_id,
			im_project_nr_from_id(main_project_id) as main_project_nr,
			source_language_id,
			target_language_id,
			im_category_from_id(source_language_id) as source_language,
			im_category_from_id(target_language_id) as target_language,
			sum(raw_units) as raw_units,
			sum(billable_units) as billable_units
		from    (
			select  main_p.company_id as customer_id,
				main_p.project_id as main_project_id,
				coalesce(
					match0 + match50 + match75 + match85 + match95 + match100 + 
					match_rep + match_perf + match_cfr + match_x + 
					match_f50 + match_f75 + match_f85 + match_f95
				,billable_units) as raw_units,
				t.billable_units,
				t.source_language_id,
				t.target_language_id
			from    im_trans_tasks t,
				im_projects p,
				im_projects main_p
			where   t.project_id = p.project_id and
				p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
				main_p.parent_id is null
				$customer_sql
			) t
		group by
			customer_id,
			main_project_id,
			source_language_id,
			target_language_id


) t
order by
	customer_name,
	main_project_id,
	source_language,
	target_language
"


# ------------------------------------------------------------
# Report Definition
#

# Global Header
set header0 {
	"Customer"
	"Main Project"
	"Customer Contact"
	"Customer Contact Dept"
	"Source"
	"Target"
	"Raw Units"
	"Billable Units"
	"Saving"
}

# Main content line
set tm_vars {
	"<a href='$company_url$customer_id'>$customer_name</a>"
	"<a href='$project_url$main_project_id'>$main_project_nr</a>"
	"<a href='$user_url$customer_contact_id'>$customer_contact_name</a>"
	""
	$source_language
	$target_language
	"#align=right $raw_units_pretty"
	"#align=right $billable_units_pretty"
	"#align=right $savings_percent_pretty"
}

set project_header {
	"<a href=$this_url&customer_id=$customer_id&level_of_detail=3
	target=_blank><img src=/intranet/images/plus_9.gif width=9 height=9 border=0></a> 
	<a href=$company_url$customer_id>$customer_name</a>"
	"<a href=$project_url$main_project_id>$main_project_nr</a>"
}

# The entries in this list include <a HREF=...> tags
# in order to link the entries to the rest of the system (New!)
#
set report_def [list \
    group_by main_project_id \
    header $project_header \
    content [list \
	group_by language_combination \
	header $tm_vars \
	content {} \
    ] \
    footer {} \
]


# Global Footer Line
set footer0 {}


# ------------------------------------------------------------
# Counters
#

#
# Subtotal Counters (per project)
#
set project_risk_value_counter [list \
	pretty_name "Risk Value" \
	var risk_value \
	reset \$main_project_id \
	expr "\$risk_value+0" \
]

set project_risk_value_total_counter [list \
	pretty_name "Risk Value Total" \
	var risk_value_total \
	reset 0 \
	expr "\$risk_value+0" \
]


set counters [list \
]

#	$project_risk_value_counter \
#	$project_risk_value_total_counter \

# Set the values to 0 as default (New!)
set risk_value 0
set risk_value_total 0

# ------------------------------------------------------------
# Start Formatting the HTML Page Contents
#

im_report_write_http_headers -report_name $menu_label -output_format $output_format

switch $output_format {
    html {
	ns_write "
	[im_header]
	[im_navbar]
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	  <td width='30%'>
		<!-- 'Filters' - Show the Report parameters -->
		<form>
		<table cellspacing=2>
		<tr class=rowtitle>
		  <td class=rowtitle colspan=2 align=center>Filters</td>
		</tr>
		<tr>
		  <td>Level of<br>Details</td>
		  <td>
			[im_select -translate_p 0 level_of_detail $levels $level_of_detail]
		  </td>
		</tr>
		<tr>
		  <td>[lang::message::lookup "" intranet-core.Customer Customer]:</td>
		  <td>[im_company_select -include_empty_p 1 customer_id $customer_id "" "Customer"]</td>
		</tr>
		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-reporting.Output_Format Format]</td>
		  <td class=form-widget>
			[im_report_output_format_select output_format "" $output_format]
		  </td>
		</tr>
		<tr>
		  <td class=form-label><nobr>[lang::message::lookup "" intranet-reporting.Number_Format "Number Format"]</nobr></td>
		  <td class=form-widget>
			[im_report_number_locale_select number_locale $number_locale]
		  </td>
		</tr>
		<tr>
		  <td</td>
		  <td><input type=submit value='Submit'></td>
		</tr>
		</table>
		</form>
	  </td>
	  <td align=center>
		<table cellspacing=2 width='90%'>
		<tr>
		  <td>$help_text</td>
		</tr>
		</table>
	  </td>
	</tr>
	</table>
	
	<!-- Here starts the main report table -->
	<table border=0 cellspacing=1 cellpadding=1>
    "
    }
}

set footer_array_list [list]
set last_value_list [list]

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"

set counter 0
set class ""
db_foreach sql $report_sql {
	set class $rowclass([expr $counter % 2])

	set raw_units_pretty [im_report_format_number $raw_units $output_format $number_locale]
	set billable_units_pretty [im_report_format_number $billable_units $output_format $number_locale]

    ns_log Notice "number_locale=$number_locale"

	if {[string is double $savings_percent]} {
	    set savings_percent_pretty [im_report_format_number $savings_percent $output_format $number_locale]
	} else {
	    set savings_percent_pretty $savings_percent
	}

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

	im_report_update_counters -counters $counters

	set last_value_list [im_report_render_header \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	set footer_array_list [im_report_render_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	incr counter
}

im_report_display_footer \
    -output_format $output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -output_format $output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class \
    -upvar_level 1


# Write out the HTMl to close the main report table
#
switch $output_format {
    html {
	ns_write "</table>\n"
	ns_write "<br>&nbsp;<br>"
	ns_write [im_footer]
    }
}

