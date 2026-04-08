# EBS Year-Type Paid Sick Leave Data

This repository is a small replication package for building a national year-by-type dataset of paid sick leave access from the BLS Employee Benefits Survey (EBS). It contains the raw EBS workbook, one standalone Stata `.do` file, a ready-to-use `.dta` output, and a plain-text variable codebook.

This version includes code to add census region and census division all-industry variables to the dataset.

## What This Repository Contains

- `raw_data/employee-benefits-in-the-united-states-dataset.xlsx`
  - The raw BLS EBS workbook used for the build.
- `build_ebs_year_type_wide.do`
  - A standalone Stata script that recreates the output dataset from the raw workbook.
- `build_ebs_year_type_wide_wCensusDiv.do`
  - A Stata script that creates a version of the output dataset with all industry estimates for census regions and divisions.
- `output/ebs_psl_access_year_type_wide.dta`
  - The final year-by-type dataset.
- `ebs_psl_access_year_type_wide_codebook.txt`
  - A text codebook for the industry variables in the output dataset.

## Main Output

The main output file is `output/ebs_psl_access_year_type_wide.dta`.

Its structure is:

- One row per `year x type`
- `type` takes three values:
  - `private`
  - `public`
  - `all`

Industry variables follow two naming rules:

- True standard two-digit NAICS sectors are named `naics_XX`
- All other published EBS industry groupings are named `Z_YYYYYY`

Census Regions are included in variables `Z_0000004` `Z_0000007` `Z_0000009` `Z_00000011`

Census Divisions are included in variables `Z_0000001` `Z_0000002` `Z_0000003` `Z_0000005` `Z_0000006` `Z_0000008` `Z_00000010` `Z_00000012` `Z_00000013`

See US Census Bureau definitions [here](https://www2.census.gov/geo/pdfs/maps-data/maps/reference/us_regdiv.pdf).

## Type Definitions

- `private` = `Private industry workers`
- `public` = `State and local government workers`
- `all` = `Civilian workers`

## How The `all` Rows Are Built

- If `Civilian workers` publishes a value for a given year-industry cell, that value is used.
- If `Civilian workers` does not publish that cell, the script fills from the same-year `private` value.
- If the same-year `private` value is also missing, the script fills from the same-year `public` value.
- If all three are missing for a given year-industry cell, the script carries forward the most recent earlier `all` value for that same industry series.
