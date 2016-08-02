import "AbstractCampaign.sol";
import "AbstractSingularDTVFund.sol";
import "AbstractSingularDTVCrowdfunding.sol";


/// @title Crowdfunding contract - Implements crowdfunding functionality.
/// @author Stefan George - <stefan.george@consensys.net>
contract SingularDTVWeifund is Campaign {

    /*
     *  External contracts
     */
    SingularDTVFund constant singularDTVFund = SingularDTVFund({{SingularDTVFund}});
    SingularDTVCrowdfunding constant singularDTVCrowdfunding = SingularDTVCrowdfunding({{SingularDTVCrowdfunding}});

    string constant public contributeMethodABI = "fund()";
    string constant public refundMethodABI = "withdrawFunding()";
    string constant public payoutMethodABI = "withdrawForWorkshop()";

    /// @notice use to determine the beneficiary destination for the campaign
    /// @return the beneficiary address that will receive the campaign payout
    function beneficiary() constant returns(address) {
        return singularDTVFund.workshop();
    }

    /// @notice the time at which the campaign fails or succeeds
    /// @return the uint unix timestamp at which time the campaign expires
    function expiry() constant returns(uint256 timestamp) {
        return singularDTVCrowdfunding.startDate() + singularDTVCrowdfunding.CROWDFUNDING_PERIOD();
    }

    /// @notice the goal the campaign must reach in order for it to succeed
    /// @return the campaign funding goal specified in wei as a uint256
    function fundingGoal() constant returns(uint256 amount) {
        return singularDTVCrowdfunding.TOKEN_TARGET() * singularDTVCrowdfunding.valuePerShare();
    }

    /// @notice the goal the campaign must reach in order for it to succeed
    /// @return the campaign funding goal specified in wei as a uint256
    function amountRaised() constant returns(uint256 amount) {
        return singularDTVCrowdfunding.fundBalance();
    }

    function target() constant returns(address) {
        return singularDTVCrowdfunding;
    }
}
