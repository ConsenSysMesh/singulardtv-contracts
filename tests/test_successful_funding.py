from abstract_test import *


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest tests.test_successful_funding
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)

    def test(self):
        # Setups cannot be called twice
        self.assertFalse(self.crowdfunding_contract.setup(0, 0))
        self.assertFalse(self.fund_contract.setup(0, 0))
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
        # Backer 1 wants to withdraw his investment now, but fails, because the campaign ended successfully
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
