# SingularDTV CODE

Use `vagrant up` then
`vagrant ssh default`

### To run all tests:
`cd /vagrant/`
`python -m unittest discover tests`

### Run one test:
`cd /vagrant/`
`python -m unittest tests.test_successful_funding`

### To run the testrpc:
`./testrpc_command.sh`

### To deploy the contracts:
`python deploy.py -f deploy.json`

### To generate the ABIs:
`python generate_abi.py`
