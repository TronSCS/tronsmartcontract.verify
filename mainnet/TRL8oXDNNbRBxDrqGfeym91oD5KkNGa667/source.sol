pragma solidity ^0.4.25;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a && c >= b);
        return c;
    }
}

interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, bytes _extraData) external;
}

contract USDT
{
    using SafeMath for uint256;

    address owner;
    bool public canBurn;
    bool public canApproveCall;
    uint8 public decimals = 6;
    uint256 public totalSupply = 100000000000 * (10 ** uint256(decimals));
    string public name = "USDT";
    string public symbol = "USDT";

    mapping (address => uint256) private _balances;
    mapping (address => mapping(address => uint256)) private _allowed;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Burn(address indexed _from, uint256 _value);

    constructor() public {
        owner = msg.sender;
        canBurn = false;
        canApproveCall = true;
        _balances[owner] = totalSupply;
    }
    
    function issue(uint256 _val) external {
        require(msg.sender == owner);
        totalSupply = totalSupply + _val;
        _balances[owner].add(_val);
    }

    function setCanBurn(bool _val) external {
        require(msg.sender == owner);
        require(_val != canBurn);
        canBurn = _val;
    }

    function setCanApproveCall(bool _val) external {
        require(msg.sender == owner);
        require(_val != canApproveCall);
        canApproveCall = _val;
    }

    function transferOwnership(address _newOwner) external {
        require(msg.sender == owner);
        require(_newOwner != address(0) && _newOwner != owner);
        owner = _newOwner;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return _balances[_owner];
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowed[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        require(_value <= _balances[msg.sender] && _value > 0);
        require(_to != address(0));

        _balances[msg.sender] = _balances[msg.sender].sub(_value);
        _balances[_to] = _balances[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0));

        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        require(_to != address(0));
        require(_value <= _balances[_from] && _value > 0);
        require(_value <= _allowed[_from][msg.sender]);

        _balances[_from] = _balances[_from].sub(_value);
        _balances[_to] = _balances[_to].add(_value);
        _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);

        return true;
    }

    function burn(uint256 _value) external returns (bool success)
    {
        require(canBurn == true);
        require(_balances[msg.sender] >= _value && totalSupply > _value);
        _balances[msg.sender] = _balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit Burn(msg.sender, _value);
        return true;
    }

    function approveAndCall(address _spender, uint256 _value, bytes _extraData) external returns (bool success)
    {
        require(canApproveCall == true);
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, _extraData);
            return true;
        }
    }
}
