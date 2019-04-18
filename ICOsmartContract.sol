pragma solidity ^0.4.25;

// Author: Canlead Developer | Iceman
// Telegram: ice_man0

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (_a == 0) {
      return 0;
    }

    uint256 c = _a * _b;
    require(c / _a == _b);

    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
    require(_b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = _a / _b;
    // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold

    return c;
  }


  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
    uint256 c = _a + _b;
    require(c >= _a);

    return c;
  }


}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

  address public owner;

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
   constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner)public onlyOwner {
    require(newOwner != address(0));
    owner = newOwner;
  }
}

/**
 * @title Price Updater
 * @dev API interface for interacting with the price updater contract 
 */
 interface PriceUpdater {
    function getTokenPrice() external view returns(uint256);
    function getSaleMinimum() external view returns(uint256);
}

/**
 * @title Token
 * @dev API interface for interacting with the CAND contract 
 */
interface Token {
  function transfer(address _to, uint256 _value)external returns (bool);
  function balanceOf(address _owner)external view returns (uint256 balance);
}

contract Crowdsale is Ownable {

  using SafeMath for uint256;

  Token public token;
  
  PriceUpdater public pricesContract; 

  uint256 public raisedWei; // Raised Wei
  uint256 public soldTokens; // Tokens Sold
  uint256 public startingTime = 1541700000; // CHANGE ME
  uint256 public endingTime = 1541706600; // CHANGE ME
  uint256 softCap; // CHANGE ME
  uint256 hardCap; // CHANGE ME

  address public beneficiary;
  
  mapping(address => bool) internal whiteList;

  // They'll be represented by their index numbers i.e 
  // if the state is Dormant, then the value should be 0 
  // Dormant:0, Active:1, , Successful:2
  enum State {Dormant, Active}

  State public state;
 
  event ActiveState();
  event DormantState();

  event BoughtTokens(
      address indexed who, 
      uint256 tokensBought, 
      uint256 investedETH
      );
      
  event WhiteListManyEntry(
      address[] who,
      bool status
      );
     
  event WhiteListSingleEntry(
      address indexed who,
      bool status
      );

    modifier preValidation() {
    
    isItWhiteListed(msg.sender) == true;
    
    // TODO: CHANGE ME TO YOUR TIMEZONE BY ADDING OR SUBTRACTING HOURS
    require(now.add(1 hours * 5) >= startingTime);
    require(now.add(1 hours * 5) <= endingTime);

    require(msg.value >= pricesContract.getSaleMinimum());

    require(state == State.Active);
  
    _;
  }
  
  constructor() 
              public 
              {
                token = Token(0x92196b19b3cfa5e70907cfea7b6207ab92d4e6ef); // CHANGE ME
                beneficiary = msg.sender; // CHANGE ME TO THE RECEIVER OF THE FUNDS
                state = State.Active;
                pricesContract = PriceUpdater(0xe73ca9eedfc15d825a1ea3b792eb95615e61caf9); // CHANGE ME
    }

    /**
     * Fallback function
     *
     * @dev This function will be called whenever anyone sends funds to a contract,
     * throws if the sale isn't Active or the sale minimum isn't met
     */
    function () public payable {

        buyTokens();

      }

  /**
  * @dev Function that sells available tokens
  */
  function buyTokens() public payable preValidation()  {
    
    uint256 invested = msg.value;
    
    uint256 numberOfTokens = invested.mul(pricesContract.getTokenPrice());
    
    beneficiary.transfer(msg.value);
    
    token.transfer(msg.sender, numberOfTokens);
    
    raisedWei = raisedWei.add(msg.value);
    
    soldTokens = soldTokens.add(numberOfTokens);

    emit BoughtTokens(msg.sender, numberOfTokens, invested);
    
    }
    
    
  function changePriceUpdaterAddress(PriceUpdater _newAddres) public onlyOwner {
        pricesContract = _newAddres;
    }
    
  function addManyToWhiteList(address[] _addresses) external onlyOwner {
       require(_addresses.length > 0);
       
      for (uint256 i = 0; i < _addresses.length; i++) {
            whiteList[_addresses[i]] = true;     
        }
        
      emit WhiteListManyEntry(_addresses, true);
  }
    
  function addToWhiteList(address _address) public onlyOwner {
      whiteList[_address] = true;  
      emit WhiteListSingleEntry(_address, true);  
  }
  
  function removeManyFromWhiteList(address[] _addresses) public onlyOwner {
       require(_addresses.length > 0);
       
      for (uint256 i = 0; i < _addresses.length; i++) {
            whiteList[_addresses[i]] = false;   
        }
          emit WhiteListManyEntry(_addresses, false);

  }
  
    function removeFromWhiteList(address _address) public onlyOwner {
       whiteList[_address] = false;  
       emit WhiteListSingleEntry(_address, false); 
  }


   /**
   * @dev Makes the sale dormant, no deposits are allowed
   */
  function pauseSale() public onlyOwner {
      require(state == State.Active);
      
      state = State.Dormant;
      emit DormantState();
  }
  
  /**
   * @dev Makes the sale active, thus funds can be received
   */
  function openSale() public onlyOwner {
      require(state == State.Dormant);
      
      state = State.Active;
      emit ActiveState();
  }
  
    /**
   * @dev Incase a problem arises, gives the owner to flush the contract
   */
  function emergencyFlush() public onlyOwner {
      token.transfer(owner,token.balanceOf(this));
  }
  
  /**
   *  @dev Returns the number of tokens in contract
   */
  function tokensAvailable() public view returns(uint256) {
      return token.balanceOf(this);
  }
  
  
  function weiRaised() public view returns(uint256) {
      return raisedWei;
  }
  
  function startTime() public view returns(uint256) {
      return startingTime;
  }
  
  function endTime() public view returns(uint256) {
      return endingTime;
  }
  
  function minCap() public view returns(uint256) {
      return softCap;
  }
  
  function cap() public view returns(uint256) {
      return hardCap;
  }
  
  function isItWhiteListed(address _address) public view returns(bool) {
      return whiteList[_address];
  }
  
  function returnLosersTokens(Token _tokenAddress, uint256 _amount,  address _loserAddress) public onlyOwner {
      _tokenAddress.transfer(balanceOf(this), _loserAddress);
 } 

}