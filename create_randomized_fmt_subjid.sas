/*
PROGRAM: create_randomized_fmt_subjid.sas
PURPOSE: Create format for random reassignment of SUBJID.
DATE CREATED: 2022 10 13
DATE MODIFIED: 2022 10 13
AUTHOR: Alex Safronov
BACKGROUND: The assumptions are:
		There is only one study ID, therefore USUBJID must be excluded from the output dataset.
		SUBJID is used to identify the subjects, not USUBJID.
		SUBJID has the format '/^\d+-\d+\s*$/', that is a series of digits at the start
			followed by a dash followed by a series of digits at the end.
		SUBJID is not longer than 50 characters.
		The first part before '-' is the center ID. The second part is the subject ID *within the center*.
		All datasets from the WORK library will be deleted at the end of this program.
		The result of the program is a format.
		Validation is not a goal of this macro. Validation must be done separately.

INPUTS: global macro variables &input_dataset and &fmt_output_library must be specified.
*/

* Now checking the expected format of subjid, if not then stop data step and ;
%macro create_randomized_fmt_subjid;
	%global ERR;
	%let ERR=0;
	data subj_0; set &input_dataset.; keep usubjid subjid  ctr_id_n subj_id_n ;
		if not prxmatch('/^\d+-\d+\s*$/', subjid) and length(subjid) gt 50  then do;
			put "ER" "ROR: " subjid " does not match the expected format.";
			call symput('ERR', '1');
			stop;
	   	end;
		ctr_id_n  = input(scan(subjid, 1, '-'), best.);
		subj_id_n = input(scan(subjid, 2, '-'), best.);
	run;
	%if (&ERR eq 1) %then %goto finish;

	%let seed=0;
	proc sql;
		create table ctr_id_n as select distinct ctr_id_n from subj_0;
		create table ctr_id_n_reordered as select ctr_id_n, ranuni(&seed.) as rnd from ctr_id_n order by rnd;
	quit;
	
	data ctr_id_n_keys; set ctr_id_n_reordered; new_ctr_id_c = translate(put(_n_, 4.0), '0',' '); run;
	proc sql;
		create table both_id_n as select distinct subjid, ctr_id_n, subj_id_n from subj_0;
		create table both_id_n_reordered as select subjid, ctr_id_n, subj_id_n, ranuni(&seed.) as rnd from both_id_n order by rnd;
	quit;
	data subj_id_keys; set both_id_n_reordered; new_subj_id_c = translate(put(_n_, 5.0), '0',' '); run;
	proc sql;
		create table both_keys(keep=subjid new_full_subj_id_c)
			as select 
			subj_id_keys.*
			,ctr_id_n_keys.new_ctr_id_c
			,catx('-', new_ctr_id_c, new_subj_id_c) as new_full_subj_id_c
			from subj_id_keys full join ctr_id_n_keys on subj_id_keys.ctr_id_n = ctr_id_n_keys.ctr_id_n
			order by subjid;
	quit;
	
	data fmtinput; set both_keys; START = subjid; LABEL = new_full_subj_id_c; FMTNAME = "$SUBJID"; keep START LABEL FMTNAME; run;
	
	PROC FORMAT CNTLIN= fmtinput LIBRARY=&fmt_output_library.; run;
	
	* Next: checking the created format: ;
	PROC FORMAT FMTLIB LIBRARY=&fmt_output_library.; select $SUBJID; run;
	
	%finish :
	%if (&ERR eq 1) %then %put %str(ER)ROR: macro ended prematurely;
	proc datasets lib=work kill; run; quit;
	
%mend;

%create_randomized_fmt_subjid;


