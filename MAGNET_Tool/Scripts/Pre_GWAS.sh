
######################################################################################
# 11) Split into chunks of 5000 and Find the minor allele frequency of the SNPS	     #
######################################################################################



awk '{print $2}' Subset_EUAIMS.bim >AllSNPs.txt


NSNPs=($(wc -l AllSNPs.txt)) #Total number of SNPs

DivFiles=$[$NSNPs/$chunkSize] #Files after dividing into chunks of 5000

if [[($(expr $NSNPs % $chunkSize) -gt 1)]]; then #If there is a remainder existing after dividing it into chunks of 5000
	NFiles=$(expr $DivFiles + 1) #If exists then add 1 to the number of main files
	else Nfiles=$DivFiles #Else let the number as it is
fi


digi=${#NFiles}

x=$NFiles
split -a $digi -l 5000 -d --additional-suffix=.txt AllSNPs.txt splitFiles



chmod 775 splitFiles*.txt

Files=($(ls splitFiles*.txt))

for (( i=0; i<=$x; i++ ))
do
echo ${Files[i]}
	if [[ -e ${Files[i]} ]]
	then
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

