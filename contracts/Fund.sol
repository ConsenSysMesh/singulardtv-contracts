import "StandardToken.sol";


/// @title Fund contract - Implements crowdfunding and revenue distribution.
/// @author Stefan George - <stefan.george@consensys.net>
contract FundContract is StandardToken {

    /*
     *  Storage
     */
    address public workshop = {{MistWallet}};
    address public guard;
    uint public fundBalance;
    uint public revenueTotal;
    uint public startDate;
    bool public sharesIssued;
    // User's address => Revenue at time of withdraw
    mapping (address => uint) public revenueAtTimeOfWithdraw;

    /*
     *  Constants
     */
    uint constant MAX_TOKEN_COUNT = 1000000000; // 1B
    uint constant TOKEN_LOCKING_PERIOD = 2 years; // 2 years
    uint constant CROWDFUNDING_PERIOD = 4 weeks; // 1 month
    uint constant TOKEN_ISSUANCE_PERIOD = 1 weeks ; // 1 week, guard has to issue tokens within one week after crowdfunding ends.
    uint constant ETH_VALUE_PER_SHARE = 1 finney; // 0.001 ETH
    uint constant ETH_TARGET = 100000 ether; // 100.000 ETH

    /*
     *  Token meta data
     */
    string public name = "SingularDTV";
    string public symbol = "STV";
    uint8 public decimals = 0;

    /*
     *  Modifiers
     */
    modifier afterTwoYears() {
        // Workshop can only transfer shares after a two years period.
        if (msg.sender == workshop && block.timestamp - startDate < TOKEN_LOCKING_PERIOD) {
            throw;
        }
        _
    }

    modifier sharesFungible() {
        // Checks if the Guard already issued tokens.
        if (!sharesIssued) {
            throw;
        }
        _
    }

    modifier onlyByGuard() {
        // Only guard is allowed to do this action.
        if (msg.sender != guard) {
            throw;
        }
        _
    }

    modifier crowdfundingEnded() {
        // Check crowdfunding period is over.
        if (block.timestamp - startDate < CROWDFUNDING_PERIOD) {
            throw;
        }
        _
    }

    modifier crowdfundingGoing() {
        // Check crowdfunding is not over.
        if (block.timestamp - startDate >= CROWDFUNDING_PERIOD) {
            throw;
        }
        _
    }

    modifier targetReached() {
        // Check target was reached.
        if (fundBalance < ETH_TARGET) {
            throw;
        }
        _
    }

    modifier targetNotReachedOrGuardAbsent() {
        // Check target balance was not reached yet or guard did not issue tokens in time.
        if (fundBalance >= ETH_TARGET && (sharesIssued || !sharesIssued && block.timestamp - startDate < CROWDFUNDING_PERIOD + TOKEN_ISSUANCE_PERIOD)) {
            throw;
        }
        _
    }

    modifier withinTokenIssuancePeriod() {
        // Check target balance was not reached yet or guard did not issue tokens in time.
        if (block.timestamp - startDate > CROWDFUNDING_PERIOD + TOKEN_ISSUANCE_PERIOD) {
            throw;
        }
        _
    }

    modifier capNotReached() {
        // Check that cap was not reached yet.
        if (totalSupply == MAX_TOKEN_COUNT) {
            throw;
        }
        _
    }

    modifier minInvestment() {
        // User has to invest at least the ether value of one share.
        if (msg.value < ETH_VALUE_PER_SHARE) {
            throw;
        }
        _
    }

    /*
     *  Contract functions
     */
    /// @dev Allows user to fund the campaign if campaign is still going and cap not reached. Returns share count.
    function fund() crowdfundingGoing() capNotReached() minInvestment() returns (uint) {
        uint shareCount = msg.value / ETH_VALUE_PER_SHARE;
        if (totalSupply + shareCount > MAX_TOKEN_COUNT) {
            // User wants to buy more shares than available. Set shares to possible maximum.
            shareCount = MAX_TOKEN_COUNT - totalSupply;
            // Send change back to user.
            if (!msg.sender.send(msg.value - shareCount * ETH_VALUE_PER_SHARE)) {
                throw;
            }
        }
        // Update fund's and user's balance and total supply of shares.
        fundBalance += shareCount * ETH_VALUE_PER_SHARE;
        balances[msg.sender] += shareCount;
        totalSupply += shareCount;
        return shareCount;
    }

    /// @dev Allows user to withdraw his funding if crowdfunding ended and target was not reached. Returns success.
    function withdrawFunding() crowdfundingEnded() targetNotReachedOrGuardAbsent() returns (bool) {
        // Update fund's and user's balance and total supply of shares.
        uint value = balances[msg.sender] * ETH_VALUE_PER_SHARE;
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
        fundBalance -= value;
        // Send funds back to user.
        if (value > 0  && !msg.sender.send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Withdraws funding for workshop. Returns success.
    function withdrawForWorkshop() sharesFungible() returns (bool) {
        uint value = fundBalance;
        fundBalance = 0;
        if (value > 0  && !workshop.send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Deposits revenue. Returns success.
    function depositRevenue() sharesFungible() returns (bool) {
        revenueTotal += msg.value;
        return true;
    }

    /// @dev Withdraws revenue share for user. Returns revenue share.
    /// @param reinvestRevenue User can reinvest his revenue share. The workshop always reinvests its revenue share.
    function withdrawRevenue(address forAddress, bool reinvestRevenue) returns (uint) {
        uint value = balances[forAddress] * (revenueTotal - revenueAtTimeOfWithdraw[forAddress]) / MAX_TOKEN_COUNT;
        revenueAtTimeOfWithdraw[forAddress] = revenueTotal;
        if (reinvestRevenue || forAddress == workshop) { // toDo: Should the reinvestment of workshop's revenue be enforced?
            if (value > 0 && !workshop.send(value)) {
                throw;
            }
        }
        else {
            if (value > 0 && !forAddress.send(value)) {
                throw;
            }
        }
        return value;
    }

    /// @dev Only guard can trigger to make shares fungible. Returns success.
    function issueTokens() crowdfundingEnded() targetReached() withinTokenIssuancePeriod() onlyByGuard() returns (bool) {
        sharesIssued = true;
        return true;
    }

    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param to Address of token receiver.
    /// @param value Number of tokens to transfer.
    function transfer(address to, uint256 value) sharesFungible() afterTwoYears() returns (bool) {
        // Both parties withdraw their revenue first
        withdrawRevenue(msg.sender, false);
        withdrawRevenue(to, false);
        if (super.transfer(to, value)) {
            return true;
        }
        return false;
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param from Address from where tokens are withdrawn.
    /// @param to Address to where tokens are sent.
    /// @param value Number of tokens to transfer.
    function transferFrom(address from, address to, uint256 value) sharesFungible() afterTwoYears() returns (bool) {
        // Both parties withdraw their revenue first
        withdrawRevenue(from, false);
        withdrawRevenue(to, false);
        if (super.transferFrom(from, to, value)) {
            return true;
        }
        return false;
    }

    /// @dev Default function triggers fund function.
    function () {
        // This fallback function needs more than 2,300 gas.
        // Fallback function for funding is required to be compatible with WeiFund.
        fund();
    }

    /// @dev Contract constructor function sets guard and initial token balances.
    function FundContract() {
        // Set guard address
        guard = msg.sender;
        // Set initial share distribution
        balances[workshop] = 400070000; // ~400M
        // Series A investors
        balances[0x0196b712a0459cbee711e7c1d34d2c85a9910379] = 500 * 10000;
        balances[0x0f94dc84ce0f5fa2a8cc8d27a6969e25b5a39273] = 20 * 10000;
        balances[0x122b7eb5f629d806c8adb0baa0560266abb3ec80] = 45 * 10000;
        balances[0x13870d30fcdb7d7ae875668f2a1219225295d57c] = 5 * 10000;
        balances[0x26640e826547bc700b8c7a9cc2c1c39a4ab3cbb3] = 90 * 10000;
        balances[0x26bbfc6b23bc36e84447f061c6804f3a8b1a3698] = 25 * 10000;
        balances[0x2d37383a45b5122a27efade69f7180eee4d965da] = 127 * 10000;
        balances[0x2e79b81121193d55c4934c0f32ad3d0474ca7b9c] = 420 * 10000;
        balances[0x3114844fc0e3de03963bbd1d983ba17ca89ad010] = 500 * 10000;
        balances[0x378e6582e4e3723f7076c7769eef6febf51258e1] = 68 * 10000;
        balances[0x3e18530a4ee49a0357ffc8e74c08bfdee3915482] = 249 * 10000;
        balances[0x43fed1208d25ca0ef5681a5c17180af50c19f826] = 10 * 10000;
        balances[0x4f183b18302c0ac5804b8c455018efc51af15a56] = 1 * 10000;
        balances[0x55a886834658ccb6f26c39d5fdf6d833df3a276a] = 10 * 10000;
        balances[0x5faa1624422db662c654ab35ce57bf3242888937] = 500 * 10000;
        balances[0x6407b662b306e2353b627488da952337a5a0bbaa] = 500 * 10000;
        balances[0x66c334fff8c8b8224b480d8da658ca3b032fe625] = 1000 * 10000;
        balances[0x6c24991c6a40cd5ad6fab78388651fb324b35458] = 25 * 10000;
        balances[0x781ba492f786b2be48c2884b733874639f50022c] = 50 * 10000;
        balances[0x79b48f6f1ac373648c509b74a2c04a3281066457] = 200 * 10000;
        balances[0x8280f94b16ea65890910a555b01e363a62f5cac1] = 1000 * 10000;
        balances[0x835898804ed30e20aa29f2fe35c9f225175b049f] = 10 * 10000;
        balances[0x889f06275193b982e0679f7f193b5bdad97b0e84] = 1000 * 10000;
        balances[0x93bf1d2b1c8304f61176e7a5a36a3efd658b1b33] = 5 * 10000;
        balances[0x93c56ea8848150389e0917de868b0a23c87cf7b1] = 279 * 10000;
        balances[0x9adc0215372e4ffd8c89621a6bd9cfddf230349f] = 55 * 10000;
        balances[0xae4dbd3dae66722315541d66fe9457b342ac76d9] = 50 * 10000;
        balances[0xb7049710014166c166af8ca0431c0964f182b09f] = 899 * 10000;
        balances[0xbae02fe006f115e45b372f2ddc053eedca2d6fff] = 180 * 10000;
        balances[0xcc835821f643e090d8157de05451b416cd1202c4] = 30 * 10000;
        balances[0xce75342b92a7d0b1a2c6e9835b6b85787e12e585] = 67 * 10000;
        balances[0xd2b388467d9d0c30bab0a68070c6f49c473583a0] = 99 * 10000;
        balances[0xdca0724ddde95bbace1b557cab4375d9a813da49] = 350 * 10000;
        balances[0xe3ef62165b60cac0fcbe9c2dc6a03aab4c5c8462] = 15 * 10000;
        balances[0xe4f7d5083baeea7810b6d816581bb0ee7cd4b6f4] = 1056 * 10000;
        balances[0xef08eb55d3482973c178b02bd4d5f2cea420325f] = 8 * 10000;
        balances[0xfdecc9f2ee374cedc94f72ab4da2de896ce58c19] = 500 * 10000;
        
        totalSupply = 500000000; // 500M
        // Set start-date of crowdfunding
        startDate = block.timestamp;
    }
}