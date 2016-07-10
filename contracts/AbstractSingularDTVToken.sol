import "AbstractToken.sol";


contract SingularDTVToken is Token {
    function issueTokens(address _for, uint tokenCount) returns (bool);
    function revokeTokens(address _for, uint tokenCount) returns (bool);
    function changeFund(address singularDTVFundAddress) returns (bool);
}