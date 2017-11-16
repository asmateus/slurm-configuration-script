# Slurm Configuration Debian based Cluster
Here I will describe a simple configuration of the slurm management tool for launching jobs in a really simplistic cluster. I will assume the following configuration: a main node (for me it is an Arch Linux distribution) and 3 compute nodes (for me compute nodes are Debian VMs). I also assume there is ping access between the nodes and some sort of mechanism for you to know the IP of each node at all times (most basic should be a local NAT with static IPs)

## Basic Structure
Slurm management tool work on a set of nodes, one of which is considered the master node, and has the `slurmctld` daemon running; all other compute nodes have the `slurmd` daemon. All communications are authenticated via the `munge` service and all nodes need to share the same authentication key. Slurm by default holds a journal of activities in a directory configured in the `slurm.conf` file, however a Database management system can be set. All in all what we will try to do is:

* Install `munge` in all nodes and configure the same authentication key in each of them
* Configure the `slurmctld` service in the master node
* Configure the `slurmd` service in the compute nodes
* Create a basic file structure for storing jobs and jobs result that is equal in all the nodes of the cluster
* Manipulate the state of the nodes, and learn to resume them if they are down
* Run some simple jobs as test
* Set up a database for slurm
* Set up a user based job submission protocol
* Set up MPI task on the cluster

## Install Packages
### Munge
Lets start installing `munge` authentication tool using the system package manager, for all nodes in the network:

    sudo apt-get install -y libmunge-dev libmunge2 munge

`munge` requires that we generate a key file for testing authentication, for this we use the `dd` utility, with the fast pseudo-random device `/dev/urandom`. At master node do:

    sudo dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
    
Upon installing `munge` previously, a `munge` user should have been created, if it was not simply create it. Now we need to give full permissions to this user on the file `munge.key`:

    chown munge:munge /etc/munge/munge.key
    chmod 400 /etc/munge/munge.key
    
Now copy this key to each node via `ssh`:

    scp /etc/munge/munge.key <node-user>@<node-ip>:/etc/munge/munge.key

We restrict login access to the `munge` account, for all nodes in the network:

    vi  /etc/passwd

Edit the file as follows:

    munge:x:501:501::/var/run/munge;/sbin/nologin
    
This much is enough configuration, lets enable and start the service in each node (including master) with the commands:

    sudo systemctl enable munge
    sudo systemctl start munge
    
Test communication with, locally and remotely with these commands respectively:

    munge -n | unmunge
    munge -n | ssh <some-host-node-of-the-network> unmunge

### Slurm

Install the `slurm` packages from the distribution repositories, for all nodes in the network:

    sudo apt-get install -y slurm-llnl
    
This will do the following things (among many others):
* Create a `slurm` user
* Create a configuration directory at `/etc/slurm-llnl`
* Create a log directory at `/var/log/slurm-llnl`
* Create two `systemd` files for configuring `slurmd.service` and `slurmctld.service` at `/lib/systemd/system`
* Create a directory for saving the state of the service at `/var/spool/slurm`

First edit the configuration file in the master node, to make it suitable for our network. Take a look at the file provided, along with this `instructions.md` named `slurm.conf` and edit the values in the form `<value>` with the appropiate content. Do not override the default file given to you, rename it and then copy the provided (I have deleted various commented lines for sake of brevity). Notice that if you change the cluster name in the configuration file you should also modify the file `/var/spool/slurm/ctld/clustername` accordingly. Also, create as many compute nodes as you need.
    
Now we need to clean the file structure for `slurm`, check if all the directories mentioned before exists, if they don't, create them. All the directories mentioned should belong to the `slurm` user and the `slurm` group, to any file or directory in this directories that do not follow this criteria, change the permissions accordingly:

    sudo chown slurm:slurm <file-or-directory>
    
 Also we need to create a PID file for `slurm`, as it does not create it for us. Do:
 
    # For master node
    sudo touch /var/slurmctld.pid
    sudo chown slurm:slurm /var/slurmctld.pid
    
    # For compute nodes
    sudo touch /var/slurmd.pid
    sudo chown slurm:slurm /var/slurmd.pid

We are almost ready to activate the services, previous to that, we need to tell, in the `.service` files the user in which each script will run as. Under the `[SERVICE]` section add the following line (for the respective node types):

    User=slurm  # Master node
    User=root   # Slave node
    
Now enable and start the services:

    # For master node
    sudo systemctl enable slurmctld
    sudo systemctl start slurmctld
    
    # For compute nodes
    sudo systemctl enable slurmd
    sudo systemctl start slurmd
