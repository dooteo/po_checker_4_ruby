#!/usr/bin/awk -f
#
#   Copyright (c) 2020 Iñaki Larrañaga Murgoitio <dooteo@zundan.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */


# ---- ---- VERSIONS ---- ----
# 0.0.5: Fixed bugs: fuzzy detection; 
#              in error cases msgstr doubles first line when 'msgid ""' line is;
#              '(' and ')' chars not belong to msg var.
# 0.0.4: Added Copyright line
# 0.0.3: Counts untranslated messages and added print to output logfile option.
# 0.0.2: Fixed total messages count bug.
# 0.0.1: Initial version :P
#
# ---- ---- USAGE ---- ----
#
#  ${MY_BASENAME} helps to check whether Ruby PO files variables from msgid are
#  in msgstr too.
#  Note: this script does not convert PO file into MO.
#
#  Usage:
#    CUR_SCRIPT INPUT_RUBY_POFILE
#    or
#    CUR_SCRIPT INPUT_RUBY_POFILE OUTPUT_LOGFILE
#
#  If INPUT_RUBY_POFILE filename and OUTPUT_LOGFILE filename are the same,
#  output will be written into filename with .log extension.
#


# ---- ---- FUNCTIONS ---- ----

function print_log(logfile, log_msg) {
	if ( logfile == "" ) {
		print log_msg;
	} else {
		print log_msg >> logfile;
	}
}


# Input params: error_msgs, msg_id, msgid_array, msgstr_array, in_line;
# Output params: none
function print_error_content(logfile, error_msgs, msg_id, msgid_array, msgstr_array, in_line) {

	print_log(logfile, "\n>>>> Error at message ID: " msg_id "     [line: " in_line "]  <<<<");

	for (i = 1; i in error_msgs; ++i) {
		print_log(logfile, ">>>> "error_msgs[i]);
	}

	print_log(logfile, ">>>> ---- ---- Message: ---- ---- <<<<");
	for (i=1; i in msgid_array; ++i) {
		print_log(logfile, msgid_array[i]);
	}
	for (i=1; i in msgstr_array; ++i) {
		print_log(logfile, msgstr_array[i]);
	}

	print_log(logfile, ">>>> ---- ---- ---- ---- <<<<");
}

function skip_header(logfile) {

	msgid_part=0;
	msgstr_part=0;

	print_log(logfile, ".... Ignoring PO header....");

	while (msgid_part < 1) {
		getline;
		if ( $1 == "msgid" ) {
			msgid_part+=1;
		}
	}

	while (msgstr_part < 1) {
		getline;

		# An empty line means header is finished.
		if (NF == 0) {
			msgstr_part+=1;
		}
	}

	return 1;
}

function ignore_empty_lines() {

	while (1) {
		if (NF != 0) {
			break;
		}

		if (getline == 0) {
			break;
		}

	}
}

function is_fuzzy() {
	is_comment=1;
	cur_fuzzy_msg=0;

	ignore_empty_lines();

	# Cur line is a first non empty line..
	# Check it out

	if (/#, *fuzzy/) {
		return 1;
	}

	while (is_comment == 1) {
		if (getline == 0) {
			break;
		}

		if (substr($1, 1, 1) != "#") {
			break;
		}

		if (/#, *fuzzy/) {
			cur_fuzzy_msg=1;
		}
	}

	# ---- Ignore rest of fuzzy msg lines ----

	return cur_fuzzy_msg;
}

# Input params: cur_vars_str
# Output params: cleaned_arr_vars
function insert_vars_into_array(cleaned_arr_vars, cur_vars_str) {
	var_pos = 0;
	var_item="";

	# ---- Clean array ----
	delete cleaned_arr_vars;

	# ---- cur_vars_str can have a %% symbol as well ----
	# ---- gonna remove that %%, \n, \t symbols when they exists...
	cur_vars = gensub(/%%|\\n|\\t/, "", "g", cur_vars_str);


	# ---- gonna remove all chars except:  a-zA-Z0-9%{}_,.  ----
	cur_vars = gensub(/[^a-zA-Z0-9\$%\{\}\(\)\-_,\.]+/, "", "g", cur_vars);
	cur_vars_count = split(cur_vars, cleaned_arr_vars, "%");

	# ---- as first char is always %, first left part does not exist, is empty----
	# ---- reorganize array: shift all to one item less ----

	for (j=2; j <= cur_vars_count; ++j) {

		# ---- NOTE: Ruby uses placeholders like %{sevty}, ----
		# ----       but it could be %{sevty}bugs where _bugs_ is not part of var name...
		# ----       gonna remove all {} outside part ----
		if (substr(cleaned_arr_vars[j], 1, 1) == "{") {
			var_pos = index(cleaned_arr_vars[j], "}");
			var_item = substr(cleaned_arr_vars[j], 1, var_pos);
		} else {
			var_item = cleaned_arr_vars[j];
		}
		# ---- Remove placeholders like 3$ from '%3$s'
		var_item = gensub(/[0-9]*\$/, "", "1", var_item);
		# ---- Remove chars not part of vars )* til end, 
		# ----   Ie: %s(whatever %s)whatever %s.whatever %s-whatever
		var_item = gensub(/\..*$|[\(\)\-_].*$/, "", "1", var_item);
		cleaned_arr_vars[j-1] = gensub(/}.*/, "}", "1", var_item);

	}

	delete cleaned_arr_vars[cur_vars_count];
}



