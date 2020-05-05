#!/bin/bash

LocSource=$(pwd)


source /$LocSource/ConfigFiles/Tools.config
source /$LocSource/ConfigFiles/Thresholds.config

check_tool "PLINK" $PLINK


echo -e "
#######################################
# Stage 1: Quality Control	      #
#######################################
"

#### Read the arguments passed

if [[ ! -e $installationDir ]] #Check if the installation directory is existing
	then
    	mkdir -p $installationDir/OUTPUT_DIR/Stage1_GenoQC #If not create directory
	chmod 770 *
else
    echo -e 	"...In Stage 1 QC:Installation directory already exists, please make sure you are not overwriting any previous results...">> $MAGNET/MAIN_DIR/Warnings.txt

fi
wait


sleep 1

echo '
...checking if Data files exist'


Alleles=(A G C T) #Save alleles in ACGT format
AllelesRec=(1 2 3 4) #Save alleles in 1234 format


if [ -e $SamplesToQC.fam ]
then
	AllelesInData=$(cut -f5 $SamplesToQC.bim | sort | uniq) #Save the alleles format provided in the data
else
	if [ -e $SamplesToQC.ped ]
	then
	AllelesInData=$(cut -d ' ' -f7 $SamplesToQC.ped | sort | uniq)
	fi
fi
read -a arr2 <<< $AllelesInData #Read the alleles in an array



A=${arr2[@]}; # Save the array with alleles in study data in variable B
B=${Alleles[@]}; # Save the array with alleles in ACGT format in variable A
C=${AllelesRec[@]} # Save the array with alleles in 1234 format



if [[ $A == $B || $C ]] ; then #Check if the study alleles are ACGT/1234
    echo -e "...Alleles are correctly coded... \n"
else
    echo -e "...In Stage 1 QC:Alles are not correctly coded the code will exit, please read the manual for allele coding, provide ACGT coding and run the program again...">> $MAGNET/MAIN_DIR/Warnings.txt
exit;
fi;

sleep 1

if [[ $A == $C ]]
then
$PLINK --bfile $SamplesToQC --make-bed --alleleACGT --out $SamplesToQC
fi
wait

if [ -e $SamplesToQC.fam ]
then
    echo ".....$SamplesToQC.fam exists"
    convert="false"
else
    if [ -e $SamplesToQC.ped ]
    then
	echo "..... $SamplesToQC.ped exists"
	convert="true"
    else
	echo ".....In Stage 1 QC:$SamplesToQC.fam or $SamplesToQC.ped  does not exist; program exits">> $MAGNET/MAIN_DIR/Warnings.txt
	exit;
    fi
fi
wait


if [ $convert ==  "true" ]
then
    if [ -e $SamplesToQC.map ]
	then
	$PLINK --file $SamplesToQC --make-bed --out $installationDir/OUTPUT_DIR/Stage1_GenoQC/QC1.1
	else
	echo "In Stage 1 QC:$SamplesToQC.map file does not exist. program exits">> $MAGNET/MAIN_DIR/Warnings.txt
	exit;
    fi
wait

else
    if [ -e $SamplesToQC.bim ]
    then
	echo ".....$SamplesToQC.bim exists"
    else
	echo ".....In Stage 1 QC:$SamplesToQC.bim does not exist; program exits">> $MAGNET/MAIN_DIR/Warnings.txt
	exit;
    fi
wait

    if [ -e $SamplesToQC.bed ]
    then
	echo ".....$SamplesToQC.bed exists"
	cp $SamplesToQC.bed $installationDir/OUTPUT_DIR/Stage1_GenoQC/QC1.1.bed
	cp $SamplesToQC.bim $installationDir/OUTPUT_DIR/Stage1_GenoQC/QC1.1.bim
	cp $SamplesToQC.fam $installationDir/OUTPUT_DIR/Stage1_GenoQC/QC1.1.fam
    else
	echo ".....In Stage 1 QC:$SamplesToQC.bed does not exist; program exits">> $MAGNET/MAIN_DIR/Warnings.txt
	exit;
    fi
fi
wait



if [[ "$A" != "$C" && "$A" != "$B" ]]
then
echo "Please check your $PLINK data coding format, the tool accepts only ACGT/1234 coded alleles"
fi


