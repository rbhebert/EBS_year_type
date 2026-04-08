clear all
set more off

global dir "/Users/reginald.hebert/Downloads/EBS_year_type-main"

cd "$dir"

* Define the raw input and output files.
local raw_file "raw_data/employee-benefits-in-the-united-states-dataset.xlsx"
local out_file "output/ebs_psl_access_year_type_wide_wCensusDiv.dta"

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
keep if characteristic_category == "All workers" | characteristic_category == "Census area"
keep if inlist(ownership, ///
    "Private industry workers", ///
    "State and local government workers", ///
    "Civilian workers")

* Keep only the variables needed to build the final dataset.
keep year ownership industry industry_code estimate characteristic


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
duplicates drop year type output_suffix characteristic, force

* Reshape to year x output_suffix so private, public, and all values are side
* by side for each published industry grouping.
rename estimate psl_access
keep year type output_suffix psl_access characteristic
reshape wide psl_access, i(year output_suffix characteristic) j(type) string

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
reshape long psl_access, i(year output_suffix characteristic) j(type) string
sort year type output_suffix characteristic

* Reshape again so each published industry code becomes its own variable.
reshape wide psl_access, i(year type characteristic) j(output_suffix) string

* Remove the temporary stub from the reshaped variable names.
ds psl_access*
foreach var of varlist `r(varlist)' {
    local new_name = subinstr("`var'", "psl_access", "", 1)
    rename `var' `new_name'
}

* At this stage we have one row per year x type and one variable per industry.
* For type = all only, carry the last observed value forward within each series
* if a year-level hole remains after the same-year civilian/private/public fill.
ds year type characteristic, not
local industry_vars `r(varlist)'
sort characteristic type year 
foreach var of local industry_vars {
    by characteristic (type  year ): replace `var' = `var'[_n-1] if type == "all" & missing(`var') & characteristic == "All workers"
}

tempfile temp_national
save `temp_national', replace

drop if characteristic == "All workers"
encode characteristic, gen(division)
levelsof(characteristic),  local(censusdivisions)
keep year type division Z_000000
reshape wide Z_000000, i(year type) j(division)
forval i=1/13 {
	local censusD : word `i' of `censusdivisions'
	label variable Z_000000`i' "All industries: `censusD'"
}

tempfile temp_regional
save `temp_regional', replace

use `temp_national', clear
keep if characteristic == "All workers"
drop characteristic
merge 1:1 year type using `temp_regional'
drop _merge


sort year type
label variable year "Reference year"
label variable type "Ownership-based EBS type"

label variable Z_000000 "All industries"
label variable Z_300000 "Manufacturing"
label variable Z_400000 "Trade, transportation, and utilities"
label variable Z_412000 "Retail trade"
label variable Z_430000 "Transportation and warehousing"
label variable Z_520A00 "Financial activities"
label variable Z_522000 "Credit intermediation"
label variable Z_524000 "Insurance carriers"
label variable Z_540A00 "Professional and business services"
label variable Z_600000 "Education and health services"
label variable Z_611100 "Elementary and secondary schools"
label variable Z_612000 "Junior colleges, colleges, universities, and professional schools"
label variable Z_622000 "Hospitals"
label variable Z_700000 "Leisure and hospitality"
label variable Z_920000 "Public administration"
label variable Z_G00000 "Goods-producing"
label variable Z_S00000 "Service-providing"

label variable naics_22 "Utilities (NAICS 22)"
label variable naics_23 "Construction (NAICS 23)"
label variable naics_42 "Wholesale Trade (NAICS 42)"
label variable naics_51 "Information (NAICS 51)"
label variable naics_52 "Finance and Insurance (NAICS 52)"
label variable naics_53 "Real Estate and Rental and Leasing (NAICS 53)"
label variable naics_54 "Professional and Business Services (NAICS 54)"
label variable naics_56 "Administrative and Support and Waste Management and Remediation Services (NAICS 56)"
label variable naics_61 "Educational Services (NAICS 61)"
label variable naics_62 "Health Care and Social Assistance (NAICS 62)"
label variable naics_72 "Leisure and Hospitality (NAICS 72)"
label variable naics_81 "Other Services (NAICS 81)"


* Save the final year-by-type wide dataset.
save "`out_file'", replace
