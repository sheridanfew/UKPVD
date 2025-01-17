# Script to add substation number and GMT proportion, based on dom meter density, calibrated WPD data
# Sheridan Few, Oct 2020
# See also readme file

### PACKAGES

library(data.table) # For fread to import subset of data (saving memory) - not currently implememnted
library(plyr) # For renaming data frame columns
library(stringr)
library(readxl)


### PATH DEFINITION

root_path <- '/Users/Shez/Library/CloudStorage/GoogleDrive-sheridan.few@gmail.com/My\ Drive/Grantham/JUICE/UKPVD/'
input_path <- paste(root_path,'Input_data/',sep='')
intermediate_path <- paste(root_path,'Intermediate_data/',sep='') # This is where UKLCTD is kept
output_path <- paste(root_path,'Output_data/',sep='')

### INPUT DATA

# UKLCTD containing recent LSOA-level data on spatial area, population, rurality, meter data, and PV deployment. Generated from raw data sources using 'Generate_UKLCTD.R'
UKLCTD_input <- 'UKLCTD_Oct2020.csv'

# WPD data on number and type of substations per LSOA. This is an outome derived from WPD GIS data by Paul Westacott as part of previous project - PV2025 – Potential Costs and Benefits of Photovoltaic for UK Infrastructure and Society’ funded by the RCUK's Energy Programme (Contract no: EP/ K02227X/1).
WPD_substations_input <- "WPD/WPD_Substations.csv" 

### OUTPUT DATA
UKLCTD_w_substations_output <- 'UKLCTD_w_substations_Oct2020.csv'


# Places for plots:
Meter_Density_Meters_Per_Substation_Plot_path <- 'Plots/Substations/Meter_Density_Meters_Per_Substation.png'
Meter_Density_GMT_Substation_Proportion_Plot_path <- 'Plots/Substations/Meter_Density_GMT_Substation_Proportion.png'

### DO STUFF

### 1. IMPORT UKLCTD & WPD data
#############################################################################################################

# Import data
UKLCTD_df<-read.csv(paste(intermediate_path,UKLCTD_input, sep=''), header=TRUE)

WPD_substations_df<-read.csv(paste(input_path,WPD_substations_input, sep=''), header=TRUE)


### 2. MAKE FUNCTION FOR (1) SUBSTATIONS PER METER, (2) PROPORTION OF GMT SUBSTATIONS AS FUNCTION OF METER DENSITY
#############################################################################################################

# Calculate meter density (comes in handy later)
UKLCTD_df$Meter_Density  <-  (UKLCTD_df$Meters_domestic + UKLCTD_df$Meters_nondom)/UKLCTD_df$Area_km2

# Generate combined df containing relevant variables
SW_LSOA_df <- merge(UKLCTD_df,WPD_substations_df,by="LSOA")

# Derive additional variables
SW_LSOA_df$N_Substations <- SW_LSOA_df$NSubstations_11kV_PMT + SW_LSOA_df$NSubstations_11kV_GMT
SW_LSOA_df$Meters_Per_Substation <- (SW_LSOA_df$Meters_domestic + SW_LSOA_df$Meters_nondom)/ SW_LSOA_df$N_Substations 
SW_LSOA_df$Substation_Dens <- SW_LSOA_df$N_Substations/SW_LSOA_df$Area_km2
SW_LSOA_df$GMT_Substation_Proportion <- SW_LSOA_df$NSubstations_11kV_GMT/SW_LSOA_df$N_Substations

# Cluster of values at 1 caused trouble for lowess fit -> exclude for purposes of best fit lines 
SW_LSOA_subset_df <- SW_LSOA_df[ which(! is.na(SW_LSOA_df$GMT_Substation_Proportion )),]
#SW_LSOA_subset_df <- SW_LSOA_df[ which(! is.na(SW_LSOA_df$GMT_Substation_Proportion < 0.999),]

# Generate best fit lines
Meter_Density_Meters_Per_Substation_fitline<-lowess(SW_LSOA_subset_df$Meter_Density, SW_LSOA_subset_df$Meters_Per_Substation)
Meter_Density_GMT_Substation_Proportion_fitline<-lowess(SW_LSOA_subset_df$Meter_Density, SW_LSOA_subset_df$GMT_Substation_Proportion)


# Plot relationships
png(paste(root_path,Meter_Density_Meters_Per_Substation_Plot_path,sep=''))
	plot(SW_LSOA_df$Meter_Density, SW_LSOA_df$Meters_Per_Substation,xlab = "Meter Density",ylab = "Meters per Substation")
	lines(Meter_Density_Meters_Per_Substation_fitline, col="blue") # lowess line (x,y)
dev.off()

png(paste(root_path,Meter_Density_GMT_Substation_Proportion_Plot_path,sep=''))
	plot(SW_LSOA_df$Meter_Density,SW_LSOA_df$GMT_Substation_Proportion, xlab = "Meter Density",ylab = "GMT Substation Proportion")
	lines(Meter_Density_GMT_Substation_Proportion_fitline, col="blue") # lowess line (x,y)
dev.off()

# Define function to estimate number of meters per substation based on meter density
# Uses lowess fit of meters/subs as function of meter density to estimate meters/subs at other meter densities. Uses fit directly if well within fitted range, uses extreme values otherwise. 
#  For context, the current approach includes meter densities upto the 95th percentile of GB as a whole, and 87th percentile of all LSOAs in the most urban rurality classification (A1).