cd $installationDir/OUTPUT_DIR/Stage1_GenoQC

read ind filename <<< $(wc -l QC1.1.fam)
read snps filename <<< $(wc -l QC1.1.bim)

echo -e	'..............Further calculations will be done in output directory'


echo "
...Your input file has" $ind  "samples and" $snps  "SNPs"

sleep 2





echo -e '
#######################################################################################
# Based on QC thresholds provided in config file QC will be performed of genotype data#
#######################################################################################
'
echo -e '
######################################################
#	Checking missingness, HWE and MAF    	     #
######################################################
'

echo -e	"...If no QC options provided default filtering criteria will be applied: \n callrate>95% \n genotyping-rate>95% \n  MAF>0.02 \n hwe>10e-8 \n"
$PLINK --bfile QC1.1  --make-bed --out QC1.1
$PLINK --bfile QC1.1  --geno $GENO --hwe $HWE --maf $MAF --make-bed --out tmp
wait

sleep 1


echo -e	"...Checking rate of missingness per individual...\n"

$PLINK --bfile tmp --mind $MIND --make-bed --out QC1

rm tmp* #remove extra files
sleep 1

if [ -e QC1.irem ]
then
	read  irem filename <<< $(wc -l QC1.irem)
else irem=0
fi

read SNPs filename <<< $(wc -l QC1.bim)

Diff=$(expr $snps - $SNPs)

echo -e "....." $irem  "samples were removed due to genotyping freq < 95% \n
	 ....." $Diff  "SNPS were removed due to call rates  < 95%; MAF <0.02 or significant (10e-8) deviation from HWE \n"


echo -e 		"...Report the missingness per SNP and individual wise...\n"


$PLINK --bfile QC1 --missing --out QC1_report
sleep 1
wait


echo -e  		"...Report the hardy weinberg distribution...\n"

$PLINK --bfile QC1 --hardy --out PreQC_hardy
sleep 1
wait


echo -e 		"...Report the PreQC Allele Frequency...\n"

$PLINK --bfile QC1 --freq --out PreQC_AlleleFreq
sleep 1
wait

echo -e 		"...Report the Inbreeding..\n"

$PLINK --bfile QC1 --het --out PreQC_Inbreeding
sleep 1
wait



echo '
######################################################
#		Performing Sex check                 #
######################################################
'

echo -e 	'...checking for genderdiscrepancies... \n'

$PLINK --bfile QC1 --check-sex --out QC2_Sexcheck
sleep 1
grep "PROBLEM" QC2_Sexcheck.sexcheck | awk '$3 == 0' > QC2_NAGender.txt

grep "PROBLEM" QC2_Sexcheck.sexcheck | awk '$3 != 0' > QC2_BadGender.txt

read NAgend filename <<< $(wc -l QC2_NAGender.txt)
read Badgend filename <<< $(wc -l QC2_BadGender.txt)

echo -e ".....$NAgend samples had no gender annotated..... \n
	 .....$Badgend samples had gender indiscrepancies..... \n"


sleep 1

#If there are samples with no gender annotated

if [ $NAgend -gt 0 ]
then
      echo -e "
>>>> Your file has" $NAgend "unknown samples \n

>>>> Your data consists of samples without any gender annotated, if you wish to correct for them, please rerun the analysis after correcting them else analysis will continue with them \n">> $MAGNET/MAIN_DIR/Warnings.txt

		  #rename QC1 QC2 QC1.*;
		  mv QC1.bim QC2.bim
           	  mv QC1.bed QC2.bed
	    	  mv QC1.fam QC2.fam
		  echo -e ".....samples with unknown gender will not be considered further \n";>> $MAGNET/MAIN_DIR/Warnings.txt
		  NAupdate=1
else
    NAupdate=0
    echo -e '.....No samples with unknown gender present in Dataset \n'
    #rename QC1 QC2  QC1.*;
    		  mv QC1.bim QC2.bim
           	  mv QC1.bed QC2.bed
	    	  mv QC1.fam QC2.fam
fi

sleep 1

#If there are samples with gender discrepancies

if [ $Badgend -gt 0 ]
then
    echo -e '
	     .....the following samples had gender discrepancies \n
