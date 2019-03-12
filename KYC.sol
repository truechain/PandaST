pragma solidity 0.5.0;

contract KYCSystem {
    enum Country { empty, US, CN, IN }
    enum UserType { empty, common, exchange, underwriter }

    struct Identity {
        string proveURL;
        bytes32 proveHash;
        UserType userType;
        string name;
        uint64 incomeLevel;
        Country country;
    }

    address payable public administrator;
    mapping (address => bool) public isManager;
    mapping (address => uint256) private _owner;
    mapping (uint256 => Identity) private _customer;

    event SetManager (address indexed account, bool isManagerNow);

    modifier onlyAdmin () {
        require(msg.sender == administrator);
        _;
    }

    modifier onlyManager () {
        require(msg.sender == administrator || isManager[msg.sender]);
        _;
    }

    constructor (address payable _admin) public {
      administrator = _admin;
    }

    function setManager (address _account, bool _isManager) public onlyAdmin {
        require(_account != administrator);
        if (isManager[_account] != _isManager) {
            isManager[_account] = _isManager;
            emit SetManager(_account, _isManager);
        }
    }

    function updateCustomer (
        uint256 _id,
        string memory _proveURL,
        bytes32 _proveHash,
        UserType _userType,
        string memory _name,
        uint64 _incomeLevel,
        Country _country
    ) public onlyManager {
        _customer[_id].proveURL = _proveURL;
        _customer[_id].proveHash = _proveHash;
        _customer[_id].userType = _userType;
        _customer[_id].name = _name;
        _customer[_id].incomeLevel = _incomeLevel;
        _customer[_id].country = _country;
    }

    function linkAccount (address _account, uint256 _id) public onlyManager {
        _owner[_account] = _id;
    }

    function isUnderwriter (address _add) public view returns (bool) {
        return _customer[_owner[_add]].userType == UserType.underwriter;
    }

    function isSameUser (address _add1, address _add2) public view returns (bool) {
        if (_owner[_add1] == 0) {
            return false;
        } else {
            return _owner[_add1] == _owner[_add2];
        }
    }

    function isRegistered (address _add) public view returns (bool) {
        if (_owner[_add] == 0) {
            return false;
        } else {
            return true;
        }
    }

    function ownerIDOf (address _account) public view returns (uint256 id) {
        return _owner[_account];
    }

    function ownerOf (address _account) public view returns (string memory name) {
        return _customer[_owner[_account]].name;
    }
    function ownerByID (uint256 _id) public view returns (string memory name) {
        return _customer[_id].name;
    }

    function proveOf (address _account) public view returns (string memory proveURL, bytes32 proveHash) {
        Identity storage customer = _customer[_owner[_account]];
        proveURL = customer.proveURL;
        proveHash = customer.proveHash;
    }
    function proveByID (uint256 _id) public view returns (string memory proveURL, bytes32 proveHash) {
        Identity storage customer = _customer[_id];
        proveURL = customer.proveURL;
        proveHash = customer.proveHash;
    }

    function countryOf (address _account) public view returns (Country countryCode) {
        return _customer[_owner[_account]].country;
    }
    function countryByID (uint256 _id) public view returns (Country countryCode) {
        return _customer[_id].country;
    }

    function incomeLevelOf (address _account) public view returns (uint256 incomeLevel) {
        return _customer[_owner[_account]].incomeLevel;
    }
    function incomeLevelByID (uint256 _id) public view returns (uint256 incomeLevel) {
        return _customer[_id].incomeLevel;
    }
}