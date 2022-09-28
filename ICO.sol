// SPDX-License-Identifier: MIT

// Accepts ETH in exchange for own token
pragma solidity ^0.8.0;


interface ERC20Token {

    // This interface should always be included in ERC20 interface

    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint tokens) external returns (bool success);

    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract Crypto is ERC20Token {
    string public name = "Crypto";
    string public symbol = "CRPT";
    uint public decimals = 0; //18 is most used (0 to keep simple)
    uint public override totalSupply; // Will create getter function

    address public founder;
    mapping(address => uint) public balances; // Stores number of tokens per address

    // Allows for user to enter an address (tokenHolder) and see who that address has given allowance to, as well as how much the allowance is for 
    // 0x111...(owner) allows 0x222...(spender) to withdraw 100 tokens from owners acc
    // allowed[0x111][0x222] = 100
    mapping(address => mapping(address => uint)) allowed; 

    constructor() {
        // Upon deployment, Founder will have one million tokens
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address tokenOwner) public view override returns (uint balance) {
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public virtual override returns (bool success) {
        require(balances[msg.sender] >= tokens); // Reverts transaction if user does not have enough tokens to send

        balances[to] += tokens;
        balances[msg.sender] -= tokens;

        emit Transfer(msg.sender, to, tokens);

        return(true);
    }

    function allowance(address tokenOwner, address spender) view public override returns(uint) {
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public override returns (bool success) {
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);

        allowed[msg.sender][spender] = tokens; // Updates allowed mapping

        emit Approval(msg.sender, spender, tokens);

        return(true);
    }

    function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success) {
        require(allowed[from][msg.sender] >= tokens); // Msg.sender is account that has been approved
        require(balances[from] >= tokens);

        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens;
        balances[to] += tokens;

        emit Transfer(from, to, tokens);

        return(true);
    }


}

contract CrytpoICO is Crypto {
    address public admin;
    address payable public deposit; // Address where investment funds will be held
    uint tokenPrice = 0.001 ether; // 1 ETH = 1000 CRPT, 1 CRPT = 0.001 ETH
    uint public hardCap = 300 ether; // Max amount that someone can invest
    uint public raisedAmount;
    uint public saleStart = block.timestamp + 3600; // ICO will start 1 hour after deployment
    uint public saleEnd = block.timestamp + 604800; // ICO will end in one week
    uint public tokenTradeStart = saleEnd + 604800; // Locks liquidity to ensure that early investors do not immedietly dump coin
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    enum State {beforeStart, running, afterEnd, halted}
    State public icoState;

    constructor(address payable _deposit) {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function halt() public onlyAdmin {
        icoState = State.halted;
    }

    function resume() public onlyAdmin {
        icoState = State.running;
    }

    function changeDepositAddress(address payable _newDeposit) public onlyAdmin {
        deposit = _newDeposit;
    }

    function viewState() public view returns(State) {
        if(icoState == State.halted) {
            return State.halted;
        } else if(block.timestamp < saleStart) {
            return State.beforeStart;
        } else if(block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return State.running;
        } else {
            return State.afterEnd;
        }
    }

    event Invest(address investor, uint value, uint tokens);

    function invest() payable public returns(bool) {
        icoState = viewState(); // Sets icoState equal to the value of viewState() function
        require(icoState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap); // Requires the amount raised is less than or equal to the hard cap 

        uint tokens = msg.value / tokenPrice; // Calculates # of tokens user has bought

        // balances is inherited from ERC20 contract
        balances[msg.sender] += tokens;
        balances[founder] -= tokens; 
        deposit.transfer(msg.value);

        emit Invest(msg.sender, msg.value, msg.value); // Remember this helps with front-end display
        
        return true;
    }

    // Allows for user to send ETH directly to contracts address and recieve CRPT tokens
    receive() payable external {
        invest();
    }

    function transfer(address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart);
        super.transfer(to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart);
        super.transferFrom(from, to, tokens);
        return true;
    }

    function burnTokens() public returns(bool) {
        icoState = viewState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;

        return true;
    }

}