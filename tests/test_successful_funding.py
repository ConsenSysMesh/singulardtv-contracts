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


# Accounts
GUARD = 0
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
TOKEN_LOCKING_PERIOD = 63072000  # 2 years
CROWDFUNDING_PERIOD = 2419200  # 4 weeks
TOKEN_ISSUANCE_PERIOD = 604800  # 1 week, guard has to issue tokens within one week after crowdfunding ends.
ETH_VALUE_PER_SHARE = 1250000000000000  # 0.00125 ETH
ETH_TARGET = 10**18 * 100000  # 100.000 ETH


class TestContract(TestCase):
    """
    run test with python -m unittest tests.test_successful_funding
    """

    HOMESTEAD_BLOCK = 1150000

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.pp = PreProcessor()
        self.s = t.state()
        self.s.block.number = self.HOMESTEAD_BLOCK
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
            language='solidity',
            sender=keys[GUARD]
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

    def test(self):
        # Crowdfunding has started and startDate has been set.
        self.assertEqual(self.crowdfunding_contract.startDate(), self.s.block.timestamp)
        # Series A investor with address 0x0196b712a0459cbee711e7c1d34d2c85a9910379 has 5000000 shares
        self.assertEqual(self.token_contract.balanceOf("0x0196b712a0459cbee711e7c1d34d2c85a9910379"), 5000000)
        self.assertEqual(self.token_contract.balanceOf(self.mist_wallet_contract.address), 400000000)
        # 500000000 shares have been issued to early investors.
        self.assertEqual(self.token_contract.totalSupply(), 500000000)
        # Backer 1 starts funding, but doesn't send enough money to buy a share, transaction fails.
        self.assertRaises(TransactionFailed, self.crowdfunding_contract.fund, value=ETH_VALUE_PER_SHARE - 1, sender=keys[BACKER_1])
        # Backer 1 fails to buy some shares, because he sends Ether directly to the contract, which fails.
        share_count_b1 = 1000
        self.assertRaises(TransactionFailed, self.s.send, keys[BACKER_1], self.crowdfunding_contract.address, ETH_VALUE_PER_SHARE * share_count_b1)
        # Backer 1 is now successfully buying some shares by using the fund function.
        self.assertEqual(
            self.crowdfunding_contract.fund(value=ETH_VALUE_PER_SHARE * share_count_b1, sender=keys[BACKER_1]),
            share_count_b1
        )
        # Backer 1 has now share_count shares
        self.assertEqual(self.token_contract.balanceOf(accounts[BACKER_1]), share_count_b1)
        # Backer 2 invests too and wants to buy more shares than possible. He gets the maximum amount possible.
        # Half of all tokens (500M) was assigned to early investors and backer 1 bought 1000 shares successfully.
        # This is why there are less than 500M shares left, which can be bought.
        share_count_b2 = MAX_TOKEN_COUNT / 2
        self.assertEqual(self.crowdfunding_contract.fund(value=ETH_VALUE_PER_SHARE * share_count_b2, sender=keys[BACKER_2]),
                         share_count_b2 - share_count_b1)
        # Backer 1 wants to buy more shares too, but the cap has been reached already
        self.assertEqual(self.token_contract.totalSupply(), MAX_TOKEN_COUNT)
        self.assertRaises(TransactionFailed, self.crowdfunding_contract.fund, value=ETH_VALUE_PER_SHARE, sender=keys[BACKER_1])
        # Crowdfunding period ends
        self.s.block.timestamp += CROWDFUNDING_PERIOD
        # Backer 1 wants to withdraw his shares now, but fails, because the campaign ended successfully
        self.assertRaises(TransactionFailed, self.crowdfunding_contract.withdrawFunding, sender=keys[BACKER_1])
        fund_balance = self.crowdfunding_contract.fundBalance()
        # Series A investor with address 0x0196b712a0459cbee711e7c1d34d2c85a9910379 has now 5M shares
        self.assertEqual(self.token_contract.balanceOf("0x0196b712a0459cbee711e7c1d34d2c85a9910379"), 5000000)
        # Workshop withdraws funding successfully.
        self.assertTrue(self.crowdfunding_contract.withdrawForWorkshop(sender=keys[WS_1]))
        # The funding contract is empty now.
        self.assertEqual(self.s.block.get_balance(self.crowdfunding_contract.address), 0)
        # All funds have been transferred to the mist wallet.
        self.assertEqual(self.s.block.get_balance(self.mist_wallet_contract.address), fund_balance)
        # Workshop generated revenue and deposits revenue on the fund contract.
        revenue = 10**18 * 1000
        self.assertTrue(self.fund_contract.depositRevenue(value=revenue, sender=keys[WS_1]))
        self.assertEqual(self.fund_contract.totalRevenue(), revenue)
        # WS withdraws revenue share
        withdraw_data = self.fund_contract.translator.encode("withdrawRevenue", ())
        revenue_share = revenue * 400000000 / MAX_TOKEN_COUNT
        wallet_balance = self.s.block.get_balance(self.mist_wallet_contract.address)
        self.mist_wallet_contract.execute(self.fund_contract.address, 0, withdraw_data, value=0)
        # The wallet's balance increased.
        self.assertEqual(self.s.block.get_balance(self.mist_wallet_contract.address), wallet_balance + revenue_share)
        # Backer 1 transfer shares to new backer 3 and backer 1's revenue share is credited to owed balance.
        self.assertTrue(self.token_contract.transfer(accounts[BACKER_3], share_count_b1/2, sender=keys[BACKER_1]))
        self.assertTrue(self.token_contract.approve(accounts[BACKER_3], share_count_b1/2, sender=keys[BACKER_1]))
        self.assertTrue(self.token_contract.transferFrom(accounts[BACKER_1], accounts[BACKER_3], share_count_b1/2, sender=keys[BACKER_3]))
        # Backer 1 withdraws his revenue for himself
        revenue_share = revenue * share_count_b1 / MAX_TOKEN_COUNT
        self.assertEqual(self.fund_contract.owed(accounts[BACKER_1]), revenue_share)
        self.assertEqual(self.fund_contract.withdrawRevenue(sender=keys[BACKER_1]), revenue_share)
        # The next time backer 1 wants to withdraw his revenue share, he gets nothing as no new revenue was generated.
        self.assertEqual(self.fund_contract.withdrawRevenue(sender=keys[BACKER_1]), 0)
        # Backer 3 tries to withdraw his revenue share for his new shares.
        # Backer 3 won't get anything, because no new revenue has been generated after transfer.
        self.assertEqual(self.fund_contract.withdrawRevenue(sender=keys[BACKER_3]), 0)
        # Backer 2 withdraws revenue share
        share_count_b2 = self.token_contract.balanceOf(accounts[BACKER_2])
        revenue_share = revenue * share_count_b2 / MAX_TOKEN_COUNT
        self.assertEqual(self.fund_contract.withdrawRevenue(sender=keys[BACKER_2]), revenue_share)
        # Workshop wants to transfer shares but fails because 2 years have not passed yet
        transfer_data = self.token_contract.translator.encode("transfer", (accounts[WS_1], 1000000))
        self.mist_wallet_contract.execute(self.token_contract.address, 0, transfer_data, value=0)
        self.assertEqual(self.token_contract.balanceOf(self.mist_wallet_contract.address), 400000000)
        # After waiting two years, it succeeds
        self.s.block.timestamp += TOKEN_LOCKING_PERIOD
        self.mist_wallet_contract.execute(self.token_contract.address, 0, transfer_data, value=0)
        self.assertEqual(self.token_contract.balanceOf(self.mist_wallet_contract.address), 400000000 - 1000000)
