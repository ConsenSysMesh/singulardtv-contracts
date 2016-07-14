import "AbstractSingularDTVToken.sol";
import "AbstractSingularDTVCrowdfunding.sol";


/// @title Fund contract - Implements revenue distribution.
/// @author Stefan George - <stefan.george@consensys.net>
contract SingularDTVFund {

    /*
     *  External contracts
     */
    SingularDTVCrowdfunding public singularDTVCrowdfunding;
    SingularDTVToken public singularDTVToken;

    /*
     *  Storage
     */
    address public owner;
    address public workshop = {{MistWallet}};
    uint public totalRevenue;

    // User's address => Revenue at time of withdraw
    mapping (address => uint) public revenueAtTimeOfWithdraw;

    /*
     *  Modifiers
     */
    modifier tokensAreFungible() {
        // Checks if the Guard already issued tokens.
        if (!singularDTVCrowdfunding.tokensFungible()) {
            throw;
        }
        _
    }

    modifier isWorkshop () {
        // Only workshop is allowed to proceed.
        if (msg.sender != workshop) {
            throw;
        }
        _
    }

    modifier onlyOwner() {
        // Only guard is allowed to do this action.
        if (msg.sender != owner) {
            throw;
        }
        _
    }

    /*
     *  Contract functions
     */
    /// @dev Deposits revenue. Returns success.
    function depositRevenue() tokensAreFungible returns (bool) {
        totalRevenue += msg.value;
        return true;
    }

    /// @dev Withdraws revenue share for user. Returns revenue share.
    /// @param reinvestRevenue User can reinvest his revenue share. The workshop always reinvests its revenue share.
    function withdrawRevenue(address forAddress, bool reinvestRevenue) returns (uint) {
        uint value = singularDTVToken.balanceOf(forAddress) * (totalRevenue - revenueAtTimeOfWithdraw[forAddress]) / singularDTVCrowdfunding.getMaxTokenCount();
        revenueAtTimeOfWithdraw[forAddress] = totalRevenue;
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

    /// @dev Change fund. Returns success.
    /// @param singularDTVFundAddress New fund address.
    function changeFund(address singularDTVFundAddress) isWorkshop returns (bool) { // toDo: What limitations should there be to upgrade?
        return singularDTVToken.changeFund(singularDTVFundAddress);
    }

    /// @dev Setup function sets external contracts' addresses.
    /// @param singularDTVCrowdfundingAddress Crowdfunding address.
    /// @param singularDTVTokenAddress Token address.
    function setup(address singularDTVCrowdfundingAddress, address singularDTVTokenAddress) onlyOwner returns (bool) {
        if (address(singularDTVCrowdfunding) == 0 || address(singularDTVToken) == 0) {
            singularDTVCrowdfunding = SingularDTVCrowdfunding(singularDTVCrowdfundingAddress);
            singularDTVToken = SingularDTVToken(singularDTVTokenAddress);
            return true;
        }
        return false;
    }

    /// @dev Contract constructor function sets guard and initial token balances.
    function SingularDTVFund() {
        // Set owner address
        owner = msg.sender;
    }
}