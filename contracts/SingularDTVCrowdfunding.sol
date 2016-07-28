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
        CrowdfundingEndedAndGoalReached
    }

    /*
     *  Storage
     */
    address public guard;
    uint public startDate;
    uint public fundBalance;
    uint public ethValuePerShare = 1250 szabo; // 0.00125 ETH

    // investor address => investment in Wei
    mapping (address => uint) investments;

    // Initialize stage
    Stages public stage = Stages.CrowdfundingGoingAndGoalNotReached;

    /*
     *  Constants
     */
    uint constant CAP = 500000000; // 0.5B tokens can be sold during sale
    uint constant CROWDFUNDING_PERIOD = 4 weeks; // 1 month
    uint constant TOKEN_LOCKING_PERIOD = 2 years; // 2 years
    uint constant TOKEN_TARGET = 34000000; // 34M Tokens == 42,500 ETH

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
        if (msg.value < ethValuePerShare) {
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
                singularDTVToken.assignEarlyInvestorsBalances();
            }
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
        uint tokenCount = msg.value / ethValuePerShare;
        uint investment = msg.value; // Ether invested by backer.
        if (singularDTVToken.totalSupply() + tokenCount > CAP) {
            // User wants to buy more shares than available. Set shares to possible maximum.
            tokenCount = CAP - singularDTVToken.totalSupply();
            investment = tokenCount * ethValuePerShare;
            // Send change back to user.
            if (!msg.sender.send(msg.value - investment)) {
                throw;
            }
        }
        // Update fund's and user's balance and total supply of shares.
        fundBalance += investment;
        investments[msg.sender] += investment;
        if (!singularDTVToken.issueTokens(msg.sender, tokenCount)) {
            // Tokens could not be issued.
            throw;
        }
        // Update stage
        if (stage == Stages.CrowdfundingGoingAndGoalNotReached) {
            if (singularDTVToken.totalSupply() == CAP) {
                stage = Stages.CrowdfundingEndedAndGoalReached;
                singularDTVToken.assignEarlyInvestorsBalances();
            }
            else if (singularDTVToken.totalSupply() >= TOKEN_TARGET) {
                stage = Stages.CrowdfundingGoingAndGoalReached;
            }
        }
        return tokenCount;
    }

    /// @dev Allows user to withdraw his funding if crowdfunding ended and target was not reached. Returns success.
    function withdrawFunding()
        timedTransitions
        atStage(Stages.CrowdfundingEndedAndGoalNotReached)
        returns (bool)
    {
        // Update fund's and user's balance and total supply of shares.
        uint investment = investments[msg.sender];
        investments[msg.sender] = 0;
        fundBalance -= investment;
        uint tokenCount = singularDTVToken.balanceOf(msg.sender);
        if (!singularDTVToken.revokeTokens(msg.sender, tokenCount)) {
            // Tokens could not be revoked.
            throw;
        }
        // Send funds back to user.
        if (investment > 0  && !msg.sender.send(investment)) {
            throw;
        }
        return true;
    }

    /// @dev Withdraws funding for workshop. Returns success.
    function withdrawForWorkshop()
        atStage(Stages.CrowdfundingEndedAndGoalReached)
        returns (bool)
    {
        uint value = fundBalance;
        fundBalance = 0;
        if (value > 0  && !singularDTVFund.workshop().send(value)) {
            throw;
        }
        return true;
    }

    /// @dev Returns if 2 years passed since beginning of crowdfunding.
    function workshopWaited2Years() returns (bool) {
        return now - startDate >= TOKEN_LOCKING_PERIOD;
    }

    /// @dev Sets token value in Wei.
    /// @param valueInWei New value.
    function changeTokenValue(uint valueInWei) onlyGuard {
        ethValuePerShare = valueInWei;
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