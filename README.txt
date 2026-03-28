Files used for this build:
- raw_data/employee-benefits-in-the-united-states-dataset.xlsx
- build_ebs_year_type_wide.do
- output/ebs_psl_access_year_type_wide.dta

How the output is structured:
- One row per year x type.
- type takes three values: private, public, and all.
- Industry variables use two naming rules:
  - true standard two-digit NAICS sectors are named naics_XX
  - all other published EBS industry groupings are named Z_YYYYYY

How type is defined:
- private = Private industry workers
- public = State and local government workers
- all = Civilian workers

How the all rows are built:
- If Civilian workers publishes a value for a year-industry cell, that value is used.
- If Civilian workers does not publish that cell, the script fills from the same-year private value.
- If the same-year private value is also missing, the script fills from the same-year public value.
- If all three are missing for a year-industry cell, the script carries forward the most recent earlier all-value for that same industry series.