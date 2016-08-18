from abstract_test import *


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest tests.test_unsuccessful_funding
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)

    def test(self):
        # Backer 1 is buying some shares by using the fund function.
        share_count_b1 = 1000
        investment_1 = ETH_VALUE_PER_SHARE * share_count_b1
        self.assertEqual(
            self.crowdfunding_contract.fund(value=investment_1, sender=keys[BACKER_1]),
            share_count_b1
        )
        # Backer 1 has now share_count shares
        self.assertEqual(self.token_contract.balanceOf(accounts[BACKER_1]), share_count_b1)
        # Backer 2 is buying some shares by using the fund function. Price increased because time passed.
        self.s.block.timestamp += DAY * 10
        share_count_b2 = 1000
        investment_2 = ETH_VALUE_PER_SHARE * 2 * share_count_b2
        self.assertEqual(
            self.crowdfunding_contract.fund(value=investment_2 + 1, sender=keys[BACKER_2]),
            share_count_b2
        )
        # Backer 1 has now share_count shares
        self.assertEqual(self.token_contract.balanceOf(accounts[BACKER_2]), share_count_b2)
        # Base value is changed by owner to the double
        self.assertTrue(self.crowdfunding_contract.changeBaseValue(2500000000000000, sender=keys[OWNER]))
        # Backer 2 is buying some more shares later. Price increased again because more time passed.
        self.s.block.timestamp += DAY * 4
        share_count_b2_2 = 1000
        investment_3 = ETH_VALUE_PER_SHARE * 2 * 3 * share_count_b2
        self.assertEqual(
            self.crowdfunding_contract.fund(value=investment_3, sender=keys[BACKER_2]),
            share_count_b2_2
        )
        # Backer 1 has now shares from both investments
        self.assertEqual(self.token_contract.balanceOf(accounts[BACKER_2]), share_count_b2 + share_count_b2_2)
        # Crowdfunding period ends
        self.s.block.timestamp += CROWDFUNDING_PERIOD
        # Workshop wants to withdraws funding but fails, because campaign was unsuccessful.
        self.assertRaises(TransactionFailed, self.crowdfunding_contract.withdrawForWorkshop, sender=keys[WS_1])
        # The funding contract has still all investments.
        self.assertEqual(self.s.block.get_balance(self.crowdfunding_contract.address), investment_1 + investment_2 + investment_3)
        # Workshop tries to deposit revenue but fails, because campaign ended unsuccessful.
        self.assertRaises(TransactionFailed, self.fund_contract.depositRevenue, value=1, sender=keys[WS_1])
        # Backer 2 withdraws his investment.
        self.assertTrue(self.crowdfunding_contract.withdrawFunding(sender=keys[BACKER_2]))
        # Only investment from backer 1 is left
        self.assertEqual(self.s.block.get_balance(self.crowdfunding_contract.address), investment_1)
        # Backer 1 withdraws his investment.
        self.assertTrue(self.crowdfunding_contract.withdrawFunding(sender=keys[BACKER_1]))
        # Contract is empty now
        self.assertEqual(self.s.block.get_balance(self.crowdfunding_contract.address), 0)
