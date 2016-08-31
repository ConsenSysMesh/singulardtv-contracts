import "StandardToken.sol";
import "AbstractSingularDTVFund.sol";
import "AbstractSingularDTVCrowdfunding.sol";


/// @title Token contract - Implements token issuance.
/// @author Stefan George - <stefan.george@consensys.net>
contract SingularDTVToken is StandardToken {

    /*
     *  External contracts
     */
    SingularDTVFund constant singularDTVFund = SingularDTVFund({{SingularDTVFund}});
    SingularDTVCrowdfunding constant singularDTVCrowdfunding = SingularDTVCrowdfunding({{SingularDTVCrowdfunding}});

    /*
     *  Token meta data
     */
    string constant public name = "SingularDTV";
    string constant public symbol = "SNGLS";
    uint8 constant public decimals = 0;

    /*
     *  Modifiers
     */
    modifier noEther() {
        if (msg.value > 0) {
            throw;
        }
        _
    }

    modifier workshopWaitedOneYear() {
        // Workshop can only transfer shares after a two years period.
        if (msg.sender == singularDTVFund.workshop() && !singularDTVCrowdfunding.oneYearPassed()) {
            throw;
        }
        _
    }

    modifier isCrowdfundingContract () {
        // Only crowdfunding contract is allowed to proceed.
        if (msg.sender != address(singularDTVCrowdfunding)) {
            throw;
        }
        _
    }

    /*
     *  Contract functions
     */
    /// @dev Crowdfunding contract issues new tokens for address. Returns success.
    /// @param _for Address of receiver.
    /// @param tokenCount Number of tokens to issue.
    function issueTokens(address _for, uint tokenCount)
        external
        isCrowdfundingContract
        returns (bool)
    {
        if (tokenCount == 0) {
            return false;
        }
        balances[_for] += tokenCount;
        totalSupply += tokenCount;
        return true;
    }

    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param to Address of token receiver.
    /// @param value Number of tokens to transfer.
    function transfer(address to, uint256 value)
        noEther
        workshopWaitedOneYear
        returns (bool)
    {
        // Both parties withdraw their revenue first
        singularDTVFund.softWithdrawRevenueFor(msg.sender);
        singularDTVFund.softWithdrawRevenueFor(to);
        return super.transfer(to, value);
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param from Address from where tokens are withdrawn.
    /// @param to Address to where tokens are sent.
    /// @param value Number of tokens to transfer.
    function transferFrom(address from, address to, uint256 value)
        noEther
        workshopWaitedOneYear
        returns (bool)
    {
        // Both parties withdraw their revenue first
        singularDTVFund.softWithdrawRevenueFor(from);
        singularDTVFund.softWithdrawRevenueFor(to);
        return super.transferFrom(from, to, value);
    }

    /// @dev Contract constructor function sets initial token balances.
    function SingularDTVToken() noEther {
        // Set initial share distribution
        balances[singularDTVFund.workshop()] = 400000000; // ~400M
        // Series A investors
        balances[0x0196b712a0459cbee711e7c1d34d2c85a9910379] = 5000000;
        balances[0x0f94dc84ce0f5fa2a8cc8d27a6969e25b5a39273] = 200000;
        balances[0x122b7eb5f629d806c8adb0baa0560266abb3ec80] = 450000;
        balances[0x13870d30fcdb7d7ae875668f2a1219225295d57c] = 50000;
        balances[0x26640e826547bc700b8c7a9cc2c1c39a4ab3cbb3] = 900000;
        balances[0x26bbfc6b23bc36e84447f061c6804f3a8b1a3698] = 250000;
        balances[0x2d37383a45b5122a27efade69f7180eee4d965da] = 1270000;
        balances[0x2e79b81121193d55c4934c0f32ad3d0474ca7b9c] = 4200000;
        balances[0x3114844fc0e3de03963bbd1d983ba17ca89ad010] = 5000000;
        balances[0x378e6582e4e3723f7076c7769eef6febf51258e1] = 680000;
        balances[0x3e18530a4ee49a0357ffc8e74c08bfdee3915482] = 2490000;
        balances[0x43fed1208d25ca0ef5681a5c17180af50c19f826] = 100000;
        balances[0x4f183b18302c0ac5804b8c455018efc51af15a56] = 10000;
        balances[0x55a886834658ccb6f26c39d5fdf6d833df3a276a] = 100000;
        balances[0x5faa1624422db662c654ab35ce57bf3242888937] = 5000000;
        balances[0x6407b662b306e2353b627488da952337a5a0bbaa] = 5000000;
        balances[0x66c334fff8c8b8224b480d8da658ca3b032fe625] = 10000000;
        balances[0x6c24991c6a40cd5ad6fab78388651fb324b35458] = 250000;
        balances[0x781ba492f786b2be48c2884b733874639f50022c] = 500000;
        balances[0x79b48f6f1ac373648c509b74a2c04a3281066457] = 2000000;
        balances[0x835898804ed30e20aa29f2fe35c9f225175b049f] = 100000;
        balances[0x93c56ea8848150389e0917de868b0a23c87cf7b1] = 2790000;
        balances[0x93f959df3df3c6ee01ee9748327b881b2137bf2a] = 450000;
        balances[0x9adc0215372e4ffd8c89621a6bd9cfddf230349f] = 550000;
        balances[0xae4dbd3dae66722315541d66fe9457b342ac76d9] = 500000;
        balances[0xbae02fe006f115e45b372f2ddc053eedca2d6fff] = 1800000;
        balances[0xcc835821f643e090d8157de05451b416cd1202c4] = 300000;
        balances[0xce75342b92a7d0b1a2c6e9835b6b85787e12e585] = 670000;
        balances[0xd2b388467d9d0c30bab0a68070c6f49c473583a0] = 990000;
        balances[0xdca0724ddde95bbace1b557cab4375d9a813da49] = 3500000;
        balances[0xe3ef62165b60cac0fcbe9c2dc6a03aab4c5c8462] = 150000;
        balances[0xe4f7d5083baeea7810b6d816581bb0ee7cd4b6f4] = 10560000;
        balances[0xef08eb55d3482973c178b02bd4d5f2cea420325f] = 80000;
        balances[0xfdecc9f2ee374cedc94f72ab4da2de896ce58c19] = 5000000;
        balances[0xe5ff71dc1dea8cd2552eec59e9a5e8813da9bb01] = 29110000;
        totalSupply = 500000000; // 500M
    }
}
