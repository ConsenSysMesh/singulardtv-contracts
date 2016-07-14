import "AbstractSingularDTVToken.sol";
import "AbstractSingularDTVFund.sol";


/// @title Crowdfunding contract - Implements crowdfunding functionality.
/// @author Stefan George - <stefan.george@consensys.net>
contract SingularDTVCrowdfunding {

    /*
     *  External contracts
     */
    SingularDTVToken public singularDTVToken;
    SingularDTVFund public singularDTVFund;

    /*
     *  Storage
     */
    address public guard;
    uint public startDate;
    bool public tokensFungible;
    uint public fundBalance;

    /*
     *  Constants
     */
    uint constant MAX_TOKEN_COUNT = 1000000000; // 1B
    uint constant CROWDFUNDING_PERIOD = 4 weeks; // 1 month
    uint constant TOKEN_ISSUANCE_PERIOD = 1 weeks ; // 1 week, guard has to issue tokens within one week after crowdfunding ends.
    uint constant TOKEN_LOCKING_PERIOD = 2 years; // 2 years
    uint constant ETH_VALUE_PER_SHARE = 1 finney; // 0.001 ETH
    uint constant ETH_TARGET = 100000 ether; // 100.000 ETH

    /*
     *  Modifiers
     */
    modifier tokensAreFungible() {
        // Checks if the Guard already issued tokens.
        if (!tokensFungible) {
            throw;
        }
        _
    }

    modifier onlyGuard() {
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
        if (fundBalance >= ETH_TARGET && (tokensFungible || !tokensFungible && block.timestamp - startDate < CROWDFUNDING_PERIOD + TOKEN_ISSUANCE_PERIOD)) {
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
        if (singularDTVToken.totalSupply() == MAX_TOKEN_COUNT) {
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
    function contributeMsgValue()
        crowdfundingGoing
        capNotReached
        minInvestment
        returns (uint)
    {
        uint tokenCount = msg.value / ETH_VALUE_PER_SHARE;
        if (singularDTVToken.totalSupply() + tokenCount > MAX_TOKEN_COUNT) {
            // User wants to buy more shares than available. Set shares to possible maximum.
            tokenCount = MAX_TOKEN_COUNT - singularDTVToken.totalSupply();
            // Send change back to user.
            if (!msg.sender.send(msg.value - tokenCount * ETH_VALUE_PER_SHARE)) {
                throw;
            }
        }
        // Update fund's and user's balance and total supply of shares.
        fundBalance += tokenCount * ETH_VALUE_PER_SHARE;
        if (!singularDTVToken.issueTokens(msg.sender, tokenCount)) {
            // Tokens could not be issued.
            throw;
        }
        return tokenCount;
    }

    /// @dev Allows user to withdraw his funding if crowdfunding ended and target was not reached. Returns success.
    function withdrawFunding()
        crowdfundingEnded
        targetNotReachedOrGuardAbsent
        returns (bool)
    {
        // Update fund's and user's balance and total supply of shares.
        uint tokenCount = singularDTVToken.balanceOf(msg.sender);
        uint value = tokenCount * ETH_VALUE_PER_SHARE;
        fundBalance -= value;
        if (!singularDTVToken.revokeTokens(msg.sender, tokenCount)) {
            // Tokens could not be revoked.
            throw;
        }
        // Send funds back to user.
        if (value > 0  && !msg.sender.send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Withdraws funding for workshop. Returns success.
    function withdrawForWorkshop() tokensAreFungible returns (bool) {
        uint value = fundBalance;
        fundBalance = 0;
        if (value > 0  && !singularDTVFund.workshop().send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Only guard can trigger to make shares fungible. Returns success.
    function makeTokensFungible()
        crowdfundingEnded
        targetReached
        withinTokenIssuancePeriod
        onlyGuard
        returns (bool)
    {
        tokensFungible = true;
        return true;
    }

    /// @dev Returns max token count for campaign.
    function getMaxTokenCount() returns (uint) {
        return MAX_TOKEN_COUNT;
    }

    /// @dev Returns if 2 years passed since beginning of crowdfunding.
    function towYearsPassed() returns (bool) {
        return block.timestamp - startDate >= TOKEN_LOCKING_PERIOD;
    }

    /// @dev Setup function sets external contracts' addresses.
    /// @param singularDTVFundAddress Crowdfunding address.
    /// @param singularDTVTokenAddress Token address.
    function setup(address singularDTVFundAddress, address singularDTVTokenAddress) onlyGuard returns (bool) {
        if (address(singularDTVFund) == 0 || address(singularDTVToken) == 0) {
            singularDTVFund = SingularDTVFund(singularDTVFundAddress);
            singularDTVToken = SingularDTVToken(singularDTVTokenAddress);
            return true;
        }
        return false;
    }

    /// @dev Fallback function always fails.
    function () {
        throw;
    }

    /// @dev Contract constructor function sets guard and initial token balances.
    function SingularDTVCrowdfunding() {
        // Set guard address
        guard = msg.sender;
        // Set start-date of crowdfunding
        startDate = block.timestamp;
    }
}