# Input params: vars_arr_msgid, vars_arr_msgstr
# Output params: error_msg, error_last_idx

function verify_vars_in_msgstr(error_msg, error_last_idx,
							vars_arr_msgid, total_vars_msgid,
							ars_arr_msgstr, total_vars_msgstr) {


	if (total_vars_msgid != total_vars_msgstr) {
		error_msg[++error_last_idx] = "Error: different vars numbers. Msgid has: " total_vars_msgid " != Msgstr has " total_vars_msgstr;
		return 1;
	}

	for (i = 1; i <= total_vars_msgid; ++i ) {
		is_found = 0;

		for (j = 1; j <= total_vars_msgstr; ++j) {
			if (vars_arr_msgid[i] == vars_arr_msgstr[j]) {
				is_found = 1;
				break;
			}
		}

		if (is_found == 0) {
			error_msg[++error_last_idx] = "Error: var \"%" vars_arr_msgid[i] "\" not found in msgstr";
		}
	}

	return error_last_idx;
}

# Input params: none
# Output params: vars_in_msgid, cur_msgid
function get_cur_msgid_vars(vars_arr_msgid, cur_msgid) {
	has_content=1;
	var_pos=0;
	cur_arr_vars[1]="";


	if (NF == 0) {
		return -1;
	}

	delete vars_arr_msgid;
	total_vars_msgid = 0;

	delete cur_msgid;
	cur_msgid_rows=1;

	while (has_content == 1) {
		if ( ($1 != "msgid")  && (substr($1, 1, 1) != "\"")) {
			has_content=0;
			break;
		}

		# Empty content at msgid line
		if ($2 == "\"\"") {
			cur_msgid[cur_msgid_rows]=$0;
			cur_msgid_rows+=1;
			getline;
		}

		cur_msgid[cur_msgid_rows]=$0;
		cur_msgid_rows+=1;

		for ( i = 1; i <= NF; ++i ) {

			# ---- Check whether it contains a var such as %s or %{sevty} ----
			var_pos = index($i, "%");

			if ( var_pos == 0 ) {
				continue;
			}

			# ---- Right here, $i contain what it seems as a Var, ----
			insert_vars_into_array(cur_arr_vars, $i);

			for (j=1; j in cur_arr_vars; ++j) {
				total_vars_msgid += 1;
				vars_arr_msgid[total_vars_msgid] = cur_arr_vars[j];
			}

		}

		if (getline == 0) {
			break;
		}
	}


	# ---- Right here, a msgid_plural or msgstr line should be found----

	# ---- skip msgid_plural as it must contain same vars as in msgid ----
	if ($1 == "msgid_plural") {
		has_content = 1;
		while (has_content == 1) {
			if ( ($1 != "msgid_plural") && (substr($1, 1, 1) != "\"") ) {
				has_content=0;
				break;
			}

			cur_msgid[cur_msgid_rows]=$0;
			cur_msgid_rows+=1;

			if (getline == 0) {
				break;
			}
		}

	}

	# ---- At this point, a msgstr line should be fetched....

	return total_vars_msgid;
}



