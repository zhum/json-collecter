#!/bin/sh

export CLUSTER='lomonosov-2'
export YEAR_SRV='https://msumobile.rcc.msu.ru:88/WS/supercompyearinfo.wsdl'
export YEAR_KEY='7JEA8V2Z9M4LKSFFE'

bundle exec ruby ./slurm-collecter-long.rb "$@"

