# ethereum
from ethereum import tester as t
from ethereum.tester import keys, accounts
from ethereum.utils import sha3
from preprocessor import PreProcessor
# signing
from bitcoin import ecdsa_raw_sign
# standard libraries
from unittest import TestCase

# Associate accounts
GUARD = 0
WS_1 = 1
WS_2 = 2
WS_3 = 3
REQUIRED_ACC = 2
DAILY_LIMIT = 10**18*1000


class TestContract(TestCase):
    """
    run test with python -m unittest test
    """

    HOMESTEAD_BLOCK = 1150000

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.pp = PreProcessor()
        self.s = t.state()
        self.s.block.number = self.HOMESTEAD_BLOCK
        t.gas_limit = 4712388

    def setUp(self):
        contract_dir = '../contracts/'
        self.s.block.number = self.HOMESTEAD_BLOCK
        # Create mist wallet
        constructor_parameters = (
            [accounts[WS_1], accounts[WS_2], accounts[WS_3]],
            REQUIRED_ACC,
            DAILY_LIMIT
        )
        self.mist_wallet_contract = self.s.abi_contract(open(contract_dir + 'MistWallet.sol').read(), language='solidity', constructor_parameters=constructor_parameters)
        self.token_library_contract = self.s.abi_contract(self.pp.process('TokenLibrary.sol', add_dev_code=True, contract_dir=contract_dir), language='solidity')
        # Crowdfunding contract is create by GUARD
        self.fund_contract = self.s.abi_contract(self.pp.process('Fund.sol', add_dev_code=True, contract_dir=contract_dir, addresses={
            'MistWallet': self.a2h(self.mist_wallet_contract)
        }), language='solidity', libraries={
            'TokenLibrary': self.token_library_contract.address.encode('hex')
        }, sender=keys[GUARD])

    @staticmethod
    def a2h(contract):
        return "0x{}".format(contract.address.encode('hex'))

    def test(self):
        pass
