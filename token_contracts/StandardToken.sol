/*
This implements ONLY the standard functions and NOTHING else.
For a token like you would want to deploy in something like Mist, see HumanStandardToken.sol.

If you deploy this, you won't have anything useful.

Implements ERC 20 Token standard: https://github.com/ethereum/EIPs/issues/20
.*/

import "Token.sol";

contract StandardToken is Token {

    function transfer(address _to, uint256 _value) returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    function StandardToken() {
        // Series A investors
        balances[0x80ec09329f1eec74cc3733b5825fab4412ca5268] = 500 * 10000;
        balances[0x0f94dc84ce0f5fa2a8cc8d27a6969e25b5a39273] = 20 * 10000;
        balances[0x122b7eb5f629d806c8adb0baa0560266abb3ec80] = 45 * 10000;
        balances[0x13870d30fcdb7d7ae875668f2a1219225295d57c] = 5 * 10000;
        balances[0x26640e826547bc700b8c7a9cc2c1c39a4ab3cbb3] = 90 * 10000;
        balances[0x26bbfc6b23bc36e84447f061c6804f3a8b1a3698] = 25 * 10000;
        balances[0x2d37383a45b5122a27efade69f7180eee4d965da] = 127 * 10000;
        balances[0x2e79b81121193d55c4934c0f32ad3d0474ca7b9c] = 420 * 10000;
        balances[0x3114844fc0e3de03963bbd1d983ba17ca89ad010] = 500 * 10000;
        balances[0x378e6582e4e3723f7076c7769eef6febf51258e1] = 68 * 10000;
        balances[0x3e18530a4ee49a0357ffc8e74c08bfdee3915482] = 249 * 10000;
        balances[0x43fed1208d25ca0ef5681a5c17180af50c19f826] = 10 * 10000;
        balances[0x4f183b18302c0ac5804b8c455018efc51af15a56] = 1 * 10000;
        balances[0x55a886834658ccb6f26c39d5fdf6d833df3a276a] = 10 * 10000;
        balances[0x5faa1624422db662c654ab35ce57bf3242888937] = 500 * 10000;
        balances[0x6407b662b306e2353b627488da952337a5a0bbaa] = 500 * 10000;
        balances[0x66c334fff8c8b8224b480d8da658ca3b032fe625] = 1000 * 10000;
        balances[0x6c24991c6a40cd5ad6fab78388651fb324b35458] = 25 * 10000;
        balances[0x781ba492f786b2be48c2884b733874639f50022c] = 50 * 10000;
        balances[0x79b48f6f1ac373648c509b74a2c04a3281066457] = 200 * 10000;
        balances[0x8280f94b16ea65890910a555b01e363a62f5cac1] = 1000 * 10000;
        balances[0x835898804ed30e20aa29f2fe35c9f225175b049f] = 10 * 10000;
        balances[0x889f06275193b982e0679f7f193b5bdad97b0e84] = 1000 * 10000;
        balances[0x93bf1d2b1c8304f61176e7a5a36a3efd658b1b33] = 5 * 10000;
        balances[0x93c56ea8848150389e0917de868b0a23c87cf7b1] = 279 * 10000;
        balances[0x9adc0215372e4ffd8c89621a6bd9cfddf230349f] = 55 * 10000;
        balances[0xae4dbd3dae66722315541d66fe9457b342ac76d9] = 50 * 10000;
        balances[0xb7049710014166c166af8ca0431c0964f182b09f] = 899 * 10000;
        balances[0xbae02fe006f115e45b372f2ddc053eedca2d6fff] = 180 * 10000;
        balances[0xcc835821f643e090d8157de05451b416cd1202c4] = 30 * 10000;
        balances[0xce75342b92a7d0b1a2c6e9835b6b85787e12e585] = 67 * 10000;
        balances[0xd2b388467d9d0c30bab0a68070c6f49c473583a0] = 99 * 10000;
        balances[0xdca0724ddde95bbace1b557cab4375d9a813da49] = 350 * 10000;
        balances[0xe3ef62165b60cac0fcbe9c2dc6a03aab4c5c8462] = 15 * 10000;
        balances[0xe4f7d5083baeea7810b6d816581bb0ee7cd4b6f4] = 1056 * 10000;
        balances[0xef08eb55d3482973c178b02bd4d5f2cea420325f] = 8 * 10000;
        balances[0xfdecc9f2ee374cedc94f72ab4da2de896ce58c19] = 500 * 10000;
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalSupply;
}
