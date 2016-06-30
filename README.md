# SingularDTV CODE

Use `vagrant up` then

### To run the testrpc:
`./testrpc_command.sh`

### To deploy the contracts:
`python deploy.py -f deploy.txt -add_dev_code true`
or
`python deploy.py -f token_deploy.txt -add_dev_code true -contract_dir token_contracts/`

### To generate the ABIs:
`python generate_abi.py`s