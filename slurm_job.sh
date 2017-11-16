#!/usr/bin/env bash

#SBATCH -o /opt/slurm-prc-out/slurm.sh.out

now="$(date +"%r")"
echo $now > /opt/slurm-prc-out/res.txt