'
    cat QC2_BadGender.txt
sleep 1
    echo -e "

			>>>> Your data has" $Badgend "samples with gender inconsistencies, if you wish to correct for them, please rerun the analysis after correcting them \n

			>>>> As per default option, samples with gender inconsistencies will be removed \n">> $MAGNET/MAIN_DIR/Warnings.txt


		awk {'print($1 "\t"  $2)'} QC2_BadGender.txt > QC2_BadGender_removed.txt;

		echo -e ".....Samples with genderincongruencies being removed \n";

		$PLINK --bfile QC2 --remove QC2_BadGender_removed.txt --make-bed --out QC3

		if [ -e QC3.bim ]
		then
			echo -e "........$Badgend Samples with gender incongruencies were succesfully  removed \n";
		else
			echo -e ".....update of gender incongruencies failed pelase check plinkoutput_QC3.log \n";>> $MAGNET/MAIN_DIR/Warnings.txt

		fi

else
    echo ".....no gender discrepancies detected"
    #rename QC2 QC3 QC2.*
    		  mv QC2.bim QC3.bim
           	  mv QC2.bed QC3.bed
	    	  mv QC2.fam QC3.fam
fi
sleep 1



echo											 "...Final Sexcheck..."

$PLINK --bfile QC3 --check-sex --out QC4_Sexcheck

grep "PROBLEM" QC4_Sexcheck.sexcheck | awk '$3 == 0' > QC4_NAGender.txt
grep "PROBLEM" QC4_Sexcheck.sexcheck | awk '$3 != 0' > QC4_BadGender.txt
read prob0 x <<< $(wc -l QC4_NAGender.txt)
read probNA x <<< $(wc -l QC4_NAGender.txt)
sleep 1



echo "...Report Missing Gender Handling:"

if [ $NAupdate == 1 ]
then echo ".....$prob0 samples without annotated gender will not be considered further";>> $MAGNET/MAIN_DIR/Warnings.txt
fi
sleep 1

if [ $NAupdate == 0 ]
then echo ".....No Samples without annotated gender were present in original dataset";
fi

echo "...Gender issues in current files"
sleep 1


if [ $prob0 -gt 0 ]
then
	echo -e ".....there are still $prob0 gender incongruencies \n"

    	echo -e ".....samples written to QC4_Badgender.txt; please check manually; program exits here \n";>> $MAGNET/MAIN_DIR/Warnings.txt
     	exit;
else
	echo -e ".....No gender incongruencies remained after cleaning files \n";
fi
sleep 1



echo '
									####################################################
									#	Checking for inbreeding and contamination  #
									####################################################
'

$PLINK --bfile QC3 --het --out Breeding_output

awk '$6>0.2'  Breeding_output.het | awk '$6!="F"'  > QC4_inbredIDs.txt
awk '$6<-0.15'  Breeding_output.het > QC4_contaminatedIDs.txt


read cont x  <<< $(wc -l QC4_contaminatedIDs.txt)
read inbrd x <<< $(wc -l QC4_inbredIDs.txt)

echo -e "
...there are $cont potentially contaminated samples with high heterozygosity scores and
...there are $inbrd samples potentially inbred with low heterozygosity scores
">> $MAGNET/MAIN_DIR/Warnings.txt
sleep 1



if [ $cont -gt 0 ]
then
    echo "...Contaminated samples will be excluded"
		echo -e ".....$cont contaminated samples being removed \n"
		awk {'print $1 "\t" $2'} QC4_contaminatedIDs.txt > Contaminated_samples_removed.txt

		$PLINK --bfile QC3 --remove Contaminated_samples_removed --make-bed --out QC4 >plinkoutput_QC4_rm_cont.txt
		echo -e ".....$samples succesfully removed, samples written to Contaminated_samples_removed.txt \n";
else
    echo -e ".....no samples needed to be removed due to contamination \n"
    #rename QC3 QC4 QC3.*;
    		  mv QC3.bim QC4.bim
           	  mv QC3.bed QC4.bed
	    	  mv QC3.fam QC4.fam
    echo -e "....QC4 passed \n"
fi
sleep 1


