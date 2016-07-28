import "AbstractSingularDTVToken.sol";


/// @title Fund contract - Implements revenue distribution.
/// @author Stefan George - <stefan.george@consensys.net>
contract SingularDTVFund {

    /*
     *  External contracts
     */
    SingularDTVToken public singularDTVToken;

    /*
     *  Storage
     */
    address public owner;
    address constant public workshop = {{MistWallet}};
    uint public totalRevenue;

    // User's address => Revenue at time of withdraw
    mapping (address => uint) public revenueAtTimeOfWithdraw;

    /*
     *  Modifiers
     */
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
    function depositRevenue() returns (bool) {
        totalRevenue += msg.value;
        return true;
    }

    /// @dev Withdraws revenue share for user. Returns revenue share.
    /// @param reinvestToWorkshop User can reinvest his revenue share. The workshop always reinvests its revenue share.
    function withdrawRevenue(address forAddress, bool reinvestToWorkshop) returns (uint) {
        uint value = singularDTVToken.balanceOf(forAddress) * (totalRevenue - revenueAtTimeOfWithdraw[forAddress]) / singularDTVToken.totalSupply();
        revenueAtTimeOfWithdraw[forAddress] = totalRevenue;
        if (reinvestToWorkshop || forAddress == workshop) {
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

    /// @dev Setup function sets external contracts' addresses.
    /// @param singularDTVTokenAddress Token address.
    function setup(address singularDTVTokenAddress) onlyOwner returns (bool) {
        if (address(singularDTVToken) == 0) {
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