pragma solidity 0.5.0;

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

interface KYCSystem {
    enum Country { empty, US, CN, IN }

    function countryOf (address) external view returns (Country);
    function isRegistered (address) external view returns (bool);
    function isSameUser (address, address) external view returns (bool);
    function isUnderwriter(address) external view returns (bool);
}

contract TrueSTDemo {
    using SafeMath for uint256;

    struct SnapshotInfo {
        uint256 timestamp;
        uint256 blockNumber;
    }

    KYCSystem public kycVersion;
    address public controller;
    address public debtor;
    uint256 public issueTime;

    // Basic ERC20 attribute
    string public constant name = "Test TrueST Token";
    string public constant symbol = "TTT";
    uint256 public constant decimals = 6;
    uint256 public totalSupply = 0;
    uint256 public issued = 0;
    uint256 public interestRate = 0;

    bool public assessed;
    address public underwriter;
    uint32 public underwriterRiskRating;
    string public assessmentReport;
    bytes32 public assessmentHash;

    uint256 public salt;

    mapping (address => uint256) private _balance;
    mapping (address => mapping (address => uint256)) allowed;

    event Issue(address indexed _investor, uint256 _time, uint256 _amount);
    event ControllerTransfer(address indexed _from, address indexed _to, uint256 _value);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _tokenHolder, address indexed _spender, uint256 _value);

    uint256 private _nextSnapshotNumber;
    mapping (uint256 => mapping (address => uint256)) private _snapshotBalance;
    mapping (uint256 => mapping (address => bool)) private _snapshotRecorded;
    mapping (uint256 => SnapshotInfo) private _snapshotInfo;
    uint256 private _nextSnapshotTime;

    constructor (
        KYCSystem _kycVersion,
        address _controller,
        uint256 _amount,
        uint256 _interestRate
    ) public {
        kycVersion = _kycVersion;
        controller = _controller;
        totalSupply = _amount;
        interestRate = _interestRate;
        _nextSnapshotNumber = 1;
        issueTime = now;
        debtor = msg.sender;
    }

    modifier isCompliant (address _investor) {
        require(kycVersion.isRegistered(_investor), "");
        require(!blacklist[_investor], "");
        if (now < issueTime + 365 days) {
            require(kycVersion.countryOf(_investor) != KYCSystem.Country.US, "");
        }
        _;
    }

    modifier onlyByDebtor () {
        require(msg.sender == debtor, "");
        _;
    }

    modifier onlyByController () {
        require(msg.sender == controller, "");
        _;
    }

    function specifyUnderwriter (address _spUnderwriter) public onlyByDebtor {
        require(kycVersion.isUnderwriter(_spUnderwriter), "");
        underwriter = _spUnderwriter;
    }

    function assess (
        uint32 _riskRating,
        string memory _assessmentReport,
        bytes32 _assessmentHash
    ) public {
        require(msg.sender == underwriter, "");
        require(!assessed, "");
        underwriterRiskRating = _riskRating;
        assessmentReport = _assessmentReport;
        assessmentHash = _assessmentHash;
        assessed = true;
    }

    function controllerTransfer (address _from, address _to, uint256 _value) public onlyByController {
        require(_balance[_from] >= _value, "");

        _balance[_from] = _balance[_from].sub(_value);
        _balance[_to] = _balance[_to].add(_value);

        _updateInvestor(_to);
        _updateSnapshot(_to);
        _updateSnapshot(msg.sender);

        emit ControllerTransfer(_from, _to, _value);
    }

    address[] private _investors;
    mapping (address => uint256) _investorIndex;
    function investorsCount () public view returns (uint256 count) {
        return _investors.length;
    }
    function investorsAll () public view returns (address[] memory investors) {
        return _investors;
    }

    // 
    address[] private _wlInvestors;
    mapping (address => uint256) _wlIndex;
    mapping (address => bool) _whiteList;
    function whiteListsCount () public view returns (uint256 count) {
        return _wlInvestors.length;
    }
    function whiteListsAll () public view returns (address[] memory investors) {
        return _wlInvestors;
    }

    function setWhiteList (address _investor, bool _in) public onlyByDebtor {
        require(kycVersion.isRegistered(_investor), "");
        _whiteList[_investor] = _in;
        if (_wlIndex[_investor] == 0) {
            _wlInvestors.push(_investor);
            _wlIndex[_investor] = _wlInvestors.length;
        }
    }

    mapping (address => bool) public blacklist;
    function setBlackList (address _investor, bool _in) public onlyByDebtor {
        blacklist[_investor] = _in;
    }

    function snap () public onlyByDebtor {
        _snapshotInfo[_nextSnapshotNumber] = SnapshotInfo({
            timestamp: now,
            blockNumber: block.number
        });
        _nextSnapshotNumber++;
    }

    function snapshotCount () public view returns (uint256) {
        return _nextSnapshotNumber - 1;
    }

    function snapshotInfo (uint256 _snapshotID) public view returns (uint256 timestamp, uint256 blockNumber) {
        timestamp = _snapshotInfo[_snapshotID].timestamp;
        blockNumber = _snapshotInfo[_snapshotID].blockNumber;
    }

    function getBalanceSnapshot (uint256 _snapshotID, address _investor) public view returns (uint256) {
        require(_snapshotID < _nextSnapshotNumber, "");
        for (uint256 findAt = _snapshotID; findAt > 0; findAt--) {
            if (_snapshotRecorded[_snapshotID][_investor]) {
                return _snapshotBalance[_snapshotID][_investor];
            }
        }
        return 0;
    }

    function issue (address _investor, uint256 _amount) public isCompliant(_investor) onlyByDebtor returns (bool success) {
        require(issued.add(_amount) < totalSupply, "");

        _balance[_investor] = _balance[_investor].add(_amount);
        issued = issued.add(_amount);

        _updateInvestor(_investor);
        _updateSnapshot(_investor);

        emit Issue(_investor, now, _amount);
        return true;
    }

    function redeemFrom (address _investor, uint256 _amount) public onlyByDebtor {
        _balance[_investor] = _balance[_investor].sub(_amount);
        _updateSnapshot(_investor);
    }

    function balanceOf (address _tokenHolder) public view returns (uint256) {
        return _balance[_tokenHolder];
    }

    function transfer (address _to, uint256 _value) public isCompliant(_to) returns (bool success) {
        require(_balance[msg.sender] >= _value, "");

        _balance[msg.sender] = _balance[msg.sender].sub(_value);
        _balance[_to] = _balance[_to].add(_value);

        _updateInvestor(_to);
        _updateSnapshot(_to);
        _updateSnapshot(msg.sender);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom (address _from, address _to, uint256 _value) public isCompliant(_to) returns (bool success) {
        require(_balance[_from] >= _value && allowed[_from][msg.sender] >= _value, "");

        _balance[_from] = _balance[_from].sub(_value);
        _balance[_to] = _balance[_to].add(_value);

        _updateInvestor(_to);
        _updateSnapshot(_to);
        _updateSnapshot(msg.sender);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve (address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function changeAddress (address _oldAddress) public {
        require(kycVersion.isSameUser(msg.sender, _oldAddress), "");
        _balance[msg.sender] = _balance[_oldAddress];
        _balance[_oldAddress] = 0;
        uint256 offset = _investorIndex[_oldAddress];
        if (offset != 0) {
            _investors[offset - 1] = msg.sender;
        }
    }

    function _updateInvestor (address _investor) private {
        if (_investorIndex[_investor] == 0) {
            _investors.push(_investor);
            _investorIndex[_investor] = _investors.length;
        }
    }

    function _updateSnapshot (address _investor) private {
        _snapshotBalance[_nextSnapshotNumber][_investor] = _balance[_investor];
        _snapshotRecorded[_nextSnapshotNumber][_investor] = true;
    }
}
