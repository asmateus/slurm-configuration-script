# *************************************
# ***** SLURM INSTALLATION SCRIPT *****
# *************************************

# Use this script to install slurm in your nodes, the script assumes the
# the following files and directories exist in your system:
# * /home/slurm/ (that is, a slurm user was created with a home directory)
# * /home/slurm/sconfig/ (a directory for saving slurm config files)
# * /home/slurm/sconfig/nodelist (File with no extension containing the following)
#        NODE NAME | NODE IP | NODE ROLE | ENTRY USER | USER PASSWORD
# (values in node list file are separated by spaces, roles are MASTER and SLAVE)
# The script will guess the role of the machine it is installed in based on this
# file.

# Paths and files
MUNGE_KEY_DIR_NAME="/home/slurm/munge/"
CONFIG_DIR_NAME="sconfig/"

MUNGE_KEY_FILE_NAME="munge.key"
NODELIST_FILE_NAME="nodelist"

ROOT_PTH="/home/slurm/"
CONFIG_PTH=$ROOT_PTH$CONFIG_DIR_NAME

NODELIST_FILE=$CONFIG_PTH$NODELIST_FILE_NAME

# Check if the minimum root structure holds
if [ ! -d $ROOT_PTH ]
then
    echo ">> ERROR: Install script requires $ROOT_PTH to be present"
    exit
elif [ ! -d $CONFIG_PTH ]
then
    echo ">> ERROR: Install script requires $CONFIG_PTH to be present"
    exit
elif [ ! -f $NODELIST_FILE ]
then
    echo ">> ERROR: Install script requires $NODELIST_FILE to be present"
    exit
fi

echo ">> Minimum requirements present. Installing..."

# Following packages need to be installed
# * libmunge-dev
# * libmunge2
# * munge
# * slurm-llnl
# Check if they are already present

packages=("libmunge-dev" "libmunge2" "munge" "slurm-llnl" "expect")

echo ">> Verifing if required packages are installed..."
for pkg in "${packages[@]}"
do
    response=$(echo `dpkg -s $pkg 2> /dev/null | grep Package`)

    # Check if package was found
    if test "${response#*$pkg}" != "$response"
    then
        echo "Found package: $pkg"
    else
        echo "Not found package: ${pkg}. Installing..."
        echo `apt-get install -y $pkg`
        echo "Done installing ${pkg}."
    fi
done

echo ">> All required packages present"
echo ">> Checking if a secure key is present in the cluster"

# Store nodes of the cluster
declare -a NODES
mapfile -t NODES < $NODELIST_FILE

# Get corrent host name
HOSTNAME=$(echo `uname -n`)

# If munge folder does not exists, create it
if [ ! -d $MUNGE_KEY_DIR_NAME ]
then
    echo "Creating $MUNGE_KEY_DIR_NAME"
    mkdir $MUNGE_KEY_DIR_NAME
    chown munge:munge /etc/munge
fi

# If munge.key file does not exist, generate it
if [ ! -f "$MUNGE_KEY_DIR_NAME$MUNGE_KEY_FILE_NAME" ]
then
    echo "Creating $MUNGE_KEY_DIR_NAME$MUNGE_KEY_FILE_NAME"
    dd if=/dev/urandom bs=1 count=1024 > $MUNGE_KEY_DIR_NAME$MUNGE_KEY_FILE_NAME 2> /dev/null
    chown munge:munge /etc/munge/munge.key
    chmod 400 /etc/munge/munge.key

    # Copy the file to every other node in the cluster
    echo ">> Copying file to other nodes"
    for node in "${NODES[@]}"
    do
        # Get parameters of nodes
        declare -a nodea
        IFS=' ' read -r -a nodea <<< "$node"
        if [ $HOSTNAME != "${nodea[0]}" ]
        then
            echo "Copying to ${nodea[0]}"
            expect -f scp_expect_file.exp ${nodea[3]} ${nodea[1]} ${nodea[4]} $MUNGE_KEY_DIR_NAME$MUNGE_KEY_FILE_NAME > /dev/null
        fi
    done
else
    echo "Munge key file present"
fi

echo ">> Finished!"
