// SPDX-License-Identifier: CC-BY-SA 4.0
//https://creativecommons.org/licenses/by-sa/4.0/

// TL;DR: The creator of this contract (@LogETH) is not liable for any damages associated with using the following code
// This contract must be deployed with credits toward the original creator, @LogETH.
// You must indicate if changes were made in a reasonable manner, but not in any way that suggests I endorse you or your use.
// If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
// You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
// This TL;DR is solely an explaination and is not a representation of the license.

// By deploying this contract, you agree to the license above and the terms and conditions that come with it.

pragma solidity >=0.7.0 <0.9.0;

//// What is this contract? 

//// This contract is a specific custom ERC20 token, with a gas friendly reflection system I designed myself
//// Most of my contracts have an admin, this contract does not as it is automatically renounced when deployed

//// Unlike traditional fee contracts, this contract broadcasts the fee and the sent amount in the transaction data.
//// The broadcast is supported by ethereum explorers like etherscan and makes accounting much easier.

    // How to Setup:

    // Step 0: Deploy SpecERC20graph.sol https://github.com/LogETH/commissions/blob/main/Finished%20Commissions/SpecERC20graph.sol
    // Step 1: Change the values in the constructor to the ones you want (make sure to double check as they cannot be changed)
    // Step 2: Deploy the contract
    // Step 2.5: Call setBaseContract() on the graph contract with the address of this contract
    // Step 3: Go to https://app.gelato.network/ and create a new task that executes "sendFee()" when it is available
    // Step 4: Gelato should already tell you this, but make sure you put enough ETH in the vault to activate the function when needed.
    // Step 5: Create a market using https://app.uniswap.org/#/add/v2/ETH, and grab the LP token address in the transaction receipt
    // Step 6: Call "setDEX()" with the LP token address you got from the tx receipt to enable the fee and max wallet limit
    // Step 6.5: Call "configImmuneToMaxWallet()" with the LP token address so the main market is immune to the max wallet limit
    // Step 7: Call "setGelato()" with the gelato address to enable the automatic ETH fee
    // Step 8: It should be ready to use from there, all inital tokens are sent to the wallet of the deployer

//// Commissioned by a bird I met on a walk on 8/5/2022

contract SpecERC20 {

//// The constructor, this is where you change settings before deploying
//// make sure to change these parameters to what you want

    constructor () {

        totalSupply = 2000000*1e18;         // The amount of tokens in the inital supply, you need to multiply it by 1e18 as there are 18 decimals
        name = "Test LOG token";            // The name of the token
        decimals = 18;                      // The amount of decimals in the token, usually its 18, so its 18 here
        symbol = "tLOG";                    // The ticker of the token
        BuyFeePercent = 3;                  // The % fee that is sent to the dev on a buy transaction
        SellFeePercent = 2;                 // The % fee that is sent to the dev on a sell transaction
        ReflectBuyFeePercent = 3;           // The % fee that is reflected on a buy transaction
        ReflectSellFeePercent = 2;          // The % fee that is reflected on a sell transaction
        BuyLiqTax = 1;                      // The % fee that is sent to liquidity on a buy
        SellLiqTax = 2;                     // The % fee that is sent to liquidity on a sell
        maxWalletPercent = 2;               // The maximum amount a wallet can hold, in percent of the total supply.
        threshold = 1e15;                   // When enough fees have accumulated, send this amount of wETH to the dev addresses.

        Dev1 = msg.sender;                               // The first wallet that receives 25% of the dev fee
        Dev2 = msg.sender;                               // The second wallet that receives 25% of the dev fee
        Dev3 = msg.sender;                               // The third wallet that receives 25% of the dev fee
        Dev4 = msg.sender;                               // The fourth wallet that receives 25% of the dev fee
        wETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;                     // The address of wrapped ether,
        gelato;                                          // The address of the gelato contract that automatically calls the contract when conditions are met.

        balances[msg.sender] = totalSupply; // a statement that gives the deployer of the contract the entire supply.
        deployer = msg.sender;              // a statement that marks the deployer of the contract so they can set the liquidity pool address


        router = Univ2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);  // The address of the uniswap v2 router
        ERC20(wETH).approve(address(router), type(uint256).max); // Approves infinite wETH for use on uniswap v2 (For adding liquidity)

        order.push(address(this));
        order.push(wETH);

        graph = Graph(0x6C0539f313C94116760C2E0635C576b4910e5AEb);

        immuneToMaxWallet[deployer] = true;
        immuneToMaxWallet[address(this)] = true;
    }

//////////////////////////                                                          /////////////////////////
/////////////////////////                                                          //////////////////////////
////////////////////////            Variables that this contract has:             ///////////////////////////
///////////////////////                                                          ////////////////////////////
//////////////////////                                                          /////////////////////////////

