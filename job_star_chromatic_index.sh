#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --partition=math-alderaan
#SBATCH --nice=1000
#SBATCH --job-name=star_chromatic_index
#SBATCH --output=output-job.%A_%a-%j.txt

# We'll set the parameters of the task array on the command line.
# NOTE: We are now 0-indexing!
####$ -a 0-9999

input="$1"
base=$(basename "$input" .txt)
depth="$2"
modulus="$3"

if [ "$depth" == "" ]
then
  depth=4
fi

n="$(grep 'n=' "$input" | cut -c 3-)"

app="$HOME/apps/StarChromaticIndex/git/StarChromaticIndex/src/star_precolor"
if [ "$n" -gt 64 ]
then
  app="${app}128"
fi

cluster="$(hostname -s | cut -c 6-10)"
if [ "$cluster" == "alder" ]; then
  # do nothing
  :
elif [ "$cluster" == "colib" ]; then
  app="${app}_oldgcc"
elif [ "$cluster" == "score" ]; then
  app="${app}_oldgcc"
else
  app="${app}_oldgcc"
fi

echo "Running with app=$app"

output_dir="$HOME/apps/StarChromaticIndex/output/$base"

jobnum=$SLURM_ARRAY_TASK_ID
printf -v jobnumpadded "%08d" $jobnum
numjobs=$(($SLURM_ARRAY_TASK_MAX - $SLURM_ARRAY_TASK_MIN +1))

if [ "$modulus" == "" ]
then
  modulus=$numjobs
fi 

output_file="$output_dir/output_${base}-${modulus}-job${jobnumpadded}.txt"

header="Processing base=$base into $output_dir with $numjobs total jobs; depth=$depth, modulus=$modulus; this is job $jobnum on machine $(hostname -s)"
jobinfo="JOB_NAME=${SLURM_JOB_NAME} JOB_ID=${SLURM_JOB_ID} ARRAY_JOB_ID=${SLURM_ARRAY_JOB_ID} TASK_ID=${SLURM_ARRAY_TASK_ID} TASK_MIN=${SLURM_ARRAY_TASK_MIN} TASK_MAX=${SLURM_ARRAY_TASK_MAX}"

echo "$header"
echo "$jobinfo"

echo "$header" > "$output_file"
echo "$jobinfo" >> "$output_file"
date -Iseconds >> "$output_file"
start=`date +%s`

"$app" "$input" $jobnum $modulus $depth >> $output_file

date -Iseconds >> $output_file
finish=`date +%s`
echo "Total elapsed wall time in seconds is $(($finish-$start))" >> $output_file
