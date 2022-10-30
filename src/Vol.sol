// SPDX-License-Identifier: UNLICENSED
pragma solidity  >=0.4.0 <0.9.0;

import "./Oracle.sol";

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }
}
   
/**
@title King of Vol
@author Lempire

@notice The following contract allows anyone to bet 
        on the volatily of any ERC20 token.
*/

contract Vol {
   using SignedMath for uint256;
   // UniswapV2pair used as oracle
   // IUniswapV2Pair public pair;
   // Token who's vol is being speculated on
   IERC20 public token;
   // Vol denomination
   IERC20 public usdc;
   // Time interval between epochs
   uint256 public timeInterval;
   // Window of time to bet on vol
   uint256 public bettingWindow;
   // Array of epochs
   Epoch[] public epochs;
   // Mapping of user positions to epoch Id
   mapping(uint256 => Position[]) public userPositions;
   // Owner address
   address public owner;
   // usdc decimals
   uint256 public usdcDecimals = 6;
   // Oracle
   UniswapV3Twap public oracle;

   // Status of each epoch
   enum Status {
      Active,
      Ended
   }

   // User position
   struct Position {
      uint256 capitalProvided;
      uint256 volPrediction;
      bool claimedReward;
      address user;
   }

   // Epoch for each time interval
   struct Epoch {
      uint256 startTime;
      uint256 startPrice;
      uint256 finalPrice;
      uint256 totalUsdc;
      uint256 realizedVol;
      uint256 payOffPerDollar;
      Status status;
   }

   // Constructor
   constructor(
      // address _pair,
      address _factory,
      address _token,
      address _usdc,
      uint24 _fee,
      address _owner,
      uint256 _timeInterval,
      uint256 _bettingWindow
   ) public {
      // pair = IUniswapV2Pair(_pair);
      token = IERC20(_token);
      usdc = IERC20(_usdc);
      timeInterval = _timeInterval;
      bettingWindow = _bettingWindow;
      owner = _owner;
      oracle = new UniswapV3Twap(_factory, _token, _usdc, _fee);
      init();
   }

   function init() internal {
      epochs.push(
         Epoch(
            block.timestamp,
            0,
            0,
            0,
            0,
            0,
            Status.Active
            )
      );
   }
   // @notice Function allows anyone to make a bet on the day's vol
   // @param _amount Amount of usdc to bet
   // @param _vol percentage move expected
   function bet(uint256 _amount, uint256 _vol) external {
      uint256 epochId = epochs.length - 1;
      Epoch storage currentEpoch = epochs[epochId];
      require(block.timestamp < currentEpoch.startTime + bettingWindow);
      usdc.transferFrom(msg.sender, address(this), _amount);
      currentEpoch.totalUsdc += _amount;
      userPositions[epochId].push(Position(_amount, _vol, false, msg.sender));
   }


   // @notice Function allows anyone to claim their rewards if they're elligible
   // @param _epochIndex epoch to claim from
   function claim(uint256 _epochIndex) external {
      Epoch storage epoch = epochs[_epochIndex];
      require(epoch.status == Status.Ended);
      uint256 totalPayOff;
      for(uint256 i; i < userPositions[_epochIndex].length; ++i) {
         if(userPositions[_epochIndex][i].user == msg.sender) {
            if(userPositions[_epochIndex][i].volPrediction == epoch.realizedVol) {
               if(userPositions[_epochIndex][i].claimedReward == false) {
                  uint256 payoff = 
                     userPositions[_epochIndex][i].capitalProvided * epoch.payOffPerDollar;
                  userPositions[_epochIndex][i].claimedReward = true;
                  totalPayOff += payoff;
               }
            }
         }
      }
      usdc.transfer(msg.sender, totalPayOff);
   }


   // @notice Function finalizes the epoch and starts the next one
   function finalizeEpoch() external {
      uint256 epochIndex = epochs.length - 1;
      Epoch storage epoch = epochs[epochIndex];
      require(epoch.startTime + timeInterval <= block.timestamp);
      epoch.finalPrice = getPrice();
      epoch.status = Status.Ended;
      epoch.realizedVol = 
         epoch.startPrice > epoch.finalPrice ? 
            ((epoch.startPrice - epoch.finalPrice) * 100) / epoch.startPrice: 
            ((epoch.finalPrice - epoch.startPrice) * 100) / epoch.startPrice;
      uint256 ITMCapital;
      for(uint256 i; i < userPositions[epochIndex].length; ++i) {
         if(userPositions[epochIndex][i].volPrediction == epoch.realizedVol) {
            ITMCapital += userPositions[epochIndex][i].capitalProvided;
         }
      }
      if(ITMCapital == 0) {
         if (userPositions[epochIndex].length - 1 >= 10) {
            usdc.transfer(owner, epoch.totalUsdc);
            epoch.payOffPerDollar = 0;
         } else {
             epoch.payOffPerDollar = 1;
         } 
      } else {
         epoch.payOffPerDollar = epoch.totalUsdc / ITMCapital;
      }
      epoch.status = Status.Ended;
      epochs.push(
         Epoch(
            epoch.startTime + timeInterval,
            0,
            0,
            0,
            0,
            0,
            Status.Active
            )
      );
   }


   // @notice Function is called after bettingWindow is over - sets initial price
   function setStartPrice() external {
      uint256 epochIndex = epochs.length - 1;
      Epoch storage epoch = epochs[epochIndex];
      require(epoch.startTime + bettingWindow <= block.timestamp);
      epoch.startPrice = getPrice();
   }

   // @notice Helper function to get current price of token.
   function getPrice() internal view returns (uint256) {
      return uint256(oracle.estimateAmountOut(address(token), uint128(10 ** token.decimals()), 120));
   }
}