//// Variables that make this contract ERC20 compatible (with metamask, uniswap, trustwallet, etc)

    mapping(address => uint256) public balances;
    mapping(address => mapping (address => uint256)) public allowed;

    string public name;
    uint8 public decimals;
    string public symbol;
    uint public totalSupply;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

//// Tax variables, I already explained them in the contstructor, so go look there

    uint public BuyFeePercent; uint public SellFeePercent; uint public ReflectBuyFeePercent; uint public ReflectSellFeePercent; uint public SellLiqTax; uint public BuyLiqTax;

//// Variables that make the internal parts of this contract work, I explained them the best I could

    Univ2 router;                           // The address of the uniswap router that swaps your tokens
    Graph graph;                            // The address of the graph contract that grabs a number from a graph

    address Dev1;                           // Already explained in the constructor, go look there
    address Dev2;                           // ^
    address Dev3;                           // ^
    address Dev4;                           // ^
    address Liq;                            // ^

    address public DEX;                     // The address of the LP token that is the pool where the LP is stored
    address public wETH;                    // The address of wrapped ethereum
    uint public rebaseMult = 1e18;          // The base rebase, it always starts at 1e18
    address deployer;                       // The address of the person that deployted this contract, allows them to set the LP token, only once.
    mapping(address => uint256) public AddBalState; // A variable that keeps track of everyone's rebase and makes sure it is done correctly
    mapping(address => bool) public immuneToMaxWallet; // A variable that keeps track if a wallet is immune to the max wallet limit or not.
    uint maxWalletPercent;
    uint public feeQueue;
    uint public LiqQueue;
    uint public threshold;
    address public gelato;
    bool public renounced;

    address[] public order;

    
//////////////////////////                                                              /////////////////////////
/////////////////////////                                                              //////////////////////////
////////////////////////             Visible functions this contract has:             ///////////////////////////
///////////////////////                                                              ////////////////////////////
//////////////////////                                                              /////////////////////////////

//// Sets the liquidity pool address and gelato address, can only be done once and can only be called by the inital deployer.

    function SetDEX(address LPtokenAddress) public {

        require(msg.sender == deployer, "You cannot call this as you are not the deployer");
        require(DEX == address(0), "The LP token address is already set");

        DEX = LPtokenAddress;

        this.approve(address(router), type(uint256).max); // Approves infinite tokens for use on uniswap v2
    }

    function SetGelato(address gelatoAddress) public {

        require(msg.sender == deployer, "You cannot call this as you are not the deployer");
        require(gelato == address(0), "The gelato address is already set");

        gelato = gelatoAddress;
    }

    function configImmuneToMaxWallet(address Who, bool TrueorFalse) public {

        require(msg.sender == deployer, "You cannot call this as you are not the deployer");

        immuneToMaxWallet[Who] = TrueorFalse;
    }

    function renounceContract() public {

        require(msg.sender == deployer, "You cannot call this as you are not the deployer");

        deployer = address(0);
        renounced = true;
    }

