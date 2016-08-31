from abstract_test import *


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest tests.test_break_invariant
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)

    def test(self):
        # Backer 1 is successfully buying some shares by using the fund function.
        share_count_b1 = 1000
        investment = ETH_VALUE_PER_SHARE * share_count_b1
        self.assertEqual(
            self.crowdfunding_contract.fund(value=investment, sender=keys[BACKER_1]),
            share_count_b1
        )
        # Backer 1 has now share_count shares
        self.assertEqual(self.token_contract.balanceOf(accounts[BACKER_1]), share_count_b1)
        self.assertEqual(self.s.block.get_balance(self.crowdfunding_contract.address), investment)
        # Someone tries to call the emergencyCall but nothing happens as the balances are correct.
        self.assertFalse(self.crowdfunding_contract.emergencyCall())
        self.assertEqual(self.s.block.get_balance(self.mist_wallet_contract.address), 0)
        # Someone found a bug in the EVM, which allows to set the balance of the contract.
        new_balance = 1000
        self.s.block.set_balance(self.crowdfunding_contract.address, new_balance)
        self.assertEqual(self.s.block.get_balance(self.crowdfunding_contract.address), new_balance)
        # This is inconsistent with the invariant, emergencyCall is working now.
        self.assertTrue(self.crowdfunding_contract.emergencyCall())
        self.assertEqual(self.s.block.get_balance(self.mist_wallet_contract.address), new_balance)
