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

# Mist wallet
REQUIRED_ACCOUNTS = 2
DAILY_LIMIT = 10**18*1000  # 1000 ETH

# Fund contract
MAX_TOKEN_COUNT = 1000000000  # 1B
WORKSHOP_TOKEN_COUNT = 400070000  # ~400M
TOKEN_LOCKING_PERIOD = 63072000  # 2 years
CROWDFUNDING_PERIOD = 2592000  # 1 month
TOKEN_ISSUANCE_PERIOD = 604800  # 1 week, guard has to issue tokens within one week after crowdfunding ends.
ETH_VALUE_PER_SHARE = 10**15  # 0.001 ETH
ETH_TARGET = 10**18 * 100000  # 100.000 ETH


class TestContract(TestCase):
    """
    run test with python -m unittest test_successful_funding
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
            REQUIRED_ACCOUNTS,
            DAILY_LIMIT
        )
        self.mist_wallet_contract = self.s.abi_contract(
            self.pp.process('MistWallet.sol', add_dev_code=True, contract_dir=contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        # Crowdfunding contract is create by GUARD
        self.fund_contract = self.s.abi_contract(
            self.pp.process('Fund.sol', add_dev_code=True, contract_dir=contract_dir, addresses={
                'MistWallet': self.a2h(self.mist_wallet_contract)
            }),
            language='solidity', sender=keys[GUARD]
        )

    @staticmethod
    def a2h(contract):
        return "0x{}".format(contract.address.encode('hex'))

    def test(self):
        # Crowdfunding has started and startDate has been set.
        self.assertEqual(self.fund_contract.startDate(), self.s.block.timestamp)
        # Series A investor with address 0x0196b712a0459cbee711e7c1d34d2c85a9910379 has 5M shares
        self.assertEqual(self.fund_contract.balanceOf("0x0196b712a0459cbee711e7c1d34d2c85a9910379"), 5000000)
        # Half of the shares are already assigned to Workshop and series A investors.
        self.assertEqual(self.fund_contract.totalSupply(), MAX_TOKEN_COUNT / 2)
        # Backer 1 starts funding, but doesn't send enough money to buy a share, transaction fails.
        try:
            self.fund_contract.fund(value=ETH_VALUE_PER_SHARE - 1, sender=keys[BACKER_1])
        except TransactionFailed:
            self.assertEqual(self.fund_contract.balanceOf(accounts[BACKER_1]), 0)
        # Backer 1 increased his amount to buy some shares and sends them directly to the contract (default function)
        share_count_b1 = 1000
        self.s.send(keys[BACKER_1], self.fund_contract.address, ETH_VALUE_PER_SHARE * share_count_b1)
        # Backer 1 has now share_count shares
        self.assertEqual(self.fund_contract.balanceOf(accounts[BACKER_1]), share_count_b1)
        # Backer 1 cannot move his shares yet, because the Guard hasn't activated fungibility yet.
        try:
            self.fund_contract.transfer(accounts[BACKER_2], share_count_b1, sender=keys[BACKER_1])
        except TransactionFailed:
            self.assertEqual(self.fund_contract.balanceOf(accounts[BACKER_1]), share_count_b1)
        # Backer 2 invests too and wants to buy more shares than possible. He gets the maximum amount possible.
        share_count_b2 = MAX_TOKEN_COUNT / 2
        self.assertEqual(self.fund_contract.fund(value=ETH_VALUE_PER_SHARE * share_count_b2, sender=keys[BACKER_2]),
                         share_count_b2 - share_count_b1)
        # Backer 1 wants to buy more shares too, but the cap has been reached already
        self.assertEqual(self.fund_contract.totalSupply(), MAX_TOKEN_COUNT)
        try:
            self.fund_contract.fund(value=ETH_VALUE_PER_SHARE, sender=keys[BACKER_1])
        except TransactionFailed:
            self.assertEqual(self.fund_contract.balanceOf(accounts[BACKER_1]), share_count_b1)
        # Crowdfunding period ends
        self.s.block.timestamp += CROWDFUNDING_PERIOD
        # Backer 1 wants to withdraw his shares now, but fails, because the campaign ended successfully
        try:
            self.fund_contract.withdrawFunding(sender=keys[BACKER_1])
        except TransactionFailed:
            self.assertEqual(self.fund_contract.balanceOf(accounts[BACKER_1]), share_count_b1)
        # Workshop wants to withdraw its funding but it fails, because guard has not activated shares yet.
        fund_balance = self.fund_contract.fundBalance()
        try:
            self.fund_contract.withdrawForWorkshop(sender=keys[WS_1])
        except TransactionFailed:
            self.assertEqual(self.fund_contract.fundBalance(), fund_balance)
        # A third party tries to make shares fungible, but fails. Only guard is allowed to do this operation.
        try:
            self.fund_contract.issueTokens(sender=keys[WS_1])
        except TransactionFailed:
            pass
        self.assertFalse(self.fund_contract.sharesIssued())
        # Now the guard is doing the operation successfully.
        self.assertTrue(self.fund_contract.issueTokens(sender=keys[GUARD]))
        # Workshop withdraws funding successfully.
        self.assertTrue(self.fund_contract.withdrawForWorkshop(sender=keys[WS_1]))
        # The funding contract is empty now.
        self.assertEqual(self.s.block.get_balance(self.fund_contract.address), 0)
        # All funds have been transferred to the mist wallet.
        self.assertEqual(self.s.block.get_balance(self.mist_wallet_contract.address), fund_balance)
        # Workshop generated revenue and deposits revenue on the fund contract.
        revenue = 10**18 * 1000
        self.assertTrue(self.fund_contract.depositRevenue(value=revenue, sender=keys[WS_1]))
        self.assertEqual(self.fund_contract.revenueTotal(), revenue)
        # WS reinvests its revenue
        reinvest = False
        withdraw_data = self.fund_contract.translator.encode("withdrawRevenue", [reinvest])
        revenue_share = revenue * 400070000 / MAX_TOKEN_COUNT
        wallet_balance = self.s.block.get_balance(self.mist_wallet_contract.address)
        self.mist_wallet_contract.execute(self.fund_contract.address, 0, withdraw_data, value=0)
        # The wallet's balance increased.
        self.assertEqual(self.s.block.get_balance(self.mist_wallet_contract.address), wallet_balance + revenue_share)
        # Backer 1 withdraws his funding for himself
        revenue_share = revenue * share_count_b1 / MAX_TOKEN_COUNT
        self.assertEqual(self.fund_contract.withdrawRevenue(reinvest, sender=keys[BACKER_1]), revenue_share)
        # Backer 2 reinvests his revenue
        reinvest = True
        share_count_b2 = self.fund_contract.balanceOf(accounts[BACKER_2])
        revenue_share = revenue * share_count_b2 / MAX_TOKEN_COUNT
        wallet_balance = self.s.block.get_balance(self.mist_wallet_contract.address)
        self.assertEqual(self.fund_contract.withdrawRevenue(reinvest, sender=keys[BACKER_2]), revenue_share)
        # The wallet's balance increased.
        self.assertEqual(self.s.block.get_balance(self.mist_wallet_contract.address), wallet_balance + revenue_share)
