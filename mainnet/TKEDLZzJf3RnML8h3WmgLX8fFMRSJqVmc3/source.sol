// File: openzeppelin-solidity/contracts/ownership/rbac/Roles.sol

pragma solidity ^0.4.23;


/**
 * @title Roles
 * @author Francisco Giordano (@frangio)
 * @dev Library for managing addresses assigned to a Role.
 *      See RBAC.sol for example usage.
 */
library Roles {
  struct Role {
    mapping (address => bool) bearer;
  }

  /**
   * @dev give an address access to this role
   */
  function add(Role storage role, address addr)
    internal
  {
    role.bearer[addr] = true;
  }

  /**
   * @dev remove an address' access to this role
   */
  function remove(Role storage role, address addr)
    internal
  {
    role.bearer[addr] = false;
  }

  /**
   * @dev check if an address has this role
   * // reverts
   */
  function check(Role storage role, address addr)
    view
    internal
  {
    require(has(role, addr));
  }

  /**
   * @dev check if an address has this role
   * @return bool
   */
  function has(Role storage role, address addr)
    view
    internal
    returns (bool)
  {
    return role.bearer[addr];
  }
}

// File: contracts/utils/AdminRole.sol

pragma solidity ^0.4.23;



contract AdminRole {
    using Roles for Roles.Role;

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    Roles.Role private _admins;


    modifier onlyAdmin() {
        require(isAdmin(msg.sender));
        _;
    }

    constructor() public {
        _admins.add(msg.sender);
    }

    function isAdmin(address account) public view returns (bool) {
        return _admins.has(account);
    }

    function addAdmin(address account) public onlyAdmin {
        _addAdmin(account);
    }

    function removeAdmin(address account) public onlyAdmin {
        _removeAdmin(account);
    }

    function renounceAdmin() public {
        _removeAdmin(msg.sender);
    }

    function _addAdmin(address account) internal {
        _admins.add(account);
        emit AdminAdded(account);
    }

    function _removeAdmin(address account) internal {
        _admins.remove(account);
        emit AdminRemoved(account);
    }
}

// File: openzeppelin-solidity/contracts/math/SafeMath.sol

pragma solidity ^0.4.23;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

// File: contracts/tothemoon/ConfigStorageMixin.sol

pragma solidity ^0.4.23;




contract ConfigStorageMixin is AdminRole {
    using SafeMath for uint256;


    struct User {
        address referrer1;
        address referrer2;
        address referrer3;
        bool hasTicket;
    }

    address internal _fundAddress;
    address internal _teamAddress;
    mapping (address => User) internal _users;

    event FundAddressChanged(address newAddress);
    event TeamAddressChanged(address newAddress);
    event ReferrersSet(address user, address referrer1, address referrer2, address referrer3);


    function getFundAddress() public view returns (address) {
        return _fundAddress;
    }

    function setFundAddress(address newAddress) public onlyAdmin {
        _fundAddress = newAddress;
        emit FundAddressChanged(newAddress);
    }

    function getTeamAddress() public view returns (address) {
        return _teamAddress;
    }

    function setTeamAddress(address newAddress) public onlyAdmin {
        _teamAddress = newAddress;
        emit TeamAddressChanged(newAddress);
    }

    function getUserReferrers(address user) public view returns (address[3] memory) {
        return [_users[user].referrer1, _users[user].referrer2, _users[user].referrer3];
    }

    function setUserReferrers(address user, address referrer1, address referrer2, address referrer3) public onlyAdmin {
        if (referrer1 != address(0))
            _users[user].referrer1 = referrer1;
        if (referrer2 != address(0))
            _users[user].referrer2 = referrer2;
        if (referrer3 != address(0))
            _users[user].referrer3 = referrer3;

        emit ReferrersSet(user, referrer1, referrer2, referrer3);
    }
}

// File: contracts/tothemoon/ToTheMoonPre.sol

pragma solidity ^0.4.23;




contract ToTheMoonPre is ConfigStorageMixin {
    using SafeMath for uint256;

    uint256 public TICKET_PRICE = 2000 * 1000000;  // sun = 1e-6 trx

    event WithdrawnAll(address indexed user, uint256 amount);
    event PaidToFund(address indexed from, uint256 amount);
    event PaidToReferrer(address indexed from, address indexed to, uint256 amount, uint256 level);
    event PaidToTeam(address indexed from, uint256 amount);

    event BoughtTicket(address indexed user);


    modifier onlyAdmin {
        require(isAdmin(msg.sender));
        _;
    }

    constructor() public {
        addAdmin(msg.sender);
    }

    function withdrawAll(address to) public onlyAdmin {
        if (to == address(0)) {
            to = msg.sender;
        }
        to.transfer(address(this).balance);
    }

    function distributeFunds(uint256 amount, address sender) internal {
        address[3] memory referrers = getUserReferrers(sender);

        uint256 left = amount;

        if (_fundAddress != address(0)) {
            uint256 fundAmount = amount.div(2);
            _fundAddress.transfer(fundAmount);  // 50% фонду
            left = left.sub(fundAmount);
            emit PaidToFund(sender, fundAmount);
        }

        if (referrers[0] != address(0)) {
            uint256 referrerAmount1 = amount.div(4);  // 25% первому рефералу
            referrers[0].transfer(referrerAmount1);
            left = left.sub(referrerAmount1);
            emit PaidToReferrer(sender, referrers[0], referrerAmount1, 1);
        }

        if (referrers[1] != address(0)) {
            uint256 referrerAmount2 = amount.div(10);  // 10% второму рефералу
            referrers[1].transfer(referrerAmount2);
            left = left.sub(referrerAmount2);
            emit PaidToReferrer(sender, referrers[1], referrerAmount2, 2);
        }

        if (referrers[2] != address(0)) {
            uint256 referrerAmount3 = amount.div(20);  // 5% третьему рефералу
            referrers[2].transfer(referrerAmount3);
            left = left.sub(referrerAmount3);
            emit PaidToReferrer(sender, referrers[2], referrerAmount3, 3);
        }

        if (_teamAddress != address(0)) {
            _teamAddress.transfer(left);  // остатки команде
            emit PaidToTeam(sender, left);
        }
    }

    function userHasTicket(address user) public view returns (bool) {
        return _users[user].hasTicket;
    }

    function buyTicket() public payable {
        require(!_users[msg.sender].hasTicket);
        require(msg.value >= TICKET_PRICE);

        uint256 leftover = msg.value.sub(TICKET_PRICE);
        if (leftover > 0) {
            msg.sender.transfer(leftover);
        }
        _users[msg.sender].hasTicket = true;
        distributeFunds(TICKET_PRICE, msg.sender);
        emit BoughtTicket(msg.sender);
    }

    function addFunds() public payable { }
}
