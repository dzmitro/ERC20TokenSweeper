pragma solidity ^0.4.10;

contract AbstractSweeper {
    function sweep(address token, uint amount) public returns (bool);

    function () internal { revert(); }

    Controller controller;

    constructor(address _controller) public {
        controller = Controller(_controller);
    }

    modifier canSweep() {
        require(msg.sender == controller.authorizedCaller() && msg.sender == controller.owner(), "Only owner and authorized person can sweep");
        require(!controller.halted(), "Sweeping is halted now");
        _;
    }
}

contract Token {
    function balanceOf(address a) public pure returns (uint) {
        (a);
        return 0;
    }

    function transfer(address a, uint val) public pure returns (bool) {
        (a);
        (val);
        return false;
    }
}

contract DefaultSweeper is AbstractSweeper {

    constructor(address controller) public
             AbstractSweeper(controller) {}

    function sweep(address _token, uint _amount) public canSweep returns (bool) {
        bool success = false;
        address destination = controller.destination();

        if (_token != address(0)) {
            Token token = Token(_token);
            uint amount = _amount;
            if (amount > token.balanceOf(this)) {
                return false;
            }

            success = token.transfer(destination, amount);
        }
        else {
            uint amountInWei = _amount;
            if (amountInWei > address(this).balance) {
                return false;
            }

            success = destination.send(amountInWei);
        }

        if (success) {
            controller.logSweep(this, destination, _token, _amount);
        }
        return success;
    }
}

contract UserWallet {
    AbstractSweeperList sweeperList;

    constructor(address _sweeperlist) public {
        sweeperList = AbstractSweeperList(_sweeperlist);
    }

    function () public payable { }

    function tokenFallback(address _from, uint _value, bytes _data) public pure {
        (_from);
        (_value);
        (_data);
     }

    function sweep(address _token, uint _amount) public
    returns (bool) {
        (_amount);
        return sweeperList.sweeperOf(_token).delegatecall(msg.data);
    }
}

contract AbstractSweeperList {
    function sweeperOf(address _token) public returns (address);
}

contract Controller is AbstractSweeperList {
    address public owner;
    address public authorizedCaller;

    address public destination;

    bool public halted;

    event LogNewWallet(address receiver);
    event LogSweep(address indexed from, address indexed to, address indexed token, uint amount);

    //address who created this contract
    modifier onlyOwner() { require(msg.sender == owner); _; }
    //owner of contact can add trusted callers
    modifier onlyAuthorizedCaller() { require(msg.sender == authorizedCaller); _; }
    //owner + truster callers
    modifier onlyAdmins() { require(msg.sender == authorizedCaller && msg.sender == owner); _; }
    //run first time  when contract has been deployed
    constructor() public {
        owner = msg.sender;
        destination = msg.sender;
        authorizedCaller = msg.sender;
    }
    //authorizedCaller can create new wallets
    function changeAuthorizedCaller(address _newCaller) public onlyOwner {
        authorizedCaller = _newCaller;
    }
    //
    function changeDestination(address _dest) public onlyOwner {
        destination = _dest;
    }
    //can change owner when private key stolen
    function changeOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    //create new contract address
    function makeWallet() public onlyAdmins returns (address wallet)  {
        wallet = address(new UserWallet(this));
        emit LogNewWallet(wallet);
    }

    function halt() public onlyAdmins {
        halted = true;
    }

    function start() public onlyOwner {
        halted = false;
    }

    address public defaultSweeper = address(new DefaultSweeper(this));
    mapping (address => address) sweepers;

    function addSweeper(address _token, address _sweeper) public onlyOwner {
        sweepers[_token] = _sweeper;
    }

    function sweeperOf(address _token) public returns (address) {
        address sweeper = sweepers[_token];
        if (sweeper == 0) sweeper = defaultSweeper;
        return sweeper;
    }

    function logSweep(address from, address to, address token, uint amount) external {
        emit LogSweep(from, to, token, amount);
    }
}