if [ $inbrd -gt 0 ]
then
    echo -e '>>>The following individuals have high inbred scores \n'>> $MAGNET/MAIN_DIR/Warnings.txt
    cat QC4_inbredIDs.txt>> $MAGNET/MAIN_DIR/Warnings.txt

    echo ".....$inbrd samples will be removed"
		  awk {'print $1 " " $2'} QC4_inbredIDs.txt > Inbred_samples_removed.txt

		  $PLINK --bfile QC4 --remove Inbred_samples_removed.txt --make-bed --out QC5 > ../../LOG/Stage1_GenoQC/plinkoutput_QC5_rmInbred.log

		  if [ -e QC5.bim ]
		  then
		      	echo -e "...$inbrd samples removed, Samples written to Inbred_samples_removed.txt \n";
		  else
			echo -e "...there were some issues with removing inbred samples. Please check plinkoutput_QC5_rmInbred.log \n";
		       	exit;
		  fi
else
    echo -e "...no samples needed to be removed due to inbreeding \n"
    #rename QC4 QC5 QC4.*
    		  mv QC4.bim QC5.bim
           	  mv QC4.bed QC5.bed
	    	  mv QC4.fam QC5.fam
    echo -e "...QC5 passed \n"
fi
sleep 1


echo "
									###########################################################
									#	         Checking for Mendel Errors               #
									###########################################################
"

#parameter "Set-me missing" zero out specific Mendelian inconsistencies to be used in conjuction with me 1 1 so that no particular snp/individual is removed but to zero out specific genotypes

echo "...excluding families with more then 1% mendel errors and SNPs with more then 10% mendel errors"

$PLINK --bfile QC5 --me $MEFam $MESNP --set-me-missing --make-bed --out QC6
$PLINK --bfile QC6 --mendel --out MendelsummaryQC6

echo "...checking again for callrate>95% genotyping-rate>95%  MAF>0.02 hwe>10e-8"

$PLINK --bfile QC6  --geno $GENO --hwe $HWE --maf $MAF --make-bed --out tmp

$PLINK --bfile tmp --mind $MIND --make-bed --out  QC7

read SNPs filename <<< $(wc -l QC7.bim)
snps=$(cat QC5.bim | wc -l)
Diff=$(expr $snps - $SNPs)

Indiv=$(cat QC7.fam | wc -l)
Allind=$(cat QC5.fam | wc -l)

irem=$(expr $Allind - $Indiv)


echo "....." $irem  "samples were removed due to Mendel error rates"
echo "....." $Diff  "SNPS were removed due to call rates  < 95%; MAF <0.02 or significant (10e-8) deviation from HWE"
sleep 1


# clean all files

#rename QC7 QC8 QC7.*
    		  mv QC7.bim QC8.bim
           	  mv QC7.bed QC8.bed
	    	  mv QC7.fam QC8.fam

read ind filename <<< $(wc -l  QC8.fam)
read snps filename <<< $(wc -l  QC8.bim)

echo "
...Your Final file has" $ind  "samples and" $snps  "SNPs that passed QC
...Files are stored as $PLINK binary files QC_final.*"

wait


echo "
									#########################################################
									#	  Calculating Identity by descent             	#
									#########################################################
"


$PLINK --bfile QC8  --genome --out QC8_Relcheck

echo -e								"...Relatedness scores across all individuals are being calculated... \n"
wait

if [ -e  QC8_Relcheck.genome ]
then
    echo -e 									"....relcheck is succesfully finished.... \n"
else
    echo -e						 "...there were some major issues with your data. For details check QC8_Relcheck.log... \n">> $MAGNET/MAIN_DIR/Warnings.txt
fi
sleep 1

echo -e										"...IBD scores successfully calculated... \n"

awk '$9 >0.8 && $10 >0.8'  QC8_Relcheck.genome > QC8_Relcheck.duplicates



read dups x <<< $(wc -l QC8_Relcheck.duplicates)

echo -e 						    "...there are $dups duplicated samples. Samples written to QC8_Relcheck.duplicates \n..."

sleep 1
## Decisions on how to deal with families, user should provide additional files to correct the errors if any