# Input params: vars_arr_msgid, total_vars_msgid, cur_msgid_msg
# Output params: none
# Return values:
#      -1 : message not translated
#      0 : message translated with no errors
#      > 0 : message translated with errors
function get_cur_msgstr_vars(vars_arr_msgstr, vars_arr_msgid, total_vars_msgid, cur_msgid_msg) {

	has_content = 1;
	var_pos = 0;
	cur_arr_vars[1] = "";
	cur_msgstr_msg[1] = "";
	cur_msgstr_total_lines = 0;
	error_in_vars_cheking = 0;
	error_report[1] = "";
	error_last_idx = 0;

	if (NF == 0) {
		return -1;
	}

	delete vars_arr_msgstr;
	total_vars_msgstr = 0;

	delete cur_msgstr_msg;
	delete error_report;
	cur_is_translated = 0;

	while (has_content == 1) {
		if ( $0 == "\"\"" ) {
			getline;
			continue;
		}


		if ( (substr($1, 1, 6) != "msgstr") && (substr($1, 1, 1) != "\"")) {
			has_content=0;
			break;
		}

		cur_msgstr_total_lines+=1;
		cur_msgstr_msg[cur_msgstr_total_lines]=$0;


		if ( (substr($1, 1, 7) == "msgstr[") && (substr($1, 8, 1) > 0)  &&
			((total_vars_msgid > 0) || (total_vars_msgstr > 0) ) ) {

			# check previously fetched msgstr vars;
			error_in_vars_cheking += verify_vars_in_msgstr(error_report,
											error_last_idx,
											vars_arr_msgid, total_vars_msgid,
											vars_arr_msgstr, total_vars_msgstr);

			delete vars_arr_msgstr;
			total_vars_msgstr = 0;

		}


		# Empty content at msgstr line
		if ( $2 == "\"\"" ) {
			getline;
			continue;
		}


		for ( i = 1; i <= NF; ++i ) {
			cur_is_translated = 1;

			# ---- Check whether it contains a var such as %s or %{sevty} ----
			var_pos = index($i, "%");

			if ( var_pos == 0 ) {
				continue;
			}

			# ---- Right here, $i contain what it seems as a Var, ----
			insert_vars_into_array(cur_arr_vars, $i);

			for (j=1; j in cur_arr_vars; ++j) {
				total_vars_msgstr += 1;
				vars_arr_msgstr[total_vars_msgstr] = cur_arr_vars[j];
			}

		}

		if (getline == 0) {
			break;
		}
	}

	if (cur_is_translated == 0) {
		return -1;
	}

	error_in_vars_cheking += verify_vars_in_msgstr(error_report, error_last_idx,
												vars_arr_msgid, total_vars_msgid,
												vars_arr_msgstr, total_vars_msgstr);

	if (error_in_vars_cheking > 0) {
		print_error_content(logfile, error_report, cur_msg_id, cur_msgid_msg,
							cur_msgstr_msg, cur_msgid_line_nmbr);
		return 1;
	}

	return 0;
}

BEGIN {
	logfile = "";
	result = 0;
	cur_msg_id = 0;
	cur_msgid_line_nmbr=0;
	cur_msgid_msg[1]="";   # cleaned into get_cur_msgid_vars()
	vars_arr_msgid[1]="";  # cleaned into get_cur_msgid_vars()

	cur_msgstr_line_nmbr=0;
	cur_msgstr_msg[1]="";  # cleaned into get_cur_msgstr_vars()
	vars_arr_msgstr[1]=""; # cleaned into get_cur_msgstr_vars()

	total_untranslated_msgs = 0;
	total_fuzzy_msgs = 0;
	total_error_msgs = 0;

	if (ARGC > 2) {
		if (ARGV[1] == ARGV[2] ) {
			logfile = ARGV[1] ".log";
		} else {
			logfile = ARGV[2];
		}
	}

	print_log(logfile, 	".... Start analyze: " ARGV[1] "");
	skip_header(logfile);
	print_log(logfile, ".... Analyze PO messages ....");
}

{

	if (is_fuzzy()) {
	    # Do not analyze current fuzzy message
		total_fuzzy_msgs += 1;

	} else if ( $1 == "msgid" ) {
		result = 0;
		cur_msg_id += 1;
		cur_msgid_line_nmbr = NR;
		total_vars_msgid = get_cur_msgid_vars(vars_arr_msgid, cur_msgid_msg);

		cur_msgstr_line_nmbr=NR;
		result = get_cur_msgstr_vars(vars_arr_msgstr,
												vars_arr_msgid, total_vars_msgid,
												cur_msgid_msg);
		if (result > 0) {
			total_error_msgs += result;

		} else if (result < 0) {
			total_untranslated_msgs += 1;
		}
	}


}

END {

	print_log(logfile, "\n.... End of analyze. Summary: ....");
	print_log(logfile, ".... Total lines: " NR);
	print_log(logfile, ".... Total messages: " cur_msg_id);
	print_log(logfile, ".... Untranslated messages: " total_untranslated_msgs);
	print_log(logfile, ".... Fuzzy messages: " total_fuzzy_msgs);
	print_log(logfile, ".... Error messages: " total_error_msgs);
}
