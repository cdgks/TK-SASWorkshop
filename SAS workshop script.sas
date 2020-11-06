/*
SAS Workshop script
Dr. Charlie Keown-Stoneman
2020-11-06
*/

*in SAS you can write comments in 2 ways, asterisks will comment out the rest of a line;
/* text between slashes with asterisks (like this comment) will be commented out,
even if they cross line breaks, and even if they have ; in them*/

*lets import the data;

/*
PROC IMPORT OUT= WORK.eg_data 
            DATAFILE= "C:\Users\Charlie\OneDrive - University of Toronto\TK\SASworkshop\eg_data.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;
*/
*The main method for data manipulation in SAS is the "data step";

data eg_data; *this line defines the output dataset;
set eg_data; *this line defines the input dataset;
format zbmi_group $15.;
if missing(zbmi) then zbmi_group = ""; *careful! SAS treats missing like negative infinity for logical tests;
else if zbmi < -2 then zbmi_group = "Underweight"; 
else if zbmi < 1 then zbmi_group = "Normal Weight";
else if zbmi < 2 then zbmi_group = "Overweight";
else zbmi_group = "Obese"; 
run; *"run" at the end tells SAS that you're done the data steps and it will now execute your code;

proc freq data=eg_data;
table zbmi_group;
run;

proc freq data=eg_data;
table zbmi_group*childgender1 /chisq;
run;

*some basic plots (in my experience sgplot has become the SAS plotting work-horse);
proc sgplot data=eg_data;
scatter x=ageinmonths y=zbmi;
*loess x=ageinmonths y=zbmi;
run;


proc sgplot data=eg_data;
vbox zbmi /group=childgender1 ;
run;

*what if we want a dataset with just the first observation per subject?;
*first let's sort the data;
proc sort data=eg_data;
by subject ageinmonths;
run;

*now "sort" by subject, but only keep the first row of subject;
proc sort data=eg_data nodupkey out=baseline_data;
by subject;
run;

*what if we want a dataset with just the last observation per subject?;
*first let's sort the data;
proc sort data=eg_data;
by subject descending ageinmonths;
run;

*now "sort" by subject, but only keep the first row of subject;
proc sort data=eg_data nodupkey out=last_obs_data;
by subject;
run;

*keeping just some variables;
data last_obs_data_zbmi;
set last_obs_data;
keep subject zbmi;
run;

*removing just some variables;
data last_obs_data_alt;
set last_obs_data;
drop instancedate;
run;

*keeping only those underweight (from the last observation);
data last_obs_data_UW;
set last_obs_data;
where zbmi < (-2);
run;



*loading in a dataset just using code;
PROC IMPORT OUT= WORK.eg_data2
            DATAFILE= "C:\Users\Charlie\OneDrive - University of Toronto\TK\SASworkshop\eg_data2.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;

*different ways to merge data together;
data combined_data;
merge eg_data eg_data2;
by subject instanceid;
run;

*oh no! the data isn't properly sorted, you need to do that first!;
proc sort data=eg_data;
by subject instanceid;
run;

proc sort data=eg_data2;
by subject instanceid;
run;

data combined_data;
merge eg_data eg_data2;
by subject instanceid;
run;

*different way to merge data together using update;
data combined_data;
update eg_data eg_data2;
by subject instanceid;
run;

*this site explains the differences pretty well: https://documentation.sas.com/?cdcId=pgmsascdc&cdcVersion=9.4_3.5&docsetId=basess&docsetTarget=n1qgf6rn4q6h39n15n9613l3z1d2.htm&locale=en;
*I find 'update' most useful if I want to merge 1 to 1, and 'merge' most useful if I want to do a many to 1 merge;

*you can also specify if you only want to include observations from one of the datasets;
data combined_data;
merge eg_data(in=a) eg_data2;
by subject instanceid;
if a;
run;

*Creating new categorical variables;

