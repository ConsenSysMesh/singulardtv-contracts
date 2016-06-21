import "AbstractToken.sol";
import "TokenLibrary.sol";


/// @title Fund contract - Implements crowdfunding and revenue distribution.
contract FundContract is AbstractTokenContract {

    {{dev_code}}

    /*
     *  Libraries
     */
    TokenLibrary.Data tokenData;

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
    uint constant TOKEN_LOCKING_PERIOD = 63072000; // 2 years
    uint constant CROWDFUNDING_PERIOD = 2592000; // 1 month
    uint constant TOKEN_ISSUANCE_PERIOD = 604800; // 1 week, guard has to issue tokens within one week after crowdfunding ends.
    uint constant ETH_VALUE_PER_SHARE = 10**15; // 0.001 ETH
    uint constant ETH_TARGET = 10**18 * 100000; // 100.000 ETH

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
        if (fundBalance >= ETH_TARGET || !sharesIssued && block.timestamp - startDate > CROWDFUNDING_PERIOD + TOKEN_ISSUANCE_PERIOD) {
            throw;
        }
        _
    }

    modifier capNotReached() {
        // Check that cap was not reached yet.
        if (tokenData.totalSupply == MAX_TOKEN_COUNT) {
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
    /// @dev Allows user to fund the campaign if campaign is still going and cap not reached. Returns success.
    function fund() crowdfundingGoing() capNotReached() minInvestment() returns (bool) {
        uint shareCount = msg.value / ETH_VALUE_PER_SHARE;
        if (tokenData.totalSupply + shareCount > MAX_TOKEN_COUNT) {
            // User wants to buy more shares than available. Set shares to possible maximum.
            shareCount = MAX_TOKEN_COUNT - tokenData.totalSupply;
            // Send change back to user.
            if (!msg.sender.send(msg.value - shareCount * ETH_VALUE_PER_SHARE)) {
                throw;
            }
        }
        // Update fund's and user's balance and total supply of shares.
        fundBalance += shareCount * ETH_VALUE_PER_SHARE;
        tokenData.balances[msg.sender] += shareCount;
        tokenData.totalSupply += shareCount;
        return true;
    }

    /// @dev Allows user to withdraw his funding if crowdfunding ended and target was not reached. Returns success.
    function withdrawFunding() crowdfundingEnded() targetNotReachedOrGuardAbsent() returns (bool) {
        // Update fund's and user's balance and total supply of shares.
        uint value = tokenData.balances[msg.sender] * ETH_VALUE_PER_SHARE;
        tokenData.totalSupply -= tokenData.balances[msg.sender];
        tokenData.balances[msg.sender] = 0;
        fundBalance -= value;
        // Send funds back to user.
        if (value > 0  && !msg.sender.send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Withdraws funding for workshop. Returns success.
    function withdrawForWorkshop() crowdfundingEnded() targetReached() sharesFungible() returns (bool) {
        uint value = fundBalance;
        fundBalance = 0;
        if (value > 0  && !workshop.send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Deposits revenue. Returns success.
    function depositRevenue() crowdfundingEnded() targetReached() sharesFungible() returns (bool) {
        revenueTotal += msg.value;
        return true;
    }

    /// @dev Withdraws revenue share for user. Returns revenue share.
    /// @param reinvestRevenue User can reinvest his revenue share. The workshop always reinvests its revenue share.
    function withdrawRevenue(bool reinvestRevenue) returns (uint) {
        uint value = tokenData.balances[msg.sender] * (revenueTotal - revenueAtTimeOfWithdraw[msg.sender]) / MAX_TOKEN_COUNT;
        revenueAtTimeOfWithdraw[msg.sender] = revenueTotal;
        if (reinvestRevenue || msg.sender == workshop) { // toDo: Should the reinvestment of workshop's revenue be enforced?
            if (value > 0 && !workshop.send(value)) {
                throw;
            }
        }
        else {
            if (value > 0 && !msg.sender.send(value)) {
                throw;
            }
        }
        return value;
    }

    /// @dev Only guard can trigger to make shares fungible. Returns success.
    function issueTokens() crowdfundingEnded() targetReached() onlyByGuard() returns (bool) {
        sharesIssued = true;
        return true;
    }

    /// @dev Default function triggers fund function.
    function () {
        fund();
    }

    /// @dev Contract constructor function sets guard and initial token balances.
    function FundContract() {
        // Set guard address
        guard = msg.sender;
        // Set initial share distribution
        tokenData.balances[workshop] = 400000000; // 400M
        // Series A investors
        tokenData.balances[0x478c576d2e1fa87536e90be202f42bcfa6ee78ee] = 500000000; // 50M
        tokenData.balances[0x478c576d2e1fa87536e90be202f42bcfa6ee78ef] = 500000000; // 50M
        tokenData.totalSupply = 5000000000; // 500M
        // Set start-date of crowdfunding
        startDate = block.timestamp;
    }

    /*
     * Implementation of standard token interface
     */
    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param to Address of token receiver.
    /// @param value Number of tokens to transfer.
    function transfer(address to, uint256 value) sharesFungible() afterTwoYears() returns (bool) {
        return TokenLibrary.transfer(tokenData, to, value);
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param from Address from where tokens are withdrawn.
    /// @param to Address to where tokens are sent.
    /// @param value Number of tokens to transfer.
    function transferFrom(address from, address to, uint256 value) sharesFungible() afterTwoYears() returns (bool) {
        return TokenLibrary.transferFrom(tokenData, from, to, value);
    }

    /// @dev Sets approved amount of tokens for spender. Returns success.
    /// @param spender Address of allowed account.
    /// @param value Number of approved tokens.
    function approve(address spender, uint256 value) returns (bool) {
        return TokenLibrary.approve(tokenData, spender, value);
    }

    /// @dev Returns number of tokens owned by given address.
    /// @param owner Address of token owner.
    function balanceOf(address owner) constant returns (uint256) {
        return tokenData.balances[owner];
    }

    /// @dev Returns number of allowed tokens for given address.
    /// @param owner Address of token owner.
    /// @param spender Address of token spender.
    function allowance(address owner, address spender) constant returns (uint256) {
      return tokenData.allowed[owner][spender];
    }

    /// @dev Returns total supply of tokens.
    function totalSupply() constant returns (uint256) {
        return tokenData.totalSupply;
    }
}