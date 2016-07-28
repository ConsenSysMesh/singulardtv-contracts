import "AbstractSingularDTVToken.sol";
import "AbstractSingularDTVFund.sol";
import "SingularDTVWeifund.sol";


/// @title Crowdfunding contract - Implements crowdfunding functionality.
/// @author Stefan George - <stefan.george@consensys.net>
contract SingularDTVCrowdfunding is SingularDTVWeifund {

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
    uint public valuePerShare = 1250 szabo; // 0.00125 ETH

    // investor address => investment in Wei
    mapping (address => uint) public investments;

    // Initialize stage
    Stages public stage = Stages.CrowdfundingGoingAndGoalNotReached;

    /*
     *  Constants
     */
    uint constant public CAP = 500000000; // 0.5B tokens can be sold during sale
    uint constant public CROWDFUNDING_PERIOD = 4 weeks; // 1 month
    uint constant public TOKEN_LOCKING_PERIOD = 2 years; // 2 years
    uint constant public TOKEN_TARGET = 34000000; // 34M Tokens == 42,500 ETH

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
        if (msg.value < valuePerShare) {
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
        if (now - startDate >= CROWDFUNDING_PERIOD) {
            if (stage == Stages.CrowdfundingGoingAndGoalNotReached) {
                stage = Stages.CrowdfundingEndedAndGoalNotReached;
            }
            else if (stage == Stages.CrowdfundingGoingAndGoalReached) {
                stage = Stages.CrowdfundingEndedAndGoalReached;
                singularDTVToken.assignEarlyInvestorsBalances();
            }
        }
        _
    }

    /*
     *  Contract functions
     */

    function checkInvariants() {
        if (fundBalance != this.balance) {
            throw;
        }
    }

    /// @dev Allows user to fund the campaign if campaign is still going and cap not reached. Returns share count.
    function fund()
        timedTransitions
        atStageOR(Stages.CrowdfundingGoingAndGoalNotReached, Stages.CrowdfundingGoingAndGoalReached)
        minInvestment
        returns (uint)
    {
        uint tokenCount = msg.value / valuePerShare;
        uint investment = msg.value; // Ether invested by backer.
        if (singularDTVToken.totalSupply() + tokenCount > CAP) {
            // User wants to buy more shares than available. Set shares to possible maximum.
            tokenCount = CAP - singularDTVToken.totalSupply();
            investment = tokenCount * valuePerShare;
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
        checkInvariants();
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
        checkInvariants();
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
        checkInvariants;
        return true;
    }

    /// @dev Returns if 2 years passed since beginning of crowdfunding.
    function workshopWaited2Years() returns (bool) {
        return now - startDate >= TOKEN_LOCKING_PERIOD;
    }

    /// @dev Sets token value in Wei.
    /// @param valueInWei New value.
    function changeTokenValue(uint valueInWei) onlyGuard {
        valuePerShare = valueInWei;
    }

    /// @notice use to determine the beneficiary destination for the campaign
    /// @return the beneficiary address that will receive the campaign payout
    function beneficiary() constant returns(address) {
        return singularDTVFund.workshop();
    }

    /// @notice the time at which the campaign fails or succeeds
    /// @return the uint unix timestamp at which time the campaign expires
    function expiry() constant returns(uint256 timestamp) {
        return startDate + CROWDFUNDING_PERIOD;
    }

    /// @notice the goal the campaign must reach in order for it to succeed
    /// @return the campaign funding goal specified in wei as a uint256
    function fundingGoal() constant returns(uint256 amount) {
        return TOKEN_TARGET * valuePerShare;
    }

    /// @notice the goal the campaign must reach in order for it to succeed
    /// @return the campaign funding goal specified in wei as a uint256
    function amountRaised() constant returns(uint256 amount) {
        return fundBalance;
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
