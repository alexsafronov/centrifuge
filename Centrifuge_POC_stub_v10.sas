/*
PROGRAM: Centrifuge_POC_stub_v10.sas
AUTHOR:	Alexander Safronov
CREATED ON:	2018-11-03
PURPOSE: This code stub was used to generate datasets that demonstrate a proof of concept of the "ordinal centrifuge" protocol.
TODO: Based on this code stub create a macro to "centrifuge".  Write a macro to de-centrifuge data based on keys.
	Add the request-portion of the protocol.
	Use the centrifuged data to conduct analysis in order to show that the results of the analysis are exactly the same as
	the one of the original dataset.
*/


libname example "C:\data";

options nofmterr;
data names; set sashelp.vcolumn; if libname="EXAMPLE"; run;
%let seed = 109;
data original; set example.Chapter15_example; _ORIG_N_ = _N_; run;
%let libname = WORK;
%let dataset_name = original;

* The following data to be filled out by the data owner;
data user_defined_vars; length var $ 32 type $ 7 role $ 40 newvarnum $ 3 ; 
	var = "PATIENT  "; type = "CAT_NOM" ; role = "PRIMARY_ID" ; newvarnum = "009"; output;
	var = "HAMATOTL "; type = "NUMERIC" ; role = "QUALIFIER"  ; newvarnum = "002"; output;
	var = "PGIIMP   "; type = "NUMERIC" ; role = "QUALIFIER"  ; newvarnum = "003"; output;
	var = "RELDAYS  "; type = "NUMERIC" ; role = "TIMING"     ; newvarnum = "004"; output;
	var = "VISIT    "; type = "NUMERIC" ; role = "TIMING"     ; newvarnum = "005"; output;
	var = "THERAPY  "; type = "CAT_NOM" ; role = "TOPIC"      ; newvarnum = "011"; output;
	var = "GENDER   "; type = "CAT_NOM" ; role = "QUALIFIER"  ; newvarnum = "007"; output;
	var = "POOLINV  "; type = "CAT_NOM" ; role = "IDENTIFIER" ; newvarnum = "008"; output;
	var = "basval   "; type = "NUMERIC" ; role = "QUALIFIER"  ; newvarnum = "001"; output;
	var = "HAMDTL17 "; type = "NUMERIC" ; role = "QUALIFIER"  ; newvarnum = "010"; output;
	var = "change   "; type = "NUMERIC" ; role = "QUALIFIER"  ; newvarnum = "006"; output;
run;
data user_defined_vars; set user_defined_vars; userdef_list_varnum = _n_; run;

* selecting the required vars ;
data vcolumn; set sashelp.vcolumn; if libname = "&libname" and memname = upcase("&dataset_name"); run;
proc sql;
	create table premerged_varlist as select userdef.*, vcolumn.varnum
	from sashelp.vcolumn  as vcolumn full join user_defined_vars as userdef on  vcolumn.name = userdef.var
	where vcolumn.libname = "&libname" and vcolumn.memname = upcase("&dataset_name")
	;
quit;
data _null_; set merged_varlist; if missing(varnum) then put "ER" "ROR: Variable " var "is not in the input dataset"; run;
data merged_varlist; set premerged_varlist; if not missing(var); rand = ranuni(&seed); run;
proc sort data=	merged_varlist; by rand; run;
data merged_varlist; set merged_varlist; random_varnum = _n_; run;


data vars; set user_defined_vars;
	original_varnum = _n_;
	newvarnum = translate(right(put(_n_, 3.0)), '0', ' ');
run;

%let percent_sample = 50;
proc sort data=vars out=vars_srt_by_role; by role; run;


* Now making sure that PRIMARY_ID exists and unique. Also max var count of 999 is checked. : ;
%let PID_IS_FOUND = 0;
data _null_; set vars_srt_by_role end=last; by role;
	if role = "PRIMARY_ID" then call symput('PID_IS_FOUND', "1");
	if not(first.role and last.role) and role = "PRIMARY_ID" then do; put "ER" "ROR: Multiple PRIMARY_IDs are detected."; end; 
	if last and _n_ gt 999 then put "ER" "ROR: Variable count exceeds the assumed limit of 999.";
run;
%put &PID_IS_FOUND;



* Now taking a stratified sample of required size by primary id;

proc sort data=original out=sorted(keep=PATIENT) nodupkey; by PATIENT; run;
data sample_ind; set sorted end=last; rand = ranuni(&seed.); if last then call symput('ORIG_N', put(_n_, best.)); run;
proc sort data=sample_ind ; by rand; run;
%let sampleSize = %eval(&ORIG_N. * &percent_sample. / 100);
%put &ORIG_N.;
%put &sampleSize.;
data sample_ind; set sample_ind; sample_ind = (_n_ le &sampleSize.); drop rand; run;


proc datasets library = work; delete key_: var_: ; run; quit;

* First - recode the variables, then - take a sample ;

%macro recode(newvarnum, type, varname);
	* generate a list of unique values : ;
	proc sort data=original out=deduped(keep=&varname.) nodupkey; by &varname.; run;
	* If the variable is categorical nominal, then sorting is random, otherwise the sorting remains according to the value order : ;
	%if (%upcase(&type) eq CAT_NOM) %then %do;
		* generate a column with random numbers and sort by this random number : ;
		data deduped; set deduped; rand = ranuni(&seed.);  run;
		proc sort data=deduped; by rand; run;
	%end;
	* After sorting, set the recoded value to the ordinal number : ;
	data key_&newvarnum._&varname.; set deduped; var_&newvarnum. = _n_; if missing(&varname.) then var_&newvarnum. = .; %if %upcase(&type) eq CAT_NOM %then drop rand;; run;
	* Populate the recoded column: ;
	proc sql; create table var_&newvarnum. as select _ORIG_N_, var_&newvarnum. from original full join key_&newvarnum._&varname. as key on original.&varname. =  key.&varname. order by _ORIG_N_; quit;
%mend;

%macro toCsv(newvarnum, var);
	proc export data=key_&newvarnum._&var. outfile="C:\data\key_&newvarnum._&var..csv" dbms=csv replace; run;
%mend;
proc datasets library = work; delete key_: var_: ; run; quit;
data _null_; set vars; length text $ 100;
	text1 = cats("%nrquote(%)recode(", newvarnum, ", ", type, ", ", var, ");");
	text2 = cats("%nrquote(%)toCsv(", newvarnum, ", ", var, ");");
	put text1;
	put text2;
	call execute(text1);
	call execute(text2);
run;
data allvars; merge var_:; by _ORIG_N_; run;
proc export data=allvars(drop=_ORIG_N_) outfile="C:\data\recoded_dataset.csv" dbms=csv replace; run;
proc export data=original(drop=_ORIG_N_) outfile="C:\data\original_dataset.csv" dbms=csv replace; run;