PROC IMPORT OUT= WORK.eg_data3
            DATAFILE= "C:\Users\Charlie\OneDrive - University of Toronto\TK\SASworkshop\eg_data3.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;

data eg_data3;
set eg_data3;
format new_childcare $32.;
if CHILDCARE_ARRANGEMENT = "Care by a relative" OR 
	CHILDCARE_ARRANGEMENT = "Care in child’s home by a non-relative" OR
	CHILDCARE_ARRANGEMENT = "Care in someone’s home by a non-relative" OR
	licensed_provider_yn = "No" then new_childcare = "Unlicensed childcare";
else if CHILDCARE_ARRANGEMENT = "Daycare (centre-based or home-based)" AND
	homebased_daycare_yn = "Yes" AND
	licensed_provider_yn = "Yes" then new_childcare = "Licensed home-based care";
else if CHILDCARE_ARRANGEMENT = "Daycare (centre-based or home-based)" AND
	homebased_daycare_yn = "No" AND
	licensed_provider_yn = "Yes" then new_childcare = "Licensed centre-based childcare";
run;

proc freq data=eg_data3;
table CHILDCARE_ARRANGEMENT*new_childcare;
run;

*We may want to save SAS datafiles to a specific location (not just our current working directory;
libname SAS_WS "C:\Users\Charlie\OneDrive - University of Toronto\TK\SASworkshop\";

data SAS_WS.combined_data;
set combined_data;
run;

*I prefer to use PROC MIXED or GLIMMIX instead of PROC REG for linear regression, they have some features that are lacking in PROC REG;
proc mixed data=combined_data plots=all;
class momethnicity CHILDGENDER1;
model zbmi = ageinmonths momethnicity CHILDGENDER1 cmr_zscr_tot_adj /s;
run;

*restricted cubic splines (based on https://blogs.sas.com/content/iml/2017/04/19/restricted-cubic-splines-sas.html);
proc GLIMMIX  data=combined_data;
class momethnicity CHILDGENDER1;
  effect cmr_spl = spline(cmr_zscr_tot_adj / details naturalcubic basis=tpf(noint)                 
                               knotmethod=PERCENTILELIST(5 27.5 50 72.5 95) );
model zbmi = ageinmonths momethnicity CHILDGENDER1 cmr_spl /s;
run;

*be careful with PROC LOGISTIC! double check what level is the reference from the output;
proc logistic data=combined_data;
class momethnicity CHILDGENDER1;
model CHILDGENDER1 = ageinmonths momethnicity cmr_zscr_tot_adj;
run;

*multiple imputaiton in SAS;

*Creating the multiple imputation datasets (in one file);
proc mi data=combined_data out=mi_test nimpute=20 seed=894321;
class momethnicity CHILDGENDER1 FAMILY_INCOM;
var zbmi ageinmonths momethnicity CHILDGENDER1 cmr_zscr_tot_adj FAMILY_INCOM;
fcs discrim (momethnicity CHILDGENDER1 FAMILY_INCOM/classeffects=include) plots=TRACE;
run;


*Running the model of the multiple imputed datasets;
proc mixed data=mi_test METHOD=TYPE3;
class momethnicity CHILDGENDER1;
model zbmi = ageinmonths momethnicity CHILDGENDER1 cmr_zscr_tot_adj /s;
 by _imputation_;
 ods output SolutionF  = mi_parms_est Type3=type3table;
 run;
*Pooling the results;
 proc mianalyze parms=mi_parms_est;
class momethnicity CHILDGENDER1;
modeleffects intercept ageinmonths momethnicity CHILDGENDER1 cmr_zscr_tot_adj;
title'Imputation - pooling';
ods output ParameterEstimates=mi_output;
run;

*macro I found on the official SAS website by someone from NYU: https://support.sas.com/resources/papers/proceedings14/1543-2014.pdf;
%type3_MI_mixed(type3table);
