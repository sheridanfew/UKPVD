# UKPVD
Data on PV deployment and other relevant quantities at an LSOA level. R scripts to generate and process this data.

Readme
######

This directory contains a set of R scripts and associated data to generate from raw data: (1) the UKPVD database, (2) future scenarios at an LSOA level based on National Grid FES, and (3) future scenarios at an LSOA level based upon National Grid FES and UKPN and NPG DFES. Comments in R scripts indicate the sources of this data.

Files intended to be run in this order (names mostly self explanatory)

- Generate_UKPVD.R
- Add_substations_to_UKPVD.R
- Generate_NG_scenarios.R
- Add_DFES_scenarios.R

(Note: 'root_path' variable will need updating in each sheet to reflect the path these files are kept in on your local directory)

Each of these scripts generates data used by subsequent scripts. These are broken down into stages as far as possible.

All raw data is in "Input Data". This data can be updated as new information becomes available (input data files, sheets, and cells referred to in the above scripts will likely need to be updated accordingly). Data produced by these scripts in "Intermediate Data" and "Output Data" folders depending on whether it is used by subsequent scripts.

Convention
##########

These scripts mainly use to the following naming/processing convention (consistency could be improved, however):

Databases: Source_Datatype_Resolution_Format (Ofgem_FiT_PV_LSOA_df)

Variables: Variable_Sector_Aggregation_Unit (eg. PV_dom_med_kW)

Processing: (1) Import/merge data, (2) Rename columns, (3) Subset data, (4) Process data