echo ">>> One duplicated individual will be deleted"

	    awk {'print $1 " " $2'} QC8_Relcheck.duplicates > QC8_duplicatesDeleted.txt;

	    $PLINK --bfile QC8 --remove QC8_duplicatesDeleted.txt --make-bed --out QC9 > ../../LOG/Stage1_GenoQC/plinkoutput_QC8_rmDupls.log

	    if [ -e QC9.bed ]
	    then
		echo -e "...$(cat QC8_Relcheck.duplicates| wc -l) Samples were deleted. Samples written to QC8_duplicatesDeleted.txt \n"
	    else
		echo -e "...there were some issues with deleting duplicated samples, for more details please check plinkoutput_QC8.1_rmDupls.log \n">> $MAGNET/MAIN_DIR/Warnings.txt
	    fi

	    mv 	QC8.bim QC9.bim
            mv  QC8.bed QC9.bed
	    mv  QC8.fam QC9.fam


sleep 1

echo -e 								"...Checking for unrelated Parent offspring duos...\n"

$PLINK --bfile QC9 --genome rel-check --out QC9_Relcheck > plinkoutput_QC9_PO_Relcheck
sleep 1
awk '($5=="PO"  &&  ($7>0.1 ||  $8<0.8 || $9>0.1))'  QC9_Relcheck.genome > Not_related_POs.txt

awk '{print $1}' Not_related_POs.txt | sort -u > temp

grep -f temp QC9_Relcheck.genome > Not_related_fams.txt

NnotPO=$(cat temp | wc -l);

echo -e						"... there were $NnotPO not related parent offspring duos. Families are written to Not_related_fams.txt... \n"
wait

echo -e ">>> Deleting families with discordant relation status..... \n"

	    grep -f temp QC9.fam | awk '{print $1 " " $2}' > RmIndividuals_QC9.txt

	    $PLINK --bfile QC9 --remove RmIndividuals_QC9.txt --make-bed --out QC9.1 > ../../LOG/Stage1_GenoQC/plinkoutput_QC9.1_rmNotPO.log

	    if [ -e QC9.1.bed ]
	    then
		echo -e ".....$NnotPO Samples were deleted. Samples written to RmIndividuals_QC9.txt\n"
	    else
		echo -e ".....there were some issues with deleting not related families. For more details please check plinkoutput_QC9.1_rmNotPO.log \n">> $MAGNET/MAIN_DIR/Warnings.txt
		echo -e "... program is terminated \n"
		exit;
	    fi;
wait

	    mv QC9.bim QC10.bim
	    mv QC9.bed QC10.bed
	    mv QC9.fam QC10.fam;
	    mv QC9.log QC10.log

sleep 1

echo -e "... calculating significance across families relations\n"

$PLINK --bfile QC10 --genome --out QC10_Relcheck > plinkoutput_QC10_Relcheckround2.txt
wait

if [ -e  QC10_Relcheck.genome ]
then
    echo -e									"....relcheck is succesfully finished.... \n"
else
    echo -e						"...there were some major issues with your data. For details check plinkoutput_QC10_relcheck.log...\n"
fi
wait

awk '($1!=$3 && $10>0.1)' QC10_Relcheck.genome > CrossfamRelations.txt
sleep 1
NCroFamsR=$(cat CrossfamRelations.txt | wc -l)

cat  CrossfamRelations.txt

echo -e 				      "...There are $NCroFamsR 3rd degree or closer Relations across families. Families  written to  CrossfamRelations.txt...\n"  >> $MAGNET/MAIN_DIR/Warnings.txt




echo -e 					">>> You can check the output and rerun the analysis otherwise the program by default deleted one of the two families <<< \n">> $MAGNET/MAIN_DIR/Warnings.txt

	    awk '{print $1}' CrossfamRelations.txt | sort -u > temp

	    fams=$(cat temp | wc -l)

	    grep -f temp QC10.fam | awk '{print $1 " " $2}' > RmIndividuals_QC10.txt

	    $PLINK --bfile QC10 --remove RmIndividuals_QC10.txt --make-bed --out QC11 > ../../LOG/Stage1_GenoQC/plinkoutput_QC11.1_rmRelFam.log

	    if [ -e QC11.bed ]
	    then
		echo -e							".....$fams Families were deleted. Samples written to RmIndividuals_QC8.txt.....\n"
		cat temp
	    else
		echo -e				  ".....there were some issues with deleting related families. For more details please check plinkoutput_QC8.1_rmNotPO.log">> $MAGNET/MAIN_DIR/Warnings.txt
		echo -e										"...program is terminated... \n"
	    fi


	    mv QC10.bim QC11.bim
	    mv QC10.bed QC11.bed
	    mv QC10.fam QC11.fam
