// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.0 <0.9.0;

import "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "v3-periphery/libraries/OracleLibrary.sol";

contract UniswapV3Twap {
    address public immutable token0;
    address public immutable token1;
    address public immutable pool;

    constructor(address _factory, address _token0, address _token1, uint24 _fee) public {
        token0 = _token0;
        token1 = _token1;

        address _pool = IUniswapV3Factory(_factory).getPool(_token0, _token1, _fee);
        require(_pool != address(0), "pool doesn't exist");
        pool = _pool;
    }

    function estimateAmountOut(address tokenIn, uint128 amountIn, uint32 secondsAgo)
        external
        view
        returns (uint256 amountOut)
    {
        require(tokenIn == token0 || tokenIn == token1, "invalid token");
        address tokenOut = tokenIn == token0 ? token1 : token0;
        (int24 tick,) = OracleLibrary.consult(pool, secondsAgo);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, tokenIn, tokenOut);
    }
}
