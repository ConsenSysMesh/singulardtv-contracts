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
     *  Enums
     */
    enum Stages {
        CrowdfundingGoingAndGoalNotReached,
        CrowdfundingEndedAndGoalNotReached,
        CrowdfundingGoingAndGoalReached,
        CrowdfundingEndedAndGoalReached,
        TokenFungiblePeriodEndedAndTokensNotFungible,
        TokenFungiblePeriodEndedAndTokensFungible
    }

    /*
     *  Storage
     */
    address public guard;
    uint public startDate;
    uint public fundBalance;

    // Initialize stage
    Stages public stage = Stages.CrowdfundingGoingAndGoalNotReached;

    /*
     *  Constants
     */
    uint constant MAX_TOKEN_COUNT = 500000000; // 0.5B tokens can be sold during sale
    uint constant CROWDFUNDING_PERIOD = 4 weeks; // 1 month
    uint constant TOKEN_ISSUANCE_PERIOD = 1 weeks ; // 1 week, guard has to issue tokens within one week after crowdfunding ends.
    uint constant TOKEN_LOCKING_PERIOD = 2 years; // 2 years
    uint constant ETH_VALUE_PER_SHARE = 1 finney; // 0.001 ETH
    uint constant ETH_TARGET = 100000 ether; // 100.000 ETH

    /*
     *  Modifiers
     */
    modifier onlyGuard() {
        // Only guard is allowed to do this action.
        if (msg.sender != guard) {
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

    modifier atStage(Stages _stage) {
        if (stage != _stage) {
            throw;
        }
        _
    }

    modifier atStageOR(Stages _stage1, Stages _stage2) {
        if (stage != _stage1 && stage != _stage2) {
            throw;
        }
        _
    }

    modifier timedTransitions() {
        if ((stage == Stages.CrowdfundingGoingAndGoalNotReached || stage == Stages.CrowdfundingGoingAndGoalReached)
            && now - startDate >= CROWDFUNDING_PERIOD)
        {
            if (stage == Stages.CrowdfundingGoingAndGoalNotReached) {
                stage = Stages.CrowdfundingEndedAndGoalNotReached;
            }
            else {
                stage = Stages.CrowdfundingEndedAndGoalReached;
            }
        }
        if (stage == Stages.CrowdfundingEndedAndGoalReached
            && now - startDate > CROWDFUNDING_PERIOD + TOKEN_ISSUANCE_PERIOD)
        {
            stage = Stages.TokenFungiblePeriodEndedAndTokensNotFungible;
        }
        _
    }

    /*
     *  Contract functions
     */
    /// @dev Allows user to fund the campaign if campaign is still going and cap not reached. Returns share count.
    function fund()
        timedTransitions
        atStageOR(Stages.CrowdfundingGoingAndGoalNotReached, Stages.CrowdfundingGoingAndGoalReached)
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
        // Update stage
        if (stage == Stages.CrowdfundingGoingAndGoalNotReached
            && singularDTVToken.totalSupply() * ETH_VALUE_PER_SHARE >= ETH_TARGET)
        {
            stage = Stages.CrowdfundingGoingAndGoalReached;
        }
        return tokenCount;
    }

    /// @dev Allows user to withdraw his funding if crowdfunding ended and target was not reached. Returns success.
    function withdrawFunding()
        timedTransitions
        atStageOR(Stages.CrowdfundingEndedAndGoalNotReached, Stages.TokenFungiblePeriodEndedAndTokensNotFungible)
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
    function withdrawForWorkshop()
        atStage(Stages.TokenFungiblePeriodEndedAndTokensFungible)
        returns (bool)
    {
        uint value = fundBalance;
        fundBalance = 0;
        if (value > 0  && !singularDTVFund.workshop().send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Only guard can trigger to make shares fungible. Returns success.
    function makeTokensFungible()
        timedTransitions
        atStage(Stages.CrowdfundingEndedAndGoalReached)
        onlyGuard
        returns (bool)
    {
        // Update stage
        stage = Stages.TokenFungiblePeriodEndedAndTokensFungible;
        // Set early investor tokens
        singularDTVToken.assignEarlyInvestorsBalances();
        return true;
    }

    /// @dev Returns if 2 years passed since beginning of crowdfunding.
    function towYearsPassed() returns (bool) {
        return now - startDate >= TOKEN_LOCKING_PERIOD;
    }

    function tokensFungible() returns (bool) {
        return stage == Stages.TokenFungiblePeriodEndedAndTokensFungible;
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

    /// @dev Contract constructor function sets guard and initial token balances.
    function SingularDTVCrowdfunding() {
        // Set guard address
        guard = msg.sender;
        // Set start-date of crowdfunding
        startDate = now;
    }

    /// @dev Fallback function always fails. Use fund function to fund the contract with Ether.
    function () {
        throw;
    }
}