sleep 1

echo "
									#########################################################
									#	 	 Performing Final QC            	#
									#########################################################
"

echo -e								".......Perform final QC before proceeding to next stage of the program........\n"



echo -e								  "...checking again for callrate>95% genotyping-rate>95%  MAF>0.02 hwe>10e-8...\n"

$PLINK --bfile QC11  --geno 0.05 --hwe 10e-8 --maf 0.02 --make-bed --out tmp12
sleep 1
$PLINK --bfile tmp12  --mind 0.05 --make-bed --out QC12 > ../../LOG/Stage1_GenoQC/plinkoutput_QC12.log
sleep 1
if [ -e QC12.irem ]
then
	read  irem filename <<< $(wc -l QC12.irem)
else
	irem=0
fi;

read SNPs filename <<< $(wc -l QC12.bim)

Diff=$(expr $snps - $SNPs)

echo -e									"....." $irem  "samples were removed to to genotyping freq < 95%.....\n

						....." $Diff  "SNPS were removed due to call rates  < 95%; MAF <0.02 or significant (10e-8) deviation from HWE....."

sleep 1


read ind filename <<< $(wc -l QC12.fam)
read snps filename <<< $(wc -l QC12.bim)

echo -e "
								...The file after primary quality check has" $ind  "samples and" $snps  "SNPs...\n and is named as QC12"



$PLINK --bfile QC12 --missing --out PostQC_report

$PLINK --bfile QC12 --hardy --out PostQC_Hardyreport

$PLINK --bfile QC12 --freq --out PostQC_AlleleFreq

$PLINK --bfile QC12 --het --out PostQC_Inbreeding

$PLINK --bfile QC12 --check-sex --out Final_Sexcheck

QCFile=QC12

sleep 1
echo "
					################################################
					#					       #
					# 	     MDS plots and IBD analysis        #
					#                                              #
					################################################
"

echo -e			">>> Provide Path to HAP Map files (bim fam bed coded) for ethnicity check <<<< \n"

hapmap=$Hapmapfile

    if [ ! -e $hapmap.fam ] || [ ! -e $hapmap.bim ] || [ ! -e $hapmap.bed ]
    then
	echo -e "...$hapmap files do not exist, the program will exit. Please download the hapmap files from the link provided in the user manual and rerun the analysis again... \n">> $MAGNET/MAIN_DIR/Warnings.txt
	exit;
    else
	echo -e "...$hapmap files found... \n"
    fi;

sleep 1


datafileQC=QC12 #Study data

datafileHP=$hapmap


awk '{print $2}' $datafileQC.bim | sort -u > temp1
awk '{print $2}' $datafileHP.bim | sort -u  > temp2

comm -12 temp1 temp2 >overlapping.snps.txt
wait

rm temp*


$PLINK --bfile $datafileQC --extract overlapping.snps.txt --alleleACGT --make-bed --out localQC #Making sure the allele coding is ACGT

$PLINK --bfile $datafileHP --extract overlapping.snps.txt --alleleACGT --make-bed --out localHM  #Making sure the allele coding is ACGT

sleep 1
#Print list of IID and FID for generating MDS plot


awk '{print $1 "\t" $2}' $datafileQC.fam > SampleInds.txt


awk '{print $2 " "  $1 }' localHM.bim > HM3CHR #Hapmap chromosomes
awk '{print $2 " " $4}' localHM.bim > HM3pos #Hapmap SNP base-pair positions
awk '{print $2 " " $3}' localHM.bim > HM3CM #Hapmap centi-morgan

echo -e 		"...Updating map, chr and cm of the study data...\n"

sleep 1
$PLINK --bfile localQC  --update-map HM3pos --make-bed  --out localQCp #updated SNP base-pair position
wait
sleep 1

