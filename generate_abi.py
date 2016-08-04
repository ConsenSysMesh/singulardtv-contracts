from ethereum.tester import languages
from preprocessor import PreProcessor
import json

pp = PreProcessor()
contracts = ['SingularDTVCrowdfunding.sol', 'SingularDTVFund.sol', 'SingularDTVToken.sol', 'SingularDTVWeifund.sol']
contract_dir = 'contracts/'

for contract_name in contracts:
    code = pp.process(contract_name, add_dev_code=False, contract_dir=contract_dir, replace_unknown_addresses=True)
    compiled = languages["solidity"].combined(code)[-1][1]
    # save abi
    h = open("abi/{}.json".format(contract_name.split(".")[0]), "w+")
    h.write(json.dumps(compiled["abi"]))
    h.close()
    print '{} ABI generated.'.format(contract_name)
