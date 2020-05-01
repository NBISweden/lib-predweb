#!/bin/bash
# install virtualenv if not installed
# first install dependencies
# make sure virtualenv is installed with Python3
python3 -m pip install --upgrade pip
pip3 install virtualenv
# then install programs in the virtual environment
mkdir -p ~/.virtualenvs
rundir=`dirname $0`
rundir=`readlink -f $rundir`
cd $rundir
exec_virtualenv=virtualenv
eval "$exec_virtualenv env"
source ./env/bin/activate

pip3 install --ignore-installed -r requirements.txt
# below is a hack to make python3 version of geoip working
pip3 uninstall --yes python-geoip
pip3 install  python-geoip-python3==1.3


