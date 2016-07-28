/// @title Crowdfunding contract - Implements crowdfunding functionality.
/// @author Stefan George - <stefan.george@consensys.net>
contract SingularDTVWeifund is Campaign {
    string constant public contributeMethodABI = "fund()";
    string constant public refundMethodABI  = "withdrawFunding()";
    string constant public payoutMethodABI  = "withdrawForWorkshop()";
}
