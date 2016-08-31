# ethereum
from ethereum import tester as t
from ethereum.tester import keys, accounts
from ethereum.tester import TransactionFailed
from ethereum.utils import sha3
from preprocessor import PreProcessor
# signing
from bitcoin import ecdsa_raw_sign
# standard libraries
from unittest import TestCase


HOMESTEAD_BLOCK = 1150000
DAY = 60*60*24

# Accounts
OWNER = 0
WS_1 = 1
WS_2 = 2
WS_3 = 3
BACKER_1 = 4
BACKER_2 = 5
BACKER_3 = 6

# Mist wallet
REQUIRED_ACCOUNTS = 2
DAILY_LIMIT = 10**18*1000  # 1000 ETH

# Fund contract
MAX_TOKEN_COUNT = 1000000000  # 1.0B
WORKSHOP_TOKEN_COUNT = 400070000  # ~400M
TOKEN_LOCKING_PERIOD = 31536000  # 1 year
CROWDFUNDING_PERIOD = 2419200  # 4 weeks
TOKEN_ISSUANCE_PERIOD = 604800  # 1 week, guard has to issue tokens within one week after crowdfunding ends.
ETH_VALUE_PER_SHARE = 1250000000000000  # 0.00125 ETH
ETH_TARGET = 10**18 * 100000  # 100.000 ETH


class AbstractTestContract(TestCase):
    """
    run test with python -m unittest discover tests
    """

    HOMESTEAD_BLOCK = 1150000

    def __init__(self, *args, **kwargs):
        super(AbstractTestContract, self).__init__(*args, **kwargs)
        self.pp = PreProcessor()
        self.s = t.state()
        self.s.block.number = HOMESTEAD_BLOCK
        t.gas_limit = 4712388

    def setUp(self):
        contract_dir = 'contracts/'
        self.s.block.number = self.HOMESTEAD_BLOCK
        # Create mist wallet
        constructor_parameters = (
            [accounts[WS_1], accounts[WS_2], accounts[WS_3]],
            REQUIRED_ACCOUNTS,
            DAILY_LIMIT
        )
        self.mist_wallet_contract = self.s.abi_contract(
            self.pp.process('MistWallet.sol', add_dev_code=True, contract_dir=contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        # Create contract
        self.fund_contract = self.s.abi_contract(
            self.pp.process('SingularDTVFund.sol', add_dev_code=True, contract_dir=contract_dir, addresses={
                'MistWallet': self.a2h(self.mist_wallet_contract)
            }),
            language='solidity'
        )
        # Crowdfunding contract is create by GUARD
        self.crowdfunding_contract = self.s.abi_contract(
            self.pp.process('SingularDTVCrowdfunding.sol', add_dev_code=True, contract_dir=contract_dir),
            language='solidity'
        )
        self.token_contract = self.s.abi_contract(
            self.pp.process('SingularDTVToken.sol', add_dev_code=True, contract_dir=contract_dir, addresses={
                'SingularDTVFund': self.a2h(self.fund_contract),
                'SingularDTVCrowdfunding': self.a2h(self.crowdfunding_contract)
            }),
            language='solidity'
        )
        self.weifund_contract = self.s.abi_contract(
            self.pp.process('SingularDTVWeifund.sol', add_dev_code=True, contract_dir=contract_dir, addresses={
                'SingularDTVFund': self.a2h(self.fund_contract),
                'SingularDTVCrowdfunding': self.a2h(self.crowdfunding_contract)
            }),
            language='solidity'
        )
        # Setup contracts
        self.assertTrue(self.fund_contract.setup(self.crowdfunding_contract.address, self.token_contract.address))
        self.assertTrue(self.crowdfunding_contract.setup(self.fund_contract.address, self.token_contract.address))

    @staticmethod
    def a2h(contract):
        return "0x{}".format(contract.address.encode('hex'))
