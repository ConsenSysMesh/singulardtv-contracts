/// @title Token library - Standard token interface functions
/// @author Stefan George - <stefan.george@consensys.net>
library TokenLibrary {

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    struct Data {
        mapping (address => uint256) balances;
        mapping (address => mapping (address => uint256)) allowed;
        uint256 totalSupply;
    }

    function transfer(Data storage self, address _to, uint256 _value) returns (bool success) {
        if (self.balances[msg.sender] >= _value && _value > 0) {
            self.balances[msg.sender] -= _value;
            self.balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        else {
            return false;
        }
    }

    function transferFrom(Data storage self, address _from, address _to, uint256 _value) returns (bool success) {
        if (self.balances[_from] >= _value && self.allowed[_from][msg.sender] >= _value && _value > 0) {
            self.balances[_to] += _value;
            self.balances[_from] -= _value;
            self.allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        }
        else {
            return false;
        }
    }

    function approve(Data storage self, address _spender, uint256 _value) returns (bool success) {
        self.allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
}
