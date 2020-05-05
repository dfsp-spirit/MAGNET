
######################################################################################
# 11) Split into chunks of 5000 and Find the minor allele frequency of the SNPS	     #
######################################################################################

LocSource=$(pwd)

source /$LocSource/ConfigFiles/Tools.config
source /$LocSource/ConfigFiles/Thresholds.config

check_tool "PLINK" $PLINK


data_files_name="Subset_EUAIMS"
bim_file="$data_files_name.bim"
bed_file="$data_files_name.bed"


if [ ! -f AllSNPs.txt ]; then

		if [ ! -f "$bim_file" ]; then
			echo "Missing input bim file '$bim_file'. Exiting."
			exit 1
		else
			echo "Creating 'AllSNPs.txt' file from bim file '$bim_file'."
			awk '{print $2}' $bim_file > AllSNPs.txt
		fi

else
	echo "Using existing 'AllSNPs.txt' file. Delete it and re-run to avoid that."
fi

if [ ! -f "$bed_file" ]; then
	echo "Missing input bed file '$bed_file'. Exiting."
	exit 1
fi

NSNPs=$(cat AllSNPs.txt | wc -l) #Total number of SNPs
echo "Found '$NSNPs' NSNPs. Using chunk size '$chunkSize'."

DivFiles=$(expr $NSNPs / $chunkSize) #Files after dividing into chunks of 5000

if [[($(expr $NSNPs % $chunkSize) -gt 1)]]; then #If there is a remainder existing after dividing it into chunks of 5000
	NFiles=$(expr $DivFiles + 1) #If exists then add 1 to the number of main files
	echo "Remainder, NFiles is now '$NFiles' (DivFiles='$DivFiles')."
else
	Nfiles=$DivFiles #Else let the number as it is
	echo "No remainder, NFiles is now '$NFiles' (DivFiles='$DivFiles')."
fi


digi=${#NFiles}
x=$NFiles

echo "DEBUG: digi='$digi', x='$x'"

split -a $digi -l 5000 -d --additional-suffix=.txt AllSNPs.txt splitFiles



chmod 775 splitFiles*.txt

Files=($(ls splitFiles*.txt))

for (( i=0; i<=$x; i++ ))
do
	echo ${Files[i]}
	if [[ -e ${Files[i]} ]]; then
		$PLINK --bfile Subset_EUAIMS --extract ${Files[i]} --make-bed --out tmp"$i"
	fi
	wait
done

for (( i=0; i<=$x; i++ ))
do
	if [[ -e tmp"$i".bim ]]
	then
		echo ${Files[i]}
		$PLINK --bfile tmp"$i" --recodeA --out Data_SNPfile"$i"
		rm tmp"$i"
	fi
done


echo -e "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- \n"

echo -e "----------------------------------------------------------------Stage 2 Imputation completed successfully-------------------------------------------------------------------------- \n"
