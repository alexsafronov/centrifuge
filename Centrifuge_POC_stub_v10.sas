/*
PROGRAM: Centrifuge_POC_stub_v11.sas
AUTHOR:	Alexander Safronov
CREATED ON:	2018-11-04
PURPOSE: This code stub was used to generate datasets that demonstrate a proof of concept of the "ordinal centrifuge" protocol.
TODO: Based on this code stub create a macro to "centrifuge".  Write a macro to de-centrifuge data based on keys.
	Add the request-portion of the protocol.
	Use the centrifuged data to conduct analysis in order to show that the results of the analysis are exactly the same as
	the one of the original dataset.
*/

libname example "C:\data";
%let seed = 1093;
%let libname =EXAMPLE;
%*let dataset_name=Chapter15_example;
%let dataset_name=transposed;

%let PID_varname='PATIENT';
%let target_var='vis7';

options nofmterr;
proc datasets library = work kill; run; quit;
data original; set &libname..&dataset_name.; _ORIG_N_ = _N_; run;
data __vars; length var $ 32 newvarnum $ 3 ;
	set sashelp.vcolumn;
	if libname = "WORK" and memname="ORIGINAL" and name ne "_ORIG_N_";
	var = name; rand = ranuni(&seed.);
	keep var rand newvarnum type;
run;
proc sort data=__vars; by rand; run;
data __vars; set __vars; newvarnum = translate(right(put(_n_, 3.0)), '0', ' ');
	IF UPCASE(VAR) = upcase(&PID_varname) then call symput('ID_varnum', newvarnum);
	IF UPCASE(VAR) = upcase(&target_var) then call symput('targetnum', newvarnum);
run;
%put ID_varnum = &ID_varnum;
%put ID_varnum = &targetnum;

data request_to_release; length parameter $ 40 value $ 400;
	PARAMETER="RELEASE NAME"   ; VALUE="NAUTILUS"; output; * Suggested name could be unique ANIMAL NAME, CITY NAME, etc.;
	PARAMETER="RELEASE VERSION"; VALUE="v1.0"; output;
	PARAMETER="PROTOCOL NAME"  ; VALUE="CENTERFUGE NOMINAL"; output;
	PARAMETER="PROTOCOL VERSION"; VALUE="v1.0"; output;
	PARAMETER="WORK TYPE"      ; VALUE="PREDICTIVE ANALYTICS"; output;
	PARAMETER="ID VARIABLE"    ; VALUE=cats("var_","&ID_varnum"); output;
	PARAMETER="TARGET VARIABLE"; VALUE=cats("var_","&targetnum"); output;
run;

proc datasets library = work; delete key_: var_: ; run; quit;

* First - recode the variables, then - take a sample ;

%macro recode(newvarnum, type, varname);
	* generate a list of unique values : ;
	proc sort data=original out=deduped(keep=&varname.) nodupkey; by &varname.; run;
	* After sorting, set the recoded value to the ordinal number : ;
	data key_&newvarnum._&varname.; set deduped; var_&newvarnum. = _n_; if missing(&varname.) then var_&newvarnum. = .; %if %upcase(&type) eq CAT_NOM %then drop rand;; run;
	* Populate the recoded column: ;
	proc sql; create table var_&newvarnum. as select _ORIG_N_, var_&newvarnum. from original full join key_&newvarnum._&varname. as key on original.&varname. =  key.&varname. order by _ORIG_N_; quit;
%mend;

%macro toCsv(newvarnum, var);
	proc export data=key_&newvarnum._&var. outfile="C:\data\key_&newvarnum._&var..csv" dbms=csv replace; run;
%mend;
proc datasets library = work; delete key_: var_: ; run; quit;
data _null_; set __vars; length text $ 100;
	text1 = cats("%nrquote(%)recode(", newvarnum, ", ", type, ", ", var, ");");
	text2 = cats("%nrquote(%)toCsv(", newvarnum, ", ", var, ");");
	put text1;
	*put text2;
	call execute(text1);
	call execute(text2);
run;
data data_to_release; merge var_:; by _ORIG_N_; run;


proc export data=original outfile="C:\data\original_data.csv" dbms=csv replace; run;
proc export data=data_to_release outfile="C:\data\data_to_release.csv" dbms=csv replace; run;
proc export data=request_to_release outfile="C:\data\request_to_release.csv" dbms=csv replace; run;