//// Sends tokens to someone normally

    function transfer(address _to, uint256 _value) public returns (bool success) {

        require(balanceOf(msg.sender) >= _value, "You can't send more tokens than you have");

        UpdateState(msg.sender);
        UpdateState(_to);

        // Sometimes, a DEX can use transfer instead of transferFrom when buying a token, the buy fees are here just in case that happens

        if(msg.sender == address(this) || _to == address(this) || DEX == address(0)){}

        else{

            if(DEX == msg.sender){
            
            _value = ProcessBuyFee(_value, msg.sender);          // The buy fee that is swapped to ETH
            _value = ProcessBuyReflection(_value, msg.sender);   // The reflection that is distributed to every single holder
            _value = ProcessBuyLiq(_value, msg.sender);          // The buy fee that is added to the liquidity pool
            
            }
        }

        balances[_to] += _value;
        balances[msg.sender] -= _value;

        if(immuneToMaxWallet[msg.sender] == true || DEX == address(0)){}
        
        else{

        require(balances[msg.sender] <= totalSupply*(maxWalletPercent/100), "This transaction would result in your balance exceeding the maximum amount");
        }

        if(immuneToMaxWallet[_to] == true || DEX == address(0)){}
        
        else{

        require(balances[_to] <= totalSupply*(maxWalletPercent/100), "This transaction would result in the destination's balance exceeding the maximum amount");
        }
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

//// This function tests all fee functions at the same time! warning: is gas heavy as it tests every single function in this contract.

    function test() public  {

        uint _value = 1e18;
        address _to = address(0);

        require(balanceOf(msg.sender) >= _value, "You can't send more tokens than you have");

        UpdateState(msg.sender);
        UpdateState(_to);

            // All Buy functions

            _value = ProcessBuyFee(_value, msg.sender);          // Works
            _value = ProcessBuyReflection(_value, msg.sender);   // Works
            _value = ProcessBuyLiq(_value, msg.sender);          // Works

            // All Sell functions
        
            _value = ProcessSellFee(_value, msg.sender);         // Works
            _value = ProcessSellReflection(_value, msg.sender);  // Works
            _value = ProcessSellLiq(_value, msg.sender);         // Works
            _value = ProcessSellBurn(_value, msg.sender);        // Works

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        if(immuneToMaxWallet[msg.sender] == true || DEX == address(0)){}
        
        else{

        require(balances[msg.sender] <= totalSupply*(maxWalletPercent/100), "This transaction would result in your balance exceeding the maximum amount");
        }

        if(immuneToMaxWallet[_to] == true || DEX == address(0)){}
        
        else{

        require(balances[_to] <= totalSupply*(maxWalletPercent/100), "This transaction would result in the destination's balance exceeding the maximum amount");
        }

        emit Transfer(msg.sender, _to, _value);

    }

//// The function that DEXs use to trade tokens (FOR TESTING ONLY.)

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {

        UpdateState(msg.sender);
        UpdateState(_to);

        // Internally, all tokens used as fees are burned, they are reminted when they are needed to swap for ETH

        require(allowed[_from][msg.sender] >= _value, "insufficent approval");

        if(_from == address(this)){}

        else{

            require(balanceOf(_from) >= _value, "You can't send more tokens than you have");
        }

        // first if statement prevents the fee from looping forever against itself 
        // the fee is disabled until the liquidity pool is set as the contract can't tell if a transaction is a buy or sell without it

        if(_from == address(this) || _to == address(this) || DEX == address(0)){}

        else{

            // The part of the function that tells if a transaction is a buy or a sell

            if(DEX == _to){
            
            _value = ProcessSellFee(_value, _from);         // The sell fee that is swapped to ETH
            _value = ProcessSellReflection(_value, _from);  // The reflection that is distributed to every single holder
            _value = ProcessSellLiq(_value, _from);         // The sell fee that is added to the liquidity pool
            _value = ProcessSellBurn(_value, _from);        // The sell fee that is burned
            
            }

            if(DEX == _from){
            
            _value = ProcessBuyFee(_value, _from);          // The buy fee that is swapped to ETH
            _value = ProcessBuyReflection(_value, _from);   // The reflection that is distributed to every single holder   
            _value = ProcessBuyLiq(_value, _from);          // The buy fee that is added to the liquidity pool
            
            }
        }

        if(_from == address(this)){}

        else{

            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
        }

        balances[_to] += _value;

        if(immuneToMaxWallet[_from] == true || DEX == address(0)){}
        
        else{

        require(balances[_from] <= totalSupply*(maxWalletPercent/100), "This transaction would result in your balance exceeding the maximum amount");
        }

        if(immuneToMaxWallet[_to] == true || DEX == address(0)){}
        
        else{

        require(balances[_to] <= totalSupply*(maxWalletPercent/100), "This transaction would result in the destination's balance exceeding the maximum amount");
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

//// functions that are used to view values like how many tokens someone has or their state of approval for a DEX

    function balanceOf(address _owner) public view returns (uint256 balance) {

        uint LocBalState;

        if(AddBalState[_owner] == 0){

            LocBalState = rebaseMult;
        }
        else{

            LocBalState = AddBalState[_owner];
        }

        uint dist = (rebaseMult - LocBalState) + 1e18;

        if(LocBalState != 0 || dist != 0){

            return (dist*balances[_owner])/1e18;
        }

        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {

        allowed[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {

        return allowed[_owner][_spender];
    }

    fallback() external payable {}
    receive() external payable {}

    
//////////////////////////                                                              /////////////////////////
/////////////////////////                                                              //////////////////////////
////////////////////////      Internal and external functions this contract has:      ///////////////////////////
///////////////////////                                                              ////////////////////////////
//////////////////////                                                              /////////////////////////////


//// ProcessFee() functions are called whenever there there needs to be a fee applied to a buy or sell

    function ProcessSellFee(uint _value, address _payee) internal returns (uint){

        uint fee = SellFeePercent*(_value/100);
        _value -= fee;
        balances[_payee] -= fee;
        feeQueue += fee;
        
        return _value;
    }

    function ProcessBuyFee(uint _value, address _payee) internal returns (uint){

        uint fee = BuyFeePercent*(_value/100);
        _value -= fee;
        balances[_payee] -= fee;
        feeQueue += fee;

        return _value;
    }

    function ProcessBuyReflection(uint _value, address _payee) internal returns(uint){

        uint fee = ReflectBuyFeePercent*(_value/100);
        _value -= fee;

        balances[_payee] -= fee;
        rebaseMult += fee*1e18/totalSupply;

        emit Transfer(_payee, address(this), fee);

        return _value;
    }

    function ProcessSellReflection(uint _value, address _payee) internal returns(uint){

        uint fee = ReflectSellFeePercent*(_value/100);
        _value -= fee;

        balances[_payee] -= fee;
        rebaseMult += fee*1e18/totalSupply;

        emit Transfer(_payee, address(this), fee);

        return _value;
    }

    function ProcessBuyLiq(uint _value, address _payee) internal returns(uint){

        uint fee = BuyLiqTax*(_value/100);
        balances[_payee] -= fee;

        _value -= fee;

        // For gas savings, the buy liq fee is placed on a queue to be executed on the next sell transaction

        feeQueue += fee;

        emit Transfer(_payee, DEX, fee);

        return _value;

    }

    function ProcessSellLiq(uint _value, address _payee) internal returns(uint){

        uint fee = SellLiqTax*(_value/100);
        balances[_payee] -= fee;

        _value -= fee;

        // Swaps the fee for wETH on the uniswap router and grabs it using the graph contract as a proxy

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens((fee+LiqQueue)/2, 0, order, address(graph), type(uint256).max);
        graph.sweepToken(ERC20(wETH));

        // Deposits the fee into the liquidity pool and burns the LP tokens

        router.addLiquidity(address(this), wETH, (fee+LiqQueue)/2, ERC20(wETH).balanceOf(address(this)), 0, 0, address(0), type(uint256).max);

        emit Transfer(_payee, DEX, fee);
        LiqQueue = 0;

        return _value;
    }

    function ProcessSellBurn(uint _value, address _payee) internal returns(uint){

        uint fee = (5*(_value/100));

        _value -= fee;
        balances[_payee] -= fee;

        emit Transfer(_payee, address(0), fee);

        return _value;
    }

//// Saves the reflection state of your balance, used in every function that sends tokens

    function UpdateState(address Who) internal{

        if(AddBalState[Who] == 0){

            AddBalState[Who] = rebaseMult;
        }

        uint dist = (rebaseMult - AddBalState[Who]) + 1e18;

        if(AddBalState[Who] != 0 || dist != 0){

            balances[Who] = (dist*balances[Who])/1e18;
        }

        AddBalState[Who] = rebaseMult;
    }

//// The function gelato uses to send the fee when it reaches the threshold

    function sendFee() public {

        require(msg.sender == gelato, "You cannot call this function");

        // Swaps the fee for wETH on the uniswap router and grabs it using the graph contract as a proxy

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(feeQueue, threshold, order, address(graph), type(uint256).max);
        graph.sweepToken(ERC20(wETH));

        Wrapped(wETH).withdraw(ERC20(wETH).balanceOf(address(this)));

        uint amt = (address(this).balance/4);

        // Sends the newly swapped ETH to the 4 dev addresses

        (bool sent1,) = Dev1.call{value: amt}("");
        (bool sent2,) = Dev2.call{value: amt}("");
        (bool sent3,) = Dev3.call{value: amt}("");
        (bool sent4,) = Dev4.call{value: amt}("");

        require(sent1 && sent2 && sent3 && sent4, "transfer failed");

        feeQueue = 0;
    }



//////////////////////////                                                              /////////////////////////
/////////////////////////                                                              //////////////////////////
////////////////////////                 Functions used for UI data                   ///////////////////////////
///////////////////////                                                              ////////////////////////////
//////////////////////                                                              /////////////////////////////




///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Additional functions that are not part of the core functionality, if you add anything, please add it here ////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
    function something() public {
        blah blah blah blah;
    }
*/


}

//////////////////////////                                                              /////////////////////////
/////////////////////////                                                              //////////////////////////
////////////////////////      Contracts that this contract uses, contractception!     ///////////////////////////
///////////////////////                                                              ////////////////////////////
//////////////////////                                                              /////////////////////////////


interface ERC20{
    function transferFrom(address, address, uint256) external;
    function transfer(address, uint256) external;
    function balanceOf(address) external view returns(uint);
    function decimals() external view returns (uint8);
    function approve(address, uint) external;
}


interface Univ2{
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

interface Graph{

    function getValue(uint X) external pure returns (uint);
    function sweepToken(ERC20) external;
}

interface Wrapped{

    function deposit() external payable;
    function withdraw(uint) external;
}