#!/bin/sh

export CLUSTER='myclustre'
export API_KEY='1234567890'
export SOAP_SRV='https://qwertyuiop/wsdl'
export JSON_SRV='https://qwertyuiop/cluster.data'

bundle exec ruby ./slurm-collecter-soap.rb

