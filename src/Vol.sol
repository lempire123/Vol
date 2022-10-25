// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/utils/math/SignedMath.sol";


/// @notice UniswapV2 pair interface
interface IUniswapV2Pair {
   function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
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
   IUniswapV2Pair pair;
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
   // usdc given to humble owner
   uint256 public ownerMoney;

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
      uint256 epochId;
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
      address _pair,
      address _token,
      address _usdc,
      uint256 _timeInterval,
      uint256 _bettingWindow
      )  {
         pair = IUniswapV2Pair(_pair);
         token = IERC20(_token);
         usdc = IERC20(_usdc);
         timeInterval = _timeInterval;
         bettingWindow = _bettingWindow;
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
      userPositions[epochId].push(Position(_amount, _vol, false, epochId, msg.sender));
   }


   // @notice Function allows anyone to claim their rewards if they're elligible
   // @param _epochIndex epoch to claim from
   function claim(uint256 _epochIndex) external {
      Epoch storage epoch = epochs[_epochIndex];
      require(epoch.status == Status.Ended);
      for(uint256 i; i < userPositions[_epochIndex].length; ++i) {
         if(userPositions[_epochIndex][i].user == msg.sender) {
            if(userPositions[_epochIndex][i].volPrediction == epoch.realizedVol) {
               if(userPositions[_epochIndex][i].claimedReward == false) {
                  uint256 totalPayOff = 
                     userPositions[_epochIndex][i].capitalProvided * epoch.payOffPerDollar;
                  userPositions[_epochIndex][i].claimedReward = true;
                  usdc.transfer(msg.sender, totalPayOff);
               }
            }
         }
      }
   }


   // @notice Function finalizes the epoch and starts the next one
   function finalizeEpoch() external {
      uint256 epochIndex = epochs.length - 1;
      Epoch storage epoch = epochs[epochIndex];
      require(epoch.startTime + timeInterval > block.timestamp);
      epoch.finalPrice = getPrice();
      epoch.status = Status.Ended;
      epoch.realizedVol = SignedMath.abs(int(epoch.startPrice - epoch.finalPrice)) / epoch.startPrice * 100;
      uint256 ITMCapital;
      for(uint256 i; i < userPositions[epochIndex].length; ++i) {
         if(userPositions[epochIndex][i].volPrediction == epoch.realizedVol) {
            ITMCapital += userPositions[epochIndex][i].capitalProvided;
         }
      }
      if(ITMCapital == 0) {
         ownerMoney += epoch.totalUsdc;
      }

      epoch.payOffPerDollar = epoch.totalUsdc / ITMCapital;
      epoch.status = Status.Ended;
      epochs.push(
         Epoch(
            epoch.startTime + timeInterval,
            epoch.finalPrice,
            0,
            0,
            0,
            0,
            Status.Active
            )
      );
   }


   // @notice Helper function to get current price of token.
   function getPrice() internal view returns (uint256) {
      (uint256 token1Amount, uint256 token2Amount, ) = pair.getReserves();
      uint256 token1Price = token2Amount / token1Amount;
      return token1Price;
   }

   // @notice Helper function to withdraw owner money.
   function withdrawMoney() external {
      require(msg.sender == owner, "ONLY_OWNER_CAN_CALL");
      usdc.transfer(msg.sender, ownerMoney);
      ownerMoney = 0;
   }





}