echo -e 		"...Updated SNP positions of the study data based on Hapmap data...\n"

$PLINK --bfile localQCp  --update-map HM3CHR --update-chr --make-bed  --out localQCpc #updated SNP base-pair position and chromosome of the study data
wait
sleep 1

echo -e 		"...Updated CHR of the study data based on Hapmap data...\n"


$PLINK --bfile localQCpc  --update-map HM3CM --update-cm --make-bed  --out localQCpcc #updated SNP base-pair position,chromosome and cm of the study data
sleep 1

echo -e 		"...Updating CM of the study data based on Hapmap data...\n"


if [ -e localQCpcc-merge.missnp ]
then
    missnps=$(cat localQCpcc-merge.missnp | wc -l)
    if [ $missnps -gt 0 ]
    then
	$PLINK --bfile localQCpc --exclude localQCpcc-merge.missnp --make-bed --out tmp  #exclude SNPs which fail to merge

	$PLINK --bfile tmp  --update-map HM3CM --update-cm --make-bed  --out localQCpcc
    fi;
fi;
wait
sleep 1

rm tmp*


datafile=localQCpcc

awk '{ if (($5=="T" && $6=="A")||($5=="A" && $6=="T")||($5=="C" && $6=="G")||($5=="G" && $6=="C")) print $2, "ambig" ; else print $2 ;}' $datafile.bim | grep -v ambig > localsnplist.txt

echo -e "...Check if there is any inconsistency between the coding of the alleles...\n"



$PLINK --bfile localHM --extract localsnplist.txt --make-bed --out external   #Extract the SNPs from Hapmap file

sleep 1
$PLINK --bfile localQCpcc --extract localsnplist.txt --make-bed --out internal  #Extract the SNPs from study data whose bp positions,chromosome and cm positions is updated.

sleep 1
$PLINK --bfile internal --bmerge external.bed external.bim external.fam --make-bed --out MDSfile
sleep 1

if [ -e MDSfile-merge.missnp ] #If there are SNPs with merging issues such as strand issues than flip those SNPs
then
	missnps=$(cat MDSfile-merge.missnp | wc -l)

    		if [ $missnps -gt 0 ]
    			then
			$PLINK --bfile internal --flip  $LocSource/OUTPUT_DIR/Stage1_GenoQC/MDSfile-merge.missnp --make-bed --out internalf
			$PLINK --bfile internalf --bmerge external.bed external.bim external.fam --make-bed --out MDSfile2 #Again try to merge the Hamap and study data file with the flipped SNPs
				if [[ -e MDSfile2-merge.missnp ]]
				then
				$PLINK --bfile internalf --exclude MDSfile2-merge.missnp --make-bed --out internalf
				$PLINK --bfile internalf --bmerge external.bed external.bim external.fam --make-bed --out MDSfile
				fi
		fi

fi
sleep 1

$PLINK --bfile MDSfile --cluster --mind .05 --mds-plot 4 --out HM3mds #Create an MDS
sleep 1


echo -e 				"...Generating all Pre and Post QC plots including MDS...\n"

#chmod +x ../../Scripts/GenerateQC_plots.R
R --slave --no-save --args QC1_report.lmiss QC1_report.imiss PreQC_hardy.hwe PreQC_AlleleFreq.frq QC2_Sexcheck.sexcheck PreQC_Inbreeding.het PostQC_report.lmiss PostQC_report.imiss PostQC_Hardyreport.hwe PostQC_AlleleFreq.frq Final_Sexcheck.sexcheck PostQC_Inbreeding.het SampleInds.txt $Siteinfo HM3mds.mds < ../../Scripts/GenerateQC_plots.R

echo -e 				"...Stage 1 of Genotype QC is successfully completed...\n"

mv QC12.fam FinalQC_Study.fam
mv QC12.bed FinalQC_Study.bed
mv QC12.bim FinalQC_Study.bim

#Remove all the uncessary files

rm external*
rm localsnplist.txt
rm internal*
rm localQCp*
rm HM3CM*
rm HM3pos*
rm HM3CHR*
rm localHM*
rm overlapping.snps.txt
rm QC*
rm Mendel*
