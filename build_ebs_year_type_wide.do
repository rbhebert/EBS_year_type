clear all
set more off

* ------------------------------------------------------------------------------
* Build a year-by-type EBS paid sick leave access dataset
* By Sam Sturm @ Johns Hopkins University
*
* Important notes:
* 1. The public EBS data are national by year, industry, and ownership group.
* 2. We keep three ownership-based types:
*      private = Private industry workers
*      public  = State and local government workers
*      all     = Civilian workers
* 3. For type = all, the raw Civilian workers value is always preferred when it
*    exists. If the Civilian workers category does not publish an industry code,
*    we fill that all-value from private/public as needed. There are no 
*    instances in the raw data where private AND public categories are defined
*    and civilian is not. 
* 4. Variables representing true standard two-digit NAICS sectors are named 
*    naics_XX. All other published groupings are named Z_YYYYYY, where YYYYYY 
*    is the original six-character source code.
*
* Output:
*   1. ebs_psl_access_year_type_wide.dta
*      One row per year x type, with one variable per published EBS industry
*      code using the naming rules above.
*
* This do-file does not create a codebook. The codebook for this output is kept
* as a separate text file outside the script.
*
* Run this do-file from inside the EBS folder.
* ------------------------------------------------------------------------------

* Define the raw input and output files.
local raw_file "raw_data/employee-benefits-in-the-united-states-dataset.xlsx"
local out_file "output/ebs_psl_access_year_type_wide.dta"

* Import the EBS workbook.
import excel "`raw_file'", sheet("2010-2025") clear allstring

* Rename the generic Excel columns to simple names.
rename (A B C D E F G H I J K L M N O P Q R S T U V W X) ///
    (survey estimate_category datatype provision ownership industry occupation ///
    characteristic_category characteristic year estimate estimate_footnote ///
    standard_error standard_error_footnote series_title series_id survey_code ///
    ownership_code estimate_code industry_code occupation_code subcell_code ///
    datatype_code provision_code)

* Drop the first row, which contains the original Excel headers.
drop in 1

* Keep only the rows that measure access to paid sick leave for the ownership
* groups we want to carry into the final file.
keep if provision == "Access to paid sick leave"
keep if datatype == "Access rate"
keep if occupation == "All occupations"
keep if characteristic_category == "All workers"
keep if characteristic == "All workers"
keep if inlist(ownership, ///
    "Private industry workers", ///
    "State and local government workers", ///
    "Civilian workers")

* Keep only the variables needed to build the final dataset.
keep year ownership industry industry_code estimate

* Remove empty rows and estimates that are not reported.
replace estimate = trim(estimate)
drop if missing(year) | missing(industry_code)
drop if inlist(estimate, "", "-")

* Rename ownership groups
gen type = ""
replace type = "private" if ownership == "Private industry workers"
replace type = "public"  if ownership == "State and local government workers"
replace type = "all"     if ownership == "Civilian workers"
drop ownership

* Keep the original source code.
rename industry_code source_industry_code

* Build a var with the first two characters of the source code.
gen naics2 = substr(source_industry_code, 1, 2)

* Create the final variable suffix for each industry grouping.
gen output_suffix = "Z_" + source_industry_code

* Replace var name with naics_XX only for standard two-digit sectors.
replace output_suffix = "naics_" + naics2 if ///
    regexm(source_industry_code, "^[0-9]{6}$") & ///
    substr(source_industry_code, 3, 4) == "0000" & ///
    regexm(naics2, "^(11|21|22|23|31|32|33|42|44|45|48|49|51|52|53|54|55|56|61|62|71|72|81)$")

* Convert year and estimate to numeric values.
destring year estimate, replace

* Convert percent values into fractions.
replace estimate = estimate / 100

* There should be one row per year x type x published source code.
duplicates drop year type output_suffix, force

* Reshape to year x output_suffix so private, public, and all values are side
* by side for each published industry grouping.
rename estimate psl_access
keep year type output_suffix psl_access
reshape wide psl_access, i(year output_suffix) j(type) string

* Build the final all-value:
*   1. use the Civilian workers value when it exists
*   2. otherwise fill from private
*   3. otherwise fill from public
*   4. if all three are missing, carry forward the most recent earlier all-value
*      for that same published industry series so the all rows are complete
gen psl_accessall_final = psl_accessall
replace psl_accessall_final = psl_accessprivate if missing(psl_accessall_final)
replace psl_accessall_final = psl_accesspublic  if missing(psl_accessall_final)
bysort output_suffix (year): replace psl_accessall_final = psl_accessall_final[_n-1] if missing(psl_accessall_final)
drop psl_accessall
rename psl_accessall_final psl_accessall

* Return to long format with the three final types.
reshape long psl_access, i(year output_suffix) j(type) string
sort year type output_suffix

* Reshape again so each published industry code becomes its own variable.
reshape wide psl_access, i(year type) j(output_suffix) string

* Remove the temporary stub from the reshaped variable names.
ds psl_access*
foreach var of varlist `r(varlist)' {
    local new_name = subinstr("`var'", "psl_access", "", 1)
    rename `var' `new_name'
}

* At this stage we have one row per year x type and one variable per industry.
* For type = all only, carry the last observed value forward within each series
* if a year-level hole remains after the same-year civilian/private/public fill.
ds year type, not
local industry_vars `r(varlist)'
sort type year
foreach var of local industry_vars {
    by type (year): replace `var' = `var'[_n-1] if type == "all" & missing(`var')
}


sort year type
label variable year "Reference year"
label variable type "Ownership-based EBS type"


* Save the final year-by-type wide dataset.
save "`out_file'", replace
