get_meters_per_subs<-function(Meter_Density)
{
	if(Meter_Density < min(Meter_Density_Meters_Per_Substation_fitline[['x']]))
	{
		meters_per_subs<-min(Meter_Density_Meters_Per_Substation_fitline[['y']])
	}
	# Judged data to be too sparse to justify end of the lowess fit -> keep 98th percentile value for higher meter densities
	else if(Meter_Density > quantile(SW_LSOA_df$Meter_Density,0.98)[[1]])
	{
		meters_per_subs<-approx(Meter_Density_Meters_Per_Substation_fitline,xout=quantile(SW_LSOA_df$Meter_Density,0.98)[[1]])[['y']]
	}
	else {
		meters_per_subs <- approx(Meter_Density_Meters_Per_Substation_fitline,xout=Meter_Density)[['y']]
	}
	return(meters_per_subs)
}

# Define function to estimate GMT substation proportion based on meter density (max 1)

get_proportion_GMT_subs<-function(Meter_Density)
{
	if(Meter_Density < min(Meter_Density_GMT_Substation_Proportion_fitline[['x']]))
	{
		GMT_Substation_Proportion<-min(Meter_Density_GMT_Substation_Proportion_fitline[['y']])
	}
	else if(Meter_Density > max(Meter_Density_GMT_Substation_Proportion_fitline[['x']]))
	{
		# If more dense than dataset, assume all GMT
		GMT_Substation_Proportion <- 1.0
	}
	else {
		# Approximate value from best fit line, max out at 1
		GMT_Substation_Proportion <- min(1.0,approx(Meter_Density_GMT_Substation_Proportion_fitline,xout=Meter_Density)[['y']])
	}
	return(GMT_Substation_Proportion)
}

# Calculate R^2 for meters per substation

SW_LSOA_wo_extremes_df <- SW_LSOA_subset_df[SW_LSOA_subset_df$Meter_Density <quantile(SW_LSOA_df$Meter_Density,0.98)[[1]],]

Mean_Meters_Per_Substation <- mean(SW_LSOA_wo_extremes_df$Meters_Per_Substation)

Meters_Per_Subs_pred <- sapply(SW_LSOA_wo_extremes_df$Meter_Density,get_meters_per_subs)

R_sq_meter_dens <- 1 - (
				   		sum((SW_LSOA_wo_extremes_df$Meters_Per_Substation - Meters_Per_Subs_pred)^2) /
				   		sum((SW_LSOA_wo_extremes_df$Meters_Per_Substation - Mean_Meters_Per_Substation)^2)
				   		)

R_sq_meter_dens

# Calculate R^2 for GMT proportion

SW_LSOA_wo_NAN_df <- SW_LSOA_subset_df[SW_LSOA_subset_df$GMT_Substation_Proportion != 'NAN',]

Mean_GMT_Substation_Proportion <- mean(SW_LSOA_wo_NAN_df$GMT_Substation_Proportion)

GMT_Substation_Proportion_pred <- sapply(SW_LSOA_wo_NAN_df$Meter_Density,get_proportion_GMT_subs)

R_sq_GMT_Substation_Proportion <- 1 - (
									  sum((SW_LSOA_wo_NAN_df$GMT_Substation_Proportion - GMT_Substation_Proportion_pred)^2) /
				   					  sum((SW_LSOA_wo_NAN_df$GMT_Substation_Proportion - Mean_GMT_Substation_Proportion)^2)
				   					  )

R_sq_GMT_Substation_Proportion


### 3. ESTIMATE NUMBER OF SUBSTATIONS & GMT PROPORTION FOR EVERY LSOA IN GB, MERGE WITH ACTUAL VALUES FOR SW ENGLAND
####################################################################################################################

# Generate estimated values per LSOA

UKLCTD_df$N_Substations <- (UKLCTD_df$Meters_domestic + UKLCTD_df$Meters_nondom)/sapply(UKLCTD_df$Meter_Density,get_meters_per_subs)
UKLCTD_df$GMT_Substation_Proportion <- sapply(UKLCTD_df$Meter_Density,get_proportion_GMT_subs)

# Add WPD data
SW_LSOA_merger_df<-SW_LSOA_df
colnames(SW_LSOA_merger_df) <- c('LSOA',paste("WPD", colnames(SW_LSOA_df)[-1], sep = "_"))
UKLCTD_w_WPD_df <- merge(UKLCTD_df,SW_LSOA_merger_df,by='LSOA',all=TRUE)

# Replace generated substation values w. actual WPD data for region where this data is available 
WPD_indices <- which(! is.na(UKLCTD_w_WPD_df$WPD_N_Substations), arr.ind=TRUE)
UKLCTD_w_WPD_df[WPD_indices,][['N_Substations']]<-UKLCTD_w_WPD_df[WPD_indices,][['WPD_N_Substations']]
UKLCTD_w_WPD_df[WPD_indices,][['GMT_Substation_Proportion']]<-UKLCTD_w_WPD_df[WPD_indices,][['WPD_GMT_Substation_Proportion']]

# Feed back into main df
UKLCTD_df$N_Substations <- UKLCTD_w_WPD_df$N_Substations
UKLCTD_df$GMT_Substation_Proportion <- UKLCTD_w_WPD_df$GMT_Substation_Proportion
UKLCTD_df<-subset(UKLCTD_df, select = -c(Meter_Density))

### 4. EXPORT
####################################################################################################################

write.table(UKLCTD_df, paste(intermediate_path,UKLCTD_w_substations_output, sep=''), sep=",", row.names=FALSE